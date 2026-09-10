package com.cybnux.net_speed_controller

import android.util.Log
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.io.PushbackInputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

class HotspotProxyServer {

    companion object {
        private const val TAG = "HotspotProxyServer"
        val instance: HotspotProxyServer by lazy { HotspotProxyServer() }

        fun getHotspotIpAddress(): String {
            try {
                val interfaces = NetworkInterface.getNetworkInterfaces()
                while (interfaces.hasMoreElements()) {
                    val iface = interfaces.nextElement()
                    val name = iface.name.lowercase()
                    // Ignore cellular interfaces
                    if (name.startsWith("rmnet") || name.startsWith("ccmni") || name.startsWith("pdp")) {
                        continue
                    }

                    val isApInterface = name.startsWith("ap") || name.startsWith("softap") ||
                                        name.startsWith("rndis") || name.contains("wlan1") ||
                                        name.contains("swlan")

                    val addrs = iface.inetAddresses
                    while (addrs.hasMoreElements()) {
                        val addr = addrs.nextElement()
                        if (!addr.isLoopbackAddress && addr is java.net.Inet4Address) {
                            val ip = addr.hostAddress ?: ""
                            if (ip.startsWith("192.168.43.")) return ip
                            if (isApInterface) return ip
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error resolving Hotspot IP: ${e.message}")
            }
            return "192.168.43.1"
        }
    }

    private var serverSocket: ServerSocket? = null
    private var executor: ExecutorService? = null

    @Volatile
    var isRunning: Boolean = false
        private set

    @Volatile
    var serverPort: Int = 8282
        private set

    private val activeSockets = ConcurrentHashMap.newKeySet<Socket>()
    private val activeClientIps = ConcurrentHashMap.newKeySet<String>()

    private val downloadLimiter = RateLimiter(-1L) // Client download from internet
    private val uploadLimiter = RateLimiter(-1L)   // Client upload to internet

    val totalRxBytes = AtomicLong(0L) // Total downloaded by hotspot clients
    val totalTxBytes = AtomicLong(0L) // Total uploaded by hotspot clients

    class RateLimiter(@Volatile var bytesPerSecond: Long) {
        private var tokens: Long = if (bytesPerSecond > 0) bytesPerSecond else 2 * 1024 * 1024
        private var lastRefillTime: Long = System.currentTimeMillis()

        @Synchronized
        fun limit(bytes: Int) {
            val limitRate = bytesPerSecond
            if (limitRate < 0) return // Unlimited
            if (limitRate == 0L) {
                // Completely muted
                try {
                    Thread.sleep(1000)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                }
                return
            }

            val now = System.currentTimeMillis()
            val elapsedTime = now - lastRefillTime

            if (elapsedTime > 0) {
                val refill = (elapsedTime * limitRate) / 1000
                tokens = Math.min(limitRate * 2, tokens + refill)
                lastRefillTime = now
            }

            tokens -= bytes
            if (tokens < 0) {
                val sleepTime = (-tokens * 1000) / limitRate
                if (sleepTime > 0) {
                    try {
                        Thread.sleep(Math.min(sleepTime, 1000))
                    } catch (e: InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                }
                lastRefillTime = System.currentTimeMillis()
                tokens = 0
            }
        }
    }

    @Synchronized
    fun start(port: Int = 8282, downloadLimitBps: Long = -1L, uploadLimitBps: Long = -1L): Boolean {
        if (isRunning) {
            setRates(downloadLimitBps, uploadLimitBps)
            return true
        }

        serverPort = port
        setRates(downloadLimitBps, uploadLimitBps)

        try {
            // Bind to 0.0.0.0 so clients connected to hotspot (192.168.43.1) can reach it
            serverSocket = ServerSocket(port, 100, InetAddress.getByName("0.0.0.0"))
            isRunning = true
            executor = Executors.newCachedThreadPool()

            executor?.execute {
                Log.i(TAG, "Hotspot Proxy Server listening on 0.0.0.0:$port")
                while (isRunning) {
                    try {
                        val clientSocket = serverSocket?.accept() ?: break
                        clientSocket.tcpNoDelay = true
                        activeSockets.add(clientSocket)
                        val clientIp = clientSocket.inetAddress.hostAddress ?: "unknown"
                        activeClientIps.add(clientIp)

                        executor?.execute {
                            try {
                                handleClient(clientSocket)
                            } catch (e: Exception) {
                                Log.d(TAG, "Hotspot client session finished: ${e.message}")
                            } finally {
                                activeSockets.remove(clientSocket)
                                if (!hasActiveSocketsForIp(clientIp)) {
                                    activeClientIps.remove(clientIp)
                                }
                            }
                        }
                    } catch (e: SocketException) {
                        if (isRunning) {
                            Log.e(TAG, "ServerSocket accept exception: ${e.message}")
                        }
                        break
                    } catch (e: Exception) {
                        Log.e(TAG, "Unexpected error in accept loop: ${e.message}")
                    }
                }
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Hotspot Proxy Server on port $port: ${e.message}")
            stop()
            return false
        }
    }

    private fun hasActiveSocketsForIp(ip: String): Boolean {
        for (s in activeSockets) {
            if (s.inetAddress?.hostAddress == ip) return true
        }
        return false
    }

    @Synchronized
    fun stop() {
        isRunning = false
        try {
            serverSocket?.close()
        } catch (_: Exception) {}
        serverSocket = null

        for (sock in activeSockets) {
            try {
                sock.close()
            } catch (_: Exception) {}
        }
        activeSockets.clear()
        activeClientIps.clear()

        try {
            executor?.shutdownNow()
        } catch (_: Exception) {}
        executor = null
        Log.i(TAG, "Hotspot Proxy Server stopped.")
    }

    fun setRates(downloadLimitBps: Long, uploadLimitBps: Long) {
        downloadLimiter.bytesPerSecond = downloadLimitBps
        uploadLimiter.bytesPerSecond = uploadLimitBps
        Log.i(TAG, "Hotspot rates updated: Down=$downloadLimitBps Bps, Up=$uploadLimitBps Bps")
    }

    fun getStatus(): Map<String, Any> {
        val map = HashMap<String, Any>()
        map["isRunning"] = isRunning
        map["port"] = serverPort
        map["ip"] = getHotspotIpAddress()
        map["activeClients"] = activeClientIps.size
        map["activeSockets"] = activeSockets.size
        map["totalRxBytes"] = totalRxBytes.get()
        map["totalTxBytes"] = totalTxBytes.get()
        map["downloadLimitBps"] = downloadLimiter.bytesPerSecond
        map["uploadLimitBps"] = uploadLimiter.bytesPerSecond
        return map
    }

    private fun handleClient(clientSocket: Socket) {
        clientSocket.soTimeout = 30000
        val rawIn = clientSocket.getInputStream()
        val pushbackIn = PushbackInputStream(BufferedInputStream(rawIn, 16384), 16)

        val firstByte = pushbackIn.read()
        if (firstByte == -1) {
            clientSocket.close()
            return
        }
        pushbackIn.unread(firstByte)

        if (firstByte == 0x05) {
            // SOCKS5 Protocol
            handleSocks5(clientSocket, pushbackIn)
        } else {
            // HTTP / HTTPS CONNECT Protocol
            handleHttpProxy(clientSocket, pushbackIn)
        }
    }

    private fun handleHttpProxy(clientSocket: Socket, clientIn: InputStream) {
        val clientOut = BufferedOutputStream(clientSocket.getOutputStream())

        // Read the first line (Request Line)
        val requestLine = readLine(clientIn) ?: run {
            clientSocket.close()
            return
        }

        val parts = requestLine.trim().split(" ")
        if (parts.size < 2) {
            clientSocket.close()
            return
        }

        val method = parts[0].uppercase()
        val target = parts[1]

        var targetHost: String
        var targetPort: Int

        var isConnectMethod = false

        if (method == "CONNECT") {
            // HTTPS Tunnel: CONNECT host:port HTTP/1.1
            isConnectMethod = true
            val hostPort = target.split(":")
            targetHost = hostPort[0]
            targetPort = if (hostPort.size > 1) hostPort[1].toIntOrNull() ?: 443 else 443

            // Consume remaining headers up to empty line
            while (true) {
                val header = readLine(clientIn) ?: break
                if (header.trim().isEmpty()) break
            }
        } else {
            // Regular HTTP: GET http://host:port/path HTTP/1.1 or GET /path HTTP/1.1
            if (target.startsWith("http://", ignoreCase = true)) {
                val uri = java.net.URI(target)
                targetHost = uri.host ?: ""
                targetPort = if (uri.port != -1) uri.port else 80
            } else {
                // Parse Host header
                val headers = ArrayList<String>()
                var parsedHost = ""
                var parsedPort = 80

                var line: String?
                while (true) {
                    line = readLine(clientIn)
                    if (line == null || line.trim().isEmpty()) break
                    headers.add(line)
                    if (line.lowercase().startsWith("host:")) {
                        val hostVal = line.substring(5).trim()
                        val hParts = hostVal.split(":")
                        parsedHost = hParts[0]
                        if (hParts.size > 1) {
                            parsedPort = hParts[1].toIntOrNull() ?: 80
                        }
                    }
                }
                targetHost = parsedHost
                targetPort = parsedPort
            }
        }

        if (targetHost.isEmpty()) {
            clientSocket.close()
            return
        }

        // Connect to remote target
        var targetSocket: Socket? = null
        try {
            targetSocket = Socket()
            targetSocket.tcpNoDelay = true
            targetSocket.soTimeout = 30000

            // Protect the socket so it bypasses VPN if VPN is running
            MyVpnService.instance?.protect(targetSocket)

            targetSocket.connect(InetSocketAddress(targetHost, targetPort), 10000)
            activeSockets.add(targetSocket)
        } catch (e: Exception) {
            Log.d(TAG, "Cannot connect to target $targetHost:$targetPort - ${e.message}")
            try {
                if (isConnectMethod) {
                    clientOut.write("HTTP/1.1 502 Bad Gateway\r\n\r\n".toByteArray())
                    clientOut.flush()
                }
            } catch (_: Exception) {}
            clientSocket.close()
            return
        }

        val targetIn = BufferedInputStream(targetSocket.getInputStream(), 16384)
        val targetOut = BufferedOutputStream(targetSocket.getOutputStream(), 16384)

        if (isConnectMethod) {
            // Send 200 Connection Established to client
            clientOut.write("HTTP/1.1 200 Connection Established\r\nProxy-Agent: NetGuard-Hotspot\r\n\r\n".toByteArray())
            clientOut.flush()
        } else {
            // Re-write the request line to target
            targetOut.write("$requestLine\r\n".toByteArray())
            targetOut.flush()
        }

        pipeSockets(clientSocket, clientIn, clientOut, targetSocket, targetIn, targetOut)
    }

    private fun handleSocks5(clientSocket: Socket, clientIn: InputStream) {
        val clientOut = clientSocket.getOutputStream()

        // 1. Version identifier/method selection
        val ver = clientIn.read()
        if (ver != 5) {
            clientSocket.close()
            return
        }
        val nmethods = clientIn.read()
        if (nmethods == -1) {
            clientSocket.close()
            return
        }
        val methods = ByteArray(nmethods)
        readFully(clientIn, methods, nmethods)

        // Reply: Version 5, Method 0 (NO AUTHENTICATION REQUIRED)
        clientOut.write(byteArrayOf(0x05, 0x00))
        clientOut.flush()

        // 2. Request details
        val reqVer = clientIn.read()
        val cmd = clientIn.read()
        val rsv = clientIn.read()
        val atyp = clientIn.read()

        if (reqVer != 5 || cmd != 1) { // 1 = CONNECT
            clientOut.write(byteArrayOf(5, 7, 0, 1, 0, 0, 0, 0, 0, 0)) // Command not supported
            clientSocket.close()
            return
        }

        val destHost: String
        when (atyp) {
            1 -> { // IPv4
                val ipv4 = ByteArray(4)
                readFully(clientIn, ipv4, 4)
                destHost = InetAddress.getByAddress(ipv4).hostAddress ?: ""
            }
            3 -> { // Domain name
                val len = clientIn.read()
                if (len == -1) throw java.io.EOFException("EOF")
                val hostBytes = ByteArray(len)
                readFully(clientIn, hostBytes, len)
                destHost = String(hostBytes)
            }
            4 -> { // IPv6
                val ipv6 = ByteArray(16)
                readFully(clientIn, ipv6, 16)
                destHost = InetAddress.getByAddress(ipv6).hostAddress ?: ""
            }
            else -> {
                clientOut.write(byteArrayOf(5, 8, 0, 1, 0, 0, 0, 0, 0, 0))
                clientSocket.close()
                return
            }
        }

        val portBytes = ByteArray(2)
        readFully(clientIn, portBytes, 2)
        val destPort = ((portBytes[0].toInt() and 0xff) shl 8) or (portBytes[1].toInt() and 0xff)

        var targetSocket: Socket? = null
        try {
            targetSocket = Socket()
            targetSocket.tcpNoDelay = true
            targetSocket.soTimeout = 30000

            MyVpnService.instance?.protect(targetSocket)
            targetSocket.connect(InetSocketAddress(destHost, destPort), 10000)
            activeSockets.add(targetSocket)
        } catch (e: Exception) {
            clientOut.write(byteArrayOf(5, 4, 0, 1, 0, 0, 0, 0, 0, 0)) // Host unreachable
            clientSocket.close()
            return
        }

        // SOCKS5 Success: 5, 0, 0, 1, 0, 0, 0, 0, 0, 0
        clientOut.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0))
        clientOut.flush()

        val targetIn = targetSocket.getInputStream()
        val targetOut = targetSocket.getOutputStream()

        pipeSockets(clientSocket, clientIn, clientOut, targetSocket, targetIn, targetOut)
    }

    private fun pipeSockets(
        clientSocket: Socket, clientIn: InputStream, clientOut: OutputStream,
        targetSocket: Socket, targetIn: InputStream, targetOut: OutputStream
    ) {
        val uploadJob = Thread {
            try {
                val buffer = ByteArray(16384)
                var bytesRead: Int
                while (isRunning && !clientSocket.isClosed && !targetSocket.isClosed) {
                    bytesRead = clientIn.read(buffer)
                    if (bytesRead == -1) break
                    if (bytesRead > 0) {
                        uploadLimiter.limit(bytesRead)
                        totalTxBytes.addAndGet(bytesRead.toLong())
                        targetOut.write(buffer, 0, bytesRead)
                        targetOut.flush()
                    }
                }
            } catch (_: Exception) {
            } finally {
                closeQuietly(clientSocket)
                closeQuietly(targetSocket)
            }
        }

        val downloadJob = Thread {
            try {
                val buffer = ByteArray(16384)
                var bytesRead: Int
                while (isRunning && !clientSocket.isClosed && !targetSocket.isClosed) {
                    bytesRead = targetIn.read(buffer)
                    if (bytesRead == -1) break
                    if (bytesRead > 0) {
                        downloadLimiter.limit(bytesRead)
                        totalRxBytes.addAndGet(bytesRead.toLong())
                        clientOut.write(buffer, 0, bytesRead)
                        clientOut.flush()
                    }
                }
            } catch (_: Exception) {
            } finally {
                closeQuietly(clientSocket)
                closeQuietly(targetSocket)
            }
        }

        uploadJob.start()
        downloadJob.start()
    }

    private fun readLine(ins: InputStream): String? {
        val bout = ByteArrayOutputStream()
        var c: Int
        var count = 0
        while (ins.read().also { c = it } != -1) {
            count++
            if (count > 8192) break // Safety limit
            if (c == '\n'.code) break
            if (c != '\r'.code) {
                bout.write(c)
            }
        }
        if (bout.size() == 0 && c == -1) return null
        return bout.toString("UTF-8")
    }

    private fun readFully(ins: InputStream, b: ByteArray, len: Int) {
        var offset = 0
        while (offset < len) {
            val count = ins.read(b, offset, len - offset)
            if (count < 0) throw java.io.EOFException("Premature EOF while reading $len bytes")
            offset += count
        }
    }

    private fun closeQuietly(sock: Socket) {
        try {
            sock.close()
        } catch (_: Exception) {}
        activeSockets.remove(sock)
    }
}
