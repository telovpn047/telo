package com.telovpn.app

import android.app.Activity
import android.content.Intent
import android.net.TrafficStats
import android.net.VpnService
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.telovpn.app/vpn"
    private val VPN_REQUEST_CODE = 100
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVpnPermission" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        pendingResult = result
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        result.success(true)
                    }
                }
                "startVpn" -> {
                    val config = call.argument<String>("config") ?: ""
                    val serverName = call.argument<String>("serverName") ?: "TeloVPN"
                    startVpnService(config, serverName)
                    result.success(true)
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                "getVpnStatus" -> {
                    result.success(TeloVpnService.isRunning)
                }
                "getTrafficStats" -> {
                    result.success(readTrafficStats())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startVpnService(config: String, serverName: String) {
        val intent = Intent(this, TeloVpnService::class.java).apply {
            action = TeloVpnService.ACTION_START
            putExtra(TeloVpnService.EXTRA_CONFIG, config)
            putExtra(TeloVpnService.EXTRA_SERVER_NAME, serverName)
        }
        startForegroundService(intent)
    }

    private fun stopVpnService() {
        val intent = Intent(this, TeloVpnService::class.java).apply {
            action = TeloVpnService.ACTION_STOP
        }
        startService(intent)
    }

    private fun readTrafficStats(): Map<String, Long> {
        return try {
            var rxBytes = 0L
            var txBytes = 0L
            val lines = File("/proc/net/dev").readLines()
            for (line in lines) {
                val trimmed = line.trim()
                if (trimmed.startsWith("tun") || trimmed.startsWith("vpn")) {
                    // Format: iface rx_bytes rx_packets rx_errs rx_drop ... tx_bytes ...
                    val parts = trimmed.split(":").getOrNull(1)
                        ?.trim()?.split("\\s+".toRegex()) ?: continue
                    rxBytes += parts.getOrNull(0)?.toLongOrNull() ?: 0L
                    txBytes += parts.getOrNull(8)?.toLongOrNull() ?: 0L
                }
            }
            if (rxBytes == 0L && txBytes == 0L) {
                val uid = Process.myUid()
                rxBytes = TrafficStats.getUidRxBytes(uid).coerceAtLeast(0L)
                txBytes = TrafficStats.getUidTxBytes(uid).coerceAtLeast(0L)
            }
            mapOf("rx" to rxBytes, "tx" to txBytes)
        } catch (e: Exception) {
            val uid = Process.myUid()
            mapOf(
                "rx" to TrafficStats.getUidRxBytes(uid).coerceAtLeast(0L),
                "tx" to TrafficStats.getUidTxBytes(uid).coerceAtLeast(0L)
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            pendingResult?.success(resultCode == Activity.RESULT_OK)
            pendingResult = null
        }
    }
}
