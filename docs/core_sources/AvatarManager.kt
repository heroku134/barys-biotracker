package com.yc.nadalsdkdemo.avatar

import android.content.Context
import android.content.SharedPreferences
import com.yc.nadalsdkdemo.intelligence.ReadinessEngine
import com.yc.nadalsdkdemo.telemetry.WatchTelemetry
import com.yc.nadalsdkdemo.utils.AudioHapticHelper

enum class AvatarState(
    val title: String,
    val badgeText: String,
    val badgeColorHex: String,
    val description: String,
    val xpBonusMultiplier: Float
) {
    CHARGED(
        "Барыс бодр и заряжен",
        "⚡ 100% ЭНЕРГИИ",
        "#7D9A92", // Sage Green
        "Барыс полон богатырской силы! Мышцы заряжены, готов к рекордам (+50% к опыту).",
        1.5f
    ),
    BALANCED(
        "Барыс в тонусе",
        "⚖️ РАБОЧИЙ РЕЖИМ",
        "#C4A574", // Amber
        "Барыс в отличной боевой форме. Оптимально для тренировок и дневной активности.",
        1.0f
    ),
    TIRED(
        "Барыс устал / Отдых",
        "💤 ИСТОЩЕНИЕ ЦНС",
        "#C45C5C", // Ruby Red
        "Барыс выложился на максимум. Режим глубокого сна, отдыха и регенерации сил (Zzz).",
        0.8f
    )
}

data class DailyQuest(
    val id: String,
    val title: String,
    val current: Int,
    val target: Int,
    val unit: String,
    val rewardXp: Int,
    val isCompleted: Boolean
)

data class AvatarProfile(
    val level: Int,
    val currentXp: Int,
    val maxXp: Int,
    val rankTitle: String,
    val endurance: Int,
    val power: Int,
    val focus: Int,
    val state: AvatarState,
    val quests: List<DailyQuest>
)

/**
 * AvatarManager - Singleton governing the RPG Bio-Avatar mechanics, state evolution,
 * and experience progression synchronized with physical watch telemetry.
 */
object AvatarManager {

    private const val PREFS_NAME = "circa_avatar_prefs"
    private const val KEY_LEVEL = "key_avatar_level"
    private const val KEY_XP = "key_avatar_xp"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun getLevel(context: Context): Int {
        return getPrefs(context).getInt(KEY_LEVEL, 4)
    }

    fun getXp(context: Context): Int {
        return getPrefs(context).getInt(KEY_XP, 620)
    }

    fun getMaxXpForLevel(level: Int): Int {
        return level * 400
    }

    fun getRankTitle(level: Int): String {
        return when {
            level <= 2 -> "Ирбис-Кадет"
            level <= 5 -> "Снежный Барс"
            level <= 9 -> "Батыр Степей"
            level <= 14 -> "Ханский Барс"
            level <= 19 -> "Нео-Титан Алатау"
            else -> "Легендарный Қар Барысы"
        }
    }

    fun calculateState(telemetry: WatchTelemetry): AvatarState {
        val readiness = ReadinessEngine.calculate(telemetry)
        return when {
            readiness.score >= 75 -> AvatarState.CHARGED
            readiness.score >= 50 -> AvatarState.BALANCED
            else -> AvatarState.TIRED
        }
    }

    fun getProfile(context: Context, telemetry: WatchTelemetry): AvatarProfile {
        val level = getLevel(context)
        val currentXp = getXp(context)
        val maxXp = getMaxXpForLevel(level)
        val state = calculateState(telemetry)
        val readiness = ReadinessEngine.calculate(telemetry)

        // Calculate dynamic RPG stats based on real bio-telemetry
        val endurance = (telemetry.steps / 150).coerceIn(15, 99)
        val power = (telemetry.calories / 8).coerceIn(20, 99)
        val focus = ((telemetry.hrvMs * 0.6f) + (telemetry.sleepScore * 0.4f)).toInt().coerceIn(10, 99)

        // Quests
        val q1Target = 8000
        val q1Current = telemetry.steps
        val q1Done = q1Current >= q1Target

        val q2Target = 420 // 7 hours
        val q2Current = telemetry.totalSleepMinutes
        val q2Done = q2Current >= q2Target

        val q3Target = 75
        val q3Current = readiness.score
        val q3Done = q3Current >= q3Target

        val quests = listOf(
            DailyQuest(
                id = "quest_steps",
                title = "Пройти дневную норму шагов",
                current = q1Current,
                target = q1Target,
                unit = "шагов",
                rewardXp = 250,
                isCompleted = q1Done
            ),
            DailyQuest(
                id = "quest_sleep",
                title = "Качественный ночной сон (>7ч)",
                current = q2Current / 60,
                target = q2Target / 60,
                unit = "ч",
                rewardXp = 300,
                isCompleted = q2Done
            ),
            DailyQuest(
                id = "quest_readiness",
                title = "Восстановление ЦНС (Готовность > 75%)",
                current = q3Current,
                target = q3Target,
                unit = "%",
                rewardXp = 350,
                isCompleted = q3Done
            )
        )

        return AvatarProfile(
            level = level,
            currentXp = currentXp,
            maxXp = maxXp,
            rankTitle = getRankTitle(level),
            endurance = endurance,
            power = power,
            focus = focus,
            state = state,
            quests = quests
        )
    }

    /**
     * Adds XP and handles Level-Up transitions with audio-haptics.
     */
    fun addXp(context: Context, rawXp: Int): Pair<Int, Boolean> {
        var level = getLevel(context)
        var currentXp = getXp(context) + rawXp
        var maxXp = getMaxXpForLevel(level)
        var didLevelUp = false

        while (currentXp >= maxXp) {
            currentXp -= maxXp
            level++
            maxXp = getMaxXpForLevel(level)
            didLevelUp = true
        }

        getPrefs(context).edit()
            .putInt(KEY_LEVEL, level)
            .putInt(KEY_XP, currentXp)
            .apply()

        if (didLevelUp) {
            AudioHapticHelper.successChime(context)
        }

        return Pair(level, didLevelUp)
    }

    /**
     * Interactive training action: gives instant XP multiplied by current vitality state.
     */
    fun trainSession(context: Context, telemetry: WatchTelemetry): Int {
        val state = calculateState(telemetry)
        val earnedXp = (150 * state.xpBonusMultiplier).toInt()
        AudioHapticHelper.heavyEngage(context)
        addXp(context, earnedXp)
        return earnedXp
    }
}
