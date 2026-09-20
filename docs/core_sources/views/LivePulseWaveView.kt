package com.yc.nadalsdkdemo.views

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.sin

/**
 * LivePulseWaveView - 60/120 FPS continuous animated real-time ECG/PPG wave in Kotlin.
 * Features physiological P-Q-R-S-T heart complex, adaptive zone coloring, neon glow, and vertical area gradient.
 */
class LivePulseWaveView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var currentBpm: Int = 74
    private var phaseOffset: Float = 0f

    private val wavePath = Path()
    private val fillPath = Path()

    private val wavePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(2.5f)
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(6f)
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        maskFilter = BlurMaskFilter(dpToPx(5f), BlurMaskFilter.Blur.NORMAL)
    }

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 1800
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            phaseOffset = it.animatedValue as Float
            invalidate()
        }
    }

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        animator.start()
        updateColors()
    }

    fun setBpm(bpm: Int) {
        currentBpm = bpm.coerceIn(40, 220)
        // Speed up animation based on bpm (higher bpm = faster wave)
        val newDuration = (120000L / currentBpm).coerceIn(400L, 1600L)
        if (animator.duration != newDuration) {
            animator.duration = newDuration
        }
        updateColors()
        invalidate()
    }

    private fun getZoneColor(): Int {
        return when {
            currentBpm < 90 -> Color.parseColor("#7D9A92")   // Sage Green (Zone 1 - Recovery)
            currentBpm < 125 -> Color.parseColor("#C4A574")  // Warm Amber (Zone 2 - Aerobic)
            currentBpm < 155 -> Color.parseColor("#E07A5F")  // Deep Coral (Zone 3 - Cardio)
            else -> Color.parseColor("#C45C5C")              // Ruby Red (Zone 4 - Anaerobic Peak)
        }
    }

    fun getZoneTitle(): String {
        return when {
            currentBpm < 90 -> "Зона 1 · Покой и восстановление"
            currentBpm < 125 -> "Зона 2 · Аэробная выносливость"
            currentBpm < 155 -> "Зона 3 · Кардио и темп"
            else -> "Зона 4 · Анаэробный пик"
        }
    }

    private fun updateColors() {
        val color = getZoneColor()
        wavePaint.color = color
        glowPaint.color = Color.argb(80, Color.red(color), Color.green(color), Color.blue(color))
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (!animator.isRunning) animator.start()
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val color = getZoneColor()
        fillPaint.shader = LinearGradient(
            0f, 0f, 0f, h.toFloat(),
            Color.argb(55, Color.red(color), Color.green(color), Color.blue(color)),
            Color.TRANSPARENT,
            Shader.TileMode.CLAMP
        )
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) return

        val midY = h * 0.58f
        val amplitude = h * 0.38f

        wavePath.reset()
        fillPath.reset()

        wavePath.moveTo(0f, midY)
        fillPath.moveTo(0f, h)
        fillPath.lineTo(0f, midY)

        val totalPoints = 120
        val wavelength = w * 0.45f // 2+ heartbeats visible simultaneously

        for (i in 0..totalPoints) {
            val x = (i / totalPoints.toFloat()) * w
            // Normalized cycle position with phase offset
            val cycle = ((x + (phaseOffset * wavelength)) % wavelength) / wavelength

            // Physiological ECG calculation: baseline + P-wave + Q-dip + R-spike + S-dip + T-wave
            val yOffset = when {
                cycle in 0.15f..0.25f -> {
                    // P-wave (atrial depolarization)
                    sin((cycle - 0.15f) / 0.10f * Math.PI).toFloat() * 0.22f
                }
                cycle in 0.28f..0.31f -> {
                    // Q-dip
                    -sin((cycle - 0.28f) / 0.03f * Math.PI).toFloat() * 0.18f
                }
                cycle in 0.31f..0.37f -> {
                    // Sharp R-spike (ventricular contraction)
                    sin((cycle - 0.31f) / 0.06f * Math.PI).toFloat() * 0.95f
                }
                cycle in 0.37f..0.41f -> {
                    // S-dip
                    -sin((cycle - 0.37f) / 0.04f * Math.PI).toFloat() * 0.30f
                }
                cycle in 0.48f..0.64f -> {
                    // T-wave (ventricular repolarization)
                    sin((cycle - 0.48f) / 0.16f * Math.PI).toFloat() * 0.32f
                }
                else -> {
                    // Micro baseline vibration
                    (sin(cycle * 30f) * 0.02f).toFloat()
                }
            }

            val y = midY - (yOffset * amplitude)
            wavePath.lineTo(x, y)
            fillPath.lineTo(x, y)
        }

        fillPath.lineTo(w, h)
        fillPath.close()

        // 1. Draw gradient fill area
        canvas.drawPath(fillPath, fillPaint)

        // 2. Draw neon glow
        canvas.drawPath(wavePath, glowPaint)

        // 3. Draw crisp main ECG line
        canvas.drawPath(wavePath, wavePaint)
    }

    private fun dpToPx(dp: Float): Float = dp * context.resources.displayMetrics.density
}
