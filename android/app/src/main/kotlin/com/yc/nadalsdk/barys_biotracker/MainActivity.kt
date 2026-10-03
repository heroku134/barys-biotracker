package com.yc.nadalsdk.barys_biotracker

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
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
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 4103

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotifyPermissionResult: MethodChannel.Result? = null
    private var hasEverRequestedBlePermission: Boolean = false

    // BLE-06: Reactive broadcast receiver for Bluetooth on/off transitions
    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                val isEnabled = (state == BluetoothAdapter.STATE_ON)
                KalkanBleManager.onBluetoothAdapterStateChanged(isEnabled)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        KalkanBleManager.init(applicationContext)
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        registerReceiver(bluetoothStateReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(bluetoothStateReceiver)
        } catch (_: Exception) {}
        KalkanBleManager.setTelemetrySink(null)
        KalkanBleManager.setScanSink(null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sport.kalkan.biotracker/notify")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        KalkanNotify.ensureChannels(this)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                                result.success(true)
                            } else {
                                pendingNotifyPermissionResult?.success(false)
                                pendingNotifyPermissionResult = result
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    NOTIFICATION_PERMISSION_REQUEST_CODE
                                )
                            }
                        } else {
                            result.success(true)
                        }
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
                    "isLocationServiceEnabled" -> {
                        result.success(isLocationServiceEnabled())
                    }
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(true)
                    }
                    "openLocationSettings" -> {
                        openLocationSettings()
                        result.success(true)
                    }
                    "checkPermissions" -> {
                        result.success(getPermissionStatusString())
                    }
                    "requestPermissions" -> {
                        if (hasRequiredPermissions()) {
                            result.success("granted")
                        } else {
                            // BLE-06: Resolve any previous pending request so it never hangs in Dart
                            pendingPermissionResult?.success("denied")
                            pendingPermissionResult = result
                            requestRequiredPermissions()
                        }
                    }
                    "startScan" -> {
                        if (!hasRequiredPermissions()) {
                            result.error("PERMISSION_DENIED", "Bluetooth scan permissions not granted", null)
                            return@setMethodCallHandler
                        }
                        if (!isLocationServiceEnabled()) {
                            result.error("LOCATION_DISABLED", "Location services must be enabled on Android <12 for BLE scan", null)
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
                        // BLE-06: Validate permissions and adapter power before attempting connect
                        if (!hasConnectPermission()) {
                            result.error("PERMISSION_DENIED", "BLUETOOTH_CONNECT permission not granted", null)
                            return@setMethodCallHandler
                        }
                        if (!KalkanBleManager.isBluetoothEnabled()) {
                            result.error("BLUETOOTH_DISABLED", "Bluetooth is turned off", null)
                            return@setMethodCallHandler
                        }
                        val address = call.argument<String>("address")
                        if (!address.isNullOrEmpty()) {
                            KalkanBleManager.connect(address) { success, err ->
                                if (success) result.success(true) else result.error("CONNECT_ERROR", err, null)
                            }
                        } else {
                            result.error("INVALID_ADDRESS", "Device address is null", null)
                        }
                    }
                    "cancelConnect" -> {
                        KalkanBleManager.cancelConnect()
                        result.success(true)
                    }
                    "disconnect" -> {
                        val forget = call.argument<Boolean>("forget") ?: false
                        KalkanBleManager.disconnect(forget)
                        result.success(true)
                    }
                    "findDevice" -> {
                        val enable = call.argument<Boolean>("enable") ?: true
                        KalkanBleManager.findDevice(enable) { success, err ->
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
                    "resetFactory" -> {
                        KalkanBleManager.resetFactory { success, err ->
                            if (success) result.success(true) else result.error("RESET_ERROR", err, null)
                        }
                    }
                    "configureHeartRateMonitoring" -> {
                        val interval = call.argument<Int>("intervalMinutes") ?: 15
                        val continuous = call.argument<Boolean>("continuous") ?: false
                        KalkanBleManager.configureHeartRateMonitoring(interval, continuous)
                        result.success(true)
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

    private fun isLocationServiceEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return true
        }
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                lm.isLocationEnabled
            } catch (_: Exception) {
                val gpsEnabled = try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) } catch (_: Exception) { false }
                val netEnabled = try { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { false }
                gpsEnabled || netEnabled
            }
        } else {
            val gpsEnabled = try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) } catch (_: Exception) { false }
            val netEnabled = try { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { false }
            gpsEnabled || netEnabled
        }
    }

    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }

    private fun openLocationSettings() {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }

    private fun hasConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun hasRequiredPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun getPermissionStatusString(): String {
        if (hasRequiredPermissions()) return "granted"
        if (!hasEverRequestedBlePermission) return "denied"

        val isPermanentlyDenied = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.BLUETOOTH_SCAN) &&
            !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_FINE_LOCATION)
        }
        return if (isPermanentlyDenied) "permanentlyDenied" else "denied"
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
            hasEverRequestedBlePermission = true
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                pendingPermissionResult?.success("granted")
            } else {
                val anyPermanentlyDenied = permissions.indices.any { i ->
                    grantResults.getOrNull(i) != PackageManager.PERMISSION_GRANTED &&
                    !ActivityCompat.shouldShowRequestPermissionRationale(this, permissions[i])
                }
                pendingPermissionResult?.success(if (anyPermanentlyDenied) "permanentlyDenied" else "denied")
            }
            pendingPermissionResult = null
        } else if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotifyPermissionResult?.success(granted)
            pendingNotifyPermissionResult = null
        }
    }
}
