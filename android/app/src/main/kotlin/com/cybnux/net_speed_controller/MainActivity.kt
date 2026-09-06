package com.cybnux.net_speed_controller

import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.Intent
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import java.util.HashMap

class MainActivity: FlutterActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.cybnux.netspeed/controller"
    private val VPN_REQUEST_CODE = 2026

    private var pendingDownloadLimit: Long = 0L
    private var pendingUploadLimit: Long = 0L
    private var pendingAllowedApps: List<String> = emptyList()
    private var pendingBlockedWifiApps: List<String> = emptyList()
    private var pendingBlockedDataApps: List<String> = emptyList()
    private var pendingBlockAllFirewall: Boolean = false
    private var pendingAllowedFirewallApps: List<String> = emptyList()
    private var pendingDnsAdBlock: Boolean = false
    private var pendingDnsAdultBlock: Boolean = false
    private var pendingDnsSocialBlock: Boolean = false
    private var pendingDataCapBytes: Long = 0L
    private var pendingDataCapAction: String = "throttle"
    private var pendingSchedEnabled: Boolean = false
    private var pendingSchedStartH: Int = 0
    private var pendingSchedStartM: Int = 0
    private var pendingSchedEndH: Int = 0
    private var pendingSchedEndM: Int = 0
    private var pendingDnsCustomBlocked: List<String> = emptyList()
    private var pendingDnsServers: List<String> = emptyList()
    private var pendingAppSpeedConfigs: String = ""
    private var pendingLockdownScreenOff: Boolean = false
    
    private var methodResult: MethodChannel.Result? = null
    private var flutterChannel: MethodChannel? = null

    companion object {
        var instance: MainActivity? = null
    }

    fun toggleVpnFromNative() {
        runOnUiThread {
            flutterChannel?.invokeMethod("onToggleVpnFromNotification", null)
        }
    }

    private var downloadBps: Long = 0L
    private var uploadBps: Long = 0L
    private var totalDownloadBytes: Long = 0L
    private var totalUploadBytes: Long = 0L
    private val cachedPackageUids = java.util.concurrent.ConcurrentHashMap<String, Int>()

    private val statsReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent != null && intent.action == "com.cybnux.netspeed.STATS_UPDATE") {
                downloadBps = intent.getLongExtra("downloadBps", 0L)
                uploadBps = intent.getLongExtra("uploadBps", 0L)
                totalDownloadBytes = intent.getLongExtra("totalDownloadBytes", 0L)
                totalUploadBytes = intent.getLongExtra("totalUploadBytes", 0L)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        val filter = android.content.IntentFilter("com.cybnux.netspeed.STATS_UPDATE")
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(statsReceiver, filter)
        }
        NetworkMonitorService.startService(this)
    }

    override fun onDestroy() {
        if (instance == this) instance = null
        try {
            unregisterReceiver(statsReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Error unregistering receiver: ${e.message}")
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        flutterChannel = channel

        // Start background NetworkMonitorService if enabled
        val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
        val monitorEnabled = prefs.getBoolean("monitor_service_enabled", true)
        if (monitorEnabled) {
            NetworkMonitorService.startService(this)
        }

        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "startVpn" -> {
                    val download = call.argument<Number>("downloadLimit")?.toLong() ?: 0L
                    val upload = call.argument<Number>("uploadLimit")?.toLong() ?: 0L
                    val allowedApps = call.argument<List<String>>("allowedApps") ?: emptyList()
                    val blockedWifiApps = call.argument<List<String>>("blockedWifiApps") ?: emptyList()
                    val blockedDataApps = call.argument<List<String>>("blockedDataApps") ?: emptyList()
                    val blockAllFirewall = call.argument<Boolean>("blockAllFirewall") ?: false
                    val allowedFirewallApps = call.argument<List<String>>("allowedFirewallApps") ?: emptyList()
                    val dnsAdBlock = call.argument<Boolean>("dnsAdBlock") ?: false
                    val dnsAdultBlock = call.argument<Boolean>("dnsAdultBlock") ?: false
                    val dnsSocialBlock = call.argument<Boolean>("dnsSocialBlock") ?: false
                    val dnsCustomBlocked = call.argument<List<String>>("dnsCustomBlocked") ?: emptyList()
                    val dnsServers = call.argument<List<String>>("dnsServers") ?: emptyList()
                    val dataCapBytes = call.argument<Number>("dataCapBytes")?.toLong() ?: 0L
                    val dataCapAction = call.argument<String>("dataCapAction") ?: "throttle"
                    val schedEnabled = call.argument<Boolean>("schedEnabled") ?: false
                    val schedStartH = call.argument<Int>("schedStartH") ?: 0
                    val schedStartM = call.argument<Int>("schedStartM") ?: 0
                    val schedEndH = call.argument<Int>("schedEndH") ?: 0
                    val schedEndM = call.argument<Int>("schedEndM") ?: 0
                    val appSpeedConfigs = call.argument<String>("appSpeedConfigs") ?: ""
                    val lockdownScreenOff = call.argument<Boolean>("lockdownScreenOff") ?: false
                    
                    pendingDownloadLimit = download
                    pendingUploadLimit = upload
                    pendingAllowedApps = allowedApps
                    pendingBlockedWifiApps = blockedWifiApps
                    pendingBlockedDataApps = blockedDataApps
                    pendingBlockAllFirewall = blockAllFirewall
                    pendingAllowedFirewallApps = allowedFirewallApps
                    pendingDnsAdBlock = dnsAdBlock
                    pendingDnsAdultBlock = dnsAdultBlock
                    pendingDnsSocialBlock = dnsSocialBlock
                    pendingDnsCustomBlocked = dnsCustomBlocked
                    pendingDnsServers = dnsServers
                    pendingDataCapBytes = dataCapBytes
                    pendingDataCapAction = dataCapAction
                    pendingSchedEnabled = schedEnabled
                    pendingSchedStartH = schedStartH
                    pendingSchedStartM = schedStartM
                    pendingSchedEndH = schedEndH
                    pendingSchedEndM = schedEndM
                    pendingAppSpeedConfigs = appSpeedConfigs
                    pendingLockdownScreenOff = lockdownScreenOff
                    
                    methodResult = result
                    
                    val intent = VpnService.prepare(this@MainActivity)
                    if (intent != null) {
                        this@MainActivity.startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        startVpnService(download, upload, allowedApps, blockedWifiApps, blockedDataApps, blockAllFirewall, allowedFirewallApps, dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked, dnsServers, dataCapBytes, dataCapAction, schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM, appSpeedConfigs, lockdownScreenOff)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                "updateSettings" -> {
                    val download = call.argument<Number>("downloadLimit")?.toLong() ?: 0L
                    val upload = call.argument<Number>("uploadLimit")?.toLong() ?: 0L
                    val allowedApps = call.argument<List<String>>("allowedApps") ?: emptyList()
                    val blockedWifiApps = call.argument<List<String>>("blockedWifiApps") ?: emptyList()
                    val blockedDataApps = call.argument<List<String>>("blockedDataApps") ?: emptyList()
                    val blockAllFirewall = call.argument<Boolean>("blockAllFirewall") ?: false
                    val allowedFirewallApps = call.argument<List<String>>("allowedFirewallApps") ?: emptyList()
                    val dnsAdBlock = call.argument<Boolean>("dnsAdBlock") ?: false
                    val dnsAdultBlock = call.argument<Boolean>("dnsAdultBlock") ?: false
                    val dnsSocialBlock = call.argument<Boolean>("dnsSocialBlock") ?: false
                    val dnsCustomBlocked = call.argument<List<String>>("dnsCustomBlocked") ?: emptyList()
                    val dnsServers = call.argument<List<String>>("dnsServers") ?: emptyList()
                    val dataCapBytes = call.argument<Number>("dataCapBytes")?.toLong() ?: 0L
                    val dataCapAction = call.argument<String>("dataCapAction") ?: "throttle"
                    val schedEnabled = call.argument<Boolean>("schedEnabled") ?: false
                    val schedStartH = call.argument<Int>("schedStartH") ?: 0
                    val schedStartM = call.argument<Int>("schedStartM") ?: 0
                    val schedEndH = call.argument<Int>("schedEndH") ?: 0
                    val schedEndM = call.argument<Int>("schedEndM") ?: 0
                    val appSpeedConfigs = call.argument<String>("appSpeedConfigs") ?: ""
                    val lockdownScreenOff = call.argument<Boolean>("lockdownScreenOff") ?: false
 
                    updateVpnSettings(download, upload, allowedApps, blockedWifiApps, blockedDataApps, blockAllFirewall, allowedFirewallApps, dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked, dnsServers, dataCapBytes, dataCapAction, schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM, appSpeedConfigs, lockdownScreenOff)
                    result.success(true)
                }
                "isVpnRunning" -> {
                    result.success(isServiceRunning())
                }
                "getPerAppUsage" -> {
                    result.success(MyVpnService.getPerAppUsageJson())
                }
                "getInstalledApps" -> {
                    Thread {
                        val appsList = ArrayList<Map<String, Any>>()
                        try {
                            val todayUidBytes = HashMap<Int, Long>()
                            try {
                                val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                                if (nsm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val cal = java.util.Calendar.getInstance().apply {
                                        set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        set(java.util.Calendar.MINUTE, 0)
                                        set(java.util.Calendar.SECOND, 0)
                                        set(java.util.Calendar.MILLISECOND, 0)
                                    }
                                    val startOfDay = cal.timeInMillis
                                    val now = System.currentTimeMillis()
                                    val bucket = NetworkStats.Bucket()

                                    try {
                                        val w = nsm.queryDetails(NetworkCapabilities.TRANSPORT_WIFI, null, startOfDay, now)
                                        while (w.hasNextBucket()) {
                                            w.getNextBucket(bucket)
                                            val u = bucket.uid
                                            if (u >= 1000) todayUidBytes[u] = (todayUidBytes[u] ?: 0L) + bucket.rxBytes + bucket.txBytes
                                        }
                                        w.close()
                                    } catch (_: Exception) {}

                                    try {
                                        val c = nsm.queryDetails(NetworkCapabilities.TRANSPORT_CELLULAR, null, startOfDay, now)
                                        while (c.hasNextBucket()) {
                                            c.getNextBucket(bucket)
                                            val u = bucket.uid
                                            if (u >= 1000) todayUidBytes[u] = (todayUidBytes[u] ?: 0L) + bucket.rxBytes + bucket.txBytes
                                        }
                                        c.close()
                                    } catch (_: Exception) {}
                                }
                            } catch (_: Exception) {}

                            val pm = this@MainActivity.packageManager
                            val packages = pm.getInstalledPackages(0)
                            for (pkg in packages) {
                                val appInfo = pkg.applicationInfo ?: continue
                                val flags = appInfo.flags
                                val isSystem = (flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
                                val launchIntent = pm.getLaunchIntentForPackage(pkg.packageName)
                                if (launchIntent != null || !isSystem) {
                                    val map = HashMap<String, Any>()
                                    map["packageName"] = pkg.packageName
                                    map["appName"] = appInfo.loadLabel(pm).toString()
                                    map["uid"] = appInfo.uid
                                    
                                    val realTodayBytes = todayUidBytes[appInfo.uid] ?: 0L
                                    map["totalMb"] = realTodayBytes.toDouble() / (1024.0 * 1024.0)
                                    
                                    cachedPackageUids[pkg.packageName] = appInfo.uid

                                    // Get app icon and convert to Base64
                                    try {
                                        val iconDrawable = appInfo.loadIcon(pm)
                                        val bitmap = if (iconDrawable is android.graphics.drawable.BitmapDrawable) {
                                            iconDrawable.bitmap
                                        } else {
                                            val w = if (iconDrawable.intrinsicWidth > 0) iconDrawable.intrinsicWidth else 64
                                            val h = if (iconDrawable.intrinsicHeight > 0) iconDrawable.intrinsicHeight else 64
                                            val bmp = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
                                            val canvas = android.graphics.Canvas(bmp)
                                            iconDrawable.setBounds(0, 0, canvas.width, canvas.height)
                                            iconDrawable.draw(canvas)
                                            bmp
                                        }
                                        
                                        // Resize to 48x48 to save memory and IPC payload size
                                        val resizedBitmap = android.graphics.Bitmap.createScaledBitmap(bitmap, 48, 48, true)
                                        val outputStream = java.io.ByteArrayOutputStream()
                                        resizedBitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 80, outputStream)
                                        val bytes = outputStream.toByteArray()
                                        val base64Icon = android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
                                        map["appIcon"] = base64Icon
                                    } catch (e: Exception) {
                                        map["appIcon"] = ""
                                    }
                                    
                                    appsList.add(map)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error getting packages: ${e.message}")
                        }
                        runOnUiThread {
                            result.success(appsList)
                        }
                    }.start()
                }
                "checkPermissionsStatus" -> {
                    val status = HashMap<String, Boolean>()
                    // 1. Usage Stats
                    val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
                    val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        appOps?.unsafeCheckOpNoThrow(
                            AppOpsManager.OPSTR_GET_USAGE_STATS,
                            Process.myUid(),
                            packageName
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        appOps?.checkOpNoThrow(
                            AppOpsManager.OPSTR_GET_USAGE_STATS,
                            Process.myUid(),
                            packageName
                        )
                    }
                    status["usageStats"] = (mode == AppOpsManager.MODE_ALLOWED)

                    // 2. Battery Optimization
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    status["batteryOptimization"] = (pm?.isIgnoringBatteryOptimizations(packageName) == true)

                    // 3. Notification
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                    status["notification"] = (nm?.areNotificationsEnabled() == true)

                    // 4. VPN
                    status["vpn"] = (VpnService.prepare(this@MainActivity) == null)

                    result.success(status)
                }
                "requestUsageStatsPermission" -> {
                    var opened = false
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (_: Exception) {}

                    if (!opened) {
                        try {
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } catch (ex: Exception) {
                            Log.e(TAG, "Failed opening usage access settings: ${ex.message}")
                        }
                    }
                    result.success(true)
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed opening app settings: ${e.message}")
                    }
                    result.success(true)
                }
                "requestBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    } catch (e: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            })
                        } catch (ex: Exception) {
                            Log.e(TAG, "Failed opening battery optimization: ${ex.message}")
                        }
                    }
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                    } else {
                        try {
                            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed opening notification settings: ${e.message}")
                        }
                    }
                    result.success(true)
                }
                "getPerAppTraffic" -> {
                    Thread {
                        val map = HashMap<String, Double>()
                        try {
                            val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
                            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                appOps?.unsafeCheckOpNoThrow(
                                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                                    Process.myUid(),
                                    packageName
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                appOps?.checkOpNoThrow(
                                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                                    Process.myUid(),
                                    packageName
                                )
                            }
                            val isUsageAllowed = (mode == AppOpsManager.MODE_ALLOWED)

                            if (isUsageAllowed && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                                if (nsm != null) {
                                    val cal = java.util.Calendar.getInstance()
                                    val endTime = cal.timeInMillis
                                    // Query from start of current day
                                    cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    cal.set(java.util.Calendar.MINUTE, 0)
                                    cal.set(java.util.Calendar.SECOND, 0)
                                    val startTime = cal.timeInMillis

                                    val uidBytesMap = HashMap<Int, Long>()

                                    try {
                                        val bucket = NetworkStats.Bucket()
                                        val wifiStats = nsm.querySummary(NetworkCapabilities.TRANSPORT_WIFI, null, startTime, endTime)
                                        while (wifiStats.hasNextBucket()) {
                                            wifiStats.getNextBucket(bucket)
                                            val u = bucket.uid
                                            val bytes = bucket.rxBytes + bucket.txBytes
                                            uidBytesMap[u] = (uidBytesMap[u] ?: 0L) + bytes
                                        }
                                        wifiStats.close()
                                    } catch (_: Exception) {}

                                    try {
                                        val bucket = NetworkStats.Bucket()
                                        val cellStats = nsm.querySummary(NetworkCapabilities.TRANSPORT_CELLULAR, null, startTime, endTime)
                                        while (cellStats.hasNextBucket()) {
                                            cellStats.getNextBucket(bucket)
                                            val u = bucket.uid
                                            val bytes = bucket.rxBytes + bucket.txBytes
                                            uidBytesMap[u] = (uidBytesMap[u] ?: 0L) + bytes
                                        }
                                        cellStats.close()
                                    } catch (_: Exception) {}

                                    for ((pkgName, uid) in cachedPackageUids) {
                                        val sysBytes = uidBytesMap[uid] ?: 0L
                                        if (sysBytes > 0L) {
                                            map[pkgName] = sysBytes.toDouble() / (1024.0 * 1024.0)
                                        } else {
                                            val uidRx = android.net.TrafficStats.getUidRxBytes(uid)
                                            val uidTx = android.net.TrafficStats.getUidTxBytes(uid)
                                            val b = maxOf(0L, uidRx) + maxOf(0L, uidTx)
                                            map[pkgName] = b.toDouble() / (1024.0 * 1024.0)
                                        }
                                    }
                                    runOnUiThread {
                                        result.success(map)
                                    }
                                    return@Thread
                                }
                            }

                            // Fallback to TrafficStats if permission not granted
                            for ((pkgName, uid) in cachedPackageUids) {
                                val uidRx = android.net.TrafficStats.getUidRxBytes(uid)
                                val uidTx = android.net.TrafficStats.getUidTxBytes(uid)
                                if (uidRx > 0L || uidTx > 0L) {
                                    val totalBytes = maxOf(0L, uidRx) + maxOf(0L, uidTx)
                                    val mb = totalBytes.toDouble() / (1024.0 * 1024.0)
                                    map[pkgName] = mb
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error reading per-app traffic: ${e.message}")
                        }
                        runOnUiThread {
                            result.success(map)
                        }
                    }.start()
                }
                "getStats" -> {
                    val statsMap = HashMap<String, Any>()
                    statsMap["downloadBps"] = downloadBps
                    statsMap["uploadBps"] = uploadBps
                    statsMap["totalDownloadBytes"] = totalDownloadBytes
                    statsMap["totalUploadBytes"] = totalUploadBytes
                    result.success(statsMap)
                }
                "getRealPeriodData" -> {
                    val period = call.argument<String>("period") ?: "today"
                    Thread {
                        val res = HashMap<String, Any>()
                        try {
                            val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                            val cal = java.util.Calendar.getInstance()
                            val now = cal.timeInMillis

                            val startCal = java.util.Calendar.getInstance()
                            when (period) {
                                "week" -> {
                                    startCal.add(java.util.Calendar.DAY_OF_YEAR, -6)
                                    startCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    startCal.set(java.util.Calendar.MINUTE, 0)
                                    startCal.set(java.util.Calendar.SECOND, 0)
                                }
                                "month" -> {
                                    startCal.add(java.util.Calendar.DAY_OF_YEAR, -29)
                                    startCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    startCal.set(java.util.Calendar.MINUTE, 0)
                                    startCal.set(java.util.Calendar.SECOND, 0)
                                }
                                "this_month" -> {
                                    startCal.set(java.util.Calendar.DAY_OF_MONTH, 1)
                                    startCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    startCal.set(java.util.Calendar.MINUTE, 0)
                                    startCal.set(java.util.Calendar.SECOND, 0)
                                }
                                else -> { // "today"
                                    startCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    startCal.set(java.util.Calendar.MINUTE, 0)
                                    startCal.set(java.util.Calendar.SECOND, 0)
                                }
                            }
                            val periodStartTime = startCal.timeInMillis

                            var totalRx = 0L
                            var totalTx = 0L
                            var wifiTotalRx = 0L
                            var wifiTotalTx = 0L
                            var cellTotalRx = 0L
                            var cellTotalTx = 0L
                            val appUsageMap = HashMap<String, Double>()
                            val uidMap = HashMap<Int, Long>()

                            if (nsm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val bucket = NetworkStats.Bucket()

                                try {
                                    val wifiStats = nsm.querySummary(NetworkCapabilities.TRANSPORT_WIFI, null, periodStartTime, now)
                                    while (wifiStats.hasNextBucket()) {
                                        wifiStats.getNextBucket(bucket)
                                        totalRx += bucket.rxBytes
                                        totalTx += bucket.txBytes
                                        wifiTotalRx += bucket.rxBytes
                                        wifiTotalTx += bucket.txBytes
                                    }
                                    wifiStats.close()
                                } catch (_: Exception) {}

                                try {
                                    val cellStats = nsm.querySummary(NetworkCapabilities.TRANSPORT_CELLULAR, null, periodStartTime, now)
                                    while (cellStats.hasNextBucket()) {
                                        cellStats.getNextBucket(bucket)
                                        totalRx += bucket.rxBytes
                                        totalTx += bucket.txBytes
                                        cellTotalRx += bucket.rxBytes
                                        cellTotalTx += bucket.txBytes
                                    }
                                    cellStats.close()
                                } catch (_: Exception) {}

                                try {
                                    val wifiDetails = nsm.queryDetails(NetworkCapabilities.TRANSPORT_WIFI, null, periodStartTime, now)
                                    while (wifiDetails.hasNextBucket()) {
                                        wifiDetails.getNextBucket(bucket)
                                        val u = bucket.uid
                                        if (u >= 1000) {
                                            uidMap[u] = (uidMap[u] ?: 0L) + bucket.rxBytes + bucket.txBytes
                                        }
                                    }
                                    wifiDetails.close()
                                } catch (_: Exception) {}

                                try {
                                    val cellDetails = nsm.queryDetails(NetworkCapabilities.TRANSPORT_CELLULAR, null, periodStartTime, now)
                                    while (cellDetails.hasNextBucket()) {
                                        cellDetails.getNextBucket(bucket)
                                        val u = bucket.uid
                                        if (u >= 1000) {
                                            uidMap[u] = (uidMap[u] ?: 0L) + bucket.rxBytes + bucket.txBytes
                                        }
                                    }
                                    cellDetails.close()
                                } catch (_: Exception) {}

                                val pm = packageManager
                                for ((uid, bytes) in uidMap) {
                                    if (bytes > 0L) {
                                        val pkgs = pm.getPackagesForUid(uid)
                                        if (pkgs != null) {
                                            for (pkg in pkgs) {
                                                appUsageMap[pkg] = (appUsageMap[pkg] ?: 0.0) + (bytes.toDouble() / (1024.0 * 1024.0))
                                            }
                                        }
                                    }
                                }
                            }

                            // Real daily points (Descending: Today first)
                            val dailyPoints = ArrayList<Map<String, Any>>()
                            val dayCal = java.util.Calendar.getInstance()
                            dayCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                            dayCal.set(java.util.Calendar.MINUTE, 0)
                            dayCal.set(java.util.Calendar.SECOND, 0)

                            val dayNames = arrayOf("الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت")
                            val numDays = when (period) {
                                "month" -> 30
                                "this_month" -> java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_MONTH)
                                else -> 7
                            }

                            for (i in 0 until numDays) {
                                val dStart = java.util.Calendar.getInstance().apply {
                                    timeInMillis = dayCal.timeInMillis
                                    add(java.util.Calendar.DAY_OF_YEAR, -i)
                                }
                                val dEnd = java.util.Calendar.getInstance().apply {
                                    timeInMillis = dStart.timeInMillis
                                    add(java.util.Calendar.DAY_OF_YEAR, 1)
                                }

                                var dayWifiRx = 0L
                                var dayWifiTx = 0L
                                var dayMobileRx = 0L
                                var dayMobileTx = 0L
                                if (nsm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val bucket = NetworkStats.Bucket()
                                    try {
                                        val w = nsm.querySummary(NetworkCapabilities.TRANSPORT_WIFI, null, dStart.timeInMillis, minOf(now, dEnd.timeInMillis))
                                        while (w.hasNextBucket()) {
                                            w.getNextBucket(bucket)
                                            dayWifiRx += bucket.rxBytes
                                            dayWifiTx += bucket.txBytes
                                        }
                                        w.close()
                                    } catch (_: Exception) {}

                                    try {
                                        val c = nsm.querySummary(NetworkCapabilities.TRANSPORT_CELLULAR, null, dStart.timeInMillis, minOf(now, dEnd.timeInMillis))
                                        while (c.hasNextBucket()) {
                                            c.getNextBucket(bucket)
                                            dayMobileRx += bucket.rxBytes
                                            dayMobileTx += bucket.txBytes
                                        }
                                        c.close()
                                    } catch (_: Exception) {}
                                }

                                val dayRx = dayWifiRx + dayMobileRx
                                val dayTx = dayWifiTx + dayMobileTx

                                val dayOfWeek = dStart.get(java.util.Calendar.DAY_OF_WEEK) - 1
                                val label = when (i) {
                                    0 -> "اليوم"
                                    1 -> "أمس"
                                    in 2..6 -> dayNames[dayOfWeek.coerceIn(0, 6)]
                                    else -> "${dStart.get(java.util.Calendar.DAY_OF_MONTH)}/${dStart.get(java.util.Calendar.MONTH) + 1} ${dayNames[dayOfWeek.coerceIn(0, 6)]}"
                                }

                                val pt = HashMap<String, Any>()
                                pt["label"] = label
                                pt["downloadMb"] = dayRx.toDouble() / (1024.0 * 1024.0)
                                pt["uploadMb"] = dayTx.toDouble() / (1024.0 * 1024.0)
                                pt["totalMb"] = (dayRx + dayTx).toDouble() / (1024.0 * 1024.0)
                                pt["wifiMb"] = (dayWifiRx + dayWifiTx).toDouble() / (1024.0 * 1024.0)
                                pt["mobileMb"] = (dayMobileRx + dayMobileTx).toDouble() / (1024.0 * 1024.0)
                                dailyPoints.add(pt)
                            }

                            res["totalDownloadMb"] = totalRx.toDouble() / (1024.0 * 1024.0)
                            res["totalUploadMb"] = totalTx.toDouble() / (1024.0 * 1024.0)
                            res["totalMb"] = (totalRx + totalTx).toDouble() / (1024.0 * 1024.0)
                            res["wifiTotalMb"] = (wifiTotalRx + wifiTotalTx).toDouble() / (1024.0 * 1024.0)
                            res["mobileTotalMb"] = (cellTotalRx + cellTotalTx).toDouble() / (1024.0 * 1024.0)
                            res["appBreakdown"] = appUsageMap
                            res["dailyPoints"] = dailyPoints

                            runOnUiThread {
                                result.success(res)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in getRealPeriodData: ${e.message}")
                            runOnUiThread {
                                result.success(res)
                            }
                        }
                    }.start()
                }
                "getPerAppTrafficByNetwork" -> {
                    val session = call.argument<String>("session") ?: "today"
                    val customStart = call.argument<Number>("startTime")?.toLong()
                    val customEnd = call.argument<Number>("endTime")?.toLong()

                    Thread {
                        val wifiMap = HashMap<String, Double>()
                        val mobileMap = HashMap<String, Double>()
                        var totalWifiBytes = 0L
                        var totalMobileBytes = 0L
                        var periodStart = 0L
                        var periodEnd = 0L

                        try {
                            val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                            if (nsm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val cal = java.util.Calendar.getInstance()
                                val now = cal.timeInMillis
                                periodEnd = now

                                when (session) {
                                    "today" -> {
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis
                                    }
                                    "yesterday" -> {
                                        cal.add(java.util.Calendar.DAY_OF_YEAR, -1)
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 23)
                                        cal.set(java.util.Calendar.MINUTE, 59)
                                        cal.set(java.util.Calendar.SECOND, 59)
                                        cal.set(java.util.Calendar.MILLISECOND, 999)
                                        periodEnd = cal.timeInMillis
                                    }
                                    "this_week" -> {
                                        cal.set(java.util.Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis
                                    }
                                    "last_7_days" -> {
                                        cal.add(java.util.Calendar.DAY_OF_YEAR, -6)
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis
                                    }
                                    "this_month" -> {
                                        cal.set(java.util.Calendar.DAY_OF_MONTH, 1)
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis
                                    }
                                    "last_month" -> {
                                        cal.set(java.util.Calendar.DAY_OF_MONTH, 1)
                                        cal.add(java.util.Calendar.MONTH, -1)
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis

                                        val lastDay = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
                                        cal.set(java.util.Calendar.DAY_OF_MONTH, lastDay)
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 23)
                                        cal.set(java.util.Calendar.MINUTE, 59)
                                        cal.set(java.util.Calendar.SECOND, 59)
                                        cal.set(java.util.Calendar.MILLISECOND, 999)
                                        periodEnd = cal.timeInMillis
                                    }
                                    "this_year" -> {
                                        cal.set(java.util.Calendar.DAY_OF_YEAR, 1)
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis
                                    }
                                    "all_time" -> {
                                        cal.add(java.util.Calendar.YEAR, -3)
                                        periodStart = cal.timeInMillis
                                    }
                                    "custom" -> {
                                        periodStart = customStart ?: (now - 86400000L * 7)
                                        periodEnd = customEnd ?: now
                                    }
                                    else -> {
                                        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
                                        cal.set(java.util.Calendar.MINUTE, 0)
                                        cal.set(java.util.Calendar.SECOND, 0)
                                        cal.set(java.util.Calendar.MILLISECOND, 0)
                                        periodStart = cal.timeInMillis
                                    }
                                }

                                val bucket = NetworkStats.Bucket()

                                // WiFi per-app
                                try {
                                    val wifiDetails = nsm.queryDetails(NetworkCapabilities.TRANSPORT_WIFI, null, periodStart, periodEnd)
                                    val uidWifi = HashMap<Int, Long>()
                                    while (wifiDetails.hasNextBucket()) {
                                        wifiDetails.getNextBucket(bucket)
                                        val u = bucket.uid
                                        val b = bucket.rxBytes + bucket.txBytes
                                        totalWifiBytes += b
                                        if (u >= 1000) {
                                            uidWifi[u] = (uidWifi[u] ?: 0L) + b
                                        }
                                    }
                                    wifiDetails.close()
                                    val pm = packageManager
                                    for ((uid, bytes) in uidWifi) {
                                        val pkgs = pm.getPackagesForUid(uid)
                                        if (pkgs != null) {
                                            for (pkg in pkgs) {
                                                wifiMap[pkg] = (wifiMap[pkg] ?: 0.0) + (bytes.toDouble() / (1024.0 * 1024.0))
                                            }
                                        }
                                    }
                                } catch (_: Exception) {}

                                // Mobile per-app
                                try {
                                    val cellDetails = nsm.queryDetails(NetworkCapabilities.TRANSPORT_CELLULAR, null, periodStart, periodEnd)
                                    val uidMobile = HashMap<Int, Long>()
                                    while (cellDetails.hasNextBucket()) {
                                        cellDetails.getNextBucket(bucket)
                                        val u = bucket.uid
                                        val b = bucket.rxBytes + bucket.txBytes
                                        totalMobileBytes += b
                                        if (u >= 1000) {
                                            uidMobile[u] = (uidMobile[u] ?: 0L) + b
                                        }
                                    }
                                    cellDetails.close()
                                    val pm = packageManager
                                    for ((uid, bytes) in uidMobile) {
                                        val pkgs = pm.getPackagesForUid(uid)
                                        if (pkgs != null) {
                                            for (pkg in pkgs) {
                                                mobileMap[pkg] = (mobileMap[pkg] ?: 0.0) + (bytes.toDouble() / (1024.0 * 1024.0))
                                            }
                                        }
                                    }
                                } catch (_: Exception) {}
                            }
                        } catch (_: Exception) {}

                        val res = HashMap<String, Any>()
                        res["wifi"] = wifiMap
                        res["mobile"] = mobileMap
                        res["totalWifiMb"] = totalWifiBytes.toDouble() / (1024.0 * 1024.0)
                        res["totalMobileMb"] = totalMobileBytes.toDouble() / (1024.0 * 1024.0)
                        res["startTime"] = periodStart
                        res["endTime"] = periodEnd
                        runOnUiThread {
                            result.success(res)
                        }
                    }.start()
                }
                "getDailyLogs" -> {
                    val file = java.io.File(filesDir, "daily_usage.txt")
                    val list = ArrayList<Map<String, Any>>()
                    if (file.exists()) {
                        try {
                            file.forEachLine { line ->
                                val parts = line.split(",")
                                if (parts.size == 3) {
                                    val map = HashMap<String, Any>()
                                    map["date"] = parts[0]
                                    map["downloadBytes"] = parts[1].toLongOrNull() ?: 0L
                                    map["uploadBytes"] = parts[2].toLongOrNull() ?: 0L
                                    list.add(map)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error reading daily log: ${e.message}")
                        }
                    }
                    result.success(list)
                }
                "startMonitorService" -> {
                    val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("monitor_service_enabled", true).apply()
                    NetworkMonitorService.startService(this)
                    result.success(true)
                }
                "stopMonitorService" -> {
                    val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("monitor_service_enabled", false).apply()
                    NetworkMonitorService.stopService(this)
                    result.success(true)
                }
                "isMonitorRunning" -> {
                    result.success(NetworkMonitorService.isRunning)
                }
                "getMonitorLiveStats" -> {
                    val map = HashMap<String, Any>()
                    map["downloadBps"] = NetworkMonitorService.liveDownBps
                    map["uploadBps"] = NetworkMonitorService.liveUpBps
                    map["todayWifiBytes"] = NetworkMonitorService.todayWifiBytes
                    map["todayMobileBytes"] = NetworkMonitorService.todayMobileBytes
                    result.success(map)
                }
                "getPerAppTraffic" -> {
                    Thread {
                        val map = HashMap<String, Double>()
                        try {
                            val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                            if (nsm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val cal = java.util.Calendar.getInstance().apply {
                                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                                    set(java.util.Calendar.MINUTE, 0)
                                    set(java.util.Calendar.SECOND, 0)
                                    set(java.util.Calendar.MILLISECOND, 0)
                                }
                                val startOfDay = cal.timeInMillis
                                val now = System.currentTimeMillis()
                                val bucket = NetworkStats.Bucket()
                                val uidMap = HashMap<Int, Long>()

                                try {
                                    val w = nsm.queryDetails(NetworkCapabilities.TRANSPORT_WIFI, null, startOfDay, now)
                                    while (w.hasNextBucket()) {
                                        w.getNextBucket(bucket)
                                        val u = bucket.uid
                                        if (u >= 1000) {
                                            uidMap[u] = (uidMap[u] ?: 0L) + bucket.rxBytes + bucket.txBytes
                                        }
                                    }
                                    w.close()
                                } catch (_: Exception) {}

                                try {
                                    val c = nsm.queryDetails(NetworkCapabilities.TRANSPORT_CELLULAR, null, startOfDay, now)
                                    while (c.hasNextBucket()) {
                                        c.getNextBucket(bucket)
                                        val u = bucket.uid
                                        if (u >= 1000) {
                                            uidMap[u] = (uidMap[u] ?: 0L) + bucket.rxBytes + bucket.txBytes
                                        }
                                    }
                                    c.close()
                                } catch (_: Exception) {}

                                val pm = packageManager
                                for ((uid, bytes) in uidMap) {
                                    if (bytes > 0L) {
                                        val pkgs = pm.getPackagesForUid(uid)
                                        if (pkgs != null) {
                                            for (pkg in pkgs) {
                                                map[pkg] = (map[pkg] ?: 0.0) + (bytes.toDouble() / (1024.0 * 1024.0))
                                            }
                                        }
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "getPerAppTraffic error: ${e.message}")
                        }
                        runOnUiThread {
                            result.success(map)
                        }
                    }.start()
                }
                "setSpikeAlertEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("spike_alert_enabled", enabled).apply()
                    result.success(true)
                }
                "setAutoQuarantine" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("cybnux_auto_quarantine", enabled).apply()
                    result.success(true)
                }
                "isSpikeAlertEnabled" -> {
                    val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                    val enabled = prefs.getBoolean("spike_alert_enabled", true)
                    result.success(enabled)
                }
                "setAppLanguage" -> {
                    val lang = call.argument<String>("language") ?: "ar"
                    val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                    prefs.edit().putString("app_language", lang).apply()
                    NetworkMonitorService.instance?.updateNotification()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                Log.i(TAG, "VPN Permission granted by user.")
                startVpnService(
                    pendingDownloadLimit, pendingUploadLimit, pendingAllowedApps,
                    pendingBlockedWifiApps, pendingBlockedDataApps, pendingBlockAllFirewall, pendingAllowedFirewallApps,
                    pendingDnsAdBlock, pendingDnsAdultBlock, pendingDnsSocialBlock, pendingDnsCustomBlocked, pendingDnsServers,
                    pendingDataCapBytes, pendingDataCapAction,
                    pendingSchedEnabled, pendingSchedStartH, pendingSchedStartM, pendingSchedEndH, pendingSchedEndM,
                    pendingAppSpeedConfigs,
                    pendingLockdownScreenOff
                )
                methodResult?.success(true)
            } else {
                Log.w(TAG, "VPN Permission denied by user.")
                methodResult?.success(false)
            }
            methodResult = null
        }
    }

    private fun startVpnService(
        download: Long, upload: Long, allowedApps: List<String>,
        blockedWifiApps: List<String>, blockedDataApps: List<String>,
        blockAllFirewall: Boolean, allowedFirewallApps: List<String>,
        dnsAdBlock: Boolean, dnsAdultBlock: Boolean, dnsSocialBlock: Boolean,
        dnsCustomBlocked: List<String>,
        dnsServers: List<String>,
        dataCapBytes: Long, dataCapAction: String,
        schedEnabled: Boolean, schedStartH: Int, schedStartM: Int, schedEndH: Int, schedEndM: Int,
        appSpeedConfigs: String,
        lockdownScreenOff: Boolean = false
    ) {
        val intent = Intent(this@MainActivity, MyVpnService::class.java).apply {
            action = MyVpnService.ACTION_START
            putExtra(MyVpnService.EXTRA_DOWNLOAD_LIMIT, download)
            putExtra(MyVpnService.EXTRA_UPLOAD_LIMIT, upload)
            putStringArrayListExtra(MyVpnService.EXTRA_ALLOWED_APPS, ArrayList(allowedApps))
            putStringArrayListExtra(MyVpnService.EXTRA_BLOCKED_WIFI_APPS, ArrayList(blockedWifiApps))
            putStringArrayListExtra(MyVpnService.EXTRA_BLOCKED_DATA_APPS, ArrayList(blockedDataApps))
            putExtra(MyVpnService.EXTRA_BLOCK_ALL_FIREWALL, blockAllFirewall)
            putStringArrayListExtra(MyVpnService.EXTRA_ALLOWED_FIREWALL_APPS, ArrayList(allowedFirewallApps))
            putExtra(MyVpnService.EXTRA_DNS_ADBLOCK, dnsAdBlock)
            putExtra(MyVpnService.EXTRA_DNS_ADULTBLOCK, dnsAdultBlock)
            putExtra(MyVpnService.EXTRA_DNS_SOCIALBLOCK, dnsSocialBlock)
            putStringArrayListExtra(MyVpnService.EXTRA_DNS_CUSTOM_BLOCKED, ArrayList(dnsCustomBlocked))
            putStringArrayListExtra(MyVpnService.EXTRA_DNS_SERVERS, ArrayList(dnsServers))
            putExtra(MyVpnService.EXTRA_DATACAP_BYTES, dataCapBytes)
            putExtra(MyVpnService.EXTRA_DATACAP_ACTION, dataCapAction)
            putExtra(MyVpnService.EXTRA_SCHED_ENABLED, schedEnabled)
            putExtra(MyVpnService.EXTRA_SCHED_START_H, schedStartH)
            putExtra(MyVpnService.EXTRA_SCHED_START_M, schedStartM)
            putExtra(MyVpnService.EXTRA_SCHED_END_H, schedEndH)
            putExtra(MyVpnService.EXTRA_SCHED_END_M, schedEndM)
            putExtra(MyVpnService.EXTRA_APP_SPEED_CONFIGS, appSpeedConfigs)
            putExtra(MyVpnService.EXTRA_LOCKDOWN_SCREEN_OFF, lockdownScreenOff)
        }

        // Save settings to native storage for persistence across reboots
        MyVpnService.saveSettingsToPrefs(
            this@MainActivity,
            download, upload, allowedApps, blockedWifiApps, blockedDataApps,
            blockAllFirewall, allowedFirewallApps,
            dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked, dnsServers,
            dataCapBytes, dataCapAction,
            schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM,
            appSpeedConfigs,
            vpnActive = true,
            lockdownScreenOff = lockdownScreenOff
        )

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            this@MainActivity.startForegroundService(intent)
        } else {
            this@MainActivity.startService(intent)
        }
    }

    private fun stopVpnService() {
        // Mark VPN as inactive in native storage
        MyVpnService.setVpnActiveState(this@MainActivity, false)

        val intent = Intent(this@MainActivity, MyVpnService::class.java).apply {
            action = MyVpnService.ACTION_STOP
        }
        this@MainActivity.startService(intent)
    }

    private fun updateVpnSettings(
        download: Long, upload: Long, allowedApps: List<String>,
        blockedWifiApps: List<String>, blockedDataApps: List<String>,
        blockAllFirewall: Boolean, allowedFirewallApps: List<String>,
        dnsAdBlock: Boolean, dnsAdultBlock: Boolean, dnsSocialBlock: Boolean,
        dnsCustomBlocked: List<String>,
        dnsServers: List<String>,
        dataCapBytes: Long, dataCapAction: String,
        schedEnabled: Boolean, schedStartH: Int, schedStartM: Int, schedEndH: Int, schedEndM: Int,
        appSpeedConfigs: String,
        lockdownScreenOff: Boolean = false
    ) {
        // Update persistent native settings
        MyVpnService.saveSettingsToPrefs(
            this@MainActivity,
            download, upload, allowedApps, blockedWifiApps, blockedDataApps,
            blockAllFirewall, allowedFirewallApps,
            dnsAdBlock, dnsAdultBlock, dnsSocialBlock, dnsCustomBlocked, dnsServers,
            dataCapBytes, dataCapAction,
            schedEnabled, schedStartH, schedStartM, schedEndH, schedEndM,
            appSpeedConfigs,
            vpnActive = MyVpnService.isRunning,
            lockdownScreenOff = lockdownScreenOff
        )

        val intent = Intent(this@MainActivity, MyVpnService::class.java).apply {
            action = MyVpnService.ACTION_UPDATE_SETTINGS
            putExtra(MyVpnService.EXTRA_DOWNLOAD_LIMIT, download)
            putExtra(MyVpnService.EXTRA_UPLOAD_LIMIT, upload)
            putStringArrayListExtra(MyVpnService.EXTRA_ALLOWED_APPS, ArrayList(allowedApps))
            putStringArrayListExtra(MyVpnService.EXTRA_BLOCKED_WIFI_APPS, ArrayList(blockedWifiApps))
            putStringArrayListExtra(MyVpnService.EXTRA_BLOCKED_DATA_APPS, ArrayList(blockedDataApps))
            putExtra(MyVpnService.EXTRA_BLOCK_ALL_FIREWALL, blockAllFirewall)
            putStringArrayListExtra(MyVpnService.EXTRA_ALLOWED_FIREWALL_APPS, ArrayList(allowedFirewallApps))
            putExtra(MyVpnService.EXTRA_DNS_ADBLOCK, dnsAdBlock)
            putExtra(MyVpnService.EXTRA_DNS_ADULTBLOCK, dnsAdultBlock)
            putExtra(MyVpnService.EXTRA_DNS_SOCIALBLOCK, dnsSocialBlock)
            putStringArrayListExtra(MyVpnService.EXTRA_DNS_CUSTOM_BLOCKED, ArrayList(dnsCustomBlocked))
            putStringArrayListExtra(MyVpnService.EXTRA_DNS_SERVERS, ArrayList(dnsServers))
            putExtra(MyVpnService.EXTRA_DATACAP_BYTES, dataCapBytes)
            putExtra(MyVpnService.EXTRA_DATACAP_ACTION, dataCapAction)
            putExtra(MyVpnService.EXTRA_SCHED_ENABLED, schedEnabled)
            putExtra(MyVpnService.EXTRA_SCHED_START_H, schedStartH)
            putExtra(MyVpnService.EXTRA_SCHED_START_M, schedStartM)
            putExtra(MyVpnService.EXTRA_SCHED_END_H, schedEndH)
            putExtra(MyVpnService.EXTRA_SCHED_END_M, schedEndM)
            putExtra(MyVpnService.EXTRA_APP_SPEED_CONFIGS, appSpeedConfigs)
            putExtra(MyVpnService.EXTRA_LOCKDOWN_SCREEN_OFF, lockdownScreenOff)
        }
        this@MainActivity.startService(intent)
    }

    private fun isServiceRunning(): Boolean {
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            if (interfaces != null) {
                while (interfaces.hasMoreElements()) {
                    val networkInterface = interfaces.nextElement()
                    if (networkInterface.name.startsWith("tun") && networkInterface.isUp) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking network interfaces: ${e.message}")
        }
        return false
    }
}
