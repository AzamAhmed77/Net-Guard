package com.cybnux.net_speed_controller

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class PackageReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_PACKAGE_ADDED) {
            val pkgName = intent.data?.schemeSpecificPart ?: return
            Log.i("PackageReceiver", "New app installed: $pkgName")

            val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
            val autoQuarantine = prefs.getBoolean("cybnux_auto_quarantine", false)
            if (autoQuarantine) {
                Log.i("PackageReceiver", "Auto-quarantining newly installed app: $pkgName")
                val blockedWifi = prefs.getStringSet("blocked_wifi_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                val blockedData = prefs.getStringSet("blocked_data_apps", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                blockedWifi.add(pkgName)
                blockedData.add(pkgName)
                prefs.edit()
                    .putStringSet("blocked_wifi_apps", blockedWifi)
                    .putStringSet("blocked_data_apps", blockedData)
                    .apply()

                if (MyVpnService.isRunning) {
                    val updateIntent = Intent(context, MyVpnService::class.java).apply {
                        action = MyVpnService.ACTION_UPDATE_SETTINGS
                        putStringArrayListExtra(MyVpnService.EXTRA_BLOCKED_WIFI_APPS, ArrayList(blockedWifi))
                        putStringArrayListExtra(MyVpnService.EXTRA_BLOCKED_DATA_APPS, ArrayList(blockedData))
                    }
                    context.startService(updateIntent)
                }
            }
        }
    }
}
