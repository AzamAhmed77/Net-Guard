package com.cybnux.net_speed_controller

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class PackageReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pkgName = intent.data?.schemeSpecificPart ?: return
        val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
        val savedLang = prefs.getString("app_language", prefs.getString("selected_language", null))
        val isAr = if (savedLang != null) savedLang == "ar" else java.util.Locale.getDefault().language == "ar"

        if (intent.action == Intent.ACTION_PACKAGE_REMOVED) {
            val msg = if (isAr) "تم إلغاء تثبيت تطبيق: $pkgName" else "App uninstalled: $pkgName"
            appendEvent(context, "WARN", msg)
            Log.i("PackageReceiver", "App removed: $pkgName")
            return
        }

        if (intent.action == Intent.ACTION_PACKAGE_ADDED) {
            val msg = if (isAr) "تم تثبيت تطبيق جديد: $pkgName" else "New app installed: $pkgName"
            appendEvent(context, "INFO", msg)
            Log.i("PackageReceiver", "New app installed: $pkgName")

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
                    MyVpnService.buildUpdateIntentFromPrefs(context)?.let { updateIntent ->
                        context.startService(updateIntent)
                    }
                }
            }
        }
    }

    private fun appendEvent(context: Context, level: String, message: String) {
        val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
        val events = JSONArray(prefs.getString("native_event_logs", "[]"))
        events.put(JSONObject().apply {
            put("level", level)
            put("message", message)
            put("time", System.currentTimeMillis())
        })
        while (events.length() > 50) events.remove(0)
        prefs.edit().putString("native_event_logs", events.toString()).apply()
    }
}
