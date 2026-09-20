package com.yc.nadalsdkdemo.utils

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.view.View
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

/**
 * Luxury Audio-Haptics Engine for CIRCA.
 * Delivers synchronized haptic tactile impulses with synthesized micro-acoustic feedback:
 * - Mechanical Click: Swiss chronometer / Leica shutter micro-snap (1850 Hz + 110 Hz sub-decay, 12ms)
 * - Heavy Engage: Solid rotary ratchet / watch crown engagement (1400 Hz -> 2200 Hz with dual transient, 24ms)
 * - Success Chime: Pure crystal dual harmonic ping (1318 Hz E6 -> 1760 Hz A6, 70ms)
 *
 * Uses pre-rendered in-memory PCM 16-bit buffers in AudioTrack.MODE_STATIC for TRUE 0ms latency.
 */
object AudioHapticHelper {

    private const val SAMPLE_RATE = 44100

    private var mechanicalClickTrack: AudioTrack? = null
    private var heavyEngageTrack: AudioTrack? = null
    private var successChimeTrack: AudioTrack? = null

    private var isInitialized = false

    @Synchronized
    private fun ensureTracks() {
        if (isInitialized) return
        try {
            mechanicalClickTrack = createStaticTrack(generateMechanicalClickPcm())
            heavyEngageTrack = createStaticTrack(generateHeavyEngagePcm())
            successChimeTrack = createStaticTrack(generateSuccessChimePcm())
            isInitialized = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createStaticTrack(pcmData: ShortArray): AudioTrack? {
        val bufferSizeBytes = pcmData.size * 2
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val format = AudioFormat.Builder()
            .setSampleRate(SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .build()

        val track = AudioTrack(
            attributes,
            format,
            bufferSizeBytes,
            AudioTrack.MODE_STATIC,
            AudioManager.AUDIO_SESSION_ID_GENERATE
        )

        track.write(pcmData, 0, pcmData.size)
        return track
    }

    /**
     * Synthesizes 12ms sharp metallic transient:
     * High resonance click at 1850Hz with 110Hz body decay.
     */
    private fun generateMechanicalClickPcm(): ShortArray {
        val durationMs = 12
        val numSamples = (SAMPLE_RATE * durationMs) / 1000
        val pcm = ShortArray(numSamples)
        val maxAmp = 28000.0

        for (i in 0 until numSamples) {
            val t = i.toDouble() / SAMPLE_RATE
            val decay = exp(-t * 450.0)
            val attack = if (i < 15) (i / 15.0) else 1.0
            val clickWave = 0.75 * sin(2.0 * PI * 1850.0 * t) + 0.25 * sin(2.0 * PI * 110.0 * t)
            val sampleVal = (clickWave * decay * attack * maxAmp).coerceIn(-32767.0, 32767.0)
            pcm[i] = sampleVal.toInt().toShort()
        }
        return pcm
    }

    /**
     * Synthesizes 24ms mechanical latch / watch crown engagement:
     * Dual micro-transients for a solid mechanical feel.
     */
    private fun generateHeavyEngagePcm(): ShortArray {
        val durationMs = 24
        val numSamples = (SAMPLE_RATE * durationMs) / 1000
        val pcm = ShortArray(numSamples)
        val maxAmp = 30000.0

        for (i in 0 until numSamples) {
            val t = i.toDouble() / SAMPLE_RATE
            val t1 = t
            val t2 = (t - 0.007).coerceAtLeast(0.0)

            val click1 = if (t < 0.007) sin(2.0 * PI * 1400.0 * t1) * exp(-t1 * 500.0) else 0.0
            val click2 = if (t >= 0.007) (sin(2.0 * PI * 2200.0 * t2) * 0.7 + sin(2.0 * PI * 95.0 * t2) * 0.3) * exp(-t2 * 280.0) else 0.0

            val sampleVal = ((click1 * 0.6 + click2 * 0.9) * maxAmp).coerceIn(-32767.0, 32767.0)
            pcm[i] = sampleVal.toInt().toShort()
        }
        return pcm
    }

    /**
     * Synthesizes 70ms luxury crystal chime (E6 -> A6 harmonic).
     */
    private fun generateSuccessChimePcm(): ShortArray {
        val durationMs = 70
        val numSamples = (SAMPLE_RATE * durationMs) / 1000
        val pcm = ShortArray(numSamples)
        val maxAmp = 22000.0

        for (i in 0 until numSamples) {
            val t = i.toDouble() / SAMPLE_RATE
            val decay = exp(-t * 50.0)
            val wave = if (t < 0.03) {
                sin(2.0 * PI * 1318.51 * t)
            } else {
                val t2 = t - 0.03
                0.8 * sin(2.0 * PI * 1760.0 * t2) + 0.2 * sin(2.0 * PI * 3520.0 * t2)
            }
            pcm[i] = (wave * decay * maxAmp).coerceIn(-32767.0, 32767.0).toInt().toShort()
        }
        return pcm
    }

    private fun playTrack(track: AudioTrack?) {
        if (track == null) return
        try {
            track.stop()
            track.reloadStaticData()
            track.play()
        } catch (e: Exception) {
            // Non-critical
        }
    }

    @JvmStatic
    @JvmOverloads
    fun mechanicalClick(context: Context, view: View? = null) {
        if (view != null) {
            HapticHelper.click(view)
        } else {
            HapticHelper.click(context)
        }
        ensureTracks()
        playTrack(mechanicalClickTrack)
    }

    @JvmStatic
    fun heavyEngage(context: Context) {
        HapticHelper.heavyClick(context)
        ensureTracks()
        playTrack(heavyEngageTrack)
    }

    @JvmStatic
    fun successChime(context: Context) {
        HapticHelper.tick(context)
        ensureTracks()
        playTrack(successChimeTrack)
    }

    @JvmStatic
    fun tick(context: Context) {
        HapticHelper.tick(context)
        ensureTracks()
        playTrack(mechanicalClickTrack)
    }
}
