package com.yc.nadalsdkdemo.avatar

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.animation.LinearInterpolator
import android.view.animation.OvershootInterpolator
import com.yc.nadalsdkdemo.R
import com.yc.nadalsdkdemo.telemetry.TelemetryHub
import com.yc.nadalsdkdemo.utils.AudioHapticHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random

/**
 * BioAvatarView - Interactive Snow Leopard (Барыс-Батыр) Avatar.
 * Features:
 * - Real character art in two dynamic states:
 *   1. Charged / Бодрый (R.drawable.hero_barys_charged): Athletic flexing Barys Batyr in Kazakh vest & hat.
 *   2. Tired / Уставший (R.drawable.hero_barys_tired): Exhausted, resting Barys Batyr with floating Zzz particles.
 * - Breathing kinematics (floating sinusoidal posture).
 * - Real-time glowing heart reactor in the chest synchronized with physical BLE heart rate.
 * - Tap bounce spring physics with mechanical click.
 */
class BioAvatarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var avatarState: AvatarState = AvatarState.CHARGED

    private var chargedBitmap: Bitmap? = null
    private var tiredBitmap: Bitmap? = null

    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val textZzzPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#A0B2C6")
        textSize = 32f
        isFakeBoldText = true
    }

    private val dstRect = RectF()

    private var animTime = 0f
    private var pulseScale = 1.0f
    private var tapBounceScale = 1.0f

    private var animator: ValueAnimator? = null
    private var coroutineJob: Job? = null
    private val viewScope = CoroutineScope(Dispatchers.Main)

    private class SparkParticle(
        var x: Float,
        var y: Float,
        var speedY: Float,
        var size: Float,
        var alpha: Float,
        var color: Int
    )

    private val particles = ArrayList<SparkParticle>()

    init {
        loadHeroBitmaps()
        initParticles()
    }

    private fun loadHeroBitmaps() {
        try {
            val options = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.RGB_565
            }
            chargedBitmap = BitmapFactory.decodeResource(resources, R.drawable.hero_barys_charged, options)
            tiredBitmap = BitmapFactory.decodeResource(resources, R.drawable.hero_barys_tired, options)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun initParticles() {
        particles.clear()
        val colors = intArrayOf(
            Color.parseColor("#7D9A92"),
            Color.parseColor("#C4A574"),
            Color.parseColor("#E0E3EB")
        )
        for (i in 0 until 18) {
            particles.add(
                SparkParticle(
                    x = Random.nextFloat(),
                    y = Random.nextFloat(),
                    speedY = 0.003f + Random.nextFloat() * 0.006f,
                    size = 3f + Random.nextFloat() * 5f,
                    alpha = 0.3f + Random.nextFloat() * 0.7f,
                    color = colors[Random.nextInt(colors.size)]
                )
            )
        }
    }

    fun setState(state: AvatarState) {
        if (this.avatarState != state) {
            this.avatarState = state
            invalidate()
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        startAnimation()
        listenToHeartBeats()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        animator?.cancel()
        coroutineJob?.cancel()
    }

    private fun startAnimation() {
        animator?.cancel()
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2000L
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener {
                animTime = it.currentPlayTime.toFloat()
                invalidate()
            }
            start()
        }
    }

    private fun listenToHeartBeats() {
        coroutineJob?.cancel()
        coroutineJob = viewScope.launch {
            TelemetryHub.pulseBeatFlow.collectLatest {
                triggerHeartPulse()
            }
        }
    }

    private fun triggerHeartPulse() {
        ValueAnimator.ofFloat(1.4f, 1.0f).apply {
            duration = 380L
            interpolator = OvershootInterpolator(2.0f)
            addUpdateListener {
                pulseScale = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                ValueAnimator.ofFloat(1.0f, 0.92f).apply {
                    duration = 100L
                    addUpdateListener {
                        tapBounceScale = it.animatedValue as Float
                        invalidate()
                    }
                    start()
                }
                AudioHapticHelper.mechanicalClick(context, this)
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                ValueAnimator.ofFloat(0.92f, 1.0f).apply {
                    duration = 350L
                    interpolator = OvershootInterpolator(3.0f)
                    addUpdateListener {
                        tapBounceScale = it.animatedValue as Float
                        invalidate()
                    }
                    start()
                }
                performClick()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0 || h <= 0) return

        canvas.save()
        // Tap bounce spring scale centered
        canvas.scale(tapBounceScale, tapBounceScale, w / 2f, h / 2f)

        val cx = w / 2f
        val cy = h / 2f

        // 1. Background Aura Glow
        drawAuraGlow(canvas, cx, cy, w)

        // 2. Floating Particles (Sparks if Charged)
        if (avatarState == AvatarState.CHARGED) {
            drawEnergySparks(canvas, w, h)
        }

        // 3. Dynamic breathing kinematics offset
        val breathSpeed = if (avatarState == AvatarState.TIRED) 0.0018 else 0.0035
        val breathOffset = (sin(animTime * breathSpeed) * (if (avatarState == AvatarState.TIRED) 3.5f else 6f)).toFloat()

        // 4. Draw Hero Character Bitmap (Barys Batyr)
        val bmp = if (avatarState == AvatarState.TIRED) tiredBitmap else chargedBitmap
        if (bmp != null && !bmp.isRecycled) {
            val aspect = bmp.width.toFloat() / bmp.height.toFloat()
            var drawW = w * 0.95f
            var drawH = drawW / aspect
            if (drawH > h * 0.95f) {
                drawH = h * 0.95f
                drawW = drawH * aspect
            }
            val left = cx - drawW / 2f
            val top = (cy - drawH / 2f) + breathOffset
            dstRect.set(left, top, left + drawW, top + drawH)
            canvas.drawBitmap(bmp, null, dstRect, bitmapPaint)
        }

        // 5. Draw Glowing Heart Reactor on Chest (pulsing with real pulse)
        drawChestHeartReactor(canvas, cx, cy, breathOffset)

        // 6. Draw floating Zzz sleep particles when tired
        if (avatarState == AvatarState.TIRED) {
            drawZzzBubbles(canvas, cx, cy)
        }

        canvas.restore()
    }

    private fun drawAuraGlow(canvas: Canvas, cx: Float, cy: Float, w: Float) {
        val auraRadius = (w * 0.5f)
        val glowColor = when (avatarState) {
            AvatarState.CHARGED -> Color.parseColor("#337D9A92")
            AvatarState.BALANCED -> Color.parseColor("#26C4A574")
            AvatarState.TIRED -> Color.parseColor("#203F4C5E")
        }
        glowPaint.shader = RadialGradient(
            cx, cy, auraRadius,
            intArrayOf(glowColor, Color.TRANSPARENT),
            floatArrayOf(0.25f, 1.0f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, auraRadius, glowPaint)
    }

    private fun drawEnergySparks(canvas: Canvas, w: Float, h: Float) {
        val sparkPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        for (p in particles) {
            p.y -= p.speedY
            if (p.y < 0.05f) {
                p.y = 0.95f
                p.x = 0.1f + Random.nextFloat() * 0.8f
            }
            val px = p.x * w
            val py = p.y * h
            sparkPaint.color = p.color
            sparkPaint.alpha = (p.alpha * 220).toInt().coerceIn(0, 255)
            canvas.drawCircle(px, py, p.size, sparkPaint)
        }
    }

    private fun drawZzzBubbles(canvas: Canvas, cx: Float, cy: Float) {
        val cycle = (animTime % 2400f) / 2400f
        val z1Y = cy - 70f - (cycle * 45f)
        val z1X = cx + 45f + sin(cycle * 2 * PI).toFloat() * 6f
        textZzzPaint.alpha = ((1f - cycle) * 220).toInt().coerceIn(0, 255)
        textZzzPaint.textSize = 24f
        canvas.drawText("z", z1X, z1Y, textZzzPaint)

        val cycle2 = ((animTime + 800f) % 2400f) / 2400f
        val z2Y = cy - 80f - (cycle2 * 50f)
        val z2X = cx + 56f + sin(cycle2 * 2 * PI).toFloat() * 8f
        textZzzPaint.alpha = ((1f - cycle2) * 220).toInt().coerceIn(0, 255)
        textZzzPaint.textSize = 30f
        canvas.drawText("Z", z2X, z2Y, textZzzPaint)

        val cycle3 = ((animTime + 1600f) % 2400f) / 2400f
        val z3Y = cy - 95f - (cycle3 * 55f)
        val z3X = cx + 68f + sin(cycle3 * 2 * PI).toFloat() * 10f
        textZzzPaint.alpha = ((1f - cycle3) * 220).toInt().coerceIn(0, 255)
        textZzzPaint.textSize = 38f
        canvas.drawText("Z", z3X, z3Y, textZzzPaint)
    }

    private fun drawChestHeartReactor(canvas: Canvas, cx: Float, cy: Float, breathOffset: Float) {
        val isTired = avatarState == AvatarState.TIRED
        val reactorY = cy + breathOffset + (if (isTired) 22f else 32f)
        val reactorX = cx + (if (isTired) -4f else 0f)

        val baseSize = if (isTired) 8f else 11f
        val reactorSize = baseSize * pulseScale

        // Outer glow
        val coreGlowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isTired) Color.parseColor("#40C45C5C") else Color.parseColor("#457D9A92")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(reactorX, reactorY, reactorSize * 2.0f, coreGlowPaint)

        // Pulsing Diamond Crystal Core
        val reactorPath = Path().apply {
            moveTo(reactorX, reactorY - reactorSize)
            lineTo(reactorX + reactorSize, reactorY)
            lineTo(reactorX, reactorY + reactorSize)
            lineTo(reactorX - reactorSize, reactorY)
            close()
        }
        val reactorCorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isTired) Color.parseColor("#C45C5C") else Color.parseColor("#7D9A92")
            style = Paint.Style.FILL
        }
        canvas.drawPath(reactorPath, reactorCorePaint)
    }
}
