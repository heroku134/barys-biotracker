package com.yc.nadalsdk.barys_biotracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

class KalkanHomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val recovery = readInt(prefs, "recovery_score")
        val strain = readDouble(prefs, "current_strain")
        val sleepH = readInt(prefs, "sleep_hours")
        val sleepM = readInt(prefs, "sleep_minutes")
        val line = prefs.getString("morning_line", "") ?: ""
        val hasNight = prefs.getBoolean("has_night_data", false) || recovery > 0
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.kalkan_widget)
            views.setTextViewText(R.id.widget_recovery, if (hasNight && recovery > 0) "$recovery" else "—")
            views.setTextViewText(R.id.widget_strain, if (strain > 0.0) String.format("%.1f", strain) else "—")
            views.setTextViewText(
                R.id.widget_sleep,
                if (sleepH > 0 || sleepM > 0) "${sleepH}ч ${sleepM.toString().padStart(2, '0')}" else "—"
            )
            views.setTextViewText(R.id.widget_line, line)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun readInt(p: SharedPreferences, key: String): Int {
        return try { p.getInt(key, 0) } catch (_: Exception) {
            p.getString(key, "0")?.toDoubleOrNull()?.toInt() ?: 0
        }
    }

    private fun readDouble(p: SharedPreferences, key: String): Double {
        return try { p.getFloat(key, 0f).toDouble() } catch (_: Exception) {
            p.getString(key, "0")?.toDoubleOrNull() ?: 0.0
        }
    }
}
