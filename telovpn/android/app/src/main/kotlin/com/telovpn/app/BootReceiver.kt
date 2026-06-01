package com.telovpn.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs: SharedPreferences =
                context.getSharedPreferences("telovpn_prefs", Context.MODE_PRIVATE)
            val autoConnect = prefs.getBoolean("autoConnect", false)

            if (autoConnect) {
                val config = prefs.getString("lastConfig", "") ?: ""
                val serverName = prefs.getString("lastServerName", "TeloVPN") ?: "TeloVPN"

                if (config.isNotEmpty()) {
                    val serviceIntent = Intent(context, TeloVpnService::class.java).apply {
                        action = TeloVpnService.ACTION_START
                        putExtra(TeloVpnService.EXTRA_CONFIG, config)
                        putExtra(TeloVpnService.EXTRA_SERVER_NAME, serverName)
                    }
                    context.startForegroundService(serviceIntent)
                }
            }
        }
    }
}
