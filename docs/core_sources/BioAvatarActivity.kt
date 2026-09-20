package com.yc.nadalsdkdemo.avatar

import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.yc.nadalsdkdemo.R
import com.yc.nadalsdkdemo.databinding.ActivityBioAvatarBinding
import com.yc.nadalsdkdemo.telemetry.TelemetryHub
import com.yc.nadalsdkdemo.utils.AudioHapticHelper

class BioAvatarActivity : AppCompatActivity() {

    private lateinit var binding: ActivityBioAvatarBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityBioAvatarBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.btnBackAvatar.setOnClickListener {
            AudioHapticHelper.mechanicalClick(this, it)
            finish()
        }

        binding.btnTrainAvatar.setOnClickListener {
            val telemetry = TelemetryHub.telemetryFlow.value
            val earnedXp = AvatarManager.trainSession(this, telemetry)
            val profile = AvatarManager.getProfile(this, telemetry)

            Toast.makeText(
                this,
                "⚡ Сессия завершена! +$earnedXp XP получено",
                Toast.LENGTH_SHORT
            ).show()

            updateProfileUI()
        }

        updateProfileUI()
    }

    override fun onResume() {
        super.onResume()
        updateProfileUI()
    }

    private fun updateProfileUI() {
        val telemetry = TelemetryHub.telemetryFlow.value
        val profile = AvatarManager.getProfile(this, telemetry)

        // 1. Avatar Kinematics View State
        binding.bioAvatarView.setState(profile.state)

        // 2. State Badge & Description
        binding.tvAvatarStateBadge.text = profile.state.badgeText
        try {
            binding.tvAvatarStateBadge.setTextColor(Color.parseColor(profile.state.badgeColorHex))
        } catch (ignored: Exception) {}
        binding.tvAvatarStateDesc.text = profile.state.description

        // 3. Level & XP
        binding.tvTopLevelBadge.text = "УР. ${profile.level}"
        binding.tvAvatarRank.text = profile.rankTitle
        binding.tvAvatarLevelNum.text = "Уровень ${profile.level}"

        binding.pbAvatarXp.max = profile.maxXp
        binding.pbAvatarXp.progress = profile.currentXp
        val remainingXp = (profile.maxXp - profile.currentXp).coerceAtLeast(0)
        binding.tvAvatarXpProgress.text =
            "${profile.currentXp} / ${profile.maxXp} XP (Осталось $remainingXp XP до Ур. ${profile.level + 1})"

        // 4. Stats
        binding.tvStatEndurance.text = "${profile.endurance} / 99"
        binding.tvStatPower.text = "${profile.power} / 99"
        binding.tvStatFocus.text = "${profile.focus} / 99"

        // 5. Quests
        val q1 = profile.quests.getOrNull(0)
        if (q1 != null) {
            binding.pbQuestSteps.max = q1.target
            binding.pbQuestSteps.progress = q1.current
            binding.tvQuestStepsStatus.text = if (q1.isCompleted) "+${q1.rewardXp} XP ✅" else "${q1.current}/${q1.target}"
        }

        val q2 = profile.quests.getOrNull(1)
        if (q2 != null) {
            binding.pbQuestSleep.max = q2.target
            binding.pbQuestSleep.progress = q2.current
            binding.tvQuestSleepStatus.text = if (q2.isCompleted) "+${q2.rewardXp} XP ✅" else "${q2.current}/${q2.target} ч"
        }

        val q3 = profile.quests.getOrNull(2)
        if (q3 != null) {
            binding.pbQuestReadiness.max = q3.target
            binding.pbQuestReadiness.progress = q3.current
            binding.tvQuestReadinessStatus.text = if (q3.isCompleted) "+${q3.rewardXp} XP ✅" else "${q3.current}/${q3.target}%"
        }

        // 6. Action Button text
        val bonusText = if (profile.state == AvatarState.CHARGED) "(+50% БОНУС!)" else ""
        binding.btnTrainAvatar.text = "⚡ Прокачать Барыса (+150 XP $bonusText)"
    }
}
