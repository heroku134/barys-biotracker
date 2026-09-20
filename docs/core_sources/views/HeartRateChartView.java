package com.yc.nadalsdkdemo.views;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.DashPathEffect;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;

import androidx.annotation.Nullable;

public class HeartRateChartView extends View {

    // 24 sample hourly points across a 24h day (00:00 to 23:00)
    private final int[] hrPoints = new int[]{
            56, 54, 55, 53, 58, 64, 72, 85, 92, 78, 74, 76,
            82, 79, 75, 88, 115, 142, 108, 86, 75, 68, 62, 58
    };

    private final Paint linePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint fillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint dashedPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint tooltipPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint tooltipTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint markerDotPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private static final int COLOR_LINE = 0xFFC45C5C;      // CIRCA Rose
    private static final int COLOR_GRAD_START = 0x44C45C5C;
    private static final int COLOR_GRAD_END = 0x0008090B;
    private static final int COLOR_MUTED = 0xFF71717A;

    private int selectedIndex = -1;
    private android.view.ScaleGestureDetector scaleGestureDetector;
    private float scaleFactor = 1.0f;
    private float focusX = 0f;

    public HeartRateChartView(Context context) {
        super(context);
        init();
    }

    public HeartRateChartView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public HeartRateChartView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        linePaint.setColor(COLOR_LINE);
        linePaint.setStyle(Paint.Style.STROKE);
        linePaint.setStrokeWidth(dpToPx(2.5f));
        linePaint.setStrokeCap(Paint.Cap.ROUND);
        linePaint.setStrokeJoin(Paint.Join.ROUND);

        fillPaint.setStyle(Paint.Style.FILL);

        dashedPaint.setColor(0x33C4A574); // Amber
        dashedPaint.setStyle(Paint.Style.STROKE);
        dashedPaint.setStrokeWidth(dpToPx(1.2f));
        dashedPaint.setPathEffect(new DashPathEffect(new float[]{dpToPx(4), dpToPx(4)}, 0));

        textPaint.setColor(COLOR_MUTED);
        textPaint.setTextSize(spToPx(10));

        tooltipPaint.setColor(0xEE16181E);
        tooltipPaint.setStyle(Paint.Style.FILL);

        tooltipTextPaint.setColor(0xFFF4F4F5);
        tooltipTextPaint.setTextSize(spToPx(11));
        tooltipTextPaint.setFakeBoldText(true);

        markerDotPaint.setColor(0xFFF4F4F5);
        markerDotPaint.setStyle(Paint.Style.FILL);

        scaleGestureDetector = new android.view.ScaleGestureDetector(getContext(), new android.view.ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override
            public boolean onScale(android.view.ScaleGestureDetector detector) {
                scaleFactor *= detector.getScaleFactor();
                scaleFactor = Math.max(1.0f, Math.min(scaleFactor, 3.5f));
                focusX = detector.getFocusX();
                invalidate();
                return true;
            }
        });
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        int w = getWidth();
        int h = getHeight();
        if (w <= 0 || h <= 0) return;

        canvas.save();
        if (scaleFactor > 1.0f) {
            canvas.scale(scaleFactor, 1.0f, focusX, 0);
        }

        float bottomPadding = dpToPx(24);
        float topPadding = dpToPx(20);
        float chartH = h - bottomPadding - topPadding;

        int minHr = 45;
        int maxHr = 160;

        float stepX = (float) w / (hrPoints.length - 1);

        Path linePath = new Path();
        Path fillPath = new Path();

        float firstX = 0;
        float firstY = topPadding + (1.0f - (float) (hrPoints[0] - minHr) / (maxHr - minHr)) * chartH;
        linePath.moveTo(firstX, firstY);
        fillPath.moveTo(firstX, h - bottomPadding);
        fillPath.lineTo(firstX, firstY);

        for (int i = 1; i < hrPoints.length; i++) {
            float prevX = (i - 1) * stepX;
            float prevY = topPadding + (1.0f - (float) (hrPoints[i - 1] - minHr) / (maxHr - minHr)) * chartH;
            float curX = i * stepX;
            float curY = topPadding + (1.0f - (float) (hrPoints[i] - minHr) / (maxHr - minHr)) * chartH;

            float midX = (prevX + curX) / 2.0f;
            linePath.cubicTo(midX, prevY, midX, curY, curX, curY);
            fillPath.cubicTo(midX, prevY, midX, curY, curX, curY);
        }

        fillPath.lineTo(w, h - bottomPadding);
        fillPath.close();

        // Draw Gradient Fill
        fillPaint.setShader(new LinearGradient(0, topPadding, 0, h - bottomPadding, COLOR_GRAD_START, COLOR_GRAD_END, Shader.TileMode.CLAMP));
        canvas.drawPath(fillPath, fillPaint);

        // Draw Resting Heart Rate baseline at 62 bpm
        float restingY = topPadding + (1.0f - (float) (62 - minHr) / (maxHr - minHr)) * chartH;
        Path dashPath = new Path();
        dashPath.moveTo(0, restingY);
        dashPath.lineTo(w, restingY);
        canvas.drawPath(dashPath, dashedPaint);
        canvas.drawText("Покой 62", dpToPx(6), restingY - dpToPx(4), textPaint);

        // Draw Line Curve
        canvas.drawPath(linePath, linePaint);

        // Draw Bottom Time Markers
        String[] timeTicks = new String[]{"00:00", "06:00", "12:00", "18:00", "23:00"};
        for (int i = 0; i < timeTicks.length; i++) {
            float x = (w / (float) (timeTicks.length - 1)) * i;
            if (i == 0) x += dpToPx(4);
            if (i == timeTicks.length - 1) x -= dpToPx(28);
            canvas.drawText(timeTicks[i], x, h - dpToPx(6), textPaint);
        }

        // Draw Selected Interactive Point
        if (selectedIndex >= 0 && selectedIndex < hrPoints.length) {
            float selX = selectedIndex * stepX;
            float selY = topPadding + (1.0f - (float) (hrPoints[selectedIndex] - minHr) / (maxHr - minHr)) * chartH;

            canvas.drawCircle(selX, selY, dpToPx(5), markerDotPaint);
            markerDotPaint.setColor(COLOR_LINE);
            canvas.drawCircle(selX, selY, dpToPx(3), markerDotPaint);
            markerDotPaint.setColor(0xFFF4F4F5);

            String text = String.format("%02d:00 · %d bpm", selectedIndex, hrPoints[selectedIndex]);
            float textWidth = tooltipTextPaint.measureText(text);
            float tooltipW = textWidth + dpToPx(20);
            float tooltipH = dpToPx(28);

            float tx = Math.max(dpToPx(8), Math.min(w - tooltipW - dpToPx(8), selX - tooltipW / 2));
            float ty = Math.max(dpToPx(4), selY - tooltipH - dpToPx(10));

            RectF tRect = new RectF(tx, ty, tx + tooltipW, ty + tooltipH);
            canvas.drawRoundRect(tRect, dpToPx(10), dpToPx(10), tooltipPaint);
            canvas.drawText(text, tx + dpToPx(10), ty + dpToPx(18), tooltipTextPaint);
        }

        canvas.restore();
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (scaleGestureDetector != null) {
            scaleGestureDetector.onTouchEvent(event);
            if (scaleGestureDetector.isInProgress()) {
                if (getParent() != null) getParent().requestDisallowInterceptTouchEvent(true);
                return true;
            }
        }
        if (event.getAction() == MotionEvent.ACTION_DOWN || event.getAction() == MotionEvent.ACTION_MOVE) {
            if (getParent() != null) getParent().requestDisallowInterceptTouchEvent(true);
            float stepX = (float) getWidth() / (hrPoints.length - 1);
            float localX = (event.getX() - focusX) / scaleFactor + focusX;
            int idx = Math.round(localX / stepX);
            idx = Math.max(0, Math.min(hrPoints.length - 1, idx));
            selectedIndex = idx;
            invalidate();
            return true;
        }
        return super.onTouchEvent(event);
    }

    private float dpToPx(float dp) {
        return dp * getResources().getDisplayMetrics().density;
    }

    private float spToPx(float sp) {
        return sp * getResources().getDisplayMetrics().scaledDensity;
    }
}
