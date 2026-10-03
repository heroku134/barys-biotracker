package com.yc.nadalsdk.barys_biotracker

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.nadal.ble/methods"
    private val SCAN_CHANNEL = "com.nadal.ble/scan"
    private val EVENT_CHANNEL = "com.nadal.ble/telemetry"
    private val PERMISSION_REQUEST_CODE = 4101

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        KalkanBleManager.init(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sport.kalkan.biotracker/notify")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        KalkanNotify.ensureChannels(this)
                        result.success(true)
                    }
                    "scheduleDaily" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = (args?.get("id") as? Number)?.toInt() ?: 1101
                        val hour = (args?.get("hour") as? Number)?.toInt() ?: 7
                        val minute = (args?.get("minute") as? Number)?.toInt() ?: 0
                        val title = args?.get("title") as? String ?: "KALKAN"
                        val body = args?.get("body") as? String ?: ""
                        val channel = args?.get("channel") as? String ?: "morning"
                        KalkanNotify.scheduleDaily(this, id, hour, minute, title, body, channel)
                        result.success(true)
                    }
                    "cancel" -> {
                        val id = ((call.arguments as? Map<*, *>)?.get("id") as? Number)?.toInt() ?: 0
                        KalkanNotify.cancel(this, id)
                        result.success(true)
                    }
                    "showNow" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = (args?.get("id") as? Number)?.toInt() ?: 1201
                        val title = args?.get("title") as? String ?: "KALKAN"
                        val body = args?.get("body") as? String ?: ""
                        val channel = args?.get("channel") as? String ?: "workout"
                        KalkanNotify.show(this, id, title, body, channel)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sport.kalkan.biotracker/background")
            .setMethodCallHandler { call, result ->
                if (call.method == "scheduleRefresh") {
                    KalkanBleManager.pollTelemetryNow()
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

        // 1. BLE MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "isBluetoothEnabled" -> {
                        result.success(KalkanBleManager.isBluetoothEnabled())
                    }
                    "checkPermissions" -> {
                        result.success(hasRequiredPermissions())
                    }
                    "requestPermissions" -> {
                        if (hasRequiredPermissions()) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            requestRequiredPermissions()
                        }
                    }
                    "startScan" -> {
                        if (!hasRequiredPermissions()) {
                            result.error("PERMISSION_DENIED", "Bluetooth scan permissions not granted", null)
                            return@setMethodCallHandler
                        }
                        if (!KalkanBleManager.isBluetoothEnabled()) {
                            result.error("BLUETOOTH_DISABLED", "Bluetooth is turned off", null)
                            return@setMethodCallHandler
                        }
                        KalkanBleManager.startScan { success, err ->
                            if (success) result.success(true) else result.error("SCAN_ERROR", err, null)
                        }
                    }
                    "stopScan" -> {
                        KalkanBleManager.stopScan()
                        result.success(true)
                    }
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (!address.isNullOrEmpty()) {
                            KalkanBleManager.connect(address) { success, err ->
                                if (success) result.success(true) else result.error("CONNECT_ERROR", err, null)
                            }
                        } else {
                            result.error("INVALID_ADDRESS", "Device address is null", null)
                        }
                    }
                    "disconnect" -> {
                        val forget = call.argument<Boolean>("forget") ?: false
                        KalkanBleManager.disconnect(forget)
                        result.success(true)
                    }
                    "findDevice" -> {
                        KalkanBleManager.findDevice { success, err ->
                            if (success) result.success(true) else result.error("NOT_CONNECTED", err, null)
                        }
                    }
                    "measureHeartRate" -> {
                        KalkanBleManager.measureHeartRate { success, err ->
                            if (success) result.success(true) else result.error("NOT_CONNECTED", err, null)
                        }
                    }
                    "syncTime" -> {
                        KalkanBleManager.syncTime { success, err ->
                            if (success) result.success(true) else result.error("NOT_CONNECTED", err, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Scan EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    KalkanBleManager.setScanSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    KalkanBleManager.setScanSink(null)
                }
            })

        // 3. Telemetry EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    KalkanBleManager.setTelemetrySink(events)
                }

                override fun onCancel(arguments: Any?) {
                    KalkanBleManager.setTelemetrySink(null)
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        KalkanBleManager.setTelemetrySink(null)
        KalkanBleManager.setScanSink(null)
    }

    private fun hasRequiredPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        }
        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }
}
