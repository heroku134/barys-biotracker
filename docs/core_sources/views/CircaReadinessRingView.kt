package com.yc.nadalsdkdemo.views

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator
import com.yc.nadalsdkdemo.utils.HapticHelper

/**
 * CircaReadinessRingView - High-end vector-animated recovery & readiness ring in Kotlin.
 * Implements smooth spring-interpolated sweep gradient, glowing leading edge, and haptic touch.
 */
class CircaReadinessRingView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var score: Int = 88
    private var animatedProgress: Float = 0f

    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(10f)
        strokeCap = Paint.Cap.ROUND
        color = Color.parseColor("#16181E")
    }

    private val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(10f)
        strokeCap = Paint.Cap.ROUND
    }

    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(14f)
        strokeCap = Paint.Cap.ROUND
        maskFilter = BlurMaskFilter(dpToPx(6f), BlurMaskFilter.Blur.NORMAL)
    }

    private val scoreTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#F4F4F5")
        textSize = spToPx(38f)
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }

    private val labelTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#7D9A92")
        textSize = spToPx(11f)
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        letterSpacing = 0.12f
        textAlign = Paint.Align.CENTER
    }

    private val subTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#71717A")
        textSize = spToPx(10f)
        textAlign = Paint.Align.CENTER
    }

    private val arcRect = RectF()
    private var sweepGradient: SweepGradient? = null
    private var currentAnimator: ValueAnimator? = null

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        animateToScore(score)
    }

    fun setScore(newScore: Int, animate: Boolean = true) {
        score = newScore.coerceIn(0, 100)
        if (animate) {
            animateToScore(score)
        } else {
            animatedProgress = score / 100f
            invalidate()
        }
    }

    private fun animateToScore(targetScore: Int) {
        currentAnimator?.cancel()
        val targetProgress = targetScore / 100f
        currentAnimator = ValueAnimator.ofFloat(0f, targetProgress).apply {
            duration = 1100
            interpolator = DecelerateInterpolator(1.8f)
            addUpdateListener { animator ->
                animatedProgress = animator.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val stroke = trackPaint.strokeWidth
        val padding = stroke + dpToPx(8f)
        val size = minOf(w, h).toFloat()
        val left = (w - size) / 2f + padding
        val top = (h - size) / 2f + padding
        val right = left + size - (padding * 2f)
        val bottom = top + size - (padding * 2f)
        arcRect.set(left, top, right, bottom)

        val centerX = arcRect.centerX()
        val centerY = arcRect.centerY()

        val colors = intArrayOf(
            Color.parseColor("#7D9A92"), // Sage green
            Color.parseColor("#C4A574"), // Amber gold
            Color.parseColor("#7D9A92")  // Return to Sage
        )
        val positions = floatArrayOf(0f, 0.65f, 1f)
        sweepGradient = SweepGradient(centerX, centerY, colors, positions).apply {
            val matrix = Matrix()
            matrix.postRotate(-90f, centerX, centerY)
            setLocalMatrix(matrix)
        }
        progressPaint.shader = sweepGradient
        glowPaint.color = Color.parseColor("#337D9A92")
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (arcRect.isEmpty) return

        // 1. Full 360 background track
        canvas.drawOval(arcRect, trackPaint)

        // 2. Animated Progress Arc
        val sweepAngle = animatedProgress * 360f
        if (sweepAngle > 0f) {
            // Soft glow
            canvas.drawArc(arcRect, -90f, sweepAngle, false, glowPaint)
            // Main gradient ring
            canvas.drawArc(arcRect, -90f, sweepAngle, false, progressPaint)
        }

        // 3. Centered Typography
        val centerX = arcRect.centerX()
        val centerY = arcRect.centerY()

        // Label: ГОТОВНОСТЬ
        canvas.drawText("ГОТОВНОСТЬ", centerX, centerY - dpToPx(28f), labelTextPaint)

        // Score: 88
        val currentDisplayScore = (animatedProgress * score).toInt()
        val scoreBounds = Rect()
        val scoreStr = currentDisplayScore.toString()
        scoreTextPaint.getTextBounds(scoreStr, 0, scoreStr.length, scoreBounds)
        canvas.drawText(scoreStr, centerX, centerY + (scoreBounds.height() / 2f) - dpToPx(2f), scoreTextPaint)

        // Subtitle: ОПТИМАЛЬНО
        val statusText = when {
            score >= 80 -> "ОПТИМАЛЬНО"
            score >= 60 -> "ХОРОШО"
            else -> "ВОССТАНОВЛЕНИЕ"
        }
        canvas.drawText(statusText, centerX, centerY + dpToPx(26f), subTextPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                HapticHelper.click(this)
                animate().scaleX(0.96f).scaleY(0.96f).setDuration(120).start()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                animate().scaleX(1.0f).scaleY(1.0f).setDuration(180).start()
                if (event.action == MotionEvent.ACTION_UP) {
                    performClick()
                    animateToScore(score)
                }
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    private fun dpToPx(dp: Float): Float = dp * context.resources.displayMetrics.density
    private fun spToPx(sp: Float): Float = sp * context.resources.displayMetrics.scaledDensity
}
