package com.cybnux.net_speed_controller

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
            val monitorEnabled = prefs.getBoolean("monitor_service_enabled", true)
            if (monitorEnabled) {
                NetworkMonitorService.startService(context)
            }

            // استعادة تشغيل الـ VPN وقواعد الجدار الناري تلقائياً عند إعادة تشغيل الجهاز
            val vpnActive = prefs.getBoolean("vpn_active", false)
            if (vpnActive) {
                try {
                    if (VpnService.prepare(context) == null) {
                        val vpnIntent = MyVpnService.buildStartIntentFromPrefs(context)
                        if (vpnIntent != null) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                context.startForegroundService(vpnIntent)
                            } else {
                                context.startService(vpnIntent)
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("BootReceiver", "Failed to restore VPN on boot: ${e.message}")
                }
            }
        }
    }
}
