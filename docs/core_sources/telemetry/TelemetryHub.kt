package com.yc.nadalsdkdemo.telemetry

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * WatchTelemetry - Immutable state of all current watch sensor readings.
 */
data class WatchTelemetry(
    val heartRate: Int = 74,
    val restingHeartRate: Int = 54,
    val hrvMs: Int = 64,
    val steps: Int = 8432,
    val stepGoal: Int = 10000,
    val calories: Int = 512,
    val calorieGoal: Int = 650,
    val distanceKm: Float = 6.2f,
    val spo2Percent: Int = 98,
    val skinTempC: Float = 36.6f,
    val sleepScore: Int = 90,
    val deepSleepMinutes: Int = 105,
    val remSleepMinutes: Int = 90,
    val totalSleepMinutes: Int = 465,
    val stressScore: Int = 26,
    val batteryPercent: Int = 84,
    val isConnected: Boolean = true,
    val deviceName: String = "CIRCA One"
)

data class PulseBeatEvent(
    val bpm: Int,
    val timestampMs: Long = System.currentTimeMillis()
)

/**
 * TelemetryHub - Central reactive stream for low-latency sensor dispatching on Kotlin StateFlow.
 * Eliminates memory leaks, lag, and thread-blocking UI updates.
 */
object TelemetryHub {

    private val scope = CoroutineScope(Dispatchers.Main.immediate)

    private val _telemetryFlow = MutableStateFlow(WatchTelemetry())
    val telemetryFlow: StateFlow<WatchTelemetry> = _telemetryFlow.asStateFlow()

    private val _pulseBeatFlow = MutableSharedFlow<PulseBeatEvent>(replay = 1, extraBufferCapacity = 16)
    val pulseBeatFlow: SharedFlow<PulseBeatEvent> = _pulseBeatFlow.asSharedFlow()

    fun updateTelemetry(update: (WatchTelemetry) -> WatchTelemetry) {
        val current = _telemetryFlow.value
        val next = update(current)
        _telemetryFlow.value = next
        try {
            val context = com.yc.nadalsdkdemo.MyApplication.getContext()
            if (context != null) {
                com.yc.nadalsdkdemo.widget.CircaGlanceWidget.updateAll(context)
            }
        } catch (ignored: Exception) {}
    }

    fun emitHeartRate(bpm: Int) {
        val safeBpm = bpm.coerceIn(40, 220)
        updateTelemetry { it.copy(heartRate = safeBpm) }
        scope.launch {
            _pulseBeatFlow.emit(PulseBeatEvent(safeBpm))
        }
    }

    fun emitSteps(steps: Int, calories: Int, distanceKm: Float) {
        updateTelemetry { it.copy(steps = steps, calories = calories, distanceKm = distanceKm) }
    }

    fun emitConnectionState(connected: Boolean, deviceName: String = "CIRCA One") {
        updateTelemetry { it.copy(isConnected = connected, deviceName = deviceName) }
    }

    fun emitSpo2(spo2: Int) {
        updateTelemetry { it.copy(spo2Percent = spo2.coerceIn(70, 100)) }
    }

    fun emitTemperature(temp: Float) {
        updateTelemetry { it.copy(skinTempC = temp) }
    }

    fun emitHrv(hrvMs: Int) {
        updateTelemetry { it.copy(hrvMs = hrvMs.coerceIn(10, 200)) }
    }
}
