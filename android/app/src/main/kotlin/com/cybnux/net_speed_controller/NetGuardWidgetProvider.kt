package com.cybnux.net_speed_controller

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import java.util.Locale

class NetGuardWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "NetGuardWidget"

        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, NetGuardWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                    for (appWidgetId in appWidgetIds) {
                        updateAppWidget(context, appWidgetManager, appWidgetId)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to update widgets: ${e.message}")
            }
        }

        private fun formatBytes(bytes: Long): String {
            if (bytes <= 0) return "0.0 MB"
            val mb = bytes / (1024.0 * 1024.0)
            return if (mb >= 1024.0) {
                String.format(Locale.US, "%.2f GB", mb / 1024.0)
            } else {
                String.format(Locale.US, "%.1f MB", mb)
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_net_guard)
                val isRunning = MyVpnService.isRunning

                // Determine language (check cybnux_settings or system locale)
                val prefs = context.getSharedPreferences("cybnux_settings", Context.MODE_PRIVATE)
                val savedLang = prefs.getString("selected_language", null)
                val isAr = if (savedLang != null) {
                    savedLang == "ar"
                } else {
                    Locale.getDefault().language == "ar"
                }

                // Status & Button Text
                if (isRunning) {
                    views.setTextViewText(R.id.tv_widget_status, if (isAr) "🟢 محمي" else "🟢 Protected")
                    views.setTextColor(R.id.tv_widget_status, 0xFF10B981.toInt())
                    views.setTextViewText(R.id.btn_widget_toggle, if (isAr) "⏹ إيقاف" else "⏹ Stop")
                    views.setInt(R.id.btn_widget_toggle, "setBackgroundResource", R.drawable.bg_notif_btn_red)
                } else {
                    views.setTextViewText(R.id.tv_widget_status, if (isAr) "⚪ متوقف" else "⚪ Protection Off")
                    views.setTextColor(R.id.tv_widget_status, 0xFF94A3B8.toInt())
                    views.setTextViewText(R.id.btn_widget_toggle, if (isAr) "⚡ تشغيل" else "⚡ Start")
                    views.setInt(R.id.btn_widget_toggle, "setBackgroundResource", R.drawable.bg_notif_btn_green)
                }

                // Traffic Usage
                val totalTodayBytes = NetworkMonitorService.todayWifiBytes + NetworkMonitorService.todayMobileBytes
                val usageStr = formatBytes(totalTodayBytes)
                views.setTextViewText(
                    R.id.tv_widget_usage,
                    if (isAr) "استهلاك اليوم: $usageStr" else "Today: $usageStr"
                )

                // Toggle PendingIntent (Sends broadcast to VpnActionReceiver)
                val toggleIntent = Intent(context, VpnActionReceiver::class.java).apply {
                    action = VpnActionReceiver.ACTION_TOGGLE_VPN
                }
                val togglePendingIntent = PendingIntent.getBroadcast(
                    context,
                    1001,
                    toggleIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                views.setOnClickPendingIntent(R.id.btn_widget_toggle, togglePendingIntent)

                // Container Click -> Open Main Activity
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                if (launchIntent != null) {
                    val openPendingIntent = PendingIntent.getActivity(
                        context,
                        1002,
                        launchIntent,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                    )
                    views.setOnClickPendingIntent(R.id.widget_container, openPendingIntent)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d(TAG, "Widget $appWidgetId updated successfully (isRunning=$isRunning)")
            } catch (e: Exception) {
                Log.e(TAG, "Error updating app widget $appWidgetId: ${e.message}", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAllWidgets(context)
    }
}
