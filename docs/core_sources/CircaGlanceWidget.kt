package com.yc.nadalsdkdemo.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import com.yc.nadalsdkdemo.BleDeviceActivity
import com.yc.nadalsdkdemo.R
import com.yc.nadalsdkdemo.intelligence.ReadinessEngine
import com.yc.nadalsdkdemo.telemetry.TelemetryHub
import com.yc.nadalsdkdemo.telemetry.WatchTelemetry
import java.util.Locale

/**
 * CircaGlanceWidget - Home Screen Glance Widget (2x2 / 4x2) in sapphire dark glass aesthetic.
 * Displays:
 * - Readiness Score & Recovery Zone
 * - Real-time Heart Rate (bpm)
 * - Daily Step count
 * - Battery percentage
 * - BLE connection state
 *
 * Tap anywhere opens BleDeviceActivity with zero latency.
 */
class CircaGlanceWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val telemetry = TelemetryHub.telemetryFlow.value
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, telemetry)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            telemetry: WatchTelemetry
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_circa_glance)

            val readiness = ReadinessEngine.calculate(telemetry)

            // Readiness score and zone
            views.setTextViewText(R.id.tv_widget_readiness_score, readiness.score.toString())
            views.setTextViewText(R.id.tv_widget_readiness_zone, readiness.zone.label.uppercase(Locale.ROOT))
            try {
                views.setTextColor(R.id.tv_widget_readiness_zone, Color.parseColor(readiness.zone.colorHex))
            } catch (ignored: Exception) {}

            views.setTextViewText(
                R.id.tv_widget_hrv,
                "HRV ${telemetry.hrvMs} мс · Покой ${telemetry.restingHeartRate}"
            )

            // Pulse
            views.setTextViewText(R.id.tv_widget_heart_rate, "${telemetry.heartRate} bpm")

            // Daily steps
            val formattedSteps = String.format(Locale.US, "%,d", telemetry.steps).replace(',', ' ')
            views.setTextViewText(R.id.tv_widget_steps, "$formattedSteps шагов")

            // Battery
            views.setTextViewText(R.id.tv_widget_battery, "${telemetry.batteryPercent}% 🔋")

            // BLE Connection status
            if (telemetry.isConnected) {
                views.setTextViewText(R.id.tv_widget_ble_status, "BLE ON")
                views.setTextColor(R.id.tv_widget_ble_status, Color.parseColor("#4EBE89"))
            } else {
                views.setTextViewText(R.id.tv_widget_ble_status, "BLE OFF")
                views.setTextColor(R.id.tv_widget_ble_status, Color.parseColor("#C45C5C"))
            }

            // Clicking the widget launches BleDeviceActivity
            val intent = Intent(context, BleDeviceActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )
            val pendingIntent = PendingIntent.getActivity(context, appWidgetId, intent, flags)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        @JvmStatic
        fun updateAll(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
                val componentName = ComponentName(context, CircaGlanceWidget::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                    val telemetry = TelemetryHub.telemetryFlow.value
                    for (appWidgetId in appWidgetIds) {
                        updateAppWidget(context, appWidgetManager, appWidgetId, telemetry)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
