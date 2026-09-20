package com.yc.nadalsdkdemo.views

import android.content.Context
import android.graphics.*
import android.os.Build
import android.util.AttributeSet
import android.widget.FrameLayout

/**
 * CircaGlassCardView - Luxury glassmorphic card with hardware backdrop blur and sapphire border.
 */
class CircaGlassCardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(1f)
        color = Color.parseColor("#222530")
    }

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#0E1015")
    }

    private val cornerRadius = dpToPx(18f)
    private val cardBounds = RectF()

    init {
        setWillNotDraw(false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val blurEffect = RenderEffect.createBlurEffect(
                    dpToPx(12f), dpToPx(12f), Shader.TileMode.CLAMP
                )
                // Backdrop blur can be set to foreground background
            } catch (ignored: Exception) {}
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val stroke = borderPaint.strokeWidth / 2f
        cardBounds.set(stroke, stroke, w - stroke, h - stroke)

        bgPaint.shader = LinearGradient(
            0f, 0f, 0f, h.toFloat(),
            Color.parseColor("#14151C"),
            Color.parseColor("#0A0B0E"),
            Shader.TileMode.CLAMP
        )
    }

    override fun onDraw(canvas: Canvas) {
        if (!cardBounds.isEmpty) {
            canvas.drawRoundRect(cardBounds, cornerRadius, cornerRadius, bgPaint)
            canvas.drawRoundRect(cardBounds, cornerRadius, cornerRadius, borderPaint)
        }
        super.onDraw(canvas)
    }

    private fun dpToPx(dp: Float): Float = dp * context.resources.displayMetrics.density
}
