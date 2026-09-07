package com.cybnux.net_speed_controller

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale

class NetworkMonitorService : Service() {
    private val TAG = "NetworkMonitorService"

    companion object {
        const val CHANNEL_ID = "cybnux_monitor_channel"
        const val NOTIFICATION_ID = 3001
        const val SPIKE_NOTIFICATION_ID = 3002

        const val ACTION_START = "com.cybnux.netspeed.MONITOR_START"
        const val ACTION_STOP = "com.cybnux.netspeed.MONITOR_STOP"
        const val ACTION_TOGGLE_VPN = "com.cybnux.netspeed.ACTION_TOGGLE_VPN"
        const val ACTION_REFRESH = "com.cybnux.netspeed.MONITOR_REFRESH"

        @Volatile var isRunning: Boolean = false
        @Volatile var instance: NetworkMonitorService? = null

        // القراءات الحالية المباشرة
        @Volatile var liveDownBps: Long = 0
        @Volatile var liveUpBps: Long = 0
        @Volatile var todayWifiBytes: Long = 0
        @Volatile var todayMobileBytes: Long = 0

        fun startService(context: Context) {
            val intent = Intent(context, NetworkMonitorService::class.java).apply {
                action = ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e("NetworkMonitorService", "startService error: ${e.message}")
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, NetworkMonitorService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                Log.e("NetworkMonitorService", "stopService error: ${e.message}")
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isScreenOn = true

    // قياس السرعة اللحظية
    private var lastRxBytes = 0L
    private var lastTxBytes = 0L
    private var lastSpeedCheckMs = 0L

    // استعلام استهلاك اليوم من NetworkStatsManager (يتم كل 10 ثوانٍ لتوفير الطاقة)
    private var lastUsageQueryMs = 0L

    // كاشف النزيف السري للبيانات (Data Spike)
    private var spikeCheckStartTime = 0L
    private var spikeStartBytes = 0L
    private var spikeAlertShownToday = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> {
                    isScreenOn = true
                    Log.d(TAG, "Screen ON: Switching to active updates")
                    updateNotification(force = true)
                    reschedule(100) // استيقاظ وتحديث فوري بمجرد فتح الشاشة
                }
                Intent.ACTION_SCREEN_OFF -> {
                    isScreenOn = false
                    Log.d(TAG, "Screen OFF: Switching to deep battery-saving mode (zero notifications)")
                    liveDownBps = 0
                    liveUpBps = 0
                    reschedule(60000) // سكون عميق 60 ثانية لتحديث الاستهلاك اليومي فقط بدون إرسال أي إشعار
                }
            }
        }
    }

    private val monitorRunnable = object : Runnable {
        override fun run() {
            try {
                performTick()
            } catch (e: Exception) {
                Log.w(TAG, "Monitor tick error: ${e.message}")
            }

            // جدولة التحديث القادم حسب حالة الشاشة (ثانيتان عند فتح الشاشة، 60 ثانية عند الإغلاق)
            val delay = if (isScreenOn) 2000L else 60000L
            handler.postDelayed(this, delay)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true

        createNotificationChannel()

        // تسجيل مستقبل حالة الشاشة (سكون ذكي لتوفير البطارية)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenReceiver, filter)

        // التهيئة الأولية لعدادات الشبكة
        lastRxBytes = TrafficStats.getTotalRxBytes()
        lastTxBytes = TrafficStats.getTotalTxBytes()
        lastSpeedCheckMs = System.currentTimeMillis()

        spikeCheckStartTime = System.currentTimeMillis()
        spikeStartBytes = (lastRxBytes + lastTxBytes)

        // بدء الخدمة في الواجهة الأمامية (Foreground)
        val initialNotif = buildNotification(0, 0, 0, 0)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                try {
                    startForeground(NOTIFICATION_ID, initialNotif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                } catch (_: Exception) {
                    startForeground(NOTIFICATION_ID, initialNotif)
                }
            } else {
                startForeground(NOTIFICATION_ID, initialNotif)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground error: ${e.message}")
        }

        // بدء حلقة المراقبة
        handler.post(monitorRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        stopForeground(STOP_FOREGROUND_REMOVE)
                    } else {
                        @Suppress("DEPRECATION")
                        stopForeground(true)
                    }
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    nm?.cancel(NOTIFICATION_ID)
                } catch (_: Exception) {}
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_TOGGLE_VPN -> {
                toggleVpnProtection()
            }
            ACTION_REFRESH -> {
                performTick()
            }
        }
        return START_STICKY
    }

    private fun reschedule(delayMs: Long) {
        handler.removeCallbacks(monitorRunnable)
        handler.postDelayed(monitorRunnable, delayMs)
    }

    private fun performTick() {
        val now = System.currentTimeMillis()

        // 1. حساب السرعة الحية (فقط إذا كانت الشاشة مضاءة)
        if (isScreenOn) {
            val curRx = TrafficStats.getTotalRxBytes()
            val curTx = TrafficStats.getTotalTxBytes()
            val dt = now - lastSpeedCheckMs

            if (dt >= 800L) {
                if (curRx >= lastRxBytes && curTx >= lastTxBytes && lastRxBytes > 0) {
                    liveDownBps = ((curRx - lastRxBytes) * 1000L) / dt
                    liveUpBps = ((curTx - lastTxBytes) * 1000L) / dt
                } else {
                    liveDownBps = 0
                    liveUpBps = 0
                }
                lastRxBytes = curRx
                lastTxBytes = curTx
                lastSpeedCheckMs = now
            }
        }

        // 2. تحديث استهلاك اليوم لشبكة الواي فاي والموبايل (كل 30 ثانية لتوفير البطارية ومنع ثقل المعالج)
        val queryInterval = if (isScreenOn) 30000L else 60000L
        if (now - lastUsageQueryMs >= queryInterval || lastUsageQueryMs == 0L) {
            queryTodayUsage()
            lastUsageQueryMs = now
            checkDataSpike(now)
        }

        // 3. تحديث الإشعار الذكي (يحدث فقط عند تغير المحتوى لتبريد المعالج)
        updateNotification()
    }

    // استعلام استهلاك اليوم بدقة من نواة أندرويد
    private fun queryTodayUsage() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        try {
            val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager ?: return
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startOfDay = cal.timeInMillis
            val now = System.currentTimeMillis()

            val bucket = NetworkStats.Bucket()

            // استهلاك الواي فاي اليوم
            var wifiSum = 0L
            try {
                val wifiStats = nsm.querySummary(NetworkCapabilities.TRANSPORT_WIFI, null, startOfDay, now)
                while (wifiStats.hasNextBucket()) {
                    wifiStats.getNextBucket(bucket)
                    wifiSum += (bucket.rxBytes + bucket.txBytes)
                }
                wifiStats.close()
            } catch (_: Exception) {}

            // استهلاك بيانات الهاتف اليوم
            var mobileSum = 0L
            try {
                val mobileStats = nsm.querySummary(NetworkCapabilities.TRANSPORT_CELLULAR, null, startOfDay, now)
                while (mobileStats.hasNextBucket()) {
                    mobileStats.getNextBucket(bucket)
                    mobileSum += (bucket.rxBytes + bucket.txBytes)
                }
                mobileStats.close()
            } catch (_: Exception) {}

            todayWifiBytes = wifiSum
            todayMobileBytes = mobileSum
        } catch (e: Exception) {
            Log.w(TAG, "Error querying today usage: ${e.message}")
        }
    }

    // كاشف النزيف السري للبيانات (أكثر من 500 ميجابايت خلال 5 دقائق)
    private fun checkDataSpike(now: Long) {
        val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
        val spikeAlertEnabled = prefs.getBoolean("spike_alert_enabled", true)
        if (!spikeAlertEnabled) return

        val totalCurrentBytes = TrafficStats.getTotalRxBytes() + TrafficStats.getTotalTxBytes()
        val durationMs = now - spikeCheckStartTime

        if (durationMs > 300000L) { // كل 5 دقائق نفحص الزيادة
            val diffBytes = totalCurrentBytes - spikeStartBytes
            val diffMb = diffBytes / (1024.0 * 1024.0)

            if (diffMb > 500.0 && !spikeAlertShownToday) {
                showSpikeNotification(diffMb.toInt())
                spikeAlertShownToday = true
            }

            // إعادة التصفير للدورة القادمة
            spikeCheckStartTime = now
            spikeStartBytes = totalCurrentBytes
        }
    }

    private fun showSpikeNotification(consumedMb: Int) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra("open_tab", "analytics")
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 999, openIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
        val isEn = (prefs.getString("app_language", "ar") == "en")

        val title = if (isEn) "⚠️ Alert: High Data Spike Detected!" else "⚠️ تنبيه: استهلاك مرتفع ومفاجئ للبيانات!"
        val text = if (isEn) "Over $consumedMb MB consumed in the last few minutes." else "تم استهلاك حوالي $consumedMb ميجابايت خلال دقائق معدودة في الخلفية."

        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(
                if (isEn) "⚠️ High Data Spike:\n$consumedMb MB used in the last 5 minutes. Tap to inspect background apps."
                else "⚠️ تنبيه استهلاك مفاجئ:\nتم استهلاك $consumedMb MB خلال آخر 5 دقائق. افتح التطبيق للتحقق من التطبيق الذي يستهلك باقتك."
            ))
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        nm.notify(SPIKE_NOTIFICATION_ID, notif)
    }

    private var latestLine1 = ""
    private var latestLine2 = ""
    private var latestSubText = ""
    private var lastNotifiedLine1 = ""
    private var lastNotifiedLine2 = ""
    private var lastNotifiedSubText = ""
    private var lastNotifiedTimeMs = 0L

    fun updateNotification(force: Boolean = false) {
        // إذا كانت الشاشة مغلقة ولا يوجد طلب إجباري، لا نرسل أي إشعار للنظام نهائياً لتوفير البطارية والسماح للعتاد بالدخول في Deep Sleep
        if (!isScreenOn && !force) {
            return
        }

        val now = System.currentTimeMillis()
        // وضع فاصل زمني لا يقل عن 3.5 ثوانٍ بين تحديثات الإشعار إلا عند الضرورة لتبريد المعالج ومنع إجهاد SystemUI
        if (!force && (now - lastNotifiedTimeMs < 3500L)) {
            return
        }

        val notif = buildNotification(liveDownBps, liveUpBps, todayWifiBytes, todayMobileBytes)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        val contentChanged = (latestLine1 != lastNotifiedLine1 || latestLine2 != lastNotifiedLine2 || latestSubText != lastNotifiedSubText)
        val heartbeatExpired = (now - lastNotifiedTimeMs >= 30000L)

        // إذا كانت السرعة صفراً ولم يتغير شيء، نتجنب إرسال إشعار متكرر
        val isIdle = (liveDownBps == 0L && liveUpBps == 0L)
        if (isIdle && !contentChanged && !force) {
            return
        }

        if (force || contentChanged || heartbeatExpired || lastNotifiedTimeMs == 0L) {
            lastNotifiedLine1 = latestLine1
            lastNotifiedLine2 = latestLine2
            lastNotifiedSubText = latestSubText
            lastNotifiedTimeMs = now
            nm?.notify(NOTIFICATION_ID, notif)
        }
    }

    fun forceImmediateSpeedUpdate() {
        reschedule(0)
    }

    fun buildCurrentNotification(): Notification {
        return buildNotification(liveDownBps, liveUpBps, todayWifiBytes, todayMobileBytes)
    }

    private fun buildNotification(downBps: Long, upBps: Long, wifiBytes: Long, mobileBytes: Long): Notification {
        val prefs = getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
        val lang = prefs.getString("app_language", "ar") ?: "ar"
        val isEn = (lang == "en")

        val downStr = formatSpeed(downBps)
        val upStr = formatSpeed(upBps)
        val wifiStr = formatBytes(wifiBytes)
        val mobileStr = formatBytes(mobileBytes)

        val line1 = "\u200E↓ $downStr    •    ↑ $upStr"
        val line2 = if (isEn) "WiFi: $wifiStr   •   Mobile: $mobileStr" else "واي فاي: \u200E$wifiStr   •   بيانات: \u200E$mobileStr"

        val isVpnActive = MyVpnService.isRunning
        val subText = if (isEn) {
            if (isVpnActive) "Protection Active 🟢" else "Monitoring Only ⚪"
        } else {
            if (isVpnActive) "حماية نشطة 🟢" else "مراقبة فقط ⚪"
        }

        latestLine1 = line1
        latestLine2 = line2
        latestSubText = subText

        // النقر على الإشعار يفتح التطبيق
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentPendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // 1. زر تشغيل / إيقاف الحماية (الـ VPN) مباشرة من الإشعار تم رفعه للمكان المحدد في الإشعار وحذف زر الإحصائيات
        val toggleVpnIntent = Intent(this, NetworkMonitorService::class.java).apply {
            action = ACTION_TOGGLE_VPN
        }
        val toggleVpnPendingIntent = PendingIntent.getService(
            this, 101, toggleVpnIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val remoteViews = RemoteViews(packageName, R.layout.notification_net_guard)
        remoteViews.setTextViewText(R.id.tv_notif_line1, line1)
        remoteViews.setTextViewText(R.id.tv_notif_line2, line2)

        if (isVpnActive) {
            remoteViews.setTextViewText(R.id.btn_notif_vpn, if (isEn) "🛑 Stop" else "🛑 إيقاف")
            remoteViews.setInt(R.id.btn_notif_vpn, "setBackgroundResource", R.drawable.bg_notif_btn_red)
        } else {
            remoteViews.setTextViewText(R.id.btn_notif_vpn, if (isEn) "⚡ Start" else "⚡ تشغيل")
            remoteViews.setInt(R.id.btn_notif_vpn, "setBackgroundResource", R.drawable.bg_notif_btn_green)
        }
        remoteViews.setOnClickPendingIntent(R.id.btn_notif_vpn, toggleVpnPendingIntent)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(line1)
            .setContentText(line2)
            .setSubText(subText)
            .setSmallIcon(R.drawable.ic_notification)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun toggleVpnProtection() {
        Log.i(TAG, "toggleVpnProtection triggered from notification action")
        val mainActivity = MainActivity.instance
        if (mainActivity != null) {
            mainActivity.toggleVpnFromNative()
        } else {
            // إذا كان التطبيق مغلقاً تماماً في الذاكرة
            if (MyVpnService.isRunning) {
                val stopIntent = Intent(this, MyVpnService::class.java).apply {
                    action = MyVpnService.ACTION_STOP
                }
                startService(stopIntent)
            } else {
                // فتح التطبيق لتشغيل الـ VPN
                val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    putExtra("auto_start_vpn", true)
                }
                if (openIntent != null) startActivity(openIntent)
            }
        }

        // تحديث الإشعار بعد التبديل
        handler.postDelayed({ updateNotification() }, 600)
    }

    private fun formatSpeed(bps: Long): String {
        val kbps = bps / 1024.0
        return if (kbps >= 1024.0) {
            String.format(Locale.US, "%.1f MB/s", kbps / 1024.0)
        } else {
            String.format(Locale.US, "%.1f KB/s", kbps)
        }
    }

    private fun formatBytes(bytes: Long): String {
        val mb = bytes / (1024.0 * 1024.0)
        return if (mb >= 1024.0) {
            String.format(Locale.US, "%.2f GB", mb / 1024.0)
        } else {
            String.format(Locale.US, "%.1f MB", mb)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Net Guard Network Monitor"
            val descriptionText = "Displays live network speed, daily WiFi & Mobile consumption, and quick controls."
            val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        instance = null
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
        handler.removeCallbacksAndMessages(null)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
