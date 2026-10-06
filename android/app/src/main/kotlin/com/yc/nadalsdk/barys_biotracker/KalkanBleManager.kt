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
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

data class TelemetrySnapshot(
    val currentBpm: Int = 0,
    val currentSteps: Int = 0,
    val currentCalories: Int = 0,
    val currentBattery: Int = 0,
    val isCharging: Boolean = false,
    val currentDeviceName: String = "",
    val isConnected: Boolean = false,
    val currentHrv: Double = 0.0,
    val currentRhr: Int = 0,
    val currentSleepMinutes: Int = 0,
    val currentDeepSleepMinutes: Int = 0,
    val currentRemSleepMinutes: Int = 0,
    val timeInBedMinutes: Int = 0,
    val currentSleepEfficiency: Double = 0.0,
    val currentHypnogram: List<Map<String, Any>> = emptyList(),
    val currentStressScore: Int = 0,
    val isOffWrist: Boolean = false,
    val skinTempDeviation: Double = 0.0,
    val respiratoryRate: Double = 0.0,
    val bloodOxygen: Int = 0
)

private data class ParsedSleepSession(
    var startSec: Int,
    var endSec: Int,
    var totalSleepMinutes: Int = 0,
    var deepSleepMinutes: Int = 0,
    var lightSleepMinutes: Int = 0,
    var remSleepMinutes: Int = 0,
    var awakeMinutes: Int = 0,
    val epochs: MutableList<Map<String, Any>> = mutableListOf()
) {
    val timeInBedMinutes: Int
        get() = totalSleepMinutes + awakeMinutes

    val sleepEfficiency: Double
        get() = if (timeInBedMinutes > 0 && totalSleepMinutes > 0) {
            Math.round((totalSleepMinutes.toDouble() / timeInBedMinutes.toDouble()) * 100.0) / 100.0
        } else 0.0
}

object KalkanBleManager {
    val bloodOxygen: Int get() = snapshotRef.get().bloodOxygen

    private var appContext: Context? = null
    var uteBleClient: UteBleClient? = null
    var uteBleConnection: UteBleConnection? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bleExecutor = Executors.newSingleThreadExecutor()
    private var backgroundScheduler: ScheduledExecutorService? = null

    private var telemetryEventSink: EventChannel.EventSink? = null
    private var scanEventSink: EventChannel.EventSink? = null

    // BLE-05: Thread-safe atomic telemetry snapshot preventing race conditions
    private val snapshotRef = AtomicReference(TelemetrySnapshot())

    // Backward-compatible properties backed by atomic snapshot
    val currentBpm: Int get() = snapshotRef.get().currentBpm
    val currentSteps: Int get() = snapshotRef.get().currentSteps
    val currentCalories: Int get() = snapshotRef.get().currentCalories
    val currentBattery: Int get() = snapshotRef.get().currentBattery
    val isCharging: Boolean get() = snapshotRef.get().isCharging
    val currentDeviceName: String get() = snapshotRef.get().currentDeviceName
    val isConnected: Boolean get() = snapshotRef.get().isConnected
    val currentHrv: Double get() = snapshotRef.get().currentHrv
    val currentRhr: Int get() = snapshotRef.get().currentRhr
    val currentSleepMinutes: Int get() = snapshotRef.get().currentSleepMinutes
    val currentDeepSleepMinutes: Int get() = snapshotRef.get().currentDeepSleepMinutes
    val currentRemSleepMinutes: Int get() = snapshotRef.get().currentRemSleepMinutes
    val timeInBedMinutes: Int get() = snapshotRef.get().timeInBedMinutes
    val currentSleepEfficiency: Double get() = snapshotRef.get().currentSleepEfficiency
    val currentHypnogram: List<Map<String, Any>> get() = snapshotRef.get().currentHypnogram
    val currentStressScore: Int get() = snapshotRef.get().currentStressScore
    val isOffWrist: Boolean get() = snapshotRef.get().isOffWrist
    val skinTempDeviation: Double get() = snapshotRef.get().skinTempDeviation

    private const val PREFS_NAME = "kalkan_ble_prefs"
    private const val KEY_SNAPSHOT = "kalkan_latest_telemetry_snapshot"
    private const val KEY_LAST_MAC = "last_device_mac"
    private const val KEY_MANUAL = "manual_disconnect"

    private var pendingConnectCallback: ((Boolean, String?) -> Unit)? = null
    private var connectTimeoutRunnable: Runnable? = null

    // BLE-01: Нативный фоновый reconnect (живёт при убитой Flutter-активности)
    private var lastConnectedMac: String? = null
    private var nativeManualDisconnect = false
    private var nativeReconnectAttempts = 0
    private var nativeReconnectRunnable: Runnable? = null

    // BLE-05: Polling rate control & queue bounding guards
    private val isPollingInProgress = AtomicBoolean(false)
    private val isScanning = AtomicBoolean(false)
    private var lastBatteryPollTimeMs: Long = 0L
    private var lastSleepPollTimeMs: Long = 0L
    private var lastStressPollTimeMs: Long = 0L
    private var lastWorkoutPollTimeMs: Long = 0L

    // BLE-05: Throttled telemetry push (1 Hz max coalescing)
    private var lastPushTimeMs: Long = 0L
    private val pushLock = Any()
    private var isPushScheduled = false
    private val pushRunnable = Runnable {
        synchronized(pushLock) {
            isPushScheduled = false
            lastPushTimeMs = System.currentTimeMillis()
        }
        sendTelemetryToSink()
    }

    fun deriveRespiratoryRate(rhr: Int, hrv: Double): Double {
        if (rhr <= 0) return 0.0
        val clampedRhr = rhr.coerceIn(40, 100)
        val baseRr = 14.0 + (clampedRhr - 60) * 0.08
        val clampedHrv = (if (hrv > 0) hrv else 50.0).coerceIn(10.0, 150.0)
        val hrvAdjustment = (clampedHrv - 50.0) * 0.03
        val derived = (baseRr - hrvAdjustment).coerceIn(11.0, 22.0)
        return Math.round(derived * 10.0) / 10.0
    }

    fun init(context: Context) {
        if (appContext == null) {
            val ctx = context.applicationContext ?: context
            appContext = ctx
            try {
                uteBleClient = UteBleClient.initialize(ctx)
                uteBleClient?.setSupportUserIdPair(false)
                uteBleConnection = uteBleClient?.getUteBleConnection()
            } catch (e: Exception) {
                e.printStackTrace()
            }
            try {
                val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                lastConnectedMac = prefs.getString(KEY_LAST_MAC, null)
                nativeManualDisconnect = prefs.getBoolean(KEY_MANUAL, false)
            } catch (_: Exception) {}
        }
    }

    fun setTelemetrySink(sink: EventChannel.EventSink?) {
        telemetryEventSink = sink
        if (sink != null) {
            cancelNativeReconnect()
            setupDeviceListeners()
            pushTelemetry(immediate = true)
        }
    }

    fun setScanSink(sink: EventChannel.EventSink?) {
        scanEventSink = sink
    }

    private fun persistLastMac(mac: String?) {
        lastConnectedMac = mac
        try {
            val ctx = appContext ?: return
            val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (mac.isNullOrEmpty()) {
                prefs.edit().remove(KEY_LAST_MAC).apply()
            } else {
                prefs.edit().putString(KEY_LAST_MAC, mac).apply()
            }
        } catch (_: Exception) {}
    }

    private fun persistManualDisconnect(manual: Boolean) {
        nativeManualDisconnect = manual
        try {
            val ctx = appContext ?: return
            ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_MANUAL, manual).apply()
        } catch (_: Exception) {}
    }

    private fun cancelNativeReconnect() {
        nativeReconnectRunnable?.let { mainHandler.removeCallbacks(it) }
        nativeReconnectRunnable = null
        nativeReconnectAttempts = 0
    }

    private fun scheduleNativeReconnect() {
        if (nativeManualDisconnect) return
        if (telemetryEventSink != null) return
        val mac = lastConnectedMac ?: return
        if (mac.isEmpty()) return

        cancelNativeReconnect()
        val attempt = nativeReconnectAttempts
        val baseSec = (2 shl minOf(attempt, 5)).coerceIn(2, 60).toLong()
        val jitterMs = (Math.random() * 1500).toLong()
        val delayMs = (baseSec * 1000 + jitterMs).coerceIn(2000L, 60000L)
        nativeReconnectAttempts = attempt + 1

        val task = Runnable {
            nativeReconnectRunnable = null
            if (nativeManualDisconnect || telemetryEventSink != null || isConnected) return@Runnable
            try {
                connect(mac) { _, _ -> }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        nativeReconnectRunnable = task
        mainHandler.postDelayed(task, delayMs)
    }

    fun isBluetoothEnabled(): Boolean {
        return uteBleClient?.isBluetoothEnable() ?: false
    }

    private fun isKalkanDevice(name: String): Boolean {
        val lower = name.lowercase().trim()
        if (lower.isBlank()) return false
        if (lower.contains("kalkan") || lower.contains("саат") || lower.contains("saat") || lower.contains("nadal")) {
            return true
        }
        if (lower.startsWith("ute") || lower.contains(" ute") || lower.contains("ute-") || lower.contains("ute_")) {
            return true
        }
        return false
    }

    fun startScan(callback: (Boolean, String?) -> Unit) {
        val client = uteBleClient
        if (client == null) {
            callback(false, "UteBleClient is not initialized")
            return
        }

        if (!isScanning.compareAndSet(false, true)) {
            // Protect against duplicate or concurrent scan triggers
            callback(true, null)
            return
        }

        val scanStarted = client.scanDevice(object : UteScanCallback {
            override fun onScanning(scanDevice: UteScanDevice?) {
                if (scanDevice != null) {
                    val rawDevice = scanDevice.device
                    val rawName = rawDevice?.name?.trim() ?: ""
                    val address = rawDevice?.address ?: ""
                    val rssi = scanDevice.rssi

                    val isKalkan = isKalkanDevice(rawName)
                    val displayName = if (rawName.isNotBlank()) rawName else if (isKalkan) "KALKAN СААТ-1" else "BLE Устройство"

                    mainHandler.post {
                        scanEventSink?.success(mapOf(
                            "name" to displayName,
                            "address" to address,
                            "rssi" to rssi,
                            "isKalkan" to isKalkan
                        ))
                    }
                }
            }

            override fun onScanComplete(scanDevices: MutableList<UteScanDevice?>?) {
                isScanning.set(false)
                mainHandler.post {
                    scanEventSink?.success(mapOf("isScanComplete" to true))
                }
            }

            override fun onScanFailed(errorCode: Int) {
                isScanning.set(false)
                mainHandler.post {
                    scanEventSink?.error("SCAN_ERROR", "Scan failed with error: $errorCode", null)
                }
            }
        }, 15000L)

        if (!scanStarted) {
            isScanning.set(false)
            callback(false, "Failed to start BLE scan")
        } else {
            callback(true, null)
        }
    }

    fun stopScan() {
        isScanning.set(false)
        try {
            uteBleClient?.cancelScan()
        } catch (_: Exception) {}
        mainHandler.post {
            scanEventSink?.success(mapOf("isScanComplete" to true))
        }
    }

    fun updateSnapshot(immediate: Boolean = false, transform: (TelemetrySnapshot) -> TelemetrySnapshot): TelemetrySnapshot {
        val next = snapshotRef.updateAndGet(transform)
        pushTelemetry(immediate = immediate)
        return next
    }

    fun connect(address: String, callback: (Boolean, String?) -> Unit) {
        stopScan()
        persistManualDisconnect(false)
        cancelNativeReconnect()
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
                val cb = pendingConnectCallback
                pendingConnectCallback = null
                try {
                    client.disconnect()
                } catch (_: Exception) {}
                cb?.invoke(false, "Connection timed out (15s)")
            }
        }
        mainHandler.postDelayed(connectTimeoutRunnable!!, 15000)

        val connectListener = object : BleConnectStateListener {
            override fun onConnecteStateChange(state: Int) {
                when (state) {
                    BleConnectStateListener.STATE_CONNECTED -> {
                        persistLastMac(address)
                        updateSnapshot(immediate = true) { prev ->
                            prev.copy(
                                isConnected = true,
                                currentDeviceName = uteBleClient?.deviceName ?: "СААТ-1"
                            )
                        }
                        cancelNativeReconnect()

                        val conn = uteBleConnection ?: uteBleClient?.getUteBleConnection()
                        uteBleConnection = conn
                        conn?.setConnectStateListener(this)
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

                                val nowMs = System.currentTimeMillis()
                                val totalOffsetMillis = TimeZone.getDefault().getOffset(nowMs)
                                val totalMinutes = totalOffsetMillis / (1000 * 60)
                                val timeZoneHours = Math.floorDiv(totalMinutes, 60)
                                val minuteOffset = Math.abs(Math.floorMod(totalMinutes, 60))

                                val tc = TimeClock()
                                tc.timeSeconds = (nowMs / 1000).toInt()
                                tc.timeZone = timeZoneHours
                                tc.minuteOffset = minuteOffset
                                tc.dateFormat = TimeClock.DATE_YYYY_MM_DD
                                tc.timeFormat = TimeClock.TIME_HOUR_24
                                uteBleConnection?.setTimeClock(tc)

                                uteBleConnection?.setContinuousHeartRate(false)
                                uteBleConnection?.setAutoHeartRate(true)
                                uteBleConnection?.setAutoStress(true)
                                uteBleConnection?.setCallRemindEnable(true)
                                uteBleConnection?.setContinuousBloodOxygen(true)
                                uteBleConnection?.setAutoOxygenInterval(15)
                                try {
                                    uteBleClient?.setSupportUserIdPair(false)
                                } catch (_: Exception) {}

                                // Initial battery query on connect
                                val fresh = uteBleConnection?.getBatteryInfo()?.data
                                if (fresh != null) {
                                    lastBatteryPollTimeMs = System.currentTimeMillis()
                                    updateSnapshot { prev ->
                                        prev.copy(
                                            currentBattery = if (fresh.percents > 0) fresh.percents else prev.currentBattery,
                                            isCharging = (fresh.status == BatteryInfo.CHARGING)
                                        )
                                    }
                                }

                                // Initial motion query on connect
                                val motion = uteBleConnection?.getMotionSummaryData()?.data
                                if (motion != null) {
                                    val stepsSum = motion.motionDetailList?.sumOf { it.step } ?: 0
                                    val hr = motion.heartRate?.rate ?: 0
                                    updateSnapshot { prev ->
                                        prev.copy(
                                            currentSteps = if (stepsSum > 0) stepsSum else prev.currentSteps,
                                            currentCalories = if (motion.calorieSum > 0) motion.calorieSum else prev.currentCalories,
                                            currentBpm = if (hr in 30..240) hr else prev.currentBpm
                                        )
                                    }
                                }

                                // Initial sleep query on connect (once per connection)
                                lastSleepPollTimeMs = System.currentTimeMillis()
                                querySleepDataInternal()

                                // Initial stress history query on connect (once per connection)
                                lastStressPollTimeMs = System.currentTimeMillis()
                                queryStressHistoryDataInternal()

                                // Initial workout history query on connect (once per connection)
                                lastWorkoutPollTimeMs = System.currentTimeMillis()
                                queryWorkoutHistoryInternal()
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }

                        try {
                            appContext?.let { KalkanBleService.start(it) }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        startBackgroundPolling()
                        pushTelemetry(immediate = true)

                        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        connectTimeoutRunnable = null
                        val cb = pendingConnectCallback
                        pendingConnectCallback = null
                        cb?.invoke(true, null)
                    }
                    BleConnectStateListener.STATE_DISCONNECTED -> {
                        updateSnapshot(immediate = true) { prev ->
                            prev.copy(
                                isConnected = false,
                                isCharging = false,
                                currentBpm = 0,
                                isOffWrist = false,
                                skinTempDeviation = 0.0
                            )
                        }
                        stopBackgroundPolling()

                        // BLE-04: DO NOT stop KalkanBleService on transient disconnection!
                        // FGS must continue running so that auto-reconnect can work in background.
                        // DO NOT zero steps, calories, sleep, hypnogram, HRV, RHR, battery, or deviceName!

                        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                        connectTimeoutRunnable = null
                        val cb = pendingConnectCallback
                        pendingConnectCallback = null
                        cb?.invoke(false, "Disconnected before ready")
                        scheduleNativeReconnect()
                    }
                }
            }
        }

        // Pre-bind on current connection instance
        val preConn = uteBleConnection ?: client.getUteBleConnection()
        preConn?.setConnectStateListener(connectListener)

        // client.connect initiates connection and returns active UteBleConnection instance
        val newConn = client.connect(address)
        uteBleConnection = newConn ?: client.getUteBleConnection()
        uteBleConnection?.setConnectStateListener(connectListener)
        setupDeviceListeners()
    }

    fun cancelConnect() {
        stopScan()
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        connectTimeoutRunnable = null
        val cb = pendingConnectCallback
        pendingConnectCallback = null
        try {
            uteBleClient?.disconnect()
        } catch (_: Exception) {}
        cb?.invoke(false, "Connection cancelled")
    }

    fun disconnect(forget: Boolean = false) {
        stopScan()
        persistManualDisconnect(true)
        if (forget) persistLastMac(null)
        cancelNativeReconnect()
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        connectTimeoutRunnable = null
        val cb = pendingConnectCallback
        pendingConnectCallback = null
        cb?.invoke(false, "Disconnected by user")

        try {
            uteBleClient?.disconnect()
        } catch (_: Exception) {}
        stopBackgroundPolling()

        if (forget) {
            snapshotRef.set(TelemetrySnapshot())
            appContext?.let { KalkanBleService.stop(it) }
            pushTelemetry(immediate = true)
        } else {
            updateSnapshot(immediate = true) { prev ->
                prev.copy(
                    isConnected = false,
                    isCharging = false,
                    currentBpm = 0,
                    isOffWrist = false,
                    skinTempDeviation = 0.0
                )
            }
        }
    }

    fun findDevice(enable: Boolean = true, callback: (Boolean, String?) -> Unit) {
        if (isConnected && uteBleConnection != null) {
            bleExecutor.execute {
                try {
                    val cmd = if (enable) FindWearState.STATE_OPEN else FindWearState.STATE_CLOSE
                    uteBleConnection?.setFindWearCmd(cmd)
                    if (enable) {
                        mainHandler.postDelayed({
                            if (isConnected) {
                                bleExecutor.execute {
                                    try {
                                        uteBleConnection?.setFindWearCmd(FindWearState.STATE_CLOSE)
                                    } catch (_: Exception) {}
                                }
                            }
                        }, 5000L)
                    }
                    mainHandler.post { callback(true, null) }
                } catch (e: Exception) {
                    mainHandler.post { callback(false, e.localizedMessage) }
                }
            }
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
                    val nowMs = System.currentTimeMillis()
                    val totalOffsetMillis = TimeZone.getDefault().getOffset(nowMs)
                    val totalMinutes = totalOffsetMillis / (1000 * 60)
                    val timeZoneHours = Math.floorDiv(totalMinutes, 60)
                    val minuteOffset = Math.abs(Math.floorMod(totalMinutes, 60))

                    val tc = TimeClock()
                    tc.timeSeconds = (nowMs / 1000).toInt()
                    tc.timeZone = timeZoneHours
                    tc.minuteOffset = minuteOffset
                    tc.dateFormat = TimeClock.DATE_YYYY_MM_DD
                    tc.timeFormat = TimeClock.TIME_HOUR_24
                    uteBleConnection?.setTimeClock(tc)
                    mainHandler.post { callback(true, null) }
                } catch (e: Exception) {
                    mainHandler.post { callback(false, e.localizedMessage) }
                }
            }
        } else {
            callback(false, "Watch is not connected")
        }
    }

    fun resetFactory(callback: (Boolean, String?) -> Unit) {
        if (!isConnected || uteBleConnection == null) {
            callback(false, "Watch is not connected")
            return
        }
        bleExecutor.execute {
            try {
                uteBleConnection?.resetFactory(0)
                mainHandler.post {
                    disconnect(forget = true)
                    callback(true, null)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    callback(false, e.localizedMessage)
                }
            }
        }
    }

    fun configureHeartRateMonitoring(intervalMinutes: Int, continuous: Boolean) {
        bleExecutor.execute {
            try {
                uteBleConnection?.setAutoHeartRate(true)
                uteBleConnection?.setContinuousHeartRate(continuous)
                if (intervalMinutes > 0) {
                    val config = HeartRateIntervalConfig().apply {
                        enable = true
                        interval = intervalMinutes
                    }
                    uteBleConnection?.setHeartRateInterval(config)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun setDisconnectRemind(enable: Boolean, callback: (Boolean, String?) -> Unit) {
        if (!isConnected || uteBleConnection == null) {
            callback(false, "Watch is not connected")
            return
        }
        bleExecutor.execute {
            try {
                uteBleConnection?.setDisconnectRemind(enable)
                mainHandler.post { callback(true, null) }
            } catch (e: Exception) {
                mainHandler.post { callback(false, e.localizedMessage) }
            }
        }
    }

    fun setCallRemindEnable(enable: Boolean, callback: ((Boolean, String?) -> Unit)? = null) {
        if (!isConnected || uteBleConnection == null) {
            callback?.invoke(false, "Watch is not connected")
            return
        }
        bleExecutor.execute {
            try {
                uteBleConnection?.setCallRemindEnable(enable)
                mainHandler.post { callback?.invoke(true, null) }
            } catch (e: Exception) {
                mainHandler.post { callback?.invoke(false, e.localizedMessage) }
            }
        }
    }

    fun notifyIncomingCall(name: String, number: String) {
        if (!isConnected || uteBleConnection == null) return
        bleExecutor.execute {
            try {
                uteBleConnection?.notifyIncomingCall(name, number)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun notifyCallEnded() {
        if (!isConnected || uteBleConnection == null) return
        bleExecutor.execute {
            try {
                uteBleConnection?.notifyAnswerCall()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun sendMessageToWatch(message: MessageInfo) {
        if (!isConnected || uteBleConnection == null) return
        bleExecutor.execute {
            try {
                uteBleConnection?.sendMessage(message)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun setSmartAlarm(enable: Boolean, hour: Int = 7, minute: Int = 0, callback: ((Boolean, String?) -> Unit)? = null) {
        if (!isConnected || uteBleConnection == null) {
            callback?.invoke(false, "Watch is not connected")
            return
        }
        bleExecutor.execute {
            try {
                val alarm = Alarm()
                alarm.index = 0
                alarm.enable = enable
                alarm.hour = hour
                alarm.minute = minute
                alarm.name = "Smart Alarm"
                alarm.cycle = 127
                alarm.cycleList = listOf(1, 2, 3, 4, 5, 6, 7)
                uteBleConnection?.setAlarmList(listOf(alarm))
                mainHandler.post { callback?.invoke(true, null) }
            } catch (e: Exception) {
                mainHandler.post { callback?.invoke(false, e.localizedMessage) }
            }
        }
    }

    fun setHydrationReminder(enable: Boolean, interval: Int = 120, callback: ((Boolean, String?) -> Unit)? = null) {
        if (!isConnected || uteBleConnection == null) {
            callback?.invoke(false, "Watch is not connected")
            return
        }
        bleExecutor.execute {
            try {
                val remind = DrinkWaterRemindInfo(enable, 9, 0, 21, 0, interval)
                uteBleConnection?.setDrinkWaterRemind(remind)
                mainHandler.post { callback?.invoke(true, null) }
            } catch (e: Exception) {
                mainHandler.post { callback?.invoke(false, e.localizedMessage) }
            }
        }
    }

    fun clearAccountData(callback: ((Boolean, String?) -> Unit)? = null) {
        bleExecutor.execute {
            try {
                uteBleConnection?.clearAccountID()
                mainHandler.post { callback?.invoke(true, null) }
            } catch (e: Exception) {
                mainHandler.post { callback?.invoke(false, e.localizedMessage) }
            }
        }
    }

    fun setUserProfile(
        heightCm: Int,
        weightKg: Int,
        age: Int,
        gender: String,
        stepGoal: Int = 10000,
        calorieGoal: Int = 650,
        callback: ((Boolean, String?) -> Unit)? = null
    ) {
        if (!isConnected || uteBleConnection == null) {
            callback?.invoke(false, "Watch is not connected")
            return
        }
        bleExecutor.execute {
            try {
                val info = UserPhysicalInfo().apply {
                    this.height = heightCm
                    this.weight = weightKg
                    this.age = age
                    this.gender = if (gender.lowercase() == "female") UserPhysicalInfo.GENDER_FEMALE else UserPhysicalInfo.GENDER_MALE
                    this.walkStepLength = (heightCm * 0.415).toInt().coerceAtLeast(30)
                    this.runStepLength = (heightCm * 0.45).toInt().coerceAtLeast(40)
                }
                uteBleConnection?.setUserPhysicalInfo(info)

                val goal = MotionGoalConfig().apply {
                    this.goalType = MotionGoalConfig.GOAL_DAY
                    this.goalStep = stepGoal
                    this.goalCalorie = calorieGoal
                    this.goalDistance = (stepGoal * (heightCm * 0.415) / 100).toInt()
                    this.goalDuration = 3600
                }
                uteBleConnection?.setMotionGoal(goal)
                mainHandler.post { callback?.invoke(true, null) }
            } catch (e: Exception) {
                mainHandler.post { callback?.invoke(false, e.localizedMessage) }
            }
        }
    }

    fun getWorkoutHistory(callback: (List<Map<String, Any>>) -> Unit) {
        if (!isConnected || uteBleConnection == null) {
            mainHandler.post { callback(emptyList()) }
            return
        }
        bleExecutor.execute {
            val results = mutableListOf<Map<String, Any>>()
            try {
                val nowSec = (System.currentTimeMillis() / 1000).toInt()
                val resp = uteBleConnection?.syncWorkoutHistoryData(nowSec - 7 * 24 * 3600, nowSec)
                val list = resp?.data
                if (!list.isNullOrEmpty()) {
                    for (w in list) {
                        val item = mutableMapOf<String, Any>()
                        item["startTime"] = w.startTime ?: ""
                        item["endTime"] = w.endTime ?: ""
                        item["duration"] = w.duration
                        item["calories"] = w.calories.toInt()
                        item["distance"] = w.distance
                        item["steps"] = w.step
                        item["heart"] = w.heart
                        item["maxHeart"] = w.maxHeart
                        item["minHeart"] = w.minHeart
                        item["sportsType"] = w.sportsType
                        results.add(item)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            mainHandler.post { callback(results) }
        }
    }

    // BLE-05: Sequential polling with chained execution (next poll scheduled strictly after previous completes)
    fun startBackgroundPolling() {
        stopBackgroundPolling()
        val scheduler = Executors.newSingleThreadScheduledExecutor()
        backgroundScheduler = scheduler
        scheduleNextPoll(initialDelayMs = 5000L)
    }

    private fun scheduleNextPoll(initialDelayMs: Long = 30000L) {
        val scheduler = backgroundScheduler ?: return
        if (scheduler.isShutdown) return
        try {
            scheduler.schedule({
                pollTelemetryNow {
                    scheduleNextPoll(30000L)
                }
            }, initialDelayMs, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {}
    }

    fun stopBackgroundPolling() {
        try {
            backgroundScheduler?.shutdownNow()
        } catch (_: Exception) {}
        backgroundScheduler = null
    }

    fun pollTelemetryNow(onComplete: (() -> Unit)? = null) {
        if (!snapshotRef.get().isConnected || uteBleConnection == null) {
            onComplete?.invoke()
            return
        }
        if (!isPollingInProgress.compareAndSet(false, true)) {
            // BLE-05: Queue bounding guard - skip if previous poll is still in flight
            onComplete?.invoke()
            return
        }

        bleExecutor.execute {
            try {
                val now = System.currentTimeMillis()

                // 1. Motion / Steps query (every 30s)
                val motionResp = uteBleConnection?.getMotionSummaryData()
                motionResp?.data?.let { motion ->
                    val stepsSum = motion.motionDetailList?.sumOf { it.step } ?: 0
                    val hr = motion.heartRate?.rate ?: 0
                    updateSnapshot { prev ->
                        prev.copy(
                            currentSteps = if (stepsSum > 0) stepsSum else prev.currentSteps,
                            currentCalories = if (motion.calorieSum > 0) motion.calorieSum else prev.currentCalories,
                            currentBpm = if (hr in 30..240) hr else prev.currentBpm
                        )
                    }
                }

                // 2. Battery query - only once every 5 minutes (300s)
                if (now - lastBatteryPollTimeMs >= 5 * 60 * 1000L) {
                    lastBatteryPollTimeMs = now
                    val fresh = uteBleConnection?.getBatteryInfo()?.data
                    if (fresh != null) {
                        updateSnapshot { prev ->
                            prev.copy(
                                currentBattery = if (fresh.percents > 0) fresh.percents else prev.currentBattery,
                                isCharging = (fresh.status == BatteryInfo.CHARGING)
                            )
                        }
                    }
                }

                // 3. Sleep query - only once every 60 minutes during routine background polling
                if (now - lastSleepPollTimeMs >= 60 * 60 * 1000L) {
                    lastSleepPollTimeMs = now
                    querySleepDataInternal()
                }

                // 4. Stress history query - only once every 30 minutes during routine background polling
                if (now - lastStressPollTimeMs >= 30 * 60 * 1000L) {
                    lastStressPollTimeMs = now
                    queryStressHistoryDataInternal()
                }

                // 5. Workout history query - only once every 60 minutes during routine background polling
                if (now - lastWorkoutPollTimeMs >= 60 * 60 * 1000L) {
                    lastWorkoutPollTimeMs = now
                    queryWorkoutHistoryInternal()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                isPollingInProgress.set(false)
                onComplete?.invoke()
            }
        }
    }

    fun querySleepDataInternal() {
        try {
            val nowSec = (System.currentTimeMillis() / 1000).toInt()
            val resp = uteBleConnection?.syncSleepHistoryData(nowSec - 36 * 3600, nowSec)
            val list = resp?.data
            if (list.isNullOrEmpty()) return

            val sessions = mutableListOf<ParsedSleepSession>()
            var currentSession: ParsedSleepSession? = null
            var sessionCursorSec = 0

            for (item in list) {
                val dur = item.sleepTime // minutes
                // Skip placeholder items with zero duration unless explicit start/end markers
                if (dur <= 0 && item.sleepType != SciSleepData.SCI_SLEEP_TYPE_START && item.sleepType != SciSleepData.SCI_SLEEP_TYPE_END) {
                    continue
                }

                var startSec = item.startTime
                var endSec = item.endTime
                if (startSec <= 0) {
                    startSec = if (sessionCursorSec > 0) sessionCursorSec else (nowSec - Math.max(1, dur) * 60)
                }
                if (endSec <= startSec) {
                    endSec = if (dur > 0) startSec + dur * 60 else startSec
                }

                // Detect session boundaries (Section 2.41):
                // 1. SCI_SLEEP_TYPE_START marks new session
                // 2. Gap of > 60 minutes between records breaks into a new session
                val isNewSessionBreak = currentSession != null && (
                    item.sleepType == SciSleepData.SCI_SLEEP_TYPE_START ||
                    (startSec - sessionCursorSec) > 3600
                )

                if (isNewSessionBreak) {
                    currentSession?.let { cs ->
                        if (cs.totalSleepMinutes > 0 || cs.awakeMinutes > 0) {
                            sessions.add(cs)
                        }
                    }
                    currentSession = null
                }

                if (currentSession == null) {
                    currentSession = ParsedSleepSession(startSec = startSec, endSec = endSec)
                }

                val session = currentSession!!
                val stage: String
                when (item.sleepType) {
                    SciSleepData.SCI_SLEEP_TYPE_DEEP -> {
                        stage = "deep"
                        session.deepSleepMinutes += dur
                        session.totalSleepMinutes += dur
                    }
                    SciSleepData.SCI_SLEEP_TYPE_LIGHT -> {
                        stage = "light"
                        session.lightSleepMinutes += dur
                        session.totalSleepMinutes += dur
                    }
                    SciSleepData.SCI_SLEEP_TYPE_REM -> {
                        stage = "rem"
                        session.remSleepMinutes += dur
                        session.totalSleepMinutes += dur
                    }
                    SciSleepData.SCI_SLEEP_TYPE_AWAKE,
                    SciSleepData.SCI_SLEEP_TYPE_SNOOZE,
                    SciSleepData.SCI_SLEEP_TYPE_SNORE -> {
                        stage = "awake"
                        session.awakeMinutes += dur
                    }
                    SciSleepData.SCI_SLEEP_TYPE_START,
                    SciSleepData.SCI_SLEEP_TYPE_END -> {
                        stage = ""
                    }
                    else -> {
                        stage = "light"
                        session.lightSleepMinutes += dur
                        session.totalSleepMinutes += dur
                    }
                }

                if (stage.isNotEmpty() && dur > 0) {
                    session.epochs.add(
                        mapOf(
                            "stage" to stage,
                            "startTime" to startSec.toLong() * 1000L,
                            "endTime" to endSec.toLong() * 1000L,
                            "durationMinutes" to dur
                        )
                    )
                }

                if (endSec > session.endSec) {
                    session.endSec = endSec
                }
                sessionCursorSec = Math.max(sessionCursorSec, endSec)

                if (item.sleepType == SciSleepData.SCI_SLEEP_TYPE_END) {
                    if (session.totalSleepMinutes > 0 || session.awakeMinutes > 0) {
                        sessions.add(session)
                    }
                    currentSession = null
                }
            }

            currentSession?.let { cs ->
                if (cs.totalSleepMinutes > 0 || cs.awakeMinutes > 0) {
                    sessions.add(cs)
                }
            }

            // Select single primary night sleep session (Section 2.41 & iOS AppDelegate parity)
            val cal = Calendar.getInstance()
            val currentHour = cal.get(Calendar.HOUR_OF_DAY)
            val cycleCal = Calendar.getInstance()
            if (currentHour < 20) {
                cycleCal.add(Calendar.DAY_OF_YEAR, -1)
            }
            cycleCal.set(Calendar.HOUR_OF_DAY, 20)
            cycleCal.set(Calendar.MINUTE, 0)
            cycleCal.set(Calendar.SECOND, 0)
            cycleCal.set(Calendar.MILLISECOND, 0)
            val cycleStartSec = (cycleCal.timeInMillis / 1000).toInt()
            val windowStartSec = cycleStartSec - 2 * 3600

            val candidates = sessions.filter { it.endSec >= windowStartSec }
            val primaryCandidates = candidates.filter { it.totalSleepMinutes >= 60 }

            val selectedSession = primaryCandidates.maxByOrNull { it.totalSleepMinutes }
                ?: candidates.maxByOrNull { it.totalSleepMinutes }
                ?: sessions.lastOrNull()

            if (selectedSession != null && (selectedSession.totalSleepMinutes > 0 || selectedSession.awakeMinutes > 0)) {
                updateSnapshot { prev ->
                    prev.copy(
                        currentSleepMinutes = selectedSession.totalSleepMinutes,
                        currentDeepSleepMinutes = selectedSession.deepSleepMinutes,
                        currentRemSleepMinutes = selectedSession.remSleepMinutes,
                        timeInBedMinutes = selectedSession.timeInBedMinutes,
                        currentSleepEfficiency = selectedSession.sleepEfficiency,
                        currentHypnogram = selectedSession.epochs
                    )
                }
                pushTelemetry()
            }
        } catch (_: Exception) {}
    }

    fun pullNightAndDay(callback: ((Boolean, String?) -> Unit)? = null) {
        if (!isConnected || uteBleConnection == null) {
            callback?.invoke(false, "Watch is not connected")
            return
        }
        bleExecutor.execute {
            try {
                querySleepDataInternal()
                mainHandler.post { callback?.invoke(true, null) }
            } catch (e: Exception) {
                mainHandler.post { callback?.invoke(false, e.localizedMessage) }
            }
        }
    }

    fun queryWorkoutHistoryInternal() {
        try {
            val nowSec = (System.currentTimeMillis() / 1000).toInt()
            // Подтверждаем/подтягиваем завершённые тренировки (протокол 2.42).
            // Полный импорт в локальную историю — отдельная задача (маппинг SportType + единиц).
            uteBleConnection?.syncWorkoutHistoryData(nowSec - 7 * 24 * 3600, nowSec)
        } catch (_: Exception) {}
    }

    fun queryStressHistoryDataInternal() {
        try {
            val nowSec = (System.currentTimeMillis() / 1000).toInt()
            val resp = uteBleConnection?.syncStressHistoryData(nowSec - 24 * 3600, nowSec)
            val list = resp?.data
            if (!list.isNullOrEmpty()) {
                val latest = list.lastOrNull { it.pressureValue in 1..100 }
                if (latest != null) {
                    updateSnapshot { prev -> prev.copy(currentStressScore = latest.pressureValue) }
                }
            }
        } catch (_: Exception) {}
    }

    fun getHeartRateHistory(callback: (List<Map<String, Any>>) -> Unit) {
        if (!isConnected || uteBleConnection == null) {
            mainHandler.post { callback(emptyList()) }
            return
        }
        bleExecutor.execute {
            val result = mutableListOf<Map<String, Any>>()
            try {
                val nowSec = (System.currentTimeMillis() / 1000).toInt()
                val data = uteBleConnection?.syncFitnessHistoryData(nowSec - 24 * 3600, nowSec)?.data
                val hrList = data?.heartRateData
                if (!hrList.isNullOrEmpty()) {
                    for (item in hrList) {
                        val ts = item.startTime
                        val bpm = item.rate
                        if (ts > 0 && bpm in 30..240) {
                            result.add(mapOf("t" to (ts.toLong() * 1000L), "bpm" to bpm))
                        }
                    }
                }
            } catch (_: Exception) {}
            mainHandler.post { callback(result) }
        }
    }

    private fun setupDeviceListeners() {
        val conn = uteBleConnection ?: uteBleClient?.getUteBleConnection()
        uteBleConnection = conn
        conn?.setDeviceNotifyListener(object : DeviceNotifyListener {
            override fun onNotify(device: UteBleDevice, notify: Notify) {
                try {
                    when (notify.type) {
                        NotifyType.DEVICE_BATTERY_REPORT -> {
                            val batteryInfo = notify.data as? BatteryInfo
                            if (batteryInfo != null) {
                                updateSnapshot { prev ->
                                    prev.copy(
                                        currentBattery = if (batteryInfo.percents > 0) batteryInfo.percents else prev.currentBattery,
                                        isCharging = (batteryInfo.status == BatteryInfo.CHARGING)
                                    )
                                }
                            }
                        }
                        NotifyType.HEART_RATE_REPORT -> {
                            val hrReport = notify.data as? HeartRateReport
                            val latestRate = hrReport?.heartRateList?.lastOrNull()?.rate ?: 0
                            if (latestRate in 30..240) {
                                updateSnapshot { prev -> prev.copy(currentBpm = latestRate) }
                            }
                        }
                        NotifyType.DEVICE_HEALTH_TEST_RESULT_NOTIFY -> {
                            val health = notify.data as? DeviceHealthDataInfo
                            if (health != null) {
                                updateSnapshot { prev ->
                                    val rhr = prev.currentRhr
                                    val hrv = if (health.hrvValue in 5..250) health.hrvValue.toDouble() else prev.currentHrv
                                    val rr = if (rhr > 0) deriveRespiratoryRate(rhr, hrv) else prev.respiratoryRate
                                    val oxy = if (health.bloodOxygenValue in 70..100) health.bloodOxygenValue else prev.bloodOxygen
                                    prev.copy(
                                        currentBpm = if (health.heartRateValue in 30..240) health.heartRateValue else prev.currentBpm,
                                        currentHrv = hrv,
                                        currentStressScore = if (health.stressValue in 1..100) health.stressValue else prev.currentStressScore,
                                        respiratoryRate = rr,
                                        bloodOxygen = oxy
                                    )
                                }
                            }
                        }
                        NotifyType.MOTION_CURRENT_MINUTE_NOTIFY -> {
                            val motion = notify.data as? MotionCurrentMinute
                            if (motion != null) {
                                updateSnapshot { prev ->
                                    val rawRhr = if (motion.restingHeartRateV3 in 35..110) motion.restingHeartRateV3 else motion.restingHeartRate
                                    val rhr = if (rawRhr in 35..110) rawRhr else prev.currentRhr
                                    val hrv = if (motion.hrvValue > 0) motion.hrvValue.toDouble() else prev.currentHrv
                                    val rr = if (rhr > 0) deriveRespiratoryRate(rhr, hrv) else prev.respiratoryRate
                                    val oxy = if (motion.bloodOxygen in 70..100) motion.bloodOxygen else prev.bloodOxygen
                                    prev.copy(
                                        currentBpm = if (motion.dynamicHeartRate in 30..240) motion.dynamicHeartRate else prev.currentBpm,
                                        currentRhr = rhr,
                                        currentHrv = hrv,
                                        respiratoryRate = rr,
                                        bloodOxygen = oxy
                                    )
                                }
                            }
                        }
                        NotifyType.WORKOUT_REAL_TIME_DATE_REPORT -> {
                            val wReport = notify.data as? WorkoutRealTimeDataReport
                            if (wReport != null) {
                                updateSnapshot { prev ->
                                    prev.copy(
                                        currentBpm = if (wReport.heartRate in 30..240) wReport.heartRate else prev.currentBpm,
                                        currentSteps = if (wReport.step > 0) wReport.step else prev.currentSteps,
                                        currentCalories = if (wReport.calorie > 0) wReport.calorie else prev.currentCalories
                                    )
                                }
                            }
                            val wData = notify.data as? WorkoutRealTimeData
                            if (wData != null) {
                                updateSnapshot { prev ->
                                    prev.copy(
                                        currentBpm = if (wData.realTimeHeartRate in 30..240) wData.realTimeHeartRate else prev.currentBpm,
                                        currentSteps = if (wData.steps > 0) wData.steps else prev.currentSteps,
                                        currentCalories = if (wData.calorie > 0) wData.calorie else prev.currentCalories
                                    )
                                }
                            }
                        }
                        NotifyType.STRESS_TEST_RESULT_NOTIFY -> {
                            val stress = notify.data as? StressData
                            if (stress != null && stress.pressureValue in 1..100) {
                                updateSnapshot { prev -> prev.copy(currentStressScore = stress.pressureValue) }
                            }
                        }
                        NotifyType.WEARING_STATE_INFO_NOTIFY -> {
                            val wear = notify.data as? WearingStateInfo
                            if (wear != null) {
                                updateSnapshot { prev -> prev.copy(isOffWrist = (wear.wearingState == WearingStateInfo.OFF_HAND)) }
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
                        NotifyType.TEMPERATURE_TEST_RESULT_NOTIFY -> {
                            val temp = notify.data as? TemperatureInfo
                            if (temp != null) {
                                val t = temp.temperature
                                if (t in 30.0f..45.0f) {
                                    val dev = Math.round((t - 36.6f) * 100.0) / 100.0
                                    updateSnapshot { prev -> prev.copy(skinTempDeviation = dev) }
                                }
                            }
                        }
                        NotifyType.DEVICE_PAIRED_STATE_NOTIFY -> {
                            // Pairing confirmed by watch firmware
                        }
                        NotifyType.FITNESS_DATA_UPDATE -> {
                            bleExecutor.execute {
                                try {
                                    querySleepDataInternal()
                                } catch (_: Exception) {}
                            }
                        }
                        NotifyType.DEVICE_RESET_NOTIFY -> {
                            persistLastMac(null)
                            cancelNativeReconnect()
                            try {
                                uteBleConnection = null
                                uteBleClient?.disconnect()
                            } catch (_: Exception) {}
                            updateSnapshot(immediate = true) { prev ->
                                prev.copy(
                                    isConnected = false,
                                    isCharging = false,
                                    currentBpm = 0,
                                    currentDeviceName = ""
                                )
                            }
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        })
    }

    // BLE-05: Coalesced 1 Hz max telemetry push
    fun pushTelemetry(immediate: Boolean = false) {
        val now = System.currentTimeMillis()
        var runNow = false
        synchronized(pushLock) {
            if (immediate || (now - lastPushTimeMs >= 1000L && !isPushScheduled)) {
                mainHandler.removeCallbacks(pushRunnable)
                isPushScheduled = false
                lastPushTimeMs = now
                runNow = true
            } else if (!isPushScheduled) {
                isPushScheduled = true
                val delay = (1000L - (now - lastPushTimeMs)).coerceIn(50L, 1000L)
                mainHandler.postDelayed(pushRunnable, delay)
            }
        }
        if (runNow) {
            mainHandler.post { sendTelemetryToSink() }
        }
    }

    private fun sendTelemetryToSink() {
        val s = snapshotRef.get()
        val telemetry = mapOf(
            "heartRate" to s.currentBpm,
            "steps" to s.currentSteps,
            "calories" to s.currentCalories,
            "batteryLevel" to s.currentBattery,
            "isCharging" to s.isCharging,
            "isConnected" to s.isConnected,
            "deviceName" to (if (s.isConnected) s.currentDeviceName else ""),
            "hrv" to s.currentHrv,
            "restingHeartRate" to s.currentRhr,
            "sleepMinutes" to s.currentSleepMinutes,
            "deepSleepMinutes" to s.currentDeepSleepMinutes,
            "remSleepMinutes" to s.currentRemSleepMinutes,
            "timeInBedMinutes" to s.timeInBedMinutes,
            "sleepEfficiency" to s.currentSleepEfficiency,
            "sleepHypnogram" to s.currentHypnogram,
            "currentStressScore" to s.currentStressScore,
            "isOffWrist" to s.isOffWrist,
            "skinTempDeviation" to s.skinTempDeviation,
            "respiratoryRate" to s.respiratoryRate,
            "bloodOxygen" to s.bloodOxygen,
            "isAncsAuthorized" to (appContext?.let { KalkanNotificationListenerService.isNotificationAccessGranted(it) } ?: false),
            "isBluetoothEnabled" to isBluetoothEnabled()
        )

        try {
            appContext?.let { ctx ->
                val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val json = JSONObject(telemetry).toString()
                prefs.edit().putString(KEY_SNAPSHOT, json).apply()
            }
        } catch (_: Exception) {}

        telemetryEventSink?.success(telemetry)
    }

    // BLE-06: Reactive adapter state handler for Bluetooth on/off transitions
    fun onBluetoothAdapterStateChanged(isEnabled: Boolean) {
        if (!isEnabled) {
            updateSnapshot(immediate = true) { prev ->
                prev.copy(
                    isConnected = false,
                    isCharging = false,
                    currentBpm = 0,
                    isOffWrist = false,
                    skinTempDeviation = 0.0
                )
            }
            stopBackgroundPolling()
        } else {
            pushTelemetry(immediate = true)
            scheduleNativeReconnect()
        }
    }
}
