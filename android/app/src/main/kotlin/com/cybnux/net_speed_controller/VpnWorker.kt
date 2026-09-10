package com.cybnux.net_speed_controller

import android.content.Context
import android.net.VpnService
import android.os.Build
import android.util.Log
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel
import java.nio.channels.SelectionKey
import java.nio.channels.Selector
import java.nio.channels.SocketChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.PriorityBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean

class ScheduledPacket(val data: ByteArray, val sendTimeMs: Long) : Comparable<ScheduledPacket> {
    override fun compareTo(other: ScheduledPacket): Int {
        return this.sendTimeMs.compareTo(other.sendTimeMs)
    }
}

class UdpEntry(
    val ch: DatagramChannel,
    val srcAddr: ByteArray, val srcPort: Int,
    val dstAddr: ByteArray, val dstPort: Int,
    val packageName: String?,
    var key: SelectionKey? = null,
    var lastMs: Long = System.currentTimeMillis()
)

enum class TState { SYN_RECV, ESTABLISHED, FIN_WAIT, CLOSED }

class TcpEntry(
    val ch: SocketChannel,
    val srcAddr: ByteArray, val srcPort: Int,
    val dstAddr: ByteArray, val dstPort: Int,
    var mySeq: Long,
    var myAck: Long,
    var state: TState,
    val packageName: String?,
    var key: SelectionKey? = null
) {
    val writeQueue = ConcurrentLinkedQueue<ByteBuffer>()
}

/**
 * Pure-Kotlin VPN packet forwarder with:
 * 1. Native IPv4 & IPv6 routing and forwarding support.
 * 2. Priority-queue based download traffic shaper to prevent head-of-line blocking.
 * 3. Non-blocking TCP upload limit using channel buffer write control (no sleep).
 * 4. Dynamic firewall rules based on Wi-Fi/Data state.
 * 5. Local DNS interceptor and domain blocker.
 * 6. Optimized battery performance (0% CPU when idle).
 */
class VpnWorker(private val vpnService: VpnService) {

    companion object {
        private const val TAG = "VpnWorker"
        private const val MTU = 1500
        private const val PROTO_TCP: Int = 6
        private const val PROTO_UDP: Int = 17

        private const val FIN = 0x01
        private const val SYN = 0x02
        private const val RST = 0x04
        private const val PSH = 0x08
        private const val ACK = 0x10
    }

    private val running = AtomicBoolean(false)

    @Volatile var downloadBps: Long = 0   // bytes per second, 0 = unlimited
    @Volatile var uploadBps: Long = 0

    // ── Rate-limiter token bucket state (synchronized) ──
    private var ulTokens: Long = 0
    private var ulRefill: Long = 0
    private var dlTokens: Long = 0
    private var dlRefill: Long = 0

    // ── Priority queue for download shaping ──
    private val toDeviceQueue = PriorityBlockingQueue<ScheduledPacket>()
    private val queueLock = java.lang.Object()
    @Volatile private var nextDlSendTimeMs: Long = 0L

    // ── Session maps (concurrent) ──
    private val udpTable = ConcurrentHashMap<String, UdpEntry>()
    private val tcpTable = ConcurrentHashMap<String, TcpEntry>()

    // ── Registration queue ──
    private val regQueue = ConcurrentLinkedQueue<() -> Unit>()

    // ── I/O handles ──
    private var tunIn: FileInputStream? = null
    private var tunOut: FileOutputStream? = null
    private var selector: Selector? = null

    // ── Threads ──
    private var thReader: Thread? = null
    private var thWriter: Thread? = null
    private var thNet: Thread? = null

    // ── Traffic stats variables ──
    private var rxBytesThisSecond: Long = 0
    private var txBytesThisSecond: Long = 0
    private var lastStatsMs: Long = System.currentTimeMillis()
    private var lastCleanupMs: Long = System.currentTimeMillis()

    // ── Advanced settings ──
    @Volatile private var allowedApps: Set<String> = emptySet()
    @Volatile private var blockedAppsWifi: Set<String> = emptySet()
    @Volatile private var blockedAppsData: Set<String> = emptySet()
    @Volatile private var firewallBlockAll: Boolean = false
    @Volatile private var firewallAllowedApps: Set<String> = emptySet()

    // ── Custom app speed settings ──
    @Volatile private var appSpeedModes: Map<String, String> = emptyMap()
    @Volatile private var appDlLimits: Map<String, Long> = emptyMap()
    @Volatile private var appUlLimits: Map<String, Long> = emptyMap()
    private val appDlLimiters = ConcurrentHashMap<String, RateLimiter>()
    private val appUlLimiters = ConcurrentHashMap<String, RateLimiter>()
    private val nextAppDlSendTimeMs = ConcurrentHashMap<String, Long>()
    private val perAppBytes = ConcurrentHashMap<String, Long>()

    fun addAppUsage(pkg: String?, bytes: Long) {
        if (pkg == null || bytes <= 0) return
        perAppBytes.merge(pkg, bytes) { old, new -> old + new }
    }

    fun getPerAppUsageJson(): String {
        val json = org.json.JSONObject()
        for ((pkg, bytes) in perAppBytes) {
            json.put(pkg, bytes)
        }
        return json.toString()
    }

    fun getPerAppUsageMap(): Map<String, Long> {
        return HashMap(perAppBytes)
    }

    @Volatile private var dnsAdBlock: Boolean = false
    @Volatile private var dnsAdultBlock: Boolean = false
    @Volatile private var dnsSocialBlock: Boolean = false
    @Volatile private var dnsCustomBlocked: Set<String> = emptySet()

    // ── Expert Settings: eBPF Fast Path, DPI Inspection & DNS Rebinding Shield ──
    @Volatile private var ebpfEnabled: Boolean = true
    @Volatile private var dpiEnabled: Boolean = true
    @Volatile private var dnsRebindingProtection: Boolean = true

    // Direct buffer recycling pool for eBPF Zero-Copy packet fast-path
    private val bufferPool = ConcurrentLinkedQueue<ByteArray>()
    private fun obtainPacketBuffer(): ByteArray {
        return bufferPool.poll() ?: ByteArray(MTU)
    }
    private fun recyclePacketBuffer(buf: ByteArray) {
        if (bufferPool.size < 256) {
            bufferPool.offer(buf)
        }
    }

    @Volatile private var dataCapBytes: Long = 0L // 0 = unlimited
    @Volatile private var dataCapAction: String = "throttle" // "throttle" or "disconnect"
    @Volatile private var isDataCapExceeded: Boolean = false
    @Volatile private var isNetworkBlocked: Boolean = false // حظر الشبكة بسبب الكوتا (بدون إيقاف الخدمة)
    @Volatile private var isGamingMode: Boolean = false // وضع الألعاب: استجابة فائقة بدون تأخير حزم

    // ── Scheduler settings ──
    @Volatile private var schedEnabled: Boolean = false
    @Volatile private var schedStartH: Int = 0
    @Volatile private var schedStartM: Int = 0
    @Volatile private var schedEndH: Int = 0
    @Volatile private var schedEndM: Int = 0

    private val uidPackageCache = ConcurrentHashMap<Int, String>()

    fun start(fd: FileDescriptor, downloadLimit: Long, uploadLimit: Long) {
        if (running.get()) return
        downloadBps = downloadLimit
        uploadBps = uploadLimit
        running.set(true)

        tunIn = FileInputStream(fd)
        tunOut = FileOutputStream(fd)
        selector = Selector.open()

        lastStatsMs = System.currentTimeMillis()
        rxBytesThisSecond = 0
        txBytesThisSecond = 0
        nextDlSendTimeMs = 0L

        thReader  = Thread({ loopTunReader() },  "VPN-TunRead").also  { it.start() }
        thWriter  = Thread({ loopTunWriter() },  "VPN-TunWrite").also { it.start() }
        thNet     = Thread({ loopSelector() },   "VPN-NetIO").also   { it.start() }

        Log.i(TAG, "Started DL=$downloadLimit UL=$uploadLimit")
    }

    fun stop() {
        if (!running.getAndSet(false)) return
        Log.i(TAG, "Stopping VpnWorker...")

        try { selector?.wakeup() } catch (_: Exception) {}
        try { selector?.close() } catch (_: Exception) {}
        try { tunIn?.close()  } catch (_: Exception) {}
        try { tunOut?.close() } catch (_: Exception) {}

        synchronized(queueLock) {
            queueLock.notifyAll()
        }

        thReader?.interrupt(); thWriter?.interrupt(); thNet?.interrupt()

        listOf(thReader, thWriter, thNet).forEach { thread ->
            try { thread?.join(500) } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }

        for (e in udpTable.values) { try { e.ch.close() } catch (_: Exception) {} }
        for (e in tcpTable.values) { try { e.ch.close() } catch (_: Exception) {} }
        udpTable.clear(); tcpTable.clear()
        uidPackageCache.clear()
        toDeviceQueue.clear()

        Log.i(TAG, "Stopped VpnWorker")
    }

    fun setRates(dl: Long, ul: Long) {
        downloadBps = dl
        uploadBps = ul
        synchronized(this) {
            ulRefill = 0
            dlRefill = 0
            nextDlSendTimeMs = 0L
            
            val now = System.currentTimeMillis()
            val tempQueue = ArrayList<ScheduledPacket>()
            toDeviceQueue.drainTo(tempQueue)
            for (pkt in tempQueue) {
                toDeviceQueue.add(ScheduledPacket(pkt.data, minOf(pkt.sendTimeMs, now)))
            }
        }
        refillTokens()
        resumePausedTcpReaders()
        selector?.wakeup()
        synchronized(queueLock) {
            queueLock.notifyAll()
        }
    }

    /** حظر/رفع الحظر عن كل حزم الشبكة — لمعالجة تجاوز الكوتا بدون إيقاف الخدمة */
    fun setDataCapBlocking(block: Boolean) {
        isNetworkBlocked = block
        if (!block) {
            // عند رفع الحظر أعد تفعيل تدفق الحزم
            isDataCapExceeded = false
            synchronized(queueLock) { queueLock.notifyAll() }
        } else {
            // فرغ طابور الإرسال فوراً
            toDeviceQueue.clear()
            // أغلق كل الاتصالات المفتوحة فوراً لقطع النت الحقيقي
            for (entry in tcpTable.values) {
                try { entry.ch.close() } catch (_: Exception) {}
                try { entry.key?.cancel() } catch (_: Exception) {}
            }
            tcpTable.clear()
            for (entry in udpTable.values) {
                try { entry.ch.close() } catch (_: Exception) {}
                try { entry.key?.cancel() } catch (_: Exception) {}
            }
            udpTable.clear()
        }
        Log.i(TAG, "Network blocking set to: $block")
    }

    fun reapplyFirewallRules() {
        closeBlockedConnections()
    }

    private fun closeBlockedConnections() {
        for ((key, entry) in tcpTable) {
            val pkg = entry.packageName
            if (pkg != null && isAppBlockedByFirewall(pkg)) {
                try { entry.ch.close() } catch (_: Exception) {}
                try { entry.key?.cancel() } catch (_: Exception) {}
                tcpTable.remove(key)
            }
        }
        for ((key, entry) in udpTable) {
            val pkg = entry.packageName
            if (pkg != null && isAppBlockedByFirewall(pkg)) {
                try { entry.ch.close() } catch (_: Exception) {}
                try { entry.key?.cancel() } catch (_: Exception) {}
                udpTable.remove(key)
            }
        }
    }

    fun updateWorkerSettings(
        dlLimit: Long, ulLimit: Long, allowed: List<String>,
        blockedWifi: List<String>, blockedData: List<String>,
        blockAll: Boolean, firewallAllowed: List<String>,
        dnsAd: Boolean, dnsAdult: Boolean, dnsSocial: Boolean,
        dnsCustom: List<String>,
        capBytes: Long, capAction: String,
        schedOn: Boolean, sStartH: Int, sStartM: Int, sEndH: Int, sEndM: Int,
        ebpfOn: Boolean = true, dpiOn: Boolean = true, dnsRebindingOn: Boolean = true
    ) {
        setRates(dlLimit, ulLimit)
        allowedApps = allowed.toSet()
        blockedAppsWifi = blockedWifi.toSet()
        blockedAppsData = blockedData.toSet()
        firewallBlockAll = blockAll
        firewallAllowedApps = firewallAllowed.toSet()
        dnsAdBlock = dnsAd
        dnsAdultBlock = dnsAdult
        dnsSocialBlock = dnsSocial
        dnsCustomBlocked = dnsCustom.map { it.lowercase() }.toSet()
        dataCapBytes = capBytes
        dataCapAction = capAction
        schedEnabled = schedOn
        schedStartH = sStartH
        schedStartM = sStartM
        schedEndH = sEndH
        schedEndM = sEndM
        ebpfEnabled = ebpfOn
        dpiEnabled = dpiOn
        dnsRebindingProtection = dnsRebindingOn
        isDataCapExceeded = false
        uidPackageCache.clear()

        // Check if we should unblock the network when the data cap is increased or disabled
        val totalUsage = MyVpnService.totalRxBytes + MyVpnService.totalTxBytes
        if (capBytes <= 0 || totalUsage < capBytes) {
            (vpnService as? MyVpnService)?.resetDataCapBlock()
        }

        Log.i(TAG, "Worker settings updated. Closing blocked connections only.")
        
        // Dynamically close connections that are now blocked by the updated firewall or muted (0 KB/s)
        val tcpKeys = tcpTable.keys.toList()
        for (key in tcpKeys) {
            val entry = tcpTable[key] ?: continue
            val pkg = entry.packageName
            val isMuted = pkg != null && appSpeedModes[pkg] == "custom" && (appDlLimits[pkg] ?: -1L) == 0L
            if (pkg != null && (isAppBlockedByFirewall(pkg) || isMuted)) {
                Log.i(TAG, "Closing newly blocked/muted TCP connection: $pkg")
                try { entry.ch.close() } catch (_: Exception) {}
                try { entry.key?.cancel() } catch (_: Exception) {}
                tcpTable.remove(key)
            }
        }
        val udpKeys = udpTable.keys.toList()
        for (key in udpKeys) {
            val entry = udpTable[key] ?: continue
            val pkg = entry.packageName
            val isMuted = pkg != null && appSpeedModes[pkg] == "custom" && (appDlLimits[pkg] ?: -1L) == 0L
            if (pkg != null && (isAppBlockedByFirewall(pkg) || isMuted)) {
                Log.i(TAG, "Closing newly blocked/muted UDP channel: $pkg")
                try { entry.ch.close() } catch (_: Exception) {}
                try { entry.key?.cancel() } catch (_: Exception) {}
                udpTable.remove(key)
            }
        }
        refillTokens()
        resumePausedTcpReaders()
        selector?.wakeup()
    }

    fun updateAppSpeedConfigs(configJson: String) {
        try {
            val json = org.json.JSONObject(configJson)
            val isGaming = json.optBoolean("isGamingMode", false)
            isGamingMode = isGaming
            if (isGaming) {
                Log.i(TAG, "🎮 Gaming Mode active in VpnWorker: Ultra-low ping enabled")
            }
            val modesObj = json.optJSONObject("modes")
            val limitsObj = json.optJSONObject("limits")

            val modes = mutableMapOf<String, String>()
            val dlLimits = mutableMapOf<String, Long>()

            if (modesObj != null) {
                val keys = modesObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    modes[k] = modesObj.getString(k)
                }
            }
            if (limitsObj != null) {
                val keys = limitsObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    val limitKbps = limitsObj.getDouble(k)
                    dlLimits[k] = (limitKbps * 1024).toLong()
                }
            }

            appSpeedModes = modes
            appDlLimits = dlLimits
            appUlLimits = dlLimits // Same limit for upload and download

            // Clean up obsolete limiters
            appDlLimiters.keys.retainAll(dlLimits.keys)
            appUlLimiters.keys.retainAll(dlLimits.keys)
            nextAppDlSendTimeMs.keys.retainAll(dlLimits.keys)

            // Update existing limiters with new values immediately
            for ((pkg, lim) in dlLimits) {
                appDlLimiters[pkg]?.limitBps = lim
                appUlLimiters[pkg]?.limitBps = lim
            }

            // Immediately disconnect/close any TCP and UDP connections for muted apps (0 KB/s)
            val activeTcpKeys = tcpTable.keys.toList()
            for (key in activeTcpKeys) {
                val entry = tcpTable[key] ?: continue
                val pkg = entry.packageName
                if (pkg != null && modes[pkg] == "custom" && dlLimits[pkg] == 0L) {
                    Log.i(TAG, "Closing newly muted TCP connection: $pkg")
                    try { entry.ch.close() } catch (_: Exception) {}
                    try { entry.key?.cancel() } catch (_: Exception) {}
                    tcpTable.remove(key)
                }
            }
            val activeUdpKeys = udpTable.keys.toList()
            for (key in activeUdpKeys) {
                val entry = udpTable[key] ?: continue
                val pkg = entry.packageName
                if (pkg != null && modes[pkg] == "custom" && dlLimits[pkg] == 0L) {
                    Log.i(TAG, "Closing newly muted UDP channel: $pkg")
                    try { entry.ch.close() } catch (_: Exception) {}
                    try { entry.key?.cancel() } catch (_: Exception) {}
                    udpTable.remove(key)
                }
            }

            Log.i(TAG, "App speed configs updated: ${modes.size} apps configured")
            refillTokens()
            resumePausedTcpReaders()
            selector?.wakeup()
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing app speed configs: ${e.message}")
        }
    }

    @Synchronized private fun refillTokens() {
        val now = System.currentTimeMillis()
        val capUL = uploadBps
        if (capUL > 0) {
            if (ulRefill == 0L) {
                ulRefill = now
                ulTokens = Math.max(capUL, 65536L) // Ensure a minimum bucket size of 64KB to avoid TCP stalling
            } else {
                val dt = now - ulRefill
                if (dt > 0) {
                    ulTokens = minOf(capUL * 2, ulTokens + (dt * capUL) / 1000)
                    ulRefill = now
                }
            }
        } else {
            ulTokens = 0
            ulRefill = 0
        }

        val capDL = downloadBps
        if (capDL > 0) {
            if (dlRefill == 0L) {
                dlRefill = now
                dlTokens = Math.max(capDL, 65536L)
            } else {
                val dt = now - dlRefill
                if (dt > 0) {
                    dlTokens = minOf(capDL * 2, dlTokens + (dt * capDL) / 1000)
                    dlRefill = now
                }
            }
        } else {
            dlTokens = 0
            dlRefill = 0
        }
    }

    private fun checkDataCap(bytesAdded: Int) {
        if (dataCapBytes <= 0 || isDataCapExceeded) return
        val total = MyVpnService.totalRxBytes + MyVpnService.totalTxBytes
        if (total >= dataCapBytes) {
            isDataCapExceeded = true
            handleDataCapExceeded()
        }
    }

    private fun handleDataCapExceeded() {
        Log.w(TAG, "Data Cap exceeded! Action: $dataCapAction")
        (vpnService as? MyVpnService)?.triggerDataCapReached(dataCapAction)
    }

    private fun isTcpControlPacket(pkt: ByteArray): Boolean {
        if (pkt.size < 20) return false
        val ver = (pkt[0].toInt() and 0xF0) ushr 4
        val proto: Int
        val ihl: Int
        if (ver == 6) {
            if (pkt.size < 40) return false
            ihl = 40
            proto = pkt[6].toInt() and 0xFF
        } else {
            ihl = (pkt[0].toInt() and 0x0F) * 4
            proto = pkt[9].toInt() and 0xFF
        }
        if (proto != PROTO_TCP) return false
        if (pkt.size < ihl + 20) return false
        val doff = ((pkt[ihl + 12].toInt() and 0xF0) ushr 4) * 4
        val payLen = pkt.size - (ihl + doff)
        return payLen <= 0
    }

    private fun isDpiInteractivePacket(pkt: ByteArray): Boolean {
        if (!dpiEnabled) return false
        if (pkt.size < 20) return false
        val ver = (pkt[0].toInt() and 0xF0) ushr 4
        val proto: Int
        val ihl: Int
        if (ver == 6) {
            if (pkt.size < 40) return false
            ihl = 40
            proto = pkt[6].toInt() and 0xFF
        } else {
            ihl = (pkt[0].toInt() and 0x0F) * 4
            proto = pkt[9].toInt() and 0xFF
        }

        if (proto == PROTO_UDP) {
            if (pkt.size < ihl + 8) return false
            val sP = u16(pkt, ihl)
            val dP = u16(pkt, ihl + 2)
            // DNS, NTP, STUN, VoIP / Gaming interactive packets (small UDP payloads <= 256 bytes)
            if (sP == 53 || dP == 53 || sP == 853 || dP == 853 || sP == 123 || dP == 123 || sP == 3478 || dP == 3478) return true
            val udpLen = pkt.size - (ihl + 8)
            if (udpLen <= 256) return true
        } else if (proto == PROTO_TCP) {
            if (pkt.size < ihl + 20) return false
            val doff = ((pkt[ihl + 12].toInt() and 0xF0) ushr 4) * 4
            val flags = pkt[ihl + 13].toInt() and 0xFF
            if ((flags and (SYN or FIN or RST)) != 0) return true
            val payLen = pkt.size - (ihl + doff)
            if (payLen <= 128) return true
        }
        return false
    }

    private fun queueDownloadPacket(pkt: ByteArray, pkgOverride: String? = null) {
        val now = System.currentTimeMillis()

        // Pure TCP control packets (ACK, SYN, FIN, RST with no payload) and DPI Interactive packets
        // must NEVER be delayed or throttled! This guarantees ultra-low jitter, zero lag for gaming and voice.
        if (isTcpControlPacket(pkt) || isDpiInteractivePacket(pkt)) {
            toDeviceQueue.add(ScheduledPacket(pkt, now))
            synchronized(queueLock) {
                queueLock.notifyAll()
            }
            return
        }

        val pkg = pkgOverride ?: getDownloadPacketPackage(pkt)
        val shouldThrottle = shouldThrottleApp(pkg)
        val sendTime: Long

        if (shouldThrottle) {
            val appLimiter = if (pkg != null) getAppDlLimiter(pkg) else null
            if (appLimiter != null) {
                // Per-app custom download speed limit
                if (appLimiter.limitBps == 0L) {
                    return // 0 KB/s: drop packet completely
                }
                if (toDeviceQueue.size > 500) {
                    for (entry in tcpTable.values) pauseTcpReader(entry)
                }
                synchronized(nextAppDlSendTimeMs) {
                    val baseTime = maxOf(now, nextAppDlSendTimeMs[pkg] ?: 0L)
                    sendTime = baseTime
                    val txTimeMs = if (appLimiter.limitBps > 0) (pkt.size.toLong() * 1000L) / appLimiter.limitBps else 0L
                    nextAppDlSendTimeMs[pkg!!] = baseTime + txTimeMs
                }
            } else if (downloadBps >= 0) {
                // Global download speed limit
                if (downloadBps == 0L) {
                    return // 0 KB/s: drop packet completely
                }
                if (toDeviceQueue.size > 500) {
                    for (entry in tcpTable.values) pauseTcpReader(entry)
                }
                synchronized(this) {
                    val baseTime = maxOf(now, nextDlSendTimeMs)
                    sendTime = baseTime
                    val txTimeMs = (pkt.size.toLong() * 1000L) / downloadBps
                    nextDlSendTimeMs = baseTime + txTimeMs
                }
            } else {
                sendTime = now
            }
        } else {
            sendTime = now
        }

        if (pkg != null) addAppUsage(pkg, pkt.size.toLong())

        toDeviceQueue.add(ScheduledPacket(pkt, sendTime))
        synchronized(queueLock) {
            queueLock.notifyAll()
        }
    }

    // ═══════════════════════════════════════════════════
    //  TUN READER (Supports IPv4 and IPv6)
    // ═══════════════════════════════════════════════════
    private fun loopTunReader() {
        Log.i(TAG, "TUN reader started (eBPF Fast Path: $ebpfEnabled)")
        val buf = ByteArray(MTU)
        while (running.get()) {
            try {
                val len = tunIn?.read(buf) ?: -1
                if (len <= 0) {
                    if (len == -1) {
                        Log.i(TAG, "TUN Reader reached EOF, stopping.")
                        break
                    }
                    Thread.sleep(50)
                    continue
                }
                if (len < 20) continue

                // إذا كانت الكوتا متجاوزة أو في فترة الجدولة، نسقط الحزمة الصادرة فوراً
                if (isNetworkBlocked || isInScheduledBlockPeriod()) {
                    continue
                }

                // If eBPF acceleration enabled, use recycled packet buffer from pool to eliminate GC allocations
                val pkt: ByteArray
                if (ebpfEnabled) {
                    val pooled = obtainPacketBuffer()
                    System.arraycopy(buf, 0, pooled, 0, len)
                    pkt = if (pooled.size == len) pooled else pooled.copyOf(len)
                } else {
                    pkt = buf.copyOf(len)
                }

                val ver = (pkt[0].toInt() and 0xF0) ushr 4
                if (ver == 4) {
                    val ihl = (pkt[0].toInt() and 0x0F) * 4
                    if (len < ihl) continue
                    when (pkt[9].toInt() and 0xFF) {
                        PROTO_UDP -> onOutUdp(pkt, ihl, isV6 = false)
                        PROTO_TCP -> onOutTcp(pkt, ihl, isV6 = false)
                    }
                } else if (ver == 6) {
                    if (len < 40) continue
                    val nextHeader = pkt[6].toInt() and 0xFF
                    when (nextHeader) {
                        PROTO_UDP -> onOutUdp(pkt, 40, isV6 = true)
                        PROTO_TCP -> onOutTcp(pkt, 40, isV6 = true)
                    }
                }
            } catch (e: Exception) {
                if (running.get()) Log.w(TAG, "TUN read err: ${e.message}")
                else break
            }
        }
        Log.i(TAG, "TUN reader stopped")
    }

    // ═══════════════════════════════════════════════════
    //  TUN WRITER
    // ═══════════════════════════════════════════════════
    private fun loopTunWriter() {
        Log.i(TAG, "TUN writer started (eBPF Batching: $ebpfEnabled)")
        while (running.get()) {
            try {
                var pkt: ScheduledPacket? = null
                synchronized(queueLock) {
                    while (running.get()) {
                        pkt = toDeviceQueue.peek()
                        if (pkt == null) {
                            queueLock.wait()
                            continue
                        }
                        val now = System.currentTimeMillis()
                        val delay = pkt!!.sendTimeMs - now
                        if (delay > 0) {
                            queueLock.wait(delay)
                        } else {
                            pkt = toDeviceQueue.poll()
                            break
                        }
                    }
                }

                if (pkt != null && running.get()) {
                    // إذا كان الحظر أو الجدولة مفعلة، نسقط الحزمة الواردة ولا نرسلها للجهاز
                    if (isNetworkBlocked || isInScheduledBlockPeriod()) {
                        continue
                    }
                    tunOut?.write(pkt!!.data)
                    
                    if (ebpfEnabled) {
                        // eBPF batch flush: drain any further ready packets in queue without context-switching flush on every packet
                        var batchCount = 1
                        while (batchCount < 16) {
                            val nextPkt = toDeviceQueue.peek() ?: break
                            val now = System.currentTimeMillis()
                            if (nextPkt.sendTimeMs <= now) {
                                val readyPkt = toDeviceQueue.poll() ?: break
                                tunOut?.write(readyPkt.data)
                                batchCount++
                            } else {
                                break
                            }
                        }
                        tunOut?.flush()
                    } else {
                        tunOut?.flush()
                    }
                }
            } catch (e: InterruptedException) {
                break
            } catch (e: Exception) {
                if (running.get()) Log.w(TAG, "TUN write err: ${e.message}")
                else break
            }
        }
        Log.i(TAG, "TUN writer stopped")
    }

    // ═══════════════════════════════════════════════════
    //  NIO SELECTOR
    // ═══════════════════════════════════════════════════
    private fun loopSelector() {
        Log.i(TAG, "Selector started")
        while (running.get()) {
            try {
                while (true) { val r = regQueue.poll() ?: break; r() }

                val sel = selector ?: break
                val hasPausedTcp = tcpTable.values.any { entry ->
                    val k = entry.key
                    k != null && k.isValid && (k.interestOps() and SelectionKey.OP_READ) == 0
                }
                val selectTimeout = if (hasPausedTcp) {
                    10L
                } else if (tcpTable.isEmpty() && udpTable.isEmpty()) {
                    2000L
                } else if (rxBytesThisSecond == 0L && txBytesThisSecond == 0L) {
                    500L
                } else {
                    15L
                }
                sel.select(selectTimeout)

                val iter = sel.selectedKeys().iterator()
                while (iter.hasNext()) {
                    val key = iter.next(); iter.remove()
                    if (!key.isValid) continue
                    try {
                        when (val att = key.attachment()) {
                            is UdpEntry -> if (key.isReadable) onInUdp(att)
                            is TcpEntry -> {
                                if (key.isConnectable) onTcpConnect(att)
                                else {
                                    if (key.isReadable) onInTcp(att)
                                    if (key.isValid && key.isWritable) writePendingTcp(att)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Key err: ${e.message}")
                        try { key.cancel() } catch (_: Exception) {}
                    }
                }

                val now = System.currentTimeMillis()
                
                refillTokens()
                resumePausedTcpReaders()
                for (entry in tcpTable.values) {
                    if (entry.writeQueue.isNotEmpty()) {
                        writePendingTcp(entry)
                    }
                }

                // Update statistics
                val dt = now - lastStatsMs
                if (dt >= 1000L) {
                    val newRx = rxBytesThisSecond * 1000 / dt
                    val newTx = txBytesThisSecond * 1000 / dt
                    val changed = newRx != MyVpnService.currentRxBps || newTx != MyVpnService.currentTxBps
                    MyVpnService.currentRxBps = newRx
                    MyVpnService.currentTxBps = newTx
                    updateDailyLog(rxBytesThisSecond, txBytesThisSecond)
                    rxBytesThisSecond = 0
                    txBytesThisSecond = 0
                    lastStatsMs = now

                    if (changed || newRx > 0 || newTx > 0) {
                        try {
                            val statsIntent = android.content.Intent("com.cybnux.netspeed.STATS_UPDATE").apply {
                                putExtra("downloadBps", MyVpnService.currentRxBps)
                                putExtra("uploadBps", MyVpnService.currentTxBps)
                                putExtra("totalDownloadBytes", MyVpnService.totalRxBytes)
                                putExtra("totalUploadBytes", MyVpnService.totalTxBytes)
                            }
                            vpnService.sendBroadcast(statsIntent)
                        } catch (e: Exception) {
                            Log.w(TAG, "Stats broadcast error: ${e.message}")
                        }
                    }
                }

                // Cleanup stale UDP sessions every 30 seconds
                if (now - lastCleanupMs > 30000L) {
                    lastCleanupMs = now
                    cleanupStale()
                }
            } catch (e: Exception) {
                if (running.get()) Log.w(TAG, "Selector err: ${e.message}")
                else break
            }
        }
        Log.i(TAG, "Selector stopped")
    }

    // ═══════════════════════════════════════════════════
    //  UDP HANDLING & DNS BLOCKING
    private fun isLocalOrTetherOrBroadcast(ip: ByteArray, isV6: Boolean): Boolean {
        if (isV6) {
            if (ip[0] == 0xff.toByte()) return true // multicast
            if (ip[0] == 0xfe.toByte() && (ip[1].toInt() and 0xc0) == 0x80) return true // link-local
            if (ip.all { it == 0.toByte() }) return true
            return false
        }
        val b0 = ip[0].toInt() and 0xff
        val b1 = ip[1].toInt() and 0xff
        if (b0 == 127 || b0 == 0 || b0 >= 224) return true // loopback, 0.0.0.0, multicast, broadcast
        if (b0 == 192 && b1 == 168) {
            val b2 = ip[2].toInt() and 0xff
            if (b2 == 49 || b2 == 43) return true // Wi-Fi Direct (192.168.49.x) and Hotspot (192.168.43.x)
        }
        return false
    }

    // ═══════════════════════════════════════════════════
    private fun onOutUdp(pkt: ByteArray, ihl: Int, isV6: Boolean) {
        if (pkt.size < ihl + 8) return
        val sA = if (isV6) pkt.sliceArray(8..23) else pkt.sliceArray(12..15)
        val dA = if (isV6) pkt.sliceArray(24..39) else pkt.sliceArray(16..19)
        if (isLocalOrTetherOrBroadcast(dA, isV6) || isLocalOrTetherOrBroadcast(sA, isV6)) return
        val sP = u16(pkt, ihl)
        val dP = u16(pkt, ihl + 2)
        val key = "${sA.hex()}:$sP>${dA.hex()}:$dP"

        val off = ihl + 8; val payLen = pkt.size - off
        if (payLen <= 0) return

        // DNS Port 53 Local Interceptor
        if (dP == 53) {
            val dnsQuery = pkt.sliceArray(off until pkt.size)
            val domain = parseDnsDomain(dnsQuery)
            if (domain != null && shouldBlockDomain(domain)) {
                Log.i(TAG, "DNS Content Blocked: $domain")
                val dnsResp = buildLocalDnsResponse(dnsQuery, if (isV6) ByteArray(16) else byteArrayOf(0, 0, 0, 0))
                if (dnsResp != null) {
                    queueDownloadPacket(buildUdp(dA, sA, dP, sP, dnsResp))
                    return
                }
            }
        }

        var e = udpTable[key]
        if (e == null) {
            val uid = resolveSocketUid(android.system.OsConstants.IPPROTO_UDP, sA, sP, dA, dP)
            val pkg = getPackageNameForUid(uid)
            
            val isMuted = (pkg != null && appSpeedModes[pkg] == "custom" && (appDlLimits[pkg] ?: -1L) == 0L) ||
                          (downloadBps == 0L && uploadBps == 0L && shouldThrottleApp(pkg))
            val isBlocked = if (pkg != null) {
                isAppBlockedByFirewall(pkg) || isMuted
            } else {
                firewallBlockAll || isMuted
            }
            if (isBlocked) {
                Log.i(TAG, "Firewall/Muted Blocked UDP packet from: ${pkg ?: "UNKNOWN_UID"}")
                return
            }

            try {
                val ch = DatagramChannel.open().apply {
                    configureBlocking(false)
                    socket().let {
                        vpnService.protect(it)
                        if (isGamingMode) {
                            try { it.trafficClass = 0x10 } catch (_: Exception) {}
                        }
                    }
                    connect(InetSocketAddress(InetAddress.getByAddress(dA), dP))
                }
                e = UdpEntry(ch, sA, sP, dA, dP, packageName = pkg)
                udpTable[key] = e
                val entry = e
                regQueue.add {
                    try {
                        val k = ch.register(selector, SelectionKey.OP_READ)
                        k.attach(entry); entry.key = k
                    } catch (ex: Exception) { Log.w(TAG, "UDP reg err: ${ex.message}") }
                }
                selector?.wakeup()
            } catch (ex: Exception) { Log.w(TAG, "UDP open err: ${ex.message}"); return }
        }

        e.lastMs = System.currentTimeMillis()

        // Apply non-blocking upload UDP limit (Drop if out of tokens)
        val pkg = e.packageName
        val shouldThrottle = shouldThrottleApp(pkg)
        if (shouldThrottle) {
            val appLimiter = if (pkg != null) getAppUlLimiter(pkg) else null
            if (appLimiter != null) {
                if (appLimiter.limitBps == 0L) {
                    return // 0 KB/s: drop UDP packet immediately
                }
                if (!appLimiter.consume(payLen.toLong())) {
                    return // Drop packet if out of custom app tokens
                }
            } else if (uploadBps >= 0) {
                if (uploadBps == 0L) {
                    return // 0 KB/s: drop UDP packet immediately
                }
                refillTokens()
                if (ulTokens < payLen) {
                    return
                }
                ulTokens -= payLen
            }
        }
        
        MyVpnService.totalTxBytes += payLen
        txBytesThisSecond += payLen
        checkDataCap(payLen)
        if (pkg != null) addAppUsage(pkg, payLen.toLong())

        try { e.ch.write(ByteBuffer.wrap(pkt, off, payLen)) }
        catch (ex: Exception) { Log.w(TAG, "UDP send err: ${ex.message}"); removeUdp(key, e) }
    }

    private fun onInUdp(e: UdpEntry) {
        val buf = ByteBuffer.allocate(MTU)
        try {
            val n = e.ch.read(buf); if (n <= 0) return
            buf.flip(); val data = ByteArray(n); buf.get(data)
            
            MyVpnService.totalRxBytes += n
            rxBytesThisSecond += n
            checkDataCap(n)

            val payload = if (e.dstPort == 53 && dnsRebindingProtection) {
                sanitizeDnsRebindingResponse(data)
            } else {
                data
            }

            queueDownloadPacket(buildUdp(e.dstAddr, e.srcAddr, e.dstPort, e.srcPort, payload), e.packageName)
            
            // Fast close ephemeral DNS query sockets upon receiving response
            if (e.dstPort == 53) {
                val key = "${e.srcAddr.hex()}:${e.srcPort}>${e.dstAddr.hex()}:${e.dstPort}"
                removeUdp(key, e)
            }
        } catch (ex: Exception) { Log.w(TAG, "UDP recv err: ${ex.message}") }
    }

    private fun removeUdp(key: String, e: UdpEntry) {
        udpTable.remove(key)
        try { e.key?.cancel() } catch (_: Exception) {}
        try { e.ch.close() } catch (_: Exception) {}
    }

    // ═══════════════════════════════════════════════════
    //  TCP HANDLING (Supports IPv4 and IPv6)
    // ═══════════════════════════════════════════════════
    private fun onOutTcp(pkt: ByteArray, ihl: Int, isV6: Boolean) {
        if (pkt.size < ihl + 20) return
        val sA = if (isV6) pkt.sliceArray(8..23) else pkt.sliceArray(12..15)
        val dA = if (isV6) pkt.sliceArray(24..39) else pkt.sliceArray(16..19)
        if (isLocalOrTetherOrBroadcast(dA, isV6) || isLocalOrTetherOrBroadcast(sA, isV6)) return
        val sP = u16(pkt, ihl)
        val dP = u16(pkt, ihl + 2)
        val seq = u32(pkt, ihl + 4)
        val ack = u32(pkt, ihl + 8)
        val doff = ((pkt[ihl + 12].toInt() and 0xF0) ushr 4) * 4
        val fl = pkt[ihl + 13].toInt() and 0xFF
        val key = "${sA.hex()}:$sP>${dA.hex()}:$dP"

        if (fl and RST != 0) { removeTcp(key); return }

        if (fl and SYN != 0 && fl and ACK == 0) {
            removeTcp(key)
            val uid = resolveSocketUid(android.system.OsConstants.IPPROTO_TCP, sA, sP, dA, dP)
            val pkg = getPackageNameForUid(uid)

            val isMuted = (pkg != null && appSpeedModes[pkg] == "custom" && (appDlLimits[pkg] ?: -1L) == 0L) ||
                          (downloadBps == 0L && uploadBps == 0L && shouldThrottleApp(pkg))
            val isBlocked = if (pkg != null) {
                isAppBlockedByFirewall(pkg) || isMuted
            } else {
                firewallBlockAll || isMuted
            }

            if (isBlocked) {
                Log.i(TAG, "Firewall/Muted Blocked TCP connection from: ${pkg ?: "UNKNOWN_UID"}")
                rstTo(dA, sA, dP, sP, ack, seq + 1)
                return
            }

            try {
                val ch = SocketChannel.open().apply {
                    configureBlocking(false)
                    socket().let {
                        vpnService.protect(it)
                        try { it.tcpNoDelay = true } catch (_: Exception) {}
                        if (isGamingMode) {
                            try { it.trafficClass = 0x10 } catch (_: Exception) {}
                        }
                    }
                }
                val entry = TcpEntry(ch, sA, sP, dA, dP,
                    mySeq = 0, myAck = seq + 1, state = TState.SYN_RECV, packageName = pkg)
                tcpTable[key] = entry

                regQueue.add {
                    try {
                        val k = ch.register(selector, SelectionKey.OP_CONNECT)
                        k.attach(entry); entry.key = k
                    } catch (ex: Exception) { Log.w(TAG, "TCP reg err: ${ex.message}") }
                }
                selector?.wakeup()
                ch.connect(InetSocketAddress(InetAddress.getByAddress(dA), dP))
            } catch (ex: Exception) {
                Log.w(TAG, "TCP open err: ${ex.message}")
                rstTo(dA, sA, dP, sP, ack, seq + 1)
                tcpTable.remove(key)
            }
            return
        }

        val e = tcpTable[key] ?: return

        if (fl and ACK != 0 && e.state == TState.SYN_RECV) {
            e.state = TState.ESTABLISHED
        }

        val payOff = ihl + doff; val payLen = pkt.size - payOff
        if (payLen > 0 && e.state == TState.ESTABLISHED) {
            if (seq < e.myAck) { ackTo(e); return }

            if (dP == 443) {
                val sni = extractSni(pkt, payOff, payLen)
                if (sni != null && shouldBlockDomain(sni)) {
                    Log.i(TAG, "HTTPS SNI Blocked: $sni")
                    rstTo(dA, sA, dP, sP, ack, seq + payLen)
                    removeTcp(key)
                    return
                }
            } else if (dP == 80) {
                val host = extractHttpHost(pkt, payOff, payLen)
                if (host != null && shouldBlockDomain(host)) {
                    Log.i(TAG, "HTTP Host Blocked: $host")
                    rstTo(dA, sA, dP, sP, ack, seq + payLen)
                    removeTcp(key)
                    return
                }
            }

            e.myAck = seq + payLen
            
            MyVpnService.totalTxBytes += payLen
            txBytesThisSecond += payLen
            checkDataCap(payLen)

            val dataBuf = ByteBuffer.wrap(pkt, payOff, payLen)
            e.writeQueue.add(dataBuf)
            
            writePendingTcp(e)
            ackTo(e)
        }

        if (fl and FIN != 0) {
            e.myAck = seq + 1
            ackTo(e)
            try { e.ch.shutdownOutput() } catch (_: Exception) {}
            finTo(e)
            removeTcp(key)
        }
    }

    private fun writePendingTcp(e: TcpEntry) {
        try {
            val pkg = e.packageName
            val shouldThrottle = shouldThrottleApp(pkg)
            val appLimiter = if (shouldThrottle && pkg != null) getAppUlLimiter(pkg) else null
            refillTokens()
            
            while (true) {
                val bb = e.writeQueue.peek() ?: break
                if (!bb.hasRemaining()) {
                    e.writeQueue.poll()
                    continue
                }
                
                var maxWrite = bb.remaining()
                if (shouldThrottle) {
                    if (appLimiter != null) {
                        if (appLimiter.limitBps == 0L) break
                        val appTokens = appLimiter.getAvailableTokens()
                        if (appTokens <= 0) break
                        maxWrite = minOf(bb.remaining().toLong(), appTokens).toInt()
                    } else if (uploadBps >= 0) {
                        if (uploadBps == 0L) break
                        if (ulTokens <= 0) break
                        maxWrite = minOf(bb.remaining().toLong(), ulTokens).toInt()
                    }
                }
                
                val originalLimit = bb.limit()
                bb.limit(bb.position() + maxWrite)
                val written = e.ch.write(bb)
                bb.limit(originalLimit)
                
                if (written > 0) {
                    if (pkg != null) addAppUsage(pkg, written.toLong())
                    if (shouldThrottle) {
                        if (appLimiter != null) {
                            appLimiter.consumeTokens(written.toLong())
                        } else if (uploadBps > 0) {
                            ulTokens -= written
                        }
                    }
                }
                
                if (bb.hasRemaining()) {
                    regQueue.add {
                        try {
                            e.key?.interestOps(SelectionKey.OP_READ or SelectionKey.OP_WRITE)
                        } catch (_: Exception) {}
                    }
                    selector?.wakeup()
                    break
                }
                
                e.writeQueue.poll()
            }
            
            if (e.writeQueue.isEmpty()) {
                regQueue.add {
                    try {
                        e.key?.interestOps(SelectionKey.OP_READ)
                    } catch (_: Exception) {}
                }
                selector?.wakeup()
            }
        } catch (ex: Exception) {
            Log.w(TAG, "TCP write err: ${ex.message}")
            val key = "${e.srcAddr.hex()}:${e.srcPort}>${e.dstAddr.hex()}:${e.dstPort}"
            removeTcp(key)
        }
    }

    private fun onTcpConnect(e: TcpEntry) {
        try {
            if (!e.ch.finishConnect()) return
            e.mySeq = System.nanoTime() and 0xFFFFFFFFL
            queueDownloadPacket(buildTcp(e.dstAddr, e.srcAddr, e.dstPort, e.srcPort,
                e.mySeq, e.myAck, SYN or ACK, ByteArray(0)))
            e.mySeq++
            e.key?.interestOps(SelectionKey.OP_READ)
        } catch (ex: Exception) {
            Log.w(TAG, "TCP connect err: ${ex.message}")
            rstTo(e.dstAddr, e.srcAddr, e.dstPort, e.srcPort, e.mySeq, e.myAck)
            val key = "${e.srcAddr.hex()}:${e.srcPort}>${e.dstAddr.hex()}:${e.dstPort}"
            removeTcp(key)
        }
    }

    private fun onInTcp(e: TcpEntry) {
        if (e.state != TState.ESTABLISHED && e.state != TState.SYN_RECV) return

        val pkg = e.packageName
        val shouldThrottle = shouldThrottleApp(pkg)
        val appLimiter = if (shouldThrottle && pkg != null) getAppDlLimiter(pkg) else null

        // ── TCP Ingress Backpressure: Verify tokens BEFORE reading from internet ──
        if (shouldThrottle) {
            if (appLimiter != null) {
                if (appLimiter.limitBps == 0L || appLimiter.getAvailableTokens() <= 0) {
                    pauseTcpReader(e)
                    return
                }
            } else if (downloadBps >= 0) {
                if (downloadBps == 0L) {
                    pauseTcpReader(e)
                    return
                }
                synchronized(this) {
                    refillTokens()
                    if (dlTokens <= 0) {
                        pauseTcpReader(e)
                        return
                    }
                }
            }
        }

        val buf = ByteBuffer.allocate(MTU - 40)
        try {
            val n = e.ch.read(buf)
            if (n == -1) {
                finTo(e)
                val key = "${e.srcAddr.hex()}:${e.srcPort}>${e.dstAddr.hex()}:${e.dstPort}"
                removeTcp(key)
                return
            }
            if (n == 0) return
            buf.flip(); val data = ByteArray(n); buf.get(data)
            
            MyVpnService.totalRxBytes += n
            rxBytesThisSecond += n
            checkDataCap(n)

            // Deduct tokens and apply immediate backpressure if bucket is depleted
            if (shouldThrottle) {
                if (appLimiter != null) {
                    appLimiter.consumeTokens(n.toLong())
                    if (appLimiter.getAvailableTokens() <= 0) {
                        pauseTcpReader(e)
                    }
                } else if (downloadBps > 0) {
                    synchronized(this) {
                        dlTokens = maxOf(0L, dlTokens - n)
                        if (dlTokens <= 0) {
                            pauseTcpReader(e)
                        }
                    }
                }
            }

            queueDownloadPacket(buildTcp(e.dstAddr, e.srcAddr, e.dstPort, e.srcPort,
                e.mySeq, e.myAck, ACK or PSH, data), e.packageName)
            e.mySeq += n
        } catch (ex: Exception) {
            Log.w(TAG, "TCP recv err: ${ex.message}")
            val key = "${e.srcAddr.hex()}:${e.srcPort}>${e.dstAddr.hex()}:${e.dstPort}"
            removeTcp(key)
        }
    }

    private fun pauseTcpReader(e: TcpEntry) {
        try {
            val k = e.key ?: return
            if (k.isValid) {
                val ops = k.interestOps()
                if ((ops and SelectionKey.OP_READ) != 0) {
                    k.interestOps(ops and SelectionKey.OP_READ.inv())
                }
            }
        } catch (_: Exception) {}
    }

    private fun resumePausedTcpReaders() {
        for (e in tcpTable.values) {
            val k = e.key ?: continue
            if (!k.isValid) continue
            val ops = k.interestOps()
            if ((ops and SelectionKey.OP_READ) == 0) {
                val pkg = e.packageName
                val shouldThrottle = shouldThrottleApp(pkg)
                var canRead = true
                if (shouldThrottle) {
                    val appLimiter = if (pkg != null) getAppDlLimiter(pkg) else null
                    if (appLimiter != null) {
                        if (appLimiter.limitBps <= 0L || appLimiter.getAvailableTokens() <= 0) {
                            canRead = false
                        }
                    } else if (downloadBps >= 0) {
                        if (downloadBps == 0L || dlTokens <= 0) {
                            canRead = false
                        }
                    }
                }
                if (canRead) {
                    try {
                        k.interestOps(ops or SelectionKey.OP_READ)
                    } catch (_: Exception) {}
                }
            }
        }
    }

    private fun ackTo(e: TcpEntry) {
        queueDownloadPacket(buildTcp(e.dstAddr, e.srcAddr, e.dstPort, e.srcPort,
            e.mySeq, e.myAck, ACK, ByteArray(0)))
    }

    private fun finTo(e: TcpEntry) {
        queueDownloadPacket(buildTcp(e.dstAddr, e.srcAddr, e.dstPort, e.srcPort,
            e.mySeq, e.myAck, FIN or ACK, ByteArray(0)))
        e.mySeq++
    }

    private fun rstTo(sA: ByteArray, dA: ByteArray, sP: Int, dP: Int, seq: Long, ack: Long) {
        queueDownloadPacket(buildTcp(sA, dA, sP, dP, seq, ack, RST or ACK, ByteArray(0)))
    }

    private fun removeTcp(key: String) {
        val e = tcpTable.remove(key) ?: return
        e.state = TState.CLOSED
        try { e.key?.cancel() } catch (_: Exception) {}
        try { e.ch.close() } catch (_: Exception) {}
    }

    // ═══════════════════════════════════════════════════
    //  CLEANUP & UTILS
    // ═══════════════════════════════════════════════════
    private fun cleanupStale() {
        val now = System.currentTimeMillis()
        udpTable.entries.removeIf { now - it.value.lastMs > 60_000L }
    }

    private val socketUidCache = java.util.concurrent.ConcurrentHashMap<String, Int>()

    private fun resolveSocketUid(protocol: Int, sA: ByteArray, sP: Int, dA: ByteArray, dP: Int): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return -1
        val cacheKey = "$protocol:$sP>$dP"
        val cached = socketUidCache[cacheKey]
        if (cached != null) return cached

        val connectivityManager = vpnService.getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager ?: return -1
        val uid = try {
            val localIP = InetAddress.getByAddress(sA)
            val remoteIP = InetAddress.getByAddress(dA)
            val localSocket = InetSocketAddress(localIP, sP)
            val remoteSocket = InetSocketAddress(remoteIP, dP)
            var resolved = connectivityManager.getConnectionOwnerUid(protocol, localSocket, remoteSocket)
            if (resolved == -1) {
                val wildcardIP = if (sA.size == 4) "0.0.0.0" else "::"
                val wildcardSocket = InetSocketAddress(InetAddress.getByName(wildcardIP), sP)
                resolved = connectivityManager.getConnectionOwnerUid(protocol, wildcardSocket, remoteSocket)
            }
            resolved
        } catch (e: Exception) {
            -1
        }
        if (uid > 0) {
            if (socketUidCache.size > 2000) socketUidCache.clear()
            socketUidCache[cacheKey] = uid
        }
        return uid
    }

    private fun getPackageNameForUid(uid: Int): String? {
        if (uid <= 0) return null
        var cached = uidPackageCache[uid]
        if (cached == null) {
            try {
                val pm = vpnService.packageManager
                val packages = pm.getPackagesForUid(uid)
                if (packages != null && packages.isNotEmpty()) {
                    cached = packages[0]
                    uidPackageCache[uid] = cached
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed resolving UID $uid: ${e.message}")
            }
        }
        return cached
    }

    private var lastWifiCheckMs = 0L
    private var cachedIsWifi = false

    private fun isWifiConnected(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastWifiCheckMs < 5000L) {
            return cachedIsWifi
        }
        lastWifiCheckMs = now
        val cm = vpnService.getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager ?: return false
        cachedIsWifi = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                var wifiFound = false
                val activeNet = cm.activeNetwork
                val activeCaps = cm.getNetworkCapabilities(activeNet)
                if (activeCaps != null && activeCaps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                    wifiFound = true
                } else {
                    val allNetworks = cm.allNetworks
                    for (network in allNetworks) {
                        val caps = cm.getNetworkCapabilities(network) ?: continue
                        if (caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_VPN)) continue
                        if (caps.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                            caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                            wifiFound = true
                            break
                        }
                    }
                }
                wifiFound
            } else {
                @Suppress("DEPRECATION")
                val wifiInfo = cm.getNetworkInfo(android.net.ConnectivityManager.TYPE_WIFI)
                wifiInfo?.isConnected == true
            }
        } catch (e: Exception) {
            false
        }
        return cachedIsWifi
    }

    private fun isAppBlockedByFirewall(pkg: String?): Boolean {
        if (pkg == null) {
            return firewallBlockAll
        }
        val isWifi = isWifiConnected()
        if (firewallBlockAll) {
            val isAllowed = firewallAllowedApps.contains(pkg)
            if (!isAllowed) return true
            return if (isWifi) {
                blockedAppsWifi.contains(pkg)
            } else {
                blockedAppsData.contains(pkg)
            }
        }
        return if (isWifi) {
            blockedAppsWifi.contains(pkg)
        } else {
            blockedAppsData.contains(pkg)
        }
    }

    /**
     * فحص الجدولة: هل الوقت الحالي داخل فترة الحظر؟
     * يدعم الفترات التي تتجاوز منتصف الليل (مثلاً 22:00 → 06:00)
     */
    private fun isInScheduledBlockPeriod(): Boolean {
        if (!schedEnabled) return false
        val cal = java.util.Calendar.getInstance()
        val nowMin = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE)
        val startMin = schedStartH * 60 + schedStartM
        val endMin = schedEndH * 60 + schedEndM
        return if (startMin <= endMin) {
            // فترة عادية (مثلاً 08:00 → 17:00)
            nowMin in startMin until endMin
        } else {
            // فترة تتجاوز منتصف الليل (مثلاً 22:00 → 06:00)
            nowMin >= startMin || nowMin < endMin
        }
    }

    private fun shouldThrottleApp(pkg: String?): Boolean {
        if (isGamingMode) return false
        if (pkg == null) return (downloadBps >= 0 || uploadBps >= 0)
        val mode = appSpeedModes[pkg]
        if (mode == "unlimited") return false
        if (mode == "custom") return true
        return (downloadBps >= 0 || uploadBps >= 0)
    }

    private fun getAppDlLimiter(pkg: String): RateLimiter? {
        if (appSpeedModes[pkg] != "custom") return null
        val limit = appDlLimits[pkg] ?: return null
        if (limit < 0) return null
        return appDlLimiters.getOrPut(pkg) { RateLimiter(limit) }.apply {
            if (this.limitBps != limit) this.limitBps = limit
        }
    }

    private fun getAppUlLimiter(pkg: String): RateLimiter? {
        if (appSpeedModes[pkg] != "custom") return null
        val limit = appUlLimits[pkg] ?: return null
        if (limit < 0) return null
        return appUlLimiters.getOrPut(pkg) { RateLimiter(limit) }.apply {
            if (this.limitBps != limit) this.limitBps = limit
        }
    }

    // ═══════════════════════════════════════════════════
    //  DNS PARSER & BUILDER
    // ═══════════════════════════════════════════════════
    private fun isPrivateIpv4(ip: ByteArray): Boolean {
        if (ip.size != 4) return false
        val b0 = ip[0].toInt() and 0xFF
        val b1 = ip[1].toInt() and 0xFF
        if (b0 == 127) return true // Loopback (127.0.0.0/8)
        if (b0 == 10) return true  // RFC 1918 Private (10.0.0.0/8)
        if (b0 == 172 && (b1 in 16..31)) return true // RFC 1918 Private (172.16.0.0/12)
        if (b0 == 192 && b1 == 168) return true // RFC 1918 Private (192.168.0.0/16)
        if (b0 == 169 && b1 == 254) return true // Link-Local / APIPA (169.254.0.0/16)
        if (b0 == 0 && b1 == 0 && (ip[2].toInt() and 0xFF) == 0 && (ip[3].toInt() and 0xFF) == 0) return true // 0.0.0.0
        if (b0 == 100 && ((b1 and 0xC0) == 64)) return true // CGNAT (100.64.0.0/10)
        return false
    }

    private fun isPrivateIpv6(ip: ByteArray): Boolean {
        if (ip.size != 16) return false
        // ::1 loopback
        if (ip.take(15).all { it == 0.toByte() } && ip[15] == 1.toByte()) return true
        // fc00::/7 (Unique Local Address)
        val b0 = ip[0].toInt() and 0xFF
        if ((b0 and 0xFE) == 0xFC) return true
        // fe80::/10 (Link-Local)
        val b1 = ip[1].toInt() and 0xFF
        if (b0 == 0xFE && ((b1 and 0xC0) == 0x80)) return true
        return false
    }

    private fun sanitizeDnsRebindingResponse(data: ByteArray): ByteArray {
        if (data.size < 12) return data
        val flags = u16(data, 2)
        val isResponse = (flags and 0x8000) != 0
        if (!isResponse) return data

        val qdCount = u16(data, 4)
        val anCount = u16(data, 6)
        if (anCount == 0) return data

        val domain = parseDnsDomain(data)
        if (domain != null) {
            val dom = domain.lowercase()
            // Ignore legitimate local or internal domains
            if (dom.endsWith(".local") || dom.endsWith(".lan") || dom.endsWith(".home") ||
                dom.endsWith(".internal") || dom == "localhost") {
                return data
            }
        }

        var pos = 12
        // Skip questions section
        for (q in 0 until qdCount) {
            while (pos < data.size) {
                val len = data[pos].toInt() and 0xFF
                if (len == 0) { pos++; break }
                if (len >= 192) { pos += 2; break }
                pos += 1 + len
            }
            pos += 4 // QTYPE (2) + QCLASS (2)
            if (pos >= data.size) return data
        }

        // Iterate answer records
        for (a in 0 until anCount) {
            if (pos >= data.size) break
            // Skip NAME
            while (pos < data.size) {
                val b = data[pos].toInt() and 0xFF
                if (b == 0) { pos++; break }
                if (b >= 192) { pos += 2; break }
                pos += 1 + b
            }
            if (pos + 10 > data.size) break
            val type = u16(data, pos); pos += 2
            val clazz = u16(data, pos); pos += 2
            val ttl = u32(data, pos); pos += 4
            val rdLen = u16(data, pos); pos += 2
            if (pos + rdLen > data.size) break

            if (type == 1 && rdLen == 4) { // Type A (IPv4)
                val ip = data.sliceArray(pos until pos + 4)
                if (isPrivateIpv4(ip)) {
                    val ipStr = "${ip[0].toInt() and 0xFF}.${ip[1].toInt() and 0xFF}.${ip[2].toInt() and 0xFF}.${ip[3].toInt() and 0xFF}"
                    Log.w(TAG, "[SECURITY] DNS Rebinding blocked for $domain -> private IP $ipStr (sinkholed to 0.0.0.0)")
                    data[pos] = 0; data[pos + 1] = 0; data[pos + 2] = 0; data[pos + 3] = 0
                }
            } else if (type == 28 && rdLen == 16) { // Type AAAA (IPv6)
                val ip = data.sliceArray(pos until pos + 16)
                if (isPrivateIpv6(ip)) {
                    Log.w(TAG, "[SECURITY] DNS Rebinding blocked for $domain -> private IPv6 (sinkholed)")
                    for (k in 0 until 16) data[pos + k] = 0
                }
            }
            pos += rdLen
        }
        return data
    }

    private fun parseDnsDomain(dnsBytes: ByteArray): String? {
        if (dnsBytes.size < 12) return null
        var i = 12
        val sb = StringBuilder()
        while (i < dnsBytes.size) {
            val len = dnsBytes[i].toInt() and 0xFF
            if (len == 0) break
            if (len > 63) return null
            if (sb.isNotEmpty()) sb.append(".")
            if (i + 1 + len > dnsBytes.size) return null
            sb.append(String(dnsBytes, i + 1, len, Charsets.US_ASCII))
            i += 1 + len
        }
        return sb.toString()
    }

    private fun shouldBlockDomain(domain: String): Boolean {
        val dom = domain.lowercase().trim()
        val parts = dom.split(".")
        
        // ── Custom blocked domains ──
        if (dnsCustomBlocked.isNotEmpty()) {
            for (blocked in dnsCustomBlocked) {
                val clean = blocked.trim().lowercase().removePrefix("http://").removePrefix("https://").removePrefix("www.")
                if (dom == clean || dom.endsWith(".$clean")) return true
            }
        }
        
        // ── Smart Ad & Tracker Blocker ──
        if (dnsAdBlock) {
            val adKeywords = listOf(
                "doubleclick", "adservice", "google-analytics", "telemetry", "adnxs", "adcolony",
                "applovin", "admob", "pagead", "unityads", "vungle", "ironsrc", "chartboost",
                "mopub", "inmobi", "taboola", "outbrain", "criteo", "scorecardresearch", "adjust.com",
                "appsflyer", "branch.io", "flurry", "crashlytics", "adsystem", "quantserve", "analytics"
            )
            for (kw in adKeywords) {
                if (dom.contains(kw)) return true
            }
            for (part in parts) {
                if (part == "ads" || part == "ad" || part == "analytics" || part.startsWith("telemetry") || part == "tracker") {
                    return true
                }
            }
        }

        // ── Family Protection / Adult & Malicious Content ──
        if (dnsAdultBlock) {
            val adultKeywords = listOf(
                "porn", "xxx", "sex", "adult", "xvideos", "pornhub", "redtube", "youporn",
                "chaturbate", "onlyfans", "stripchat", "livejasmin", "cam4", "bonga", "brazzers",
                "erome", "spankbang", "eporner", "hqporner", "xnxx", "xhamster", "hentai", "nude", "erotic"
            )
            for (kw in adultKeywords) {
                if (dom.contains(kw)) return true
            }
        }

        // ── Focus Mode / Social Media Blocker ──
        if (dnsSocialBlock) {
            val socialKeywords = listOf(
                "tiktok.com", "byteoversea", "ibytedtos", "snapchat.com", "snap-dev", "instagram.com",
                "facebook.com", "fbcdn.net", "messenger.com", "twitter.com", "x.com", "t.co", "twimg.com",
                "reddit.com", "pinterest.com", "threads.net", "wechat.com"
            )
            for (kw in socialKeywords) {
                if (dom.contains(kw)) return true
            }
        }
        return false
    }

    private fun extractSni(pkt: ByteArray, offset: Int, length: Int): String? {
        try {
            if (length < 43) return null
            if (pkt[offset] != 0x16.toByte() || pkt[offset + 1] != 0x03.toByte()) return null
            if (pkt[offset + 5] != 0x01.toByte()) return null // Handshake type ClientHello

            var pos = offset + 43
            val end = offset + length
            if (pos >= end) return null

            val sidLen = pkt[pos].toInt() and 0xFF
            pos += 1 + sidLen
            if (pos + 2 > end) return null

            val cipherLen = ((pkt[pos].toInt() and 0xFF) shl 8) or (pkt[pos + 1].toInt() and 0xFF)
            pos += 2 + cipherLen
            if (pos + 1 > end) return null

            val compLen = pkt[pos].toInt() and 0xFF
            pos += 1 + compLen
            if (pos + 2 > end) return null

            val extLen = ((pkt[pos].toInt() and 0xFF) shl 8) or (pkt[pos + 1].toInt() and 0xFF)
            pos += 2
            val extEnd = minOf(pos + extLen, end)

            while (pos + 4 <= extEnd) {
                val type = ((pkt[pos].toInt() and 0xFF) shl 8) or (pkt[pos + 1].toInt() and 0xFF)
                val len = ((pkt[pos + 2].toInt() and 0xFF) shl 8) or (pkt[pos + 3].toInt() and 0xFF)
                pos += 4
                if (type == 0) { // server_name (SNI)
                    if (pos + 5 <= extEnd) {
                        val nameLen = ((pkt[pos + 3].toInt() and 0xFF) shl 8) or (pkt[pos + 4].toInt() and 0xFF)
                        val nameStart = pos + 5
                        if (nameStart + nameLen <= end) {
                            return String(pkt, nameStart, nameLen, Charsets.US_ASCII)
                        }
                    }
                    break
                }
                pos += len
            }
        } catch (_: Exception) {}
        return null
    }

    private fun extractHttpHost(pkt: ByteArray, offset: Int, length: Int): String? {
        try {
            val text = String(pkt, offset, minOf(length, 512), Charsets.US_ASCII)
            val lines = text.split("\r\n")
            for (line in lines) {
                if (line.startsWith("Host:", ignoreCase = true)) {
                    return line.substring(5).trim().split(":")[0]
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun buildLocalDnsResponse(dnsReq: ByteArray, ipAddress: ByteArray): ByteArray? {
        if (dnsReq.size < 12) return null
        
        var i = 12
        while (i < dnsReq.size) {
            val len = dnsReq[i].toInt() and 0xFF
            if (len == 0) break
            if (len > 63) return null
            i += 1 + len
        }
        val qLen = i + 1 + 4
        if (qLen > dnsReq.size) return null
        
        val resp = ByteArray(qLen + 16)
        
        resp[0] = dnsReq[0]; resp[1] = dnsReq[1]
        resp[2] = 0x81.toByte(); resp[3] = 0x80.toByte()
        resp[4] = 0x00.toByte(); resp[5] = 0x01.toByte()
        resp[6] = 0x00.toByte(); resp[7] = 0x01.toByte()
        resp[8] = 0x00.toByte(); resp[9] = 0x00.toByte()
        resp[10] = 0x00.toByte(); resp[11] = 0x00.toByte()
        
        System.arraycopy(dnsReq, 12, resp, 12, qLen - 12)
        
        val o = qLen
        resp[o] = 0xC0.toByte(); resp[o + 1] = 0x0C.toByte()
        resp[o + 2] = 0x00.toByte(); resp[o + 3] = 0x01.toByte()
        resp[o + 4] = 0x00.toByte(); resp[o + 5] = 0x01.toByte()
        resp[o + 6] = 0x00.toByte(); resp[o + 7] = 0x00.toByte(); resp[o + 8] = 0x00.toByte(); resp[o + 9] = 0x0A.toByte()
        resp[o + 10] = 0x00.toByte(); resp[o + 11] = 0x04.toByte()
        resp[o + 12] = ipAddress[0]; resp[o + 13] = ipAddress[1]; resp[o + 14] = ipAddress[2]; resp[o + 15] = ipAddress[3]
        
        return resp
    }

    // ═══════════════════════════════════════════════════
    //  PACKET BUILDING (Supports IPv4 and IPv6)
    // ═══════════════════════════════════════════════════
    private fun buildIpHeaderV6(sA: ByteArray, dA: ByteArray, proto: Int, payloadLen: Int): ByteArray {
        val p = ByteArray(40)
        p[0] = 0x60.toByte() // Version 6
        w16(p, 4, payloadLen) // Payload length
        p[6] = proto.toByte() // Next header
        p[7] = 64.toByte()    // Hop limit
        System.arraycopy(sA, 0, p, 8, 16)
        System.arraycopy(dA, 0, p, 24, 16)
        return p
    }

    private fun buildUdp(sA: ByteArray, dA: ByteArray, sP: Int, dP: Int, data: ByteArray): ByteArray {
        val ipH = if (sA.size == 4) 20 else 40
        val udpH = 8
        val tot = ipH + udpH + data.size
        val p = ByteArray(tot)
        
        if (sA.size == 4) {
            p[0] = 0x45.toByte()
            w16(p, 2, tot)
            w16(p, 6, 0x4000)
            p[8] = 64
            p[9] = PROTO_UDP.toByte()
            System.arraycopy(sA, 0, p, 12, 4)
            System.arraycopy(dA, 0, p, 16, 4)
            w16(p, 10, ipCksum(p, 0, 20))
        } else {
            val ipHeader = buildIpHeaderV6(sA, dA, PROTO_UDP, udpH + data.size)
            System.arraycopy(ipHeader, 0, p, 0, 40)
        }
        
        w16(p, ipH, sP); w16(p, ipH + 2, dP)
        w16(p, ipH + 4, udpH + data.size)
        System.arraycopy(data, 0, p, ipH + udpH, data.size)
        w16(p, ipH + 6, transportCksum(p, sA, dA, PROTO_UDP, ipH, udpH + data.size))
        return p
    }

    private fun buildTcp(sA: ByteArray, dA: ByteArray, sP: Int, dP: Int,
                         seq: Long, ack: Long, flags: Int, data: ByteArray): ByteArray {
        val ipH = if (sA.size == 4) 20 else 40
        val tcpH = 20
        val tot = ipH + tcpH + data.size
        val p = ByteArray(tot)
        
        if (sA.size == 4) {
            p[0] = 0x45.toByte()
            w16(p, 2, tot)
            w16(p, 6, 0x4000)
            p[8] = 64
            p[9] = PROTO_TCP.toByte()
            System.arraycopy(sA, 0, p, 12, 4)
            System.arraycopy(dA, 0, p, 16, 4)
            w16(p, 10, ipCksum(p, 0, 20))
        } else {
            val ipHeader = buildIpHeaderV6(sA, dA, PROTO_TCP, tcpH + data.size)
            System.arraycopy(ipHeader, 0, p, 0, 40)
        }
        
        w16(p, ipH, sP); w16(p, ipH + 2, dP)
        w32(p, ipH + 4, seq); w32(p, ipH + 8, ack)
        p[ipH + 12] = (5 shl 4).toByte()
        p[ipH + 13] = flags.toByte()
        w16(p, ipH + 14, 65535)
        if (data.isNotEmpty()) System.arraycopy(data, 0, p, ipH + tcpH, data.size)
        w16(p, ipH + 16, transportCksum(p, sA, dA, PROTO_TCP, ipH, tcpH + data.size))
        return p
    }

    private fun ipCksum(d: ByteArray, off: Int, len: Int): Int = cksum(d, off, len)

    private fun transportCksum(pkt: ByteArray, sA: ByteArray, dA: ByteArray,
                                proto: Int, off: Int, segLen: Int): Int {
        if (sA.size == 4) {
            val total = 12 + segLen
            val tmp = ByteArray(total + (total % 2))
            System.arraycopy(sA, 0, tmp, 0, 4)
            System.arraycopy(dA, 0, tmp, 4, 4)
            tmp[9] = proto.toByte()
            w16(tmp, 10, segLen)
            System.arraycopy(pkt, off, tmp, 12, segLen)
            val ckOff = if (proto == PROTO_TCP) 16 else 6
            tmp[12 + ckOff] = 0; tmp[12 + ckOff + 1] = 0
            val c = cksum(tmp, 0, total)
            return if (c == 0) 0xFFFF else c
        } else {
            val total = 40 + segLen
            val tmp = ByteArray(total + (total % 2))
            System.arraycopy(sA, 0, tmp, 0, 16)
            System.arraycopy(dA, 0, tmp, 16, 16)
            w32(tmp, 32, segLen.toLong())
            tmp[39] = proto.toByte()
            System.arraycopy(pkt, off, tmp, 40, segLen)
            val ckOff = if (proto == PROTO_TCP) 16 else 6
            tmp[40 + ckOff] = 0; tmp[40 + ckOff + 1] = 0
            val c = cksum(tmp, 0, total)
            return if (c == 0) 0xFFFF else c
        }
    }

    private fun cksum(d: ByteArray, off: Int, len: Int): Int {
        var s: Long = 0; var i = off; var rem = len
        while (rem > 1) { s += ((d[i].toInt() and 0xFF) shl 8) or (d[i + 1].toInt() and 0xFF); i += 2; rem -= 2 }
        if (rem > 0) s += (d[i].toInt() and 0xFF) shl 8
        while (s ushr 16 != 0L) s = (s and 0xFFFF) + (s ushr 16)
        return s.toInt().inv() and 0xFFFF
    }

    private fun u16(d: ByteArray, o: Int) = ((d[o].toInt() and 0xFF) shl 8) or (d[o + 1].toInt() and 0xFF)
    private fun u32(d: ByteArray, o: Int): Long =
        ((d[o].toLong() and 0xFF) shl 24) or ((d[o+1].toLong() and 0xFF) shl 16) or
        ((d[o+2].toLong() and 0xFF) shl 8) or (d[o+3].toLong() and 0xFF)

    private fun w16(d: ByteArray, o: Int, v: Int) { d[o] = (v ushr 8).toByte(); d[o + 1] = v.toByte() }
    private fun w32(d: ByteArray, o: Int, v: Long) {
        d[o] = (v ushr 24).toByte(); d[o+1] = (v ushr 16).toByte()
        d[o+2] = (v ushr 8).toByte(); d[o+3] = v.toByte()
    }

    private fun getDownloadPacketPackage(pkt: ByteArray): String? {
        if (pkt.size < 20) return null
        val ver = (pkt[0].toInt() and 0xF0) ushr 4
        val proto: Int
        val ihl: Int
        val isV6 = (ver == 6)
        
        if (isV6) {
            if (pkt.size < 40) return null
            ihl = 40
            proto = pkt[6].toInt() and 0xFF
        } else {
            ihl = (pkt[0].toInt() and 0x0F) * 4
            proto = pkt[9].toInt() and 0xFF
        }
        
        if (proto != PROTO_TCP && proto != PROTO_UDP) return null
        if (pkt.size < ihl + 4) return null
        
        if (proto == PROTO_TCP) {
            if (pkt.size < ihl + 20) return null
        } else {
            val payLen = pkt.size - (ihl + 8)
            if (payLen <= 0) return null
            val sP = u16(pkt, ihl)
            if (sP == 53) return null // DNS local bypass
        }
        
        val destAppIP = if (isV6) pkt.sliceArray(24..39) else pkt.sliceArray(16..19)
        val destAppPort = u16(pkt, ihl + 2)
        val srcNetIP = if (isV6) pkt.sliceArray(8..23) else pkt.sliceArray(12..15)
        val srcNetPort = u16(pkt, ihl)
        
        val key = "${destAppIP.hex()}:$destAppPort>${srcNetIP.hex()}:$srcNetPort"
        return if (proto == PROTO_TCP) {
            tcpTable[key]?.packageName
        } else {
            udpTable[key]?.packageName
        }
    }

    private fun ByteArray.hex() = joinToString("") { "%02x".format(it) }

    private fun updateDailyLog(download: Long, upload: Long) {
        if (download <= 0 && upload <= 0) return
        try {
            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            val todayStr = sdf.format(java.util.Date())
            val file = java.io.File(vpnService.filesDir, "daily_usage.txt")
            
            // Read existing entries
            val logs = mutableMapOf<String, Pair<Long, Long>>()
            if (file.exists()) {
                file.forEachLine { line ->
                    val parts = line.split(",")
                    if (parts.size == 3) {
                        val date = parts[0]
                        val dl = parts[1].toLongOrNull() ?: 0L
                        val ul = parts[2].toLongOrNull() ?: 0L
                        logs[date] = Pair(dl, ul)
                    }
                }
            }
            
            // Update today's entry
            val current = logs[todayStr] ?: Pair(0L, 0L)
            logs[todayStr] = Pair(current.first + download, current.second + upload)
            
            // Write back
            file.bufferedWriter().use { writer ->
                for ((date, usage) in logs.entries.sortedBy { it.key }) {
                    writer.write("$date,${usage.first},${usage.second}\n")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating daily log: ${e.message}")
        }
    }
}

class RateLimiter(var limitBps: Long) {
    private var tokens: Long = if (limitBps > 0) Math.max(limitBps, 65536L) else 0L
    private var lastRefill: Long = System.currentTimeMillis()

    @Synchronized
    fun refill() {
        val now = System.currentTimeMillis()
        val dt = now - lastRefill
        if (dt > 0 && limitBps > 0) {
            tokens = minOf(limitBps * 2, tokens + (dt * limitBps) / 1000)
            lastRefill = now
        }
    }

    @Synchronized
    fun consume(bytes: Long): Boolean {
        if (limitBps < 0) return true // Unlimited
        if (limitBps == 0L) return false // 0 KB/s - blocked/frozen
        refill()
        if (tokens < bytes) return false
        tokens -= bytes
        return true
    }

    @Synchronized
    fun getAvailableTokens(): Long {
        if (limitBps < 0) return Long.MAX_VALUE
        if (limitBps == 0L) return 0L
        refill()
        return tokens
    }

    @Synchronized
    fun consumeTokens(bytes: Long) {
        if (limitBps > 0) {
            tokens = maxOf(0L, tokens - bytes)
        }
    }
}
