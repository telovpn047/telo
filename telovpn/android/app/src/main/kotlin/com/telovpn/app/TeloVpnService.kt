package com.telovpn.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream

class TeloVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.telovpn.app.START"
        const val ACTION_STOP = "com.telovpn.app.STOP"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_SERVER_NAME = "serverName"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "telovpn_channel"
        var isRunning = false
        private const val TAG = "TeloVpnService"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var xrayProcess: Process? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: ""
                val serverName = intent.getStringExtra(EXTRA_SERVER_NAME) ?: "TeloVPN"
                serviceScope.launch { startVpn(config, serverName) }
                START_STICKY
            }
            ACTION_STOP -> {
                serviceScope.launch { stopVpn() }
                START_NOT_STICKY
            }
            else -> START_NOT_STICKY
        }
    }

    private suspend fun startVpn(config: String, serverName: String) {
        withContext(Dispatchers.Main) {
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification(serverName, true))
        }

        try {
            // Write config
            val configFile = File(filesDir, "xray_config.json")
            configFile.writeText(config)
            Log.d(TAG, "Config written: ${configFile.length()} bytes")

            // Extract and start Xray
            val xrayStarted = startXrayCore(configFile.absolutePath)

            if (xrayStarted) {
                // Setup TUN interface
                withContext(Dispatchers.Main) {
                    setupVpnInterface()
                }
                isRunning = true
                Log.d(TAG, "VPN started successfully")
            } else {
                Log.e(TAG, "Xray failed to start")
                withContext(Dispatchers.Main) { stopVpn() }
            }
        } catch (e: Exception) {
            Log.e(TAG, "VPN start error: ${e.message}")
            withContext(Dispatchers.Main) { stopVpn() }
        }
    }

    private suspend fun startXrayCore(configPath: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val xrayBinary = extractXrayBinary()
                if (!xrayBinary.exists()) {
                    Log.e(TAG, "Xray binary not found at: ${xrayBinary.absolutePath}")
                    return@withContext false
                }

                xrayBinary.setExecutable(true, true)

                // Copy geo files to working dir
                copyGeoFiles()

                val processBuilder = ProcessBuilder(
                    xrayBinary.absolutePath, "run", "-c", configPath
                )
                processBuilder.environment().apply {
                    put("XRAY_LOCATION_ASSET", filesDir.absolutePath)
                    put("XRAY_LOCATION_CONFIG", filesDir.absolutePath)
                }
                processBuilder.redirectErrorStream(true)
                processBuilder.directory(filesDir)

                xrayProcess = processBuilder.start()

                // Read logs
                serviceScope.launch(Dispatchers.IO) {
                    xrayProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                        Log.d("Xray", line)
                    }
                }

                // Wait for xray to initialize (check if process is alive)
                delay(1500)
                val alive = xrayProcess?.isAlive ?: false
                Log.d(TAG, "Xray process alive: $alive")
                alive
            } catch (e: Exception) {
                Log.e(TAG, "Error starting Xray: ${e.message}")
                false
            }
        }
    }

    private fun extractXrayBinary(): File {
        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        val assetName = when {
            abi.contains("arm64") -> "xray/xray_arm64"
            abi.contains("armeabi") -> "xray/xray_arm"
            abi.contains("x86_64") -> "xray/xray_x64"
            else -> "xray/xray_arm64"
        }

        val outputFile = File(filesDir, "xray_binary")

        try {
            assets.open(assetName).use { input ->
                FileOutputStream(outputFile).use { output ->
                    input.copyTo(output)
                }
            }
            Log.d(TAG, "Extracted xray from assets: $assetName")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract xray binary: ${e.message}")
        }

        return outputFile
    }

    private fun copyGeoFiles() {
        listOf("geoip.dat", "geosite.dat").forEach { filename ->
            val destFile = File(filesDir, filename)
            if (!destFile.exists()) {
                try {
                    assets.open("xray/$filename").use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    Log.d(TAG, "Copied $filename")
                } catch (e: Exception) {
                    Log.w(TAG, "Could not copy $filename: ${e.message}")
                }
            }
        }
    }

    private fun setupVpnInterface() {
        val builder = Builder()
            .setSession("TeloVPN")
            .addAddress("10.10.10.1", 32)
            .addAddress("fd00::1", 128)
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .setMtu(1500)
            .setBlocking(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        vpnInterface?.close()
        vpnInterface = builder.establish()
        Log.d(TAG, "VPN interface: ${vpnInterface?.fd}")
    }

    private suspend fun stopVpn() {
        isRunning = false
        try {
            xrayProcess?.destroyForcibly()
            xrayProcess = null
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            Log.e(TAG, "Stop error: ${e.message}")
        }
        withContext(Dispatchers.Main) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun buildNotification(serverName: String, connected: Boolean): Notification {
        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, TeloVpnService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TeloVPN")
            .setContentText(if (connected) "✓ Birikdirildi: $serverName" else "Birikdirilmedi")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Kes", stopIntent)
            .setOngoing(connected)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "TeloVPN", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "TeloVPN birikme ýagdaýy"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        serviceScope.launch { stopVpn() }
        serviceScope.cancel()
        super.onDestroy()
    }
}
