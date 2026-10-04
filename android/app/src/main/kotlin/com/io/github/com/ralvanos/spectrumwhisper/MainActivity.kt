package com.io.github.com.ralvanos.spectrumwhisper

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spectrumwhisper/cell")
            .setMethodCallHandler { call, result ->
                if (call.method == "read") {
                    result.success(readCell())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun readCell(): Map<String, Any?> {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        if (fine != PackageManager.PERMISSION_GRANTED) {
            return mapOf(
                "available" to false,
                "detail" to "Location permission is required before Android will share a cellular signal.",
            )
        }
        val manager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val infos = try {
            manager.allCellInfo
        } catch (_: SecurityException) {
            return mapOf("available" to false, "detail" to "Android blocked the cellular reading.")
        }
        if (infos.isNullOrEmpty()) {
            return mapOf("available" to false, "detail" to "No cellular radio reported a tower.")
        }
        val serving = infos.firstOrNull { it.isRegistered } ?: infos.first()
        var kind = "Cellular"
        var dbm: Int? = null
        when (serving) {
            is CellInfoLte -> {
                kind = "LTE"
                dbm = serving.cellSignalStrength.dbm
            }
            is CellInfoGsm -> {
                kind = "GSM"
                dbm = serving.cellSignalStrength.dbm
            }
            is CellInfoWcdma -> {
                kind = "WCDMA"
                dbm = serving.cellSignalStrength.dbm
            }
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && serving is CellInfoNr) {
                    kind = "5G"
                    dbm = serving.cellSignalStrength.dbm
                }
            }
        }
        val operator = try {
            manager.networkOperatorName
        } catch (_: SecurityException) {
            ""
        }
        return mapOf(
            "available" to true,
            "kind" to kind,
            "dbm" to dbm,
            "operator" to operator,
        )
    }
}
