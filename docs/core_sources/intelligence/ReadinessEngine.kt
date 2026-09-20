package com.yc.nadalsdkdemo.intelligence

import com.yc.nadalsdkdemo.telemetry.WatchTelemetry
import kotlin.math.roundToInt

enum class RecoveryZone(val label: String, val colorHex: String) {
    OPTIMAL("Оптимально", "#7D9A92"),    // Sage Green (>75%)
    MODERATE("Умеренно", "#C4A574"),     // Warm Amber (50-74%)
    RECOVERY("Восстановление", "#C45C5C") // Ruby Red (<50%)
}

data class ReadinessResult(
    val score: Int,
    val zone: RecoveryZone,
    val hrvFactor: Int,
    val rhrFactor: Int,
    val sleepFactor: Int,
    val tempFactor: Int
)

/**
 * ReadinessEngine - Mathematical recovery & nervous system model in Kotlin.
 * Evaluates rMSSD HRV balance, nocturnal resting pulse, deep sleep ratio, and dermal temperature deviation.
 */
object ReadinessEngine {

    fun calculate(telemetry: WatchTelemetry): ReadinessResult {
        // 1. HRV Score (Target ~65ms baseline: 40ms = 50%, 80ms = 100%)
        val hrvNorm = ((telemetry.hrvMs - 25f) / (85f - 25f) * 100f).coerceIn(10f, 100f)

        // 2. Resting Heart Rate Score (Lower is better: 48 bpm = 100%, 75 bpm = 40%)
        val rhrNorm = ((78f - telemetry.restingHeartRate) / (78f - 48f) * 100f).coerceIn(20f, 100f)

        // 3. Deep & REM Sleep Quality (Target ~25% deep sleep + REM out of total)
        val deepRatio = if (telemetry.totalSleepMinutes > 0) {
            (telemetry.deepSleepMinutes + telemetry.remSleepMinutes).toFloat() / telemetry.totalSleepMinutes
        } else 0.35f
        val sleepNorm = (deepRatio / 0.45f * 100f).coerceIn(20f, 100f)

        // 4. Skin Temp Stability (Target ~36.5 - 36.8C: deviation reduces score)
        val tempDiff = kotlin.math.abs(telemetry.skinTempC - 36.6f)
        val tempNorm = (100f - (tempDiff * 40f)).coerceIn(30f, 100f)

        // Weighted sum: 35% HRV + 30% RHR + 25% Sleep + 10% Temperature
        val weightedScore = (hrvNorm * 0.35f + rhrNorm * 0.30f + sleepNorm * 0.25f + tempNorm * 0.10f).roundToInt()
        val finalScore = weightedScore.coerceIn(0, 100)

        val zone = when {
            finalScore >= 75 -> RecoveryZone.OPTIMAL
            finalScore >= 50 -> RecoveryZone.MODERATE
            else -> RecoveryZone.RECOVERY
        }

        return ReadinessResult(
            score = finalScore,
            zone = zone,
            hrvFactor = hrvNorm.roundToInt(),
            rhrFactor = rhrNorm.roundToInt(),
            sleepFactor = sleepNorm.roundToInt(),
            tempFactor = tempNorm.roundToInt()
        )
    }
}
