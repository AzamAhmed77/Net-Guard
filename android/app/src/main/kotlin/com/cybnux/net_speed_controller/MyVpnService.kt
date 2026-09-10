package com.cybnux.net_speed_controller

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import java.io.FileDescriptor
import java.io.IOException
import java.net.Inet6Address

data class VpnStats(
    val downloadBps: Long,
    val uploadBps: Long,
    val totalDownloadBytes: Long,
    val totalUploadBytes: Long
)

class MyVpnService : VpnService() {
    private val TAG = "MyVpnService"
    private val CHANNEL_ID = NetworkMonitorService.CHANNEL_ID
    private val NOTIFICATION_ID = NetworkMonitorService.NOTIFICATION_ID

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnWorker: VpnWorker? = null
    private var socksServer: LocalSocks5Server? = null

    companion object {
        const val ACTION_START = "com.cybnux.netspeed.START"
        const val ACTION_STOP = "com.cybnux.netspeed.STOP"
        const val ACTION_UPDATE_LIMITS = "com.cybnux.netspeed.UPDATE_LIMITS"
        const val ACTION_UPDATE_SETTINGS = "com.cybnux.netspeed.UPDATE_SETTINGS"
        
        const val EXTRA_DOWNLOAD_LIMIT = "download_limit" // in bytes per second
        const val EXTRA_UPLOAD_LIMIT = "upload_limit" // in bytes per second
        const val EXTRA_ALLOWED_APPS = "allowed_apps"
        const val EXTRA_BLOCKED_WIFI_APPS = "blocked_wifi_apps"
        const val EXTRA_BLOCKED_DATA_APPS = "blocked_data_apps"
        const val EXTRA_BLOCK_ALL_FIREWALL = "block_all_firewall"
        const val EXTRA_ALLOWED_FIREWALL_APPS = "allowed_firewall_apps"
        const val EXTRA_DNS_ADBLOCK = "dns_adblock"
        const val EXTRA_DNS_ADULTBLOCK = "dns_adultblock"
        const val EXTRA_DNS_SOCIALBLOCK = "dns_socialblock"
        const val EXTRA_DNS_CUSTOM_BLOCKED = "dns_custom_blocked"
        const val EXTRA_DNS_SERVERS = "dns_servers"
        const val EXTRA_DATACAP_BYTES = "datacap_bytes"
        const val EXTRA_DATACAP_ACTION = "datacap_action"
        const val EXTRA_SCHED_ENABLED = "sched_enabled"
        const val EXTRA_SCHED_START_H = "sched_start_h"
        const val EXTRA_SCHED_START_M = "sched_start_m"
        const val EXTRA_SCHED_END_H = "sched_end_h"
        const val EXTRA_SCHED_END_M = "sched_end_m"
        const val EXTRA_APP_SPEED_CONFIGS = "app_speed_configs"
        const val EXTRA_LOCKDOWN_SCREEN_OFF = "lockdown_screen_off"
        const val EXTRA_EBPF_ENABLED = "ebpf_enabled"
        const val EXTRA_DPI_ENABLED = "dpi_enabled"
        const val EXTRA_DNS_REBINDING = "dns_rebinding"

        @Volatile var totalRxBytes: Long = 0
        @Volatile var totalTxBytes: Long = 0
        @Volatile var currentRxBps: Long = 0
        @Volatile var currentTxBps: Long = 0

        // ─── حالة قطع الاتصال بسبب الكوتا (بدون إيقاف الخدمة) ───
        @Volatile var isDataCapBlocking: Boolean = false

        fun getStats(): VpnStats {
            return VpnStats(currentRxBps, currentTxBps, totalRxBytes, totalTxBytes)
        }

        // resetCurrentSpeed فقط — لا نصفر الإجمالي حتى تبقى السجلات
        fun resetCurrentSpeed() {
            currentRxBps = 0
            currentTxBps = 0
        }

        @Volatile var isRunning: Boolean = false
        @Volatile var instance: MyVpnService? = null

        fun getPerAppUsageJson(): String {
            return instance?.vpnWorker?.getPerAppUsageJson() ?: "{}"
        }

        fun saveSettingsToPrefs(
            context: Context,
            downloadLimit: Long, uploadLimit: Long,
            allowedApps: List<String>, blockedWifiApps: List<String>, blockedDataApps: List<String>,
            blockAllFirewall: Boolean, allowedFirewallApps: List<String>,
            dnsAdBlock: Boolean, dnsAdultBlock: Boolean, dnsSocialBlock: Boolean,
            dnsCustomBlocked: List<String>, dnsServers: List<String>,
            dataCapBytes: Long, dataCapAction: String,
            schedEnabled: Boolean, schedStartH: Int, schedStartM: Int, schedEndH: Int, schedEndM: Int,
            appSpeedConfigs: String,
            vpnActive: Boolean,
            lockdownScreenOff: Boolean = false,
            ebpfEnabled: Boolean = true,
            dpiEnabled: Boolean = true,
            dnsRebindingProtection: Boolean = true
        ) {
            try {
                val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putBoolean("vpn_active", vpnActive)
                    putBoolean("lockdown_screen_off", lockdownScreenOff)
                    putBoolean("ebpf_enabled", ebpfEnabled)
                    putBoolean("dpi_enabled", dpiEnabled)
                    putBoolean("dns_rebinding_protection", dnsRebindingProtection)
                    putLong("download_limit", downloadLimit)
                    putLong("upload_limit", uploadLimit)
                    putStringSet("allowed_apps", allowedApps.toSet())
                    putStringSet("blocked_wifi_apps", blockedWifiApps.toSet())
                    putStringSet("blocked_data_apps", blockedDataApps.toSet())
                    putBoolean("block_all_firewall", blockAllFirewall)
                    putStringSet("allowed_firewall_apps", allowedFirewallApps.toSet())
                    putBoolean("dns_adblock", dnsAdBlock)
                    putBoolean("dns_adultblock", dnsAdultBlock)
                    putBoolean("dns_socialblock", dnsSocialBlock)
                    putStringSet("dns_custom_blocked", dnsCustomBlocked.toSet())
                    putStringSet("dns_servers", dnsServers.toSet())
                    putLong("datacap_bytes", dataCapBytes)
                    putString("datacap_action", dataCapAction)
                    putBoolean("sched_enabled", schedEnabled)
                    putInt("sched_start_h", schedStartH)
                    putInt("sched_start_m", schedStartM)
                    putInt("sched_end_h", schedEndH)
                    putInt("sched_end_m", schedEndM)
                    putString("app_speed_configs", appSpeedConfigs)
                    apply()
                }
            } catch (e: Exception) {
                Log.e("MyVpnService", "Failed to save settings to prefs: ${e.message}")
            }
        }

        fun setVpnActiveState(context: Context, active: Boolean) {
            try {
                val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("vpn_active", active).apply()
                NetGuardTileService.requestTileUpdate(context)
                NetGuardWidgetProvider.updateAllWidgets(context)
            } catch (e: Exception) {
                Log.e("MyVpnService", "Failed to set vpn active state: ${e.message}")
            }
        }

        fun buildStartIntentFromPrefs(context: Context): Intent? {
            return try {
                val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                val downloadLimit = prefs.getLong("download_limit", 0L)
                val uploadLimit = prefs.getLong("upload_limit", 0L)
                val allowedApps = ArrayList(prefs.getStringSet("allowed_apps", emptySet()) ?: emptySet())
                val blockedWifiApps = ArrayList(prefs.getStringSet("blocked_wifi_apps", emptySet()) ?: emptySet())
                val blockedDataApps = ArrayList(prefs.getStringSet("blocked_data_apps", emptySet()) ?: emptySet())
                val blockAllFirewall = prefs.getBoolean("block_all_firewall", false)
                val allowedFirewallApps = ArrayList(prefs.getStringSet("allowed_firewall_apps", emptySet()) ?: emptySet())
                val dnsAdBlock = prefs.getBoolean("dns_adblock", false)
                val dnsAdultBlock = prefs.getBoolean("dns_adultblock", false)
                val dnsSocialBlock = prefs.getBoolean("dns_socialblock", false)
                val dnsCustomBlocked = ArrayList(prefs.getStringSet("dns_custom_blocked", emptySet()) ?: emptySet())
                val dnsServers = ArrayList(prefs.getStringSet("dns_servers", emptySet()) ?: emptySet())
                val dataCapBytes = prefs.getLong("datacap_bytes", 0L)
                val dataCapAction = prefs.getString("datacap_action", "throttle") ?: "throttle"
                val schedEnabled = prefs.getBoolean("sched_enabled", false)
                val schedStartH = prefs.getInt("sched_start_h", 0)
                val schedStartM = prefs.getInt("sched_start_m", 0)
                val schedEndH = prefs.getInt("sched_end_h", 0)
                val schedEndM = prefs.getInt("sched_end_m", 0)
                val appSpeedConfigs = prefs.getString("app_speed_configs", "") ?: ""
                val ebpfEnabled = prefs.getBoolean("ebpf_enabled", true)
                val dpiEnabled = prefs.getBoolean("dpi_enabled", true)
                val dnsRebindingProtection = prefs.getBoolean("dns_rebinding_protection", true)

                Intent(context, MyVpnService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_DOWNLOAD_LIMIT, downloadLimit)
                    putExtra(EXTRA_UPLOAD_LIMIT, uploadLimit)
                    putStringArrayListExtra(EXTRA_ALLOWED_APPS, allowedApps)
                    putStringArrayListExtra(EXTRA_BLOCKED_WIFI_APPS, blockedWifiApps)
                    putStringArrayListExtra(EXTRA_BLOCKED_DATA_APPS, blockedDataApps)
                    putExtra(EXTRA_BLOCK_ALL_FIREWALL, blockAllFirewall)
                    putStringArrayListExtra(EXTRA_ALLOWED_FIREWALL_APPS, allowedFirewallApps)
                    putExtra(EXTRA_DNS_ADBLOCK, dnsAdBlock)
                    putExtra(EXTRA_DNS_ADULTBLOCK, dnsAdultBlock)
                    putExtra(EXTRA_DNS_SOCIALBLOCK, dnsSocialBlock)
                    putStringArrayListExtra(EXTRA_DNS_CUSTOM_BLOCKED, dnsCustomBlocked)
                    putStringArrayListExtra(EXTRA_DNS_SERVERS, dnsServers)
                    putExtra(EXTRA_DATACAP_BYTES, dataCapBytes)
                    putExtra(EXTRA_DATACAP_ACTION, dataCapAction)
                    putExtra(EXTRA_SCHED_ENABLED, schedEnabled)
                    putExtra(EXTRA_SCHED_START_H, schedStartH)
                    putExtra(EXTRA_SCHED_START_M, schedStartM)
                    putExtra(EXTRA_SCHED_END_H, schedEndH)
                    putExtra(EXTRA_SCHED_END_M, schedEndM)
                    putExtra(EXTRA_APP_SPEED_CONFIGS, appSpeedConfigs)
                    putExtra(EXTRA_LOCKDOWN_SCREEN_OFF, prefs.getBoolean("lockdown_screen_off", false))
                    putExtra(EXTRA_EBPF_ENABLED, ebpfEnabled)
                    putExtra(EXTRA_DPI_ENABLED, dpiEnabled)
                    putExtra(EXTRA_DNS_REBINDING, dnsRebindingProtection)
                }
            } catch (e: Exception) {
                Log.e("MyVpnService", "Failed to build start intent from prefs: ${e.message}")
                null
            }
        }

        fun buildUpdateIntentFromPrefs(context: Context): Intent? {
            return buildStartIntentFromPrefs(context)?.apply {
                action = ACTION_UPDATE_SETTINGS
            }
        }
    }

    private var lockdownScreenOffEnabled = false
    private var isScreenOffLocked = false
    private var currentConfiguredDownloadLimit: Long = 0L
    private var currentConfiguredUploadLimit: Long = 0L

    private val screenLockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    if (lockdownScreenOffEnabled && isRunning) {
                        isScreenOffLocked = true
                        Log.i(TAG, "Screen OFF & lockdown enabled: reapplying per-app firewall rules")
                        vpnWorker?.reapplyFirewallRules()
                    }
                }
                Intent.ACTION_SCREEN_ON -> {
                    if (isScreenOffLocked) {
                        isScreenOffLocked = false
                        Log.i(TAG, "Screen ON: preserving normal per-app firewall rules")
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        vpnWorker = VpnWorker(this)
        socksServer = LocalSocks5Server(this)

        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenLockReceiver, screenFilter)

        try {
            val notification = getVpnNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                try {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                } catch (e: Exception) {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Initial startForeground error: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val notification = getVpnNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                try {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                } catch (e: Exception) {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "onStartCommand startForeground error: ${e.message}")
        }

        if (intent != null) {
            val action = intent.action
            Log.i(TAG, "onStartCommand received action: $action")
            when (action) {
                ACTION_START -> {
                    val downloadLimit = intent.getLongExtra(EXTRA_DOWNLOAD_LIMIT, 0L)
                    val uploadLimit = intent.getLongExtra(EXTRA_UPLOAD_LIMIT, 0L)
                    val allowedApps = intent.getStringArrayListExtra(EXTRA_ALLOWED_APPS) ?: emptyList<String>()
                    val blockedAppsWifi = intent.getStringArrayListExtra(EXTRA_BLOCKED_WIFI_APPS) ?: emptyList<String>()
                    val blockedAppsData = intent.getStringArrayListExtra(EXTRA_BLOCKED_DATA_APPS) ?: emptyList<String>()
                    val blockAllFirewall = intent.getBooleanExtra(EXTRA_BLOCK_ALL_FIREWALL, false)
                    val allowedFirewallApps = intent.getStringArrayListExtra(EXTRA_ALLOWED_FIREWALL_APPS) ?: emptyList<String>()
                    val dnsAdBlock = intent.getBooleanExtra(EXTRA_DNS_ADBLOCK, false)
                    val dnsAdultBlock = intent.getBooleanExtra(EXTRA_DNS_ADULTBLOCK, false)
                    val dnsSocialBlock = intent.getBooleanExtra(EXTRA_DNS_SOCIALBLOCK, false)
                    val dnsCustomBlocked = intent.getStringArrayListExtra(EXTRA_DNS_CUSTOM_BLOCKED) ?: emptyList<String>()
                    val dnsServers = intent.getStringArrayListExtra(EXTRA_DNS_SERVERS) ?: emptyList<String>()
                    val dataCapBytes = intent.getLongExtra(EXTRA_DATACAP_BYTES, 0L)
                    val dataCapAction = intent.getStringExtra(EXTRA_DATACAP_ACTION) ?: "throttle"
                    val schedEnabled = intent.getBooleanExtra(EXTRA_SCHED_ENABLED, false)
                    val schedStartH = intent.getIntExtra(EXTRA_SCHED_START_H, 0)
                    val schedStartM = intent.getIntExtra(EXTRA_SCHED_START_M, 0)
                    val schedEndH = intent.getIntExtra(EXTRA_SCHED_END_H, 0)
                    val schedEndM = intent.getIntExtra(EXTRA_SCHED_END_M, 0)
                    val appSpeedConfigs = intent.getStringExtra(EXTRA_APP_SPEED_CONFIGS) ?: ""
                    lockdownScreenOffEnabled = intent.getBooleanExtra(EXTRA_LOCKDOWN_SCREEN_OFF, false)
                    val ebpfEnabled = intent.getBooleanExtra(EXTRA_EBPF_ENABLED, true)
                    val dpiEnabled = intent.getBooleanExtra(EXTRA_DPI_ENABLED, true)
                    val dnsRebindingProtection = intent.getBooleanExtra(EXTRA_DNS_REBINDING, true)
                    currentConfiguredDownloadLimit = downloadLimit
                    currentConfiguredUploadLimit = uploadLimit

                    startVpn(
                        downloadLimit, uploadLimit, allowedApps, blockedAppsWifi, blockedAppsData,
                        blockAllFirewall, allowedFirewallApps,
                        dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked, dnsServers,
                        dataCapBytes, dataCapAction,
                        schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM,
                        ebpfEnabled, dpiEnabled, dnsRebindingProtection
                    )
                    val effectiveAppSpeedConfigs = if (appSpeedConfigs.isNotEmpty()) {
                        appSpeedConfigs
                    } else {
                        val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                        prefs.getString("app_speed_configs", "") ?: ""
                    }
                    if (effectiveAppSpeedConfigs.isNotEmpty()) {
                        vpnWorker?.updateAppSpeedConfigs(effectiveAppSpeedConfigs)
                    }
                    socksServer?.start(1080)
                    NetworkMonitorService.instance?.forceImmediateSpeedUpdate()
                    socksServer?.setRates(downloadLimit, uploadLimit)
                }
                ACTION_STOP -> {
                    stopVpn()
                    stopSelf()
                }
                ACTION_UPDATE_LIMITS -> {
                    val downloadLimit = intent.getLongExtra(EXTRA_DOWNLOAD_LIMIT, 0L)
                    val uploadLimit = intent.getLongExtra(EXTRA_UPLOAD_LIMIT, 0L)
                    currentConfiguredDownloadLimit = downloadLimit
                    currentConfiguredUploadLimit = uploadLimit
                    vpnWorker?.setRates(downloadLimit, uploadLimit)
                    socksServer?.setRates(downloadLimit, uploadLimit)
                }
                ACTION_UPDATE_SETTINGS -> {
                    val downloadLimit = intent.getLongExtra(EXTRA_DOWNLOAD_LIMIT, 0L)
                    val uploadLimit = intent.getLongExtra(EXTRA_UPLOAD_LIMIT, 0L)
                    lockdownScreenOffEnabled = intent.getBooleanExtra(EXTRA_LOCKDOWN_SCREEN_OFF, false)
                    val ebpfEnabled = intent.getBooleanExtra(EXTRA_EBPF_ENABLED, true)
                    val dpiEnabled = intent.getBooleanExtra(EXTRA_DPI_ENABLED, true)
                    val dnsRebindingProtection = intent.getBooleanExtra(EXTRA_DNS_REBINDING, true)
                    currentConfiguredDownloadLimit = downloadLimit
                    currentConfiguredUploadLimit = uploadLimit
                    val allowedApps = intent.getStringArrayListExtra(EXTRA_ALLOWED_APPS) ?: emptyList<String>()
                    val blockedAppsWifi = intent.getStringArrayListExtra(EXTRA_BLOCKED_WIFI_APPS) ?: emptyList<String>()
                    val blockedAppsData = intent.getStringArrayListExtra(EXTRA_BLOCKED_DATA_APPS) ?: emptyList<String>()
                    val blockAllFirewall = intent.getBooleanExtra(EXTRA_BLOCK_ALL_FIREWALL, false)
                    val allowedFirewallApps = intent.getStringArrayListExtra(EXTRA_ALLOWED_FIREWALL_APPS) ?: emptyList<String>()
                    val dnsAdBlock = intent.getBooleanExtra(EXTRA_DNS_ADBLOCK, false)
                    val dnsAdultBlock = intent.getBooleanExtra(EXTRA_DNS_ADULTBLOCK, false)
                    val dnsSocialBlock = intent.getBooleanExtra(EXTRA_DNS_SOCIALBLOCK, false)
                    val dnsCustomBlocked = intent.getStringArrayListExtra(EXTRA_DNS_CUSTOM_BLOCKED) ?: emptyList<String>()
                    val dataCapBytes = intent.getLongExtra(EXTRA_DATACAP_BYTES, 0L)
                    val dataCapAction = intent.getStringExtra(EXTRA_DATACAP_ACTION) ?: "throttle"
                    val schedEnabled = intent.getBooleanExtra(EXTRA_SCHED_ENABLED, false)
                    val schedStartH = intent.getIntExtra(EXTRA_SCHED_START_H, 0)
                    val schedStartM = intent.getIntExtra(EXTRA_SCHED_START_M, 0)
                    val schedEndH = intent.getIntExtra(EXTRA_SCHED_END_H, 0)
                    val schedEndM = intent.getIntExtra(EXTRA_SCHED_END_M, 0)
                    val appSpeedConfigs = intent.getStringExtra(EXTRA_APP_SPEED_CONFIGS) ?: ""

                    vpnWorker?.updateWorkerSettings(
                        downloadLimit, uploadLimit, allowedApps, blockedAppsWifi, blockedAppsData,
                        blockAllFirewall, allowedFirewallApps,
                        dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked,
                        dataCapBytes, dataCapAction,
                        schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM,
                        ebpfEnabled, dpiEnabled, dnsRebindingProtection
                    )
                    val effectiveUpdateConfigs = if (appSpeedConfigs.isNotEmpty()) {
                        appSpeedConfigs
                    } else {
                        val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                        prefs.getString("app_speed_configs", "") ?: ""
                    }
                    if (effectiveUpdateConfigs.isNotEmpty()) {
                        vpnWorker?.updateAppSpeedConfigs(effectiveUpdateConfigs)
                    }
                    socksServer?.setRates(downloadLimit, uploadLimit)
                    NetworkMonitorService.instance?.updateNotification()
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenLockReceiver)
        } catch (_: Exception) {}
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }

    private fun startVpn(
        downloadLimit: Long, uploadLimit: Long, allowedApps: List<String>,
        blockedAppsWifi: List<String>, blockedAppsData: List<String>,
        blockAllFirewall: Boolean, allowedFirewallApps: List<String>,
        dnsAdBlock: Boolean, dnsAdultBlock: Boolean, dnsSocialBlock: Boolean,
        dnsCustomBlocked: List<String>,
        dnsServers: List<String>,
        dataCapBytes: Long, dataCapAction: String,
        schedEnabled: Boolean, schedStartH: Int, schedStartM: Int, schedEndH: Int, schedEndM: Int,
        ebpfEnabled: Boolean = true,
        dpiEnabled: Boolean = true,
        dnsRebindingProtection: Boolean = true
    ) {
        if (isRunning && vpnInterface != null) {
            Log.i(TAG, "VPN is already running; updating the existing worker")
            vpnWorker?.updateWorkerSettings(
                downloadLimit, uploadLimit, allowedApps, blockedAppsWifi, blockedAppsData,
                blockAllFirewall, allowedFirewallApps,
                dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked,
                dataCapBytes, dataCapAction,
                schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM,
                ebpfEnabled, dpiEnabled, dnsRebindingProtection
            )
            return
        }

        // 1. Create and show foreground notification
        val notification = getVpnNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } catch (e: Exception) {
                startForeground(NOTIFICATION_ID, notification)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // نصفر السرعة الآنية فقط (لا نحذف الإجمالي)
        resetCurrentSpeed()
        isDataCapBlocking = false

        // 2. Configure and establish VPN Interface
        try {
            val builder = Builder()
            
            // IPv4 config
            builder.addAddress("10.0.0.1", 24)
            builder.addRoute("0.0.0.0", 0) // Route all IPv4 traffic
            
            // IPv6 config: only enable if the underlying physical network actually supports global IPv6.
            // On IPv4-only networks (most mobile data carriers), routing ::/0 creates a blackhole
            // causing apps to hang, retry endlessly, and waste cellular quota.
            if (hasGlobalIpv6()) {
                try {
                    builder.addAddress("fd00::1", 128)
                    builder.addRoute("::", 0)
                    Log.i(TAG, "Native IPv6 supported on network; IPv6 route enabled")
                } catch (e: Exception) {
                    Log.w(TAG, "IPv6 route setup ignored: ${e.message}")
                }
            } else {
                Log.i(TAG, "No native IPv6 on network; IPv6 route omitted to prevent connection retry loops")
            }
            
            
            if (dnsServers.isNotEmpty()) {
                for (dns in dnsServers) {
                    try {
                        builder.addDnsServer(dns)
                    } catch (e: Exception) {
                        Log.e(TAG, "Invalid DNS: $dns", e)
                    }
                }
            } else {
                builder.addDnsServer("8.8.8.8")
                builder.addDnsServer("1.1.1.1")
            }
            builder.setMtu(1500)
            builder.setSession("NetSpeedController")

            builder.allowBypass()

            // Always exclude own package and system networkstack / tethering so hotspot and p2p never stall or loop
            val excludedPkgs = listOf(
                packageName,
                "com.google.android.networkstack.tethering",
                "com.android.networkstack.tethering",
                "com.google.android.networkstack",
                "com.android.networkstack"
            )
            for (pkg in excludedPkgs) {
                try {
                    builder.addDisallowedApplication(pkg)
                    Log.i(TAG, "Excluded package from VPN: $pkg")
                } catch (_: Exception) {}
            }

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN interface (null)")
                stopVpn()
                return
            }

            Log.i(TAG, "VPN Interface established. FD = ${vpnInterface!!.fd}")

            // 3. Start pure Kotlin VpnWorker and pass initial settings
            vpnWorker?.start(vpnInterface!!.fileDescriptor, downloadLimit, uploadLimit)
            vpnWorker?.updateWorkerSettings(
                downloadLimit, uploadLimit, allowedApps, blockedAppsWifi, blockedAppsData,
                blockAllFirewall, allowedFirewallApps,
                dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked,
                dataCapBytes, dataCapAction,
                schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM,
                ebpfEnabled, dpiEnabled, dnsRebindingProtection
            )
            val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
            val savedAppSpeedConfigs = prefs.getString("app_speed_configs", "") ?: ""
            if (savedAppSpeedConfigs.isNotEmpty()) {
                Log.i(TAG, "Restoring saved app speed configs upon start: $savedAppSpeedConfigs")
                vpnWorker?.updateAppSpeedConfigs(savedAppSpeedConfigs)
            }
            isRunning = true
            instance = this
            setVpnActiveState(this, true)
            NetworkMonitorService.instance?.forceImmediateSpeedUpdate()

        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN: ${e.message}")
            e.printStackTrace()
            stopVpn()
        }
    }

    fun triggerDataCapReached(action: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Net Speed Limiter")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(false)
            .setOngoing(true)

        if (action == "disconnect") {
            // ✅ إصلاح: قطع الإنترنت فقط بدون إيقاف الخدمة
            // الخدمة تبقى شغالة لكن يتم إسقاط كل الحزم داخل VpnWorker
            isDataCapBlocking = true
            vpnWorker?.setDataCapBlocking(true)
            builder.setContentText("🚫 تم قطع الإنترنت — تجاوزت حد البيانات اليومي. افتح التطبيق لإعادة التفعيل.")
            manager.notify(2027, builder.build())
            // تحديث إشعار الخدمة
            NetworkMonitorService.instance?.updateNotification()
        } else {
            builder.setContentText("⚠️ تم تقييد سرعة الإنترنت لتجاوزك حد البيانات اليومي.")
            manager.notify(2027, builder.build())
            // تحديث إشعار الخدمة
            NetworkMonitorService.instance?.updateNotification()
            // تقييد السرعة لـ 1 KB/s
            vpnWorker?.setRates(1024L, 1024L)
        }
    }

    // رفع الحظر الناتج عن الكوتا (يستدعيه Flutter عند إعادة التفعيل)
    fun resetDataCapBlock() {
        isDataCapBlocking = false
        vpnWorker?.setDataCapBlocking(false)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(2027)
        NetworkMonitorService.instance?.updateNotification()
    }

    fun getPerAppUsageMap(): Map<String, Long> {
        return vpnWorker?.getPerAppUsageMap() ?: emptyMap()
    }

    private fun hasGlobalIpv6(): Boolean {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val activeNet = cm.activeNetwork ?: return false
                val lp = cm.getLinkProperties(activeNet) ?: return false
                lp.linkAddresses.any { linkAddr ->
                    val addr = linkAddr.address
                    addr is Inet6Address && !addr.isAnyLocalAddress && !addr.isLinkLocalAddress &&
                            !addr.isLoopbackAddress && !addr.isSiteLocalAddress && !addr.isMulticastAddress
                }
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping VPN Service...")
        isRunning = false
        instance = null
        resetCurrentSpeed()

        // 1. Stop VpnWorker and Socks5 server
        try {
            vpnWorker?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping vpnWorker: ${e.message}")
        }
        try {
            socksServer?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping socksServer: ${e.message}")
        }

        // 2. Close TUN descriptor
        try {
            vpnInterface?.close()
            Log.i(TAG, "VPN interface closed")
        } catch (e: IOException) {
            Log.w(TAG, "Error closing VPN interface: ${e.message}")
        }
        vpnInterface = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.cancel(NOTIFICATION_ID)
        setVpnActiveState(this, false)
        Log.i(TAG, "VPN Service fully stopped")
        NetworkMonitorService.instance?.forceImmediateSpeedUpdate()
        stopSelf()
    }

    private fun getVpnNotification(): Notification {
        return NetworkMonitorService.instance?.buildCurrentNotification() ?: run {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )

            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Net Guard")
                .setContentText("Network Guardian Active")
                .setSmallIcon(R.drawable.ic_notification)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .build()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "Net Guard app swiped from Recents. VPN Service will continue uninterrupted in background.")
        super.onTaskRemoved(rootIntent)
    }
}
