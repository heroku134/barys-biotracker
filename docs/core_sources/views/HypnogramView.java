package com.yc.nadalsdkdemo.views;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;

import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.List;

public class HypnogramView extends View {

    public static class SleepStage {
        public final int stage; // 0: Awake, 1: REM, 2: Light, 3: Deep
        public final float startPercent; // 0.0 to 1.0
        public final float endPercent;
        public final String timeLabel;

        public SleepStage(int stage, float startPercent, float endPercent, String timeLabel) {
            this.stage = stage;
            this.startPercent = startPercent;
            this.endPercent = endPercent;
            this.timeLabel = timeLabel;
        }
    }

    private final List<SleepStage> stages = new ArrayList<>();
    private final Paint barPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint linePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint tooltipPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint tooltipTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private static final int COLOR_AWAKE = 0xFFC45C5C; // Rose
    private static final int COLOR_REM = 0xFF7D9A92;   // Sage
    private static final int COLOR_LIGHT = 0xFF6B9EAA; // Cyan
    private static final int COLOR_DEEP = 0xFF9D84B7;  // Soft Purple
    private static final int COLOR_GRID = 0x1FFFFFFF;
    private static final int COLOR_MUTED = 0xFF71717A;

    private int selectedIndex = -1;

    public HypnogramView(Context context) {
        super(context);
        init();
    }

    public HypnogramView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public HypnogramView(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        linePaint.setColor(COLOR_GRID);
        linePaint.setStrokeWidth(1.5f);

        textPaint.setColor(COLOR_MUTED);
        textPaint.setTextSize(spToPx(10));

        tooltipPaint.setColor(0xEE16181E);
        tooltipPaint.setStyle(Paint.Style.FILL);

        tooltipTextPaint.setColor(0xFFF4F4F5);
        tooltipTextPaint.setTextSize(spToPx(11));
        tooltipTextPaint.setFakeBoldText(true);

        loadDemoHypnogram();
    }

    private void loadDemoHypnogram() {
        stages.clear();
        // Simulation of a full night sleep from 23:30 to 07:15
        stages.add(new SleepStage(0, 0.00f, 0.04f, "23:30")); // Засыпание
        stages.add(new SleepStage(2, 0.04f, 0.16f, "23:45")); // Лёгкий
        stages.add(new SleepStage(3, 0.16f, 0.32f, "00:40")); // Глубокий
        stages.add(new SleepStage(2, 0.32f, 0.40f, "01:50")); // Лёгкий
        stages.add(new SleepStage(1, 0.40f, 0.52f, "02:30")); // REM
        stages.add(new SleepStage(3, 0.52f, 0.68f, "03:25")); // Глубокий
        stages.add(new SleepStage(2, 0.68f, 0.78f, "04:40")); // Лёгкий
        stages.add(new SleepStage(1, 0.78f, 0.90f, "05:30")); // REM
        stages.add(new SleepStage(2, 0.90f, 0.96f, "06:30")); // Лёгкий
        stages.add(new SleepStage(0, 0.96f, 1.00f, "07:00")); // Пробуждение
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        int w = getWidth();
        int h = getHeight();
        if (w <= 0 || h <= 0) return;

        float bottomPadding = dpToPx(24);
        float chartHeight = h - bottomPadding;
        float rowHeight = chartHeight / 4.0f;

        // Draw 4 Stage Guideline Rows: 0: Awake, 1: REM, 2: Light, 3: Deep
        String[] labels = new String[]{"Бодрствование", "REM", "Лёгкий", "Глубокий"};
        for (int i = 0; i < 4; i++) {
            float y = i * rowHeight + rowHeight * 0.5f;
            canvas.drawLine(0, y, w, y, linePaint);
        }

        // Draw Sleep Blocks
        float corner = dpToPx(6);
        for (int i = 0; i < stages.size(); i++) {
            SleepStage s = stages.get(i);
            float left = s.startPercent * w + dpToPx(1.5f);
            float right = s.endPercent * w - dpToPx(1.5f);
            float top = s.stage * rowHeight + dpToPx(4);
            float bottom = (s.stage + 1) * rowHeight - dpToPx(4);

            switch (s.stage) {
                case 0: barPaint.setColor(COLOR_AWAKE); break;
                case 1: barPaint.setColor(COLOR_REM); break;
                case 2: barPaint.setColor(COLOR_LIGHT); break;
                case 3: default: barPaint.setColor(COLOR_DEEP); break;
            }

            if (i == selectedIndex) {
                barPaint.setAlpha(255);
            } else {
                barPaint.setAlpha(215);
            }

            RectF rect = new RectF(left, top, right, bottom);
            canvas.drawRoundRect(rect, corner, corner, barPaint);
        }

        // Draw Time Markers at bottom
        String[] timeTicks = new String[]{"23:30", "01:30", "03:30", "05:30", "07:15"};
        for (int i = 0; i < timeTicks.length; i++) {
            float x = (w / (float) (timeTicks.length - 1)) * i;
            if (i == 0) x += dpToPx(4);
            if (i == timeTicks.length - 1) x -= dpToPx(28);
            canvas.drawText(timeTicks[i], x, h - dpToPx(6), textPaint);
        }

        // Draw Interactive Tooltip if tapped
        if (selectedIndex >= 0 && selectedIndex < stages.size()) {
            SleepStage s = stages.get(selectedIndex);
            String title = labels[s.stage] + " · " + s.timeLabel;
            float textWidth = tooltipTextPaint.measureText(title);
            float tooltipW = textWidth + dpToPx(20);
            float tooltipH = dpToPx(28);

            float cx = (s.startPercent + s.endPercent) * 0.5f * w;
            float tx = Math.max(dpToPx(8), Math.min(w - tooltipW - dpToPx(8), cx - tooltipW / 2));
            float ty = dpToPx(4);

            RectF tRect = new RectF(tx, ty, tx + tooltipW, ty + tooltipH);
            canvas.drawRoundRect(tRect, dpToPx(10), dpToPx(10), tooltipPaint);
            canvas.drawText(title, tx + dpToPx(10), ty + dpToPx(18), tooltipTextPaint);
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_DOWN || event.getAction() == MotionEvent.ACTION_MOVE) {
            float xPercent = event.getX() / getWidth();
            for (int i = 0; i < stages.size(); i++) {
                SleepStage s = stages.get(i);
                if (xPercent >= s.startPercent && xPercent <= s.endPercent) {
                    selectedIndex = i;
                    invalidate();
                    return true;
                }
            }
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
