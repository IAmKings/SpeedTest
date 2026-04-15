package com.klz.speedtest

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "network_info_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWifiSignalStrength" -> {
                    val signal = getWifiSignalStrength()
                    result.success(signal)
                }
                "getMobileOperator" -> {
                    val operator = getMobileOperator()
                    result.success(operator)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getWifiSignalStrength(): Int? {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiInfo = wifiManager.connectionInfo
            wifiInfo?.rssi
        } catch (e: Exception) {
            null
        }
    }

    private fun getMobileOperator(): String? {
        return try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            telephonyManager.networkOperatorName
        } catch (e: Exception) {
            null
        }
    }
}
