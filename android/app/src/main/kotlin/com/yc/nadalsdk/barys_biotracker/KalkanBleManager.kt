package com.yc.nadalsdk.barys_biotracker

import android.content.Context
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import com.yc.nadalsdk.bean.*
import com.yc.nadalsdk.ble.open.UteBleClient
import com.yc.nadalsdk.ble.open.UteBleConnection
import com.yc.nadalsdk.ble.open.UteBleDevice
import com.yc.nadalsdk.constants.NotifyType
import com.yc.nadalsdk.constants.ServiceIds
import com.yc.nadalsdk.listener.BleConnectStateListener
import com.yc.nadalsdk.listener.DeviceNotifyListener
import com.yc.nadalsdk.scan.UteScanCallback
import com.yc.nadalsdk.scan.UteScanDevice
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

object KalkanBleManager {
    private var appContext: Context? = null
    var uteBleClient: UteBleClient? = null
    var uteBleConnection: UteBleConnection? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bleExecutor = Executors.newSingleThreadExecutor()
    private var backgroundScheduler: ScheduledExecutorService? = null

    private var telemetryEventSink: EventChannel.EventSink? = null
    private var scanEventSink: EventChannel.EventSink? = null

    var currentBpm: Int = 0
    var currentSteps: Int = 0
    var currentCalories: Int = 0
    var currentBattery: Int = 0
    var isCharging: Boolean = false
    var currentDeviceName: String = ""
    var isConnected: Boolean = false
    var currentHrv: Double = 0.0
    var currentRhr: Int = 0
    var currentSleepMinutes: Int = 0
    var currentDeepSleepMinutes: Int = 0
    var currentRemSleepMinutes: Int = 0
    var timeInBedMinutes: Int = 0
    var currentSleepEfficiency: Double = 0.0
    var currentHypnogram: List<Map<String, Any>> = emptyList()
    var currentStressScore: Int = 0
    var isOffWrist: Boolean = false
    var skinTempDeviation: Double = 0.0

    private const val PREFS_NAME = "kalkan_ble_prefs"
    private const val KEY_SNAPSHOT = "kalkan_latest_telemetry_snapshot"

    private var pendingConnectCallback: ((Boolean, String?) -> Unit)? = null
    private var connectTimeoutRunnable: Runnable? = null

    fun init(context: Context) {
        if (appContext == null) {
            appContext = context.applicationContext
            try {
                uteBleClient = UteBleClient.initialize(appContext)
                uteBleConnection = uteBleClient?.getUteBleConnection()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun setTelemetrySink(sink: EventChannel.EventSink?) {
        telemetryEventSink = sink
        if (sink != null) {
            setupDeviceListeners()
            pushTelemetry()
        }
    }

    fun setScanSink(sink: EventChannel.EventSink?) {
        scanEventSink = sink
    }

    fun isBluetoothEnabled(): Boolean {
        return uteBleClient?.isBluetoothEnable() ?: false
    }

    fun startScan(callback: (Boolean, String?) -> Unit) {
        val client = uteBleClient
        if (client == null) {
            callback(false, "UteBleClient is not initialized")
            return
        }

        client.scanDevice(object : UteScanCallback {
            override fun onScanning(scanDevice: UteScanDevice?) {
                if (scanDevice != null) {
                    val rawDevice = scanDevice.device
                    val name = rawDevice?.name ?: "UTE Watch"
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
                    scanEventSink?.error("SCAN_ERROR", "Scan failed with error: $errorCode", null)
                }
            }
        }, 15000L)
        callback(true, null)
    }

    fun stopScan() {
        uteBleClient?.cancelScan()
    }

    fun connect(address: String, callback: (Boolean, String?) -> Unit) {
        val client = uteBleClient
        if (client == null) {
            callback(false, "UteBleClient not initialized")
            return
        }

        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        pendingConnectCallback?.invoke(false, "Cancelled by newer connect attempt")
        pendingConnectCallback = callback

        connectTimeoutRunnable = Runnable {
            if (pendingConnectCallback != null) {
                pendingConnectCallback?.invoke(false, "Connection timed out (15s)")
                pendingConnectCallback = null
            }
        }
        mainHandler.postDelayed(connectTimeoutRunnable!!, 15000)

        uteBleConnection = client.getUteBleConnection()
        uteBleConnection?.setConnectStateListener(object : BleConnectStateListener {
            override fun onConnecteStateChange(state: Int) {
                when (state) {
                    BleConnectStateListener.STATE_CONNECTED -> {
                        isConnected = true
                        currentDeviceName = uteBleClient?.deviceName ?: "СААТ-1"
                        
                        setupDeviceListeners()

                        bleExecutor.execute {
                            try {
                                val services = listOf(
                                    ServiceIds.DEVICE_MANAGE,
                                    ServiceIds.HEART_RATE,
                                    ServiceIds.FITNESS,
                                    ServiceIds.WORKOUT,
                                    ServiceIds.STRESS,
                                    ServiceIds.ALARM
                                )
                                uteBleConnection?.querySupportService(services)

                                val timeSeconds = (System.currentTimeMillis() / 1000).toInt()
                                val timeZone = TimeZone.getDefault().rawOffset / (1000 * 3600)
                                val tc = TimeClock()
                                tc.timeSeconds = timeSeconds
                                tc.timeZone = timeZone
                                tc.minuteOffset = 0
                                uteBleConnection?.setTimeClock(tc)

                                uteBleConnection?.setContinuousHeartRate(true)
                                uteBleConnection?.setAutoHeartRate(true)
                                uteBleConnection?.setAutoStress(true)

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

                        appContext?.let { KalkanBleService.start(it) }
                        startBackgroundPolling()
                        pushTelemetry()

                        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        connectTimeoutRunnable = null
                        val cb = pendingConnectCallback
                        pendingConnectCallback = null
                        cb?.invoke(true, null)
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
                        stopBackgroundPolling()
                        appContext?.let { KalkanBleService.stop(it) }
                        pushTelemetry()

                        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        connectTimeoutRunnable = null
                        val cb = pendingConnectCallback
                        pendingConnectCallback = null
                        cb?.invoke(false, "Disconnected before ready")
                    }
                }
            }
        })

        uteBleConnection = client.connect(address)
    }

    fun disconnect() {
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
        stopBackgroundPolling()
        appContext?.let { KalkanBleService.stop(it) }
        pushTelemetry()
    }

    fun findDevice(callback: (Boolean, String?) -> Unit) {
        if (isConnected && uteBleConnection != null) {
            bleExecutor.execute {
                try {
                    uteBleConnection?.setFindWearCmd(FindWearState.STATE_OPEN)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            callback(true, null)
        } else {
            callback(false, "Watch is not connected")
        }
    }

    fun measureHeartRate(callback: (Boolean, String?) -> Unit) {
        if (isConnected && uteBleConnection != null) {
            bleExecutor.execute {
                try {
                    uteBleConnection?.oneClickMeasurement()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            callback(true, null)
        } else {
            callback(false, "Watch is not connected")
        }
    }

    fun syncTime(callback: (Boolean, String?) -> Unit) {
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
            callback(true, null)
        } else {
            callback(false, "Watch is not connected")
        }
    }

    fun startBackgroundPolling() {
        stopBackgroundPolling()
        val scheduler = Executors.newSingleThreadScheduledExecutor()
        backgroundScheduler = scheduler
        scheduler.scheduleWithFixedDelay({
            pollTelemetryNow()
        }, 1, 5, TimeUnit.SECONDS)
    }

    fun stopBackgroundPolling() {
        try {
            backgroundScheduler?.shutdownNow()
        } catch (_: Exception) {}
        backgroundScheduler = null
    }

    fun pollTelemetryNow() {
        if (!isConnected || uteBleConnection == null) return
        bleExecutor.execute {
            try {
                val cachedBattery = uteBleConnection?.smartGetBatteryInfo()?.data
                if (cachedBattery != null) {
                    if (cachedBattery.percents > 0) currentBattery = cachedBattery.percents
                    isCharging = (cachedBattery.status == BatteryInfo.CHARGING)
                }

                val batteryResp = uteBleConnection?.getBatteryInfo()
                batteryResp?.data?.let { batteryInfo ->
                    if (batteryInfo.percents > 0) currentBattery = batteryInfo.percents
                    isCharging = (batteryInfo.status == BatteryInfo.CHARGING)
                }

                val motionResp = uteBleConnection?.getMotionSummaryData()
                motionResp?.data?.let { motion ->
                    val stepsSum = motion.motionDetailList?.sumOf { it.step } ?: 0
                    if (stepsSum > 0) currentSteps = stepsSum
                    if (motion.calorieSum > 0) currentCalories = motion.calorieSum
                    val hr = motion.heartRate?.rate ?: 0
                    if (hr in 30..240) currentBpm = hr
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
                            timeInBedMinutes = if (inBed > 0) inBed else total
                            currentSleepEfficiency = if (timeInBedMinutes > 0 && total > 0) {
                                Math.round((currentSleepMinutes.toDouble() / timeInBedMinutes.toDouble()) * 100.0) / 100.0
                            } else 0.0
                            currentHypnogram = epochs
                        } else {
                            currentSleepMinutes = sleep.sleepTotalTime
                            currentDeepSleepMinutes = 0
                            currentRemSleepMinutes = 0
                            timeInBedMinutes = sleep.sleepTotalTime
                            currentSleepEfficiency = 0.0
                            currentHypnogram = emptyList()
                        }
                    }
                } catch (_: Exception) {}
            } catch (e: Exception) {
                e.printStackTrace()
            }
            pushTelemetry()
        }
    }

    private fun setupDeviceListeners() {
        uteBleConnection?.setDeviceNotifyListener(object : DeviceNotifyListener {
            override fun onNotify(device: UteBleDevice, notify: Notify) {
                try {
                    when (notify.type) {
                        NotifyType.DEVICE_BATTERY_REPORT -> {
                            val batteryInfo = notify.data as? BatteryInfo
                            if (batteryInfo != null) {
                                if (batteryInfo.percents > 0) currentBattery = batteryInfo.percents
                                isCharging = (batteryInfo.status == BatteryInfo.CHARGING)
                            }
                        }
                        NotifyType.HEART_RATE_REPORT -> {
                            val hrReport = notify.data as? HeartRateReport
                            val latestRate = hrReport?.heartRateList?.lastOrNull()?.rate ?: 0
                            if (latestRate in 30..240) currentBpm = latestRate
                        }
                        NotifyType.DEVICE_HEALTH_TEST_RESULT_NOTIFY -> {
                            val health = notify.data as? DeviceHealthDataInfo
                            if (health != null) {
                                if (health.heartRateValue in 30..240) currentBpm = health.heartRateValue
                                if (health.hrvValue in 5..250) currentHrv = health.hrvValue.toDouble()
                                if (health.stressValue in 1..100) currentStressScore = health.stressValue
                            }
                        }
                        NotifyType.MOTION_CURRENT_MINUTE_NOTIFY -> {
                            val motion = notify.data as? MotionCurrentMinute
                            if (motion != null) {
                                if (motion.dynamicHeartRate in 30..240) currentBpm = motion.dynamicHeartRate
                                if (motion.step > 0) currentSteps = motion.step
                                if (motion.calorie > 0) currentCalories = motion.calorie
                                if (motion.restingHeartRate in 35..110) currentRhr = motion.restingHeartRate
                                if (motion.hrvValue > 0) currentHrv = motion.hrvValue.toDouble()
                            }
                        }
                        NotifyType.WORKOUT_REAL_TIME_DATE_REPORT -> {
                            val wReport = notify.data as? WorkoutRealTimeDataReport
                            if (wReport != null) {
                                if (wReport.heartRate in 30..240) currentBpm = wReport.heartRate
                                if (wReport.step > 0) currentSteps = wReport.step
                                if (wReport.calorie > 0) currentCalories = wReport.calorie
                            }
                            val wData = notify.data as? WorkoutRealTimeData
                            if (wData != null) {
                                if (wData.realTimeHeartRate in 30..240) currentBpm = wData.realTimeHeartRate
                                if (wData.steps > 0) currentSteps = wData.steps
                                if (wData.calorie > 0) currentCalories = wData.calorie
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
                                        val vibrator = appContext?.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
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
                                val vibrator = appContext?.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500, 200, 500), -1))
                                } else {
                                    vibrator?.vibrate(1000)
                                }
                                val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                                appContext?.let { RingtoneManager.getRingtone(it, ringtoneUri)?.play() }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                        NotifyType.TEMPERATURE_TEST_RESULT_NOTIFY -> {}
                        NotifyType.DEVICE_PAIRED_STATE_NOTIFY -> {
                            try {
                                val honorConfig = HonorAccountConfig()
                                uteBleConnection?.setHonorAccount(honorConfig)
                            } catch (_: Exception) {}
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
            "timeInBedMinutes" to timeInBedMinutes,
            "sleepEfficiency" to currentSleepEfficiency,
            "sleepHypnogram" to currentHypnogram,
            "currentStressScore" to currentStressScore,
            "isOffWrist" to isOffWrist,
            "skinTempDeviation" to skinTempDeviation,
            "respiratoryRate" to 0.0
        )

        try {
            appContext?.let { ctx ->
                val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val json = JSONObject(telemetry).toString()
                prefs.edit().putString(KEY_SNAPSHOT, json).apply()
            }
        } catch (_: Exception) {}

        mainHandler.post {
            telemetryEventSink?.success(telemetry)
        }
    }
}
