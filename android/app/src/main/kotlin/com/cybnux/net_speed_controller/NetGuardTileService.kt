package com.cybnux.net_speed_controller

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class NetGuardTileService : TileService() {

    companion object {
        private const val TAG = "NetGuardTileService"

        fun requestTileUpdate(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    requestListeningState(
                        context,
                        ComponentName(context, NetGuardTileService::class.java)
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to request tile update: ${e.message}")
                }
            }
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onStopListening() {
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        Log.i(TAG, "Quick Settings tile clicked! Current VPN isRunning=${MyVpnService.isRunning}")

        // Send toggle broadcast to existing VpnActionReceiver
        val toggleIntent = Intent(this, VpnActionReceiver::class.java).apply {
            action = VpnActionReceiver.ACTION_TOGGLE_VPN
        }
        sendBroadcast(toggleIntent)

        // Optimistically flip or wait a short moment and refresh tile
        Handler(Looper.getMainLooper()).postDelayed({
            updateTileState()
        }, 350)
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        try {
            val isRunning = MyVpnService.isRunning
            tile.state = if (isRunning) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            tile.label = "Net Guard"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = if (isRunning) "Protected" else "Protection Off"
            }
            tile.icon = Icon.createWithResource(this, R.drawable.ic_notification)
            tile.updateTile()
            Log.d(TAG, "Tile updated: state=${tile.state}")
        } catch (e: Exception) {
            Log.e(TAG, "Error updating tile: ${e.message}", e)
        }
    }
}
