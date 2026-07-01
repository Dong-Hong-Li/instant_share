package com.example.instant_share

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.instant_share/network"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLanIps" -> {
                        try {
                            val ips = collectLanIps(applicationContext)
                            result.success(ips)
                        } catch (error: Exception) {
                            result.error(
                                "LAN_IP_ERROR",
                                error.message ?: "无法读取局域网 IP",
                                null,
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun collectLanIps(context: Context): List<String> {
        val ips = linkedSetOf<String>()

        collectFromConnectivityManager(context, ips)
        if (ips.isEmpty()) {
            collectFromNetworkInterfaces(ips)
        }

        return ips.sortedWith(compareBy({ lanIpPriority(it) }, { it }))
    }

    private fun collectFromConnectivityManager(context: Context, ips: LinkedHashSet<String>) {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val network = cm.activeNetwork ?: return
        val caps = cm.getNetworkCapabilities(network) ?: return
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return

        val linkProps = cm.getLinkProperties(network) ?: return
        for (address in linkProps.linkAddresses) {
            val ip = address.address
            if (ip !is Inet4Address || ip.isLoopbackAddress) continue
            val host = ip.hostAddress ?: continue
            if (isPrivateLanIp(host)) {
                ips.add(host)
            }
        }
    }

    private fun collectFromNetworkInterfaces(ips: LinkedHashSet<String>) {
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return
        while (interfaces.hasMoreElements()) {
            val networkInterface = interfaces.nextElement()
            if (!networkInterface.isUp || networkInterface.isLoopback) continue

            val name = networkInterface.name.lowercase()
            if (isVirtualInterface(name)) continue

            for (address in networkInterface.inetAddresses) {
                if (address !is Inet4Address || address.isLoopbackAddress) continue
                val host = address.hostAddress ?: continue
                if (isPrivateLanIp(host)) {
                    ips.add(host)
                }
            }
        }
    }

    private fun isVirtualInterface(name: String): Boolean {
        val blocked = listOf(
            "rmnet",
            "dummy",
            "tun",
            "p2p",
            "bluetooth",
            "ifb",
        )
        return blocked.any { name.startsWith(it) }
    }

    private fun isPrivateLanIp(ip: String): Boolean {
        if (ip == "127.0.0.1" || ip.startsWith("127.")) return false
        if (ip.startsWith("169.254.")) return false

        val parts = ip.split(".")
        if (parts.size != 4) return false

        val a = parts[0].toIntOrNull() ?: return false
        val b = parts[1].toIntOrNull() ?: return false

        if (a == 10) return true
        if (a == 192 && b == 168) return true
        if (a == 172 && b in 16..31) return true
        return false
    }

    private fun lanIpPriority(ip: String): Int {
        return when {
            ip.startsWith("192.168.") -> 0
            ip.startsWith("10.") -> 1
            ip.startsWith("172.") -> 2
            else -> 3
        }
    }
}
