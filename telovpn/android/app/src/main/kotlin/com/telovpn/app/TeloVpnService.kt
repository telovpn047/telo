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
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.LinkedBlockingDeque

class TeloVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.telovpn.app.START"
        const val ACTION_STOP  = "com.telovpn.app.STOP"
        const val EXTRA_CONFIG      = "config"
        const val EXTRA_SERVER_NAME = "serverName"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID      = "telovpn_channel"
        var isRunning = false
        private const val TAG = "TeloVpnService"

        // ── Shared log ring-buffer (max 500 lines) ──────────────────────────
        private val logBuffer = LinkedBlockingDeque<String>(500)
        fun addLog(line: String) {
            if (logBuffer.size >= 500) logBuffer.pollFirst()
            logBuffer.addLast(line)
        }
        fun getLogs(): List<String> = logBuffer.toList()
        fun clearLogs() = logBuffer.clear()
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var xrayProcess: Process?    = null
    private var tun2socksProcess: Process? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START -> {
                val config     = intent.getStringExtra(EXTRA_CONFIG) ?: ""
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

    // ── VPN start ────────────────────────────────────────────────────────────

    private suspend fun startVpn(config: String, serverName: String) {
        log("VPN başlatılıyor: $serverName")
        withContext(Dispatchers.Main) {
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification(serverName, true))
        }

        try {
            // 1. Config dosyasını yaz
            val configFile = File(filesDir, "xray_config.json")
            configFile.writeText(config)
            log("Config yazıldı: ${configFile.length()} byte")

            // 2. Xray binary'yi çıkart ve başlat
            val xrayOk = startXrayCore(configFile.absolutePath)
            if (!xrayOk) {
                log("Xray başlatılamadı — VPN durduruluyor")
                withContext(Dispatchers.Main) { stopVpn() }
                return
            }

            // 3. TUN arayüzünü kur
            //    Kendi trafiğimizi VPN dışında bırak (routing loop engeli)
            withContext(Dispatchers.Main) {
                setupVpnInterface()
            }

            if (vpnInterface == null) {
                log("TUN arayüzü kurulamadı")
                withContext(Dispatchers.Main) { stopVpn() }
                return
            }

            // 4. tun2socks başlat (TUN → SOCKS5 köprüsü)
            val tunFd = vpnInterface!!.fd
            val tun2socksOk = startTun2Socks(tunFd)
            if (!tun2socksOk) {
                log("tun2socks başlatılamadı — temel mod devam ediyor (SOCKS only)")
                // Yine de devam et; kullanıcı SOCKS proxy olarak kullanabilir
            }

            isRunning = true
            log("VPN başarıyla başlatıldı")

        } catch (e: Exception) {
            log("VPN başlatma hatası: ${e.message}")
            withContext(Dispatchers.Main) { stopVpn() }
        }
    }

    // ── Xray ────────────────────────────────────────────────────────────────

    private suspend fun startXrayCore(configPath: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val xrayBin = extractBinary("xray_binary", detectAbi("xray"))
                if (!xrayBin.exists()) {
                    log("Xray binary bulunamadı: ${xrayBin.absolutePath}")
                    return@withContext false
                }
                xrayBin.setExecutable(true, true)
                copyGeoFiles()

                val pb = ProcessBuilder(xrayBin.absolutePath, "run", "-c", configPath).apply {
                    environment().apply {
                        put("XRAY_LOCATION_ASSET", filesDir.absolutePath)
                        put("XRAY_LOCATION_CONFIG", filesDir.absolutePath)
                    }
                    redirectErrorStream(true)
                    directory(filesDir)
                }

                xrayProcess = pb.start()

                // Xray stdout → log buffer
                serviceScope.launch(Dispatchers.IO) {
                    xrayProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                        Log.d("Xray", line)
                        addLog("[Xray] $line")
                    }
                }

                // Xray'in başlaması için bekle ve SOCKS portunu kontrol et
                delay(2000)
                val alive = xrayProcess?.isAlive ?: false
                log("Xray süreci hayatta: $alive")

                if (alive) {
                    // SOCKS portunun dinlenip dinlenmediğini kontrol et
                    val socksReady = checkPortOpen("127.0.0.1", 10808, timeoutMs = 3000)
                    log("SOCKS5 port 10808 hazır: $socksReady")
                    if (!socksReady) {
                        log("Xray başladı ama SOCKS portu henüz dinlenmiyor, 2s daha bekleniyor...")
                        delay(2000)
                    }
                }
                alive
            } catch (e: Exception) {
                log("Xray başlatma istisnası: ${e.message}")
                false
            }
        }
    }

    // ── tun2socks ────────────────────────────────────────────────────────────

    private suspend fun startTun2Socks(tunFd: Int): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val t2sBin = extractBinary("tun2socks_binary", detectAbi("tun2socks"))
                if (!t2sBin.exists()) {
                    log("tun2socks binary assets'te bulunamadı — yüklenmemiş olabilir")
                    return@withContext false
                }
                t2sBin.setExecutable(true, true)

                val pb = ProcessBuilder(
                    t2sBin.absolutePath,
                    "-device", "tun://fd/$tunFd",
                    "-proxy",  "socks5://127.0.0.1:10808",
                    "-loglevel", "warning"
                ).apply {
                    redirectErrorStream(true)
                    directory(filesDir)
                }

                tun2socksProcess = pb.start()

                serviceScope.launch(Dispatchers.IO) {
                    tun2socksProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                        Log.d("tun2socks", line)
                        addLog("[tun2socks] $line")
                    }
                }

                delay(1000)
                val alive = tun2socksProcess?.isAlive ?: false
                log("tun2socks süreci hayatta: $alive")
                alive
            } catch (e: Exception) {
                log("tun2socks başlatma istisnası: ${e.message}")
                false
            }
        }
    }

    // ── TUN arayüzü ──────────────────────────────────────────────────────────

    private fun setupVpnInterface() {
        val builder = Builder()
            .setSession("TeloVPN")
            .addAddress("10.0.0.1", 30)
            .addAddress("fd00::1", 126)
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .setMtu(1500)
            .setBlocking(false)

        // Kendi trafiğimizi VPN dışında bırak → xray routing loop engeli
        try {
            builder.addDisallowedApplication(packageName)
        } catch (e: Exception) {
            log("addDisallowedApplication hatası: ${e.message}")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        vpnInterface?.close()
        vpnInterface = builder.establish()
        log("TUN arayüzü fd: ${vpnInterface?.fd}")
    }

    // ── Yardımcı ─────────────────────────────────────────────────────────────

    private fun detectAbi(name: String): String {
        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        return when {
            abi.contains("arm64") -> "xray/${name}_arm64"
            abi.contains("x86_64") -> "xray/${name}_x64"
            else -> "xray/${name}_arm64"
        }
    }

    private fun extractBinary(destName: String, assetPath: String): File {
        val outputFile = File(filesDir, destName)
        return try {
            assets.open(assetPath).use { input ->
                FileOutputStream(outputFile).use { output -> input.copyTo(output) }
            }
            log("Binary çıkartıldı: $assetPath → $destName")
            outputFile
        } catch (e: Exception) {
            log("Binary çıkartma hatası ($assetPath): ${e.message}")
            outputFile
        }
    }

    private fun copyGeoFiles() {
        listOf("geoip.dat", "geosite.dat").forEach { filename ->
            val dest = File(filesDir, filename)
            if (!dest.exists()) {
                try {
                    assets.open("xray/$filename").use { i ->
                        FileOutputStream(dest).use { o -> i.copyTo(o) }
                    }
                    log("Geo dosyası kopyalandı: $filename")
                } catch (e: Exception) {
                    log("Geo dosyası kopyalanamadı ($filename): ${e.message}")
                }
            }
        }
    }

    private fun checkPortOpen(host: String, port: Int, timeoutMs: Int): Boolean {
        return try {
            val sock = Socket()
            sock.connect(InetSocketAddress(host, port), timeoutMs)
            sock.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun log(msg: String) {
        Log.d(TAG, msg)
        addLog("[VPN] $msg")
    }

    // ── Durdur ───────────────────────────────────────────────────────────────

    private suspend fun stopVpn() {
        isRunning = false
        log("VPN durduruluyor...")
        try {
            tun2socksProcess?.destroyForcibly()
            tun2socksProcess = null
            xrayProcess?.destroyForcibly()
            xrayProcess = null
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            log("Durdurma hatası: ${e.message}")
        }
        withContext(Dispatchers.Main) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    // ── Bildirim ─────────────────────────────────────────────────────────────

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
            .setContentText(if (connected) "✓ Birikdirildi: $serverName" else "Kesildi")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Kes", stopIntent)
            .setOngoing(connected)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "TeloVPN", NotificationManager.IMPORTANCE_LOW).apply {
                description = "TeloVPN birikme ýagdaýy"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    override fun onDestroy() {
        serviceScope.launch { stopVpn() }
        serviceScope.cancel()
        super.onDestroy()
    }
}
