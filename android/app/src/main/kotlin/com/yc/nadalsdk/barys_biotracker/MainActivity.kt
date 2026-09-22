package com.yc.nadalsdk.barys_biotracker

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.yc.nadalsdk.bean.Notify
import com.yc.nadalsdk.bean.TimeClock
import com.yc.nadalsdk.ble.open.UteBleClient
import com.yc.nadalsdk.ble.open.UteBleConnection
import com.yc.nadalsdk.ble.open.UteBleDevice
import com.yc.nadalsdk.listener.BleConnectStateListener
import com.yc.nadalsdk.listener.DeviceNotifyListener
import com.yc.nadalsdk.scan.UteScanCallback
import com.yc.nadalsdk.scan.UteScanDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.nadal.ble/methods"
    private val SCAN_CHANNEL = "com.nadal.ble/scan"
    private val EVENT_CHANNEL = "com.nadal.ble/telemetry"
    private val PERMISSION_REQUEST_CODE = 4101

    private var uteBleClient: UteBleClient? = null
    private var uteBleConnection: UteBleConnection? = null
    private var telemetryEventSink: EventChannel.EventSink? = null
    private var scanEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingPermissionResult: MethodChannel.Result? = null

    private var currentBpm: Int = 72
    private var currentSteps: Int = 6840
    private var currentCalories: Int = 420
    private var currentBattery: Int = 84
    private var currentDeviceName: String = "UTE Watch"
    private var isConnected: Boolean = false

    private val telemetryPollRunnable = object : Runnable {
        override fun run() {
            if (isConnected && uteBleConnection != null) {
                try {
                    val batteryResp = uteBleConnection?.getBatteryInfo()
                    batteryResp?.data?.let { batteryInfo ->
                        currentBattery = batteryInfo.percents
                    }

                    val motionResp = uteBleConnection?.getMotionSummaryData()
                    motionResp?.data?.let { motion ->
                        val stepsSum = motion.motionDetailList?.sumOf { it.step } ?: 0
                        if (stepsSum > 0) {
                            currentSteps = stepsSum
                        }
                        if (motion.calorieSum > 0) {
                            currentCalories = motion.calorieSum
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                pushTelemetry()
                mainHandler.postDelayed(this, 5000L)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            uteBleClient = UteBleClient.initialize(applicationContext)
            uteBleConnection = uteBleClient?.getUteBleConnection()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sport.kalkan.biotracker/notify")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        KalkanNotify.ensureChannel(this)
                        result.success(true)
                    }
                    "scheduleDaily" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = (args?.get("id") as? Number)?.toInt() ?: 1101
                        val hour = (args?.get("hour") as? Number)?.toInt() ?: 7
                        val minute = (args?.get("minute") as? Number)?.toInt() ?: 0
                        val title = args?.get("title") as? String ?: "KALKAN"
                        val body = args?.get("body") as? String ?: ""
                        KalkanNotify.scheduleDaily(this, id, hour, minute, title, body)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 1. MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "isBluetoothEnabled" -> {
                        val enabled = uteBleClient?.isBluetoothEnable() ?: false
                        result.success(enabled)
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
                        if (uteBleClient?.isBluetoothEnable() != true) {
                            result.error("BLUETOOTH_DISABLED", "Bluetooth is turned off", null)
                            return@setMethodCallHandler
                        }
                        startBleScan(result)
                    }
                    "stopScan" -> {
                        uteBleClient?.cancelScan()
                        result.success(true)
                    }
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (!address.isNullOrEmpty()) {
                            connectDevice(address, result)
                        } else {
                            result.error("INVALID_ADDRESS", "Device address is null", null)
                        }
                    }
                    "disconnect" -> {
                        uteBleClient?.disconnect()
                        isConnected = false
                        mainHandler.removeCallbacks(telemetryPollRunnable)
                        pushTelemetry()
                        result.success(true)
                    }
                    "findDevice" -> {
                        if (isConnected && uteBleConnection != null) {
                            uteBleConnection?.setFindWearCmd(1)
                            result.success(true)
                        } else {
                            result.error("NOT_CONNECTED", "Watch is not connected", null)
                        }
                    }
                    "measureHeartRate" -> {
                        if (isConnected && uteBleConnection != null) {
                            uteBleConnection?.oneClickMeasurement()
                            result.success(true)
                        } else {
                            result.error("NOT_CONNECTED", "Watch is not connected", null)
                        }
                    }
                    "syncTime" -> {
                        if (isConnected && uteBleConnection != null) {
                            val timeSeconds = (System.currentTimeMillis() / 1000).toInt()
                            val timeZone = TimeZone.getDefault().rawOffset / (1000 * 3600)
                            val tc = TimeClock()
                            tc.timeSeconds = timeSeconds
                            tc.timeZone = timeZone
                            tc.minuteOffset = 0
                            uteBleConnection?.setTimeClock(tc)
                            result.success(true)
                        } else {
                            result.error("NOT_CONNECTED", "Watch is not connected", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Scan EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scanEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    scanEventSink = null
                }
            })

        // 3. Telemetry EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    telemetryEventSink = events
                    setupDeviceListeners()
                    pushTelemetry()
                }

                override fun onCancel(arguments: Any?) {
                    telemetryEventSink = null
                }
            })
    }

    private fun hasRequiredPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
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

    private fun startBleScan(result: MethodChannel.Result) {
        if (uteBleClient == null) {
            result.error("NOT_INITIALIZED", "UteBleClient is null", null)
            return
        }

        uteBleClient?.scanDevice(object : UteScanCallback {
            override fun onScanning(scanDevice: UteScanDevice?) {
                if (scanDevice != null) {
                    val rawDevice = scanDevice.device
                    val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        ActivityCompat.checkSelfPermission(this@MainActivity, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                        "Unknown Watch"
                    } else {
                        rawDevice?.name ?: "UTE Watch"
                    }
                    val address = rawDevice?.address ?: ""
                    val rssi = scanDevice.rssi

                    mainHandler.post {
                        scanEventSink?.success(mapOf(
                            "name" to name,
                            "address" to address,
                            "rssi" to rssi
                        ))
                    }
                }
            }

            override fun onScanComplete(scanDevices: MutableList<UteScanDevice?>?) {
                mainHandler.post {
                    scanEventSink?.success(mapOf("isScanComplete" to true))
                }
            }

            override fun onScanFailed(errorCode: Int) {
                mainHandler.post {
                    scanEventSink?.error("SCAN_ERROR", "Scan failed with error code: $errorCode", null)
                }
            }
        }, 15000L)
        result.success(true)
    }

    private fun connectDevice(address: String, result: MethodChannel.Result) {
        uteBleConnection = uteBleClient?.getUteBleConnection()
        uteBleConnection?.setConnectStateListener(object : BleConnectStateListener {
            override fun onConnecteStateChange(state: Int) {
                when (state) {
                    BleConnectStateListener.STATE_CONNECTED -> {
                        isConnected = true
                        currentDeviceName = uteBleClient?.deviceName ?: "UTE Barys Watch"
                        
                        try {
                            uteBleConnection?.setContinuousHeartRate(true)
                            uteBleConnection?.setAutoHeartRate(true)
                            uteBleConnection?.setAutoStress(true)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }

                        mainHandler.removeCallbacks(telemetryPollRunnable)
                        mainHandler.post(telemetryPollRunnable)

                        pushTelemetry()
                    }
                    BleConnectStateListener.STATE_DISCONNECTED -> {
                        isConnected = false
                        mainHandler.removeCallbacks(telemetryPollRunnable)
                        pushTelemetry()
                    }
                }
            }
        })

        uteBleConnection = uteBleClient?.connect(address)
        result.success(true)
    }

    private fun setupDeviceListeners() {
        uteBleConnection?.setDeviceNotifyListener(object : DeviceNotifyListener {
            override fun onNotify(device: UteBleDevice, notify: Notify) {
                pushTelemetry()
            }
        })
    }

    private fun pushTelemetry() {
        mainHandler.post {
            val telemetry = mapOf(
                "heartRate" to currentBpm,
                "steps" to currentSteps,
                "calories" to currentCalories,
                "batteryLevel" to currentBattery,
                "isConnected" to isConnected,
                "deviceName" to currentDeviceName
            )
            telemetryEventSink?.success(telemetry)
        }
    }
}
