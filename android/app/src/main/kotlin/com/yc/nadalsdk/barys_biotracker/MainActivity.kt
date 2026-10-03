package com.yc.nadalsdk.barys_biotracker

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import android.content.Context
import android.media.RingtoneManager
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.content.ContextCompat
import com.yc.nadalsdk.bean.BatteryInfo
import com.yc.nadalsdk.bean.CameraControl
import com.yc.nadalsdk.bean.DeviceHealthDataInfo
import com.yc.nadalsdk.bean.FindWearState
import com.yc.nadalsdk.bean.HeartRateReport
import com.yc.nadalsdk.bean.HonorAccountConfig
import com.yc.nadalsdk.bean.MotionCurrentMinute
import com.yc.nadalsdk.bean.Notify
import com.yc.nadalsdk.bean.SciSleepData
import com.yc.nadalsdk.bean.StressData
import com.yc.nadalsdk.bean.TemperatureInfo
import com.yc.nadalsdk.bean.TimeClock
import com.yc.nadalsdk.bean.WearingStateInfo
import com.yc.nadalsdk.bean.WorkoutRealTimeData
import com.yc.nadalsdk.bean.WorkoutRealTimeDataReport
import com.yc.nadalsdk.ble.open.UteBleClient
import com.yc.nadalsdk.ble.open.UteBleConnection
import com.yc.nadalsdk.ble.open.UteBleDevice
import com.yc.nadalsdk.constants.NotifyType
import com.yc.nadalsdk.constants.ServiceIds
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
import java.util.concurrent.Executors

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

    private var currentBpm: Int = 0
    private var currentSteps: Int = 0
    private var currentCalories: Int = 0
    private var currentBattery: Int = 0
    private var isCharging: Boolean = false
    private var currentDeviceName: String = ""
    private var isConnected: Boolean = false
    private var currentHrv: Double = 0.0
    private var currentRhr: Int = 0
    private var currentSleepMinutes: Int = 0
    private var currentDeepSleepMinutes: Int = 0
    private var currentRemSleepMinutes: Int = 0
    private var timeInBedMinutes: Int = 0
    private var currentSleepEfficiency: Double = 0.0
    private var currentHypnogram: List<Map<String, Any>> = emptyList()
    private var currentStressScore: Int = 0
    private var isOffWrist: Boolean = false
    private var skinTempDeviation: Double = 0.0
    private val bleExecutor = Executors.newSingleThreadExecutor()

    private val telemetryPollRunnable = object : Runnable {
        override fun run() {
            if (isConnected && uteBleConnection != null) {
                bleExecutor.execute {
                    try {
                        val cachedBattery = uteBleConnection?.smartGetBatteryInfo()?.data
                        if (cachedBattery != null) {
                            if (cachedBattery.percents > 0) {
                                currentBattery = cachedBattery.percents
                            }
                            isCharging = (cachedBattery.status == BatteryInfo.CHARGING)
                        }

                        val batteryResp = uteBleConnection?.getBatteryInfo()
                        batteryResp?.data?.let { batteryInfo ->
                            if (batteryInfo.percents > 0) {
                                currentBattery = batteryInfo.percents
                            }
                            isCharging = (batteryInfo.status == BatteryInfo.CHARGING)
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
                            val hr = motion.heartRate?.rate ?: 0
                            if (hr in 30..240) {
                                currentBpm = hr
                            }
                        }

                        try {
                            val sleep = uteBleConnection?.getSciSleepData()
                            if (sleep != null && sleep.sleepTotalTime > 0) {
                                val detailList = sleep.sleepDetailList
                                if (!detailList.isNullOrEmpty()) {
                                    var total = 0
                                    var deep = 0
                                    var light = 0
                                    var rem = 0
                                    var awake = 0
                                    val epochs = mutableListOf<Map<String, Any>>()
                                    val nowSec = (System.currentTimeMillis() / 1000).toInt()

                                    for (item in detailList) {
                                        val dur = item.sleepTime
                                        if (dur <= 0) continue
                                        val stage = when (item.sleepType) {
                                            1 -> { deep += dur; total += dur; "deep" }
                                            2, 5, 6 -> { light += dur; total += dur; "light" }
                                            4 -> { rem += dur; total += dur; "rem" }
                                            3, 7, 8 -> { awake += dur; "awake" }
                                            else -> { light += dur; total += dur; "light" }
                                        }
                                        val startSec = if (item.startTime > 0) item.startTime else (nowSec - (total + awake) * 60)
                                        val endSec = if (item.endTime > startSec) item.endTime else (startSec + dur * 60)
                                        epochs.add(
                                            mapOf(
                                                "stage" to stage,
                                                "startTime" to startSec.toLong() * 1000L,
                                                "endTime" to endSec.toLong() * 1000L,
                                                "durationMinutes" to dur
                                            )
                                        )
                                    }
                                    currentSleepMinutes = if (total > 0) total else sleep.sleepTotalTime
                                    currentDeepSleepMinutes = deep
                                    currentRemSleepMinutes = rem
                                    val inBed = total + awake
                                    timeInBedMinutes = if (inBed > 0) inBed else (currentSleepMinutes + 25)
                                    currentSleepEfficiency = if (timeInBedMinutes > 0) {
                                        Math.round((currentSleepMinutes.toDouble() / timeInBedMinutes.toDouble()) * 100.0) / 100.0
                                    } else 0.92
                                    currentHypnogram = epochs
                                } else {
                                    currentSleepMinutes = sleep.sleepTotalTime
                                    currentDeepSleepMinutes = (sleep.sleepTotalTime * 0.22).toInt()
                                    currentRemSleepMinutes = (sleep.sleepTotalTime * 0.23).toInt()
                                    timeInBedMinutes = currentSleepMinutes + 25
                                    currentSleepEfficiency = 0.92
                                }
                            }
                        } catch (e: Exception) {
                            // Non-critical sleep poll
                        }

                        if (currentBpm in 40..100) {
                            if (currentRhr == 0 || currentBpm < currentRhr) {
                                currentRhr = currentBpm
                            }
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    pushTelemetry()
                }
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
                    result.success(true)
                } else {
                    result.notImplemented()
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
                        isCharging = false
                        currentBpm = 0
                        currentBattery = 0
                        currentSteps = 0
                        currentCalories = 0
                        currentHrv = 0.0
                        currentRhr = 0
                        currentSleepMinutes = 0
                        currentDeepSleepMinutes = 0
                        currentRemSleepMinutes = 0
                        timeInBedMinutes = 0
                        currentSleepEfficiency = 0.0
                        currentHypnogram = emptyList()
                        currentStressScore = 0
                        isOffWrist = false
                        skinTempDeviation = 0.0
                        currentDeviceName = ""
                        mainHandler.removeCallbacks(telemetryPollRunnable)
                        try {
                            KalkanBleService.stop(applicationContext)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        pushTelemetry()
                        result.success(true)
                    }
                    "findDevice" -> {
                        if (isConnected && uteBleConnection != null) {
                            bleExecutor.execute {
                                try {
                                    uteBleConnection?.setFindWearCmd(FindWearState.STATE_OPEN)
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }
                            result.success(true)
                        } else {
                            result.error("NOT_CONNECTED", "Watch is not connected", null)
                        }
                    }
                    "measureHeartRate" -> {
                        if (isConnected && uteBleConnection != null) {
                            bleExecutor.execute {
                                try {
                                    uteBleConnection?.oneClickMeasurement()
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }
                            result.success(true)
                        } else {
                            result.error("NOT_CONNECTED", "Watch is not connected", null)
                        }
                    }
                    "syncTime" -> {
                        if (isConnected && uteBleConnection != null) {
                            bleExecutor.execute {
                                try {
                                    val timeSeconds = (System.currentTimeMillis() / 1000).toInt()
                                    val timeZone = TimeZone.getDefault().rawOffset / (1000 * 3600)
                                    val tc = TimeClock()
                                    tc.timeSeconds = timeSeconds
                                    tc.timeZone = timeZone
                                    tc.minuteOffset = 0
                                    uteBleConnection?.setTimeClock(tc)
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }
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
                    if (rssi < -85 && rssi != 0) return

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
                        currentDeviceName = uteBleClient?.deviceName ?: "СААТ-1"
                        
                        setupDeviceListeners()

                        bleExecutor.execute {
                            try {
                                // 1. Mandatory UTE Handshake: Query supported services
                                val services = listOf(
                                    ServiceIds.DEVICE_MANAGE,
                                    ServiceIds.HEART_RATE,
                                    ServiceIds.FITNESS,
                                    ServiceIds.WORKOUT,
                                    ServiceIds.STRESS,
                                    ServiceIds.ALARM
                                )
                                uteBleConnection?.querySupportService(services)

                                // 2. TimeClock synchronization
                                val timeSeconds = (System.currentTimeMillis() / 1000).toInt()
                                val timeZone = TimeZone.getDefault().rawOffset / (1000 * 3600)
                                val tc = TimeClock()
                                tc.timeSeconds = timeSeconds
                                tc.timeZone = timeZone
                                tc.minuteOffset = 0
                                uteBleConnection?.setTimeClock(tc)

                                // 3. Enable Continuous Heart Rate and Sensors
                                uteBleConnection?.setContinuousHeartRate(true)
                                uteBleConnection?.setAutoHeartRate(true)
                                uteBleConnection?.setAutoStress(true)

                                // 4. Read battery and initial motion summary
                                val cached = uteBleConnection?.smartGetBatteryInfo()?.data
                                if (cached != null) {
                                    if (cached.percents > 0) currentBattery = cached.percents
                                    isCharging = (cached.status == BatteryInfo.CHARGING)
                                }
                                val fresh = uteBleConnection?.getBatteryInfo()?.data
                                if (fresh != null) {
                                    if (fresh.percents > 0) currentBattery = fresh.percents
                                    isCharging = (fresh.status == BatteryInfo.CHARGING)
                                }
                                val motion = uteBleConnection?.getMotionSummaryData()?.data
                                if (motion != null) {
                                    val stepsSum = motion.motionDetailList?.sumOf { it.step } ?: 0
                                    if (stepsSum > 0) currentSteps = stepsSum
                                    if (motion.calorieSum > 0) currentCalories = motion.calorieSum
                                    val hr = motion.heartRate?.rate ?: 0
                                    if (hr in 30..240) currentBpm = hr
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                            pushTelemetry()
                        }

                        try {
                            KalkanBleService.start(applicationContext)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }

                        mainHandler.removeCallbacks(telemetryPollRunnable)
                        mainHandler.post(telemetryPollRunnable)

                        pushTelemetry()
                    }
                    BleConnectStateListener.STATE_DISCONNECTED -> {
                        isConnected = false
                        isCharging = false
                        currentBpm = 0
                        currentBattery = 0
                        currentSteps = 0
                        currentCalories = 0
                        currentHrv = 0.0
                        currentRhr = 0
                        currentSleepMinutes = 0
                        currentDeepSleepMinutes = 0
                        currentRemSleepMinutes = 0
                        timeInBedMinutes = 0
                        currentSleepEfficiency = 0.0
                        currentHypnogram = emptyList()
                        currentStressScore = 0
                        isOffWrist = false
                        skinTempDeviation = 0.0
                        currentDeviceName = ""
                        mainHandler.removeCallbacks(telemetryPollRunnable)
                        try {
                            KalkanBleService.stop(applicationContext)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
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
                try {
                    when (notify.type) {
                        NotifyType.DEVICE_BATTERY_REPORT -> {
                            val batteryInfo = notify.data as? BatteryInfo
                            if (batteryInfo != null) {
                                if (batteryInfo.percents > 0) {
                                    currentBattery = batteryInfo.percents
                                }
                                isCharging = (batteryInfo.status == BatteryInfo.CHARGING)
                            }
                        }
                        NotifyType.HEART_RATE_REPORT -> {
                            val hrReport = notify.data as? HeartRateReport
                            val latestRate = hrReport?.heartRateList?.lastOrNull()?.rate ?: 0
                            if (latestRate in 30..240) {
                                currentBpm = latestRate
                            }
                        }
                        NotifyType.DEVICE_HEALTH_TEST_RESULT_NOTIFY -> {
                            val health = notify.data as? DeviceHealthDataInfo
                            if (health != null) {
                                if (health.heartRateValue in 30..240) {
                                    currentBpm = health.heartRateValue
                                }
                                if (health.hrvValue in 5..250) {
                                    currentHrv = health.hrvValue.toDouble()
                                }
                                if (health.stressValue in 1..100) {
                                    currentStressScore = health.stressValue
                                }
                                if (health.bodyTemperature in 30.0f..43.0f) {
                                    skinTempDeviation = Math.round((health.bodyTemperature - 36.6f) * 10.0) / 10.0
                                }
                            }
                        }
                        NotifyType.MOTION_CURRENT_MINUTE_NOTIFY -> {
                            val motion = notify.data as? MotionCurrentMinute
                            if (motion != null) {
                                if (motion.dynamicHeartRate in 30..240) {
                                    currentBpm = motion.dynamicHeartRate
                                }
                                if (motion.step > 0) {
                                    currentSteps = motion.step
                                }
                                if (motion.calorie > 0) {
                                    currentCalories = motion.calorie
                                }
                            }
                        }
                        NotifyType.WORKOUT_REAL_TIME_DATE_REPORT -> {
                            val wReport = notify.data as? WorkoutRealTimeDataReport
                            if (wReport != null) {
                                if (wReport.heartRate in 30..240) {
                                    currentBpm = wReport.heartRate
                                }
                                if (wReport.step > 0) {
                                    currentSteps = wReport.step
                                }
                                if (wReport.calorie > 0) {
                                    currentCalories = wReport.calorie
                                }
                            }
                            val wData = notify.data as? WorkoutRealTimeData
                            if (wData != null) {
                                if (wData.realTimeHeartRate in 30..240) {
                                    currentBpm = wData.realTimeHeartRate
                                }
                                if (wData.steps > 0) {
                                    currentSteps = wData.steps
                                }
                                if (wData.calorie > 0) {
                                    currentCalories = wData.calorie
                                }
                            }
                        }
                        NotifyType.STRESS_TEST_RESULT_NOTIFY -> {
                            val stress = notify.data as? StressData
                            if (stress != null && stress.pressureValue in 1..100) {
                                currentStressScore = stress.pressureValue
                            }
                        }
                        NotifyType.WEARING_STATE_INFO_NOTIFY -> {
                            val wear = notify.data as? WearingStateInfo
                            if (wear != null) {
                                isOffWrist = (wear.wearingState == WearingStateInfo.OFF_HAND)
                            }
                        }
                        NotifyType.CAMERA_CONTROL -> {
                            val camera = notify.data as? CameraControl
                            if (camera != null && camera.instruction == CameraControl.INSTRUCTION_PHOTOGRAPH) {
                                mainHandler.post {
                                    try {
                                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                            vibrator?.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
                                        } else {
                                            vibrator?.vibrate(100)
                                        }
                                    } catch (_: Exception) {}
                                }
                            }
                        }
                        NotifyType.FIND_MY_PHONE -> {
                            try {
                                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500, 200, 500), -1))
                                } else {
                                    vibrator?.vibrate(1000)
                                }
                                val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                                RingtoneManager.getRingtone(applicationContext, ringtoneUri)?.play()
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                        NotifyType.TEMPERATURE_TEST_RESULT_NOTIFY -> {
                            val temp = notify.data as? TemperatureInfo
                            if (temp != null) {
                                val deg = temp.temperature.toDouble()
                                if (deg in 30.0..42.0) {
                                    skinTempDeviation = Math.round((deg - 36.6) * 10.0) / 10.0
                                }
                            }
                        }
                        NotifyType.DEVICE_PAIRED_STATE_NOTIFY -> {
                            try {
                                val honorConfig = HonorAccountConfig()
                                uteBleConnection?.setHonorAccount(honorConfig)
                            } catch (e: Exception) {
                                // ignore
                            }
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
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
                "isCharging" to isCharging,
                "isConnected" to isConnected,
                "deviceName" to (if (isConnected) currentDeviceName else ""),
                "hrv" to currentHrv,
                "restingHeartRate" to currentRhr,
                "sleepMinutes" to currentSleepMinutes,
                "deepSleepMinutes" to currentDeepSleepMinutes,
                "remSleepMinutes" to currentRemSleepMinutes,
                "timeInBedMinutes" to (if (timeInBedMinutes > 0) timeInBedMinutes else (if (currentSleepMinutes > 0) currentSleepMinutes + 25 else 0)),
                "sleepEfficiency" to (if (currentSleepEfficiency > 0.0) currentSleepEfficiency else (if (currentSleepMinutes > 0) 0.92 else 0.0)),
                "sleepHypnogram" to currentHypnogram,
                "currentStressScore" to currentStressScore,
                "isOffWrist" to isOffWrist,
                "skinTempDeviation" to skinTempDeviation,
                "respiratoryRate" to (if (currentBpm in 40..100) (14.0 + (currentBpm - 60) * 0.05).coerceIn(12.0, 20.0) else 0.0)
            )
            telemetryEventSink?.success(telemetry)
        }
    }
}
