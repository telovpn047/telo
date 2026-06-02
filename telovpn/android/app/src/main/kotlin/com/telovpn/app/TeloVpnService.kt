package com.telovpn.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
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

    private var vpnInterface: android.os.ParcelFileDescriptor? = null
    private var xrayProcess: Process? = null
    private val serviceScope = CoroutineScope(
        Dispatchers.IO + SupervisorJob() +
        CoroutineExceptionHandler { _, throwable ->
            // Process öldürülürken stream kapanması beklenen bir durum — sessizce geç
            val msg = throwable.message ?: ""
            if (msg.contains("interrupted by close") || msg.contains("Stream closed")) {
                return@CoroutineExceptionHandler
            }
            Log.e(TAG, "VPN scope uncaught: $msg", throwable)
            addLog("[VPN] Hata (${throwable.javaClass.simpleName}): $msg")
        }
    )

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
        try {
            // Foreground bildirimi — önce bu, aksi hâlde 5s ANR / Android 14 exception
            withContext(Dispatchers.Main) {
                createNotificationChannel()
                startForegroundCompat(buildNotification(serverName, true))
            }

            // 1. Config dosyasını yaz
            val configFile = File(filesDir, "xray_config.json")
            configFile.writeText(config)
            log("Config yazıldı: ${configFile.length()} byte")

            // 2. Xray binary başlat
            val xrayOk = startXrayCore(configFile.absolutePath)
            if (!xrayOk) {
                log("Xray başlatılamadı — VPN durduruluyor")
                withContext(Dispatchers.Main) { stopVpn() }
                return
            }

            // 3. TUN arayüzünü kur (Main thread zorunlu)
            withContext(Dispatchers.Main) { setupVpnInterface() }

            if (vpnInterface == null) {
                log("TUN arayüzü kurulamadı — VPN durduruluyor")
                withContext(Dispatchers.Main) { stopVpn() }
                return
            }

            // 4. tun2socks JNI köprüsü (TUN → SOCKS5, in-process — no exec → no O_CLOEXEC issue)
            val tun2socksOk = startTun2Socks(vpnInterface!!.fd)
            if (!tun2socksOk) {
                log("tun2socks başlatılamadı — VPN durduruluyor")
                withContext(Dispatchers.Main) { stopVpn() }
                return
            }

            isRunning = true
            log("VPN başarıyla başlatıldı")

        } catch (e: Exception) {
            log("VPN başlatma hatası (${e.javaClass.simpleName}): ${e.message}")
            try { withContext(Dispatchers.Main) { stopVpn() } } catch (_: Exception) {}
        }
    }

    // ── Xray ────────────────────────────────────────────────────────────────

    private suspend fun startXrayCore(configPath: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val xrayBin = nativeBinary("libxray.so")
                if (xrayBin == null || !xrayBin.exists()) {
                    log("Xray binary bulunamadı (nativeLibraryDir): libxray.so")
                    return@withContext false
                }
                log("Xray binary: ${xrayBin.absolutePath}")
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
                    try {
                        xrayProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                            Log.d("Xray", line); addLog("[Xray] $line")
                        }
                    } catch (_: Exception) { /* process öldürüldüğünde normal */ }
                }

                // Xray'in SOCKS5 portunu açmasını bekle (en fazla ~10s)
                delay(500)
                if (xrayProcess?.isAlive != true) {
                    log("Xray süreci hemen sonlandı — config veya binary hatası")
                    return@withContext false
                }

                var socksReady = false
                for (i in 0 until 20) {
                    if (checkPortOpen("127.0.0.1", 10808, timeoutMs = 500)) {
                        socksReady = true
                        break
                    }
                    if (xrayProcess?.isAlive != true) {
                        log("Xray çalışırken durdu (deneme ${i + 1})")
                        break
                    }
                    Thread.sleep(500)
                }
                log("SOCKS5 port 10808 hazır: $socksReady")
                socksReady
            } catch (e: Exception) {
                log("Xray başlatma istisnası: ${e.message}")
                false
            }
        }
    }

    // ── tun2socks (JNI in-process) ───────────────────────────────────────────

    private fun startTun2Socks(tunFd: Int): Boolean {
        return try {
            log("tun2socks JNI başlatılıyor — fd=$tunFd")
            val rc = VpnCore.startTun2Socks(tunFd, 1500, "socks5://127.0.0.1:10808")
            log("tun2socks JNI sonucu: $rc")
            rc == 0
        } catch (e: Exception) {
            log("tun2socks JNI istisnası (${e.javaClass.simpleName}): ${e.message}")
            false
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

    /**
     * jniLibs içinden paketlenip nativeLibraryDir'e çıkarılmış ikiliyi döndürür.
     * Android 10+ yalnızca bu dizindeki dosyaların çalıştırılmasına izin verir.
     */
    private fun nativeBinary(soName: String): File? {
        val dir = applicationInfo.nativeLibraryDir
        val f = File(dir, soName)
        return if (f.exists()) f else null
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun copyGeoFiles() {
        // Uygulama sürümü değiştiğinde geo verisi de güncellensin diye
        // assets içindeki kopya daha büyük/farklıysa her zaman üzerine yaz.
        listOf("geoip.dat", "geosite.dat").forEach { filename ->
            val dest = File(filesDir, filename)
            try {
                val assetSize = assets.openFd("xray/$filename").use { it.length }
                if (!dest.exists() || dest.length() != assetSize) {
                    assets.open("xray/$filename").use { i ->
                        FileOutputStream(dest).use { o -> i.copyTo(o) }
                    }
                    log("Geo dosyası kopyalandı: $filename (${dest.length()} byte)")
                }
            } catch (e: Exception) {
                // openFd sıkıştırılmış asset'lerde başarısız olabilir → düz kopyala
                if (!dest.exists()) {
                    try {
                        assets.open("xray/$filename").use { i ->
                            FileOutputStream(dest).use { o -> i.copyTo(o) }
                        }
                        log("Geo dosyası kopyalandı (fallback): $filename")
                    } catch (e2: Exception) {
                        log("Geo dosyası kopyalanamadı ($filename): ${e2.message}")
                    }
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
            try { VpnCore.stopTun2Socks() } catch (_: Exception) {}
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
