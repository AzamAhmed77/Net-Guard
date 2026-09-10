package com.cybnux.net_speed_controller

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

class VpnActionReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "VpnActionReceiver"
        const val ACTION_TOGGLE_VPN = "com.cybnux.netspeed.TOGGLE_VPN"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == ACTION_TOGGLE_VPN) {
            Log.i(TAG, "Notification toggle button pressed: current isRunning=${MyVpnService.isRunning}")
            try {
                if (MyVpnService.isRunning) {
                    Log.i(TAG, "Stopping VPN via action receiver")
                    val stopIntent = Intent(context, MyVpnService::class.java).apply {
                        action = MyVpnService.ACTION_STOP
                    }
                    context.startService(stopIntent)
                    MyVpnService.setVpnActiveState(context, false)
                } else {
                    Log.i(TAG, "Starting VPN via action receiver")
                    val prepareIntent = VpnService.prepare(context)
                    if (prepareIntent == null) {
                        val startIntent = MyVpnService.buildStartIntentFromPrefs(context)
                        if (startIntent != null) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                context.startForegroundService(startIntent)
                            } else {
                                context.startService(startIntent)
                            }
                            MyVpnService.setVpnActiveState(context, true)
                        } else {
                            Log.w(TAG, "Could not build start intent from prefs")
                        }
                    } else {
                        Log.i(TAG, "VpnService requires preparation, launching UI")
                        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            putExtra("auto_start_vpn", true)
                        }
                        if (launchIntent != null) context.startActivity(launchIntent)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in VpnActionReceiver: ${e.message}", e)
            }

            // Sync with Flutter UI if active
            MainActivity.instance?.syncVpnStateFromNative()

            // Refresh the notification after a brief pause so service status settles
            Handler(Looper.getMainLooper()).postDelayed({
                NetworkMonitorService.instance?.updateNotification(force = true)
                MainActivity.instance?.syncVpnStateFromNative()
                NetGuardTileService.requestTileUpdate(context)
                NetGuardWidgetProvider.updateAllWidgets(context)
            }, 300)
        }
    }
}
