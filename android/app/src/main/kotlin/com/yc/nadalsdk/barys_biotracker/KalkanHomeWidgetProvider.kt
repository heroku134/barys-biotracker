package com.yc.nadalsdk.barys_biotracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class KalkanHomeWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            super.onReceive(context, intent)
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val recovery = readInt(prefs, "recovery_score")
            val strain = readDouble(prefs, "current_strain")
            val sleepH = readInt(prefs, "sleep_hours")
            val sleepM = readInt(prefs, "sleep_minutes")
            val line = readString(prefs, "morning_line")
            val hasNight = readBoolean(prefs, "has_night_data") || recovery > 0

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            for (id in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.kalkan_widget)
                views.setTextViewText(R.id.widget_recovery, if (hasNight && recovery > 0) "$recovery" else "—")
                views.setTextViewText(R.id.widget_strain, if (strain > 0.0) String.format("%.1f", strain) else "—")
                views.setTextViewText(
                    R.id.widget_sleep,
                    if (sleepH > 0 || sleepM > 0) "${sleepH}ч ${sleepM.toString().padStart(2, '0')}" else "—"
                )
                views.setTextViewText(R.id.widget_line, line)
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(id, views)
            }
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    private fun readInt(p: SharedPreferences, key: String): Int {
        val value = p.all[key] ?: return 0
        return when (value) {
            is Number -> value.toInt()
            is String -> value.toDoubleOrNull()?.toInt() ?: 0
            is Boolean -> if (value) 1 else 0
            else -> 0
        }
    }

    private fun readDouble(p: SharedPreferences, key: String): Double {
        val value = p.all[key] ?: return 0.0
        return when (value) {
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: 0.0
            else -> 0.0
        }
    }

    private fun readString(p: SharedPreferences, key: String): String {
        val value = p.all[key] ?: return ""
        return value.toString()
    }

    private fun readBoolean(p: SharedPreferences, key: String): Boolean {
        val value = p.all[key] ?: return false
        return when (value) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            is String -> value.equals("true", ignoreCase = true)
            else -> false
        }
    }
}
