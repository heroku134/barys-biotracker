package com.yc.nadalsdkdemo.intelligence

import com.yc.nadalsdkdemo.telemetry.WatchTelemetry

data class CoachAdvice(
    val title: String,
    val recommendation: String,
    val targetStrain: String,
    val badgeText: String,
    val badgeColorHex: String
)

/**
 * SmartDailyCoach - AI intelligence generator for daily biometric insights.
 */
object SmartDailyCoach {

    fun generate(telemetry: WatchTelemetry): CoachAdvice {
        val readiness = ReadinessEngine.calculate(telemetry)

        return when (readiness.zone) {
            RecoveryZone.OPTIMAL -> CoachAdvice(
                title = "Пиковая готовность к нагрузке",
                recommendation = "Нервная система полностью восстановлена (ВСР ${telemetry.hrvMs} мс, пульс покоя ${telemetry.restingHeartRate} bpm). Организм готов к интенсивным анаэробным интервалам, силовой тренировке или длинной пробежке.",
                targetStrain = "Целевая нагрузка: Высокая (14.0 — 17.5 Strain)",
                badgeText = "ПИКОВАЯ ФОРМА",
                badgeColorHex = "#7D9A92"
            )
            RecoveryZone.MODERATE -> CoachAdvice(
                title = "Сбалансированное состояние",
                recommendation = "Восстановление на хорошем уровне. Идеально для поддержания аэробной выносливости в Зоне 2, плавания или функционального тренинга средней интенсивности.",
                targetStrain = "Целевая нагрузка: Умеренная (10.0 — 13.5 Strain)",
                badgeText = "УМЕРЕННАЯ НАГРУЗКА",
                badgeColorHex = "#C4A574"
            )
            RecoveryZone.RECOVERY -> CoachAdvice(
                title = "Требуется активный отдых",
                recommendation = "Повышенный ночной пульс и сниженная ВСР сигнализируют о накопленной усталости. Рекомендуется ограничиться легкой прогулкой, растяжкой, сауной и запланировать отход ко сну на 40 минут раньше.",
                targetStrain = "Целевая нагрузка: Минимальная (< 9.0 Strain)",
                badgeText = "ДЕНЬ ВОССТАНОВЛЕНИЯ",
                badgeColorHex = "#C45C5C"
            )
        }
    }
}
