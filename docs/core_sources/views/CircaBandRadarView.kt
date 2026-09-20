package com.yc.nadalsdkdemo.views

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.animation.LinearInterpolator
import com.yc.nadalsdkdemo.utils.HapticHelper

/**
 * CircaBandRadarView - Interactive vector titanium band with radiating BLE pulse radar in Kotlin.
 */
class CircaBandRadarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var pulseProgress: Float = 0f
    private val animator: ValueAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 2400
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            pulseProgress = it.animatedValue as Float
            invalidate()
        }
    }

    private val radarPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(1.5f)
    }

    private val bandBodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#12141A")
    }

    private val bandStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(2f)
        color = Color.parseColor("#262933")
    }

    private val goldAccentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(1.5f)
        color = Color.parseColor("#C4A574")
    }

    private val centerLedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#7D9A92")
    }

    private val centerGlowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#447D9A92")
        maskFilter = BlurMaskFilter(dpToPx(8f), BlurMaskFilter.Blur.NORMAL)
    }

    private val bandRect = RectF()

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        animator.start()
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
        val cx = w / 2f
        val cy = h / 2f
        val bandW = dpToPx(64f)
        val bandH = dpToPx(64f)
        bandRect.set(cx - bandW / 2f, cy - bandH / 2f, cx + bandW / 2f, cy + bandH / 2f)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        if (cx <= 0f || cy <= 0f) return

        val maxRadarRadius = minOf(cx, cy) - dpToPx(4f)
        val minRadarRadius = dpToPx(36f)

        // 1. Draw 2 radiating radar wave pulses
        for (i in 0..1) {
            val waveProgress = (pulseProgress + (i * 0.5f)) % 1f
            val radius = minRadarRadius + (waveProgress * (maxRadarRadius - minRadarRadius))
            val alpha = ((1f - waveProgress) * 90).toInt().coerceIn(0, 255)

            radarPaint.color = Color.argb(alpha, 125, 154, 146) // Sage #7D9A92
            canvas.drawCircle(cx, cy, radius, radarPaint)
        }

        // 2. Titanium Band Outer Body (Rounded Squircle)
        val cornerRadius = dpToPx(20f)
        canvas.drawRoundRect(bandRect, cornerRadius, cornerRadius, bandBodyPaint)
        canvas.drawRoundRect(bandRect, cornerRadius, cornerRadius, bandStrokePaint)

        // 3. Inner Champagne Gold Bevel
        val innerRect = RectF(bandRect).apply {
            inset(dpToPx(4f), dpToPx(4f))
        }
        canvas.drawRoundRect(innerRect, dpToPx(16f), dpToPx(16f), goldAccentPaint)

        // 4. Center Bio-Sensor Optical Lens
        canvas.drawCircle(cx, cy, dpToPx(12f), centerGlowPaint)
        canvas.drawCircle(cx, cy, dpToPx(7f), centerLedPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                HapticHelper.heavyClick(context)
                animate().scaleX(0.93f).scaleY(0.93f).setDuration(100).start()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                animate().scaleX(1f).scaleY(1f).setDuration(160).start()
                if (event.action == MotionEvent.ACTION_UP) {
                    performClick()
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
}
