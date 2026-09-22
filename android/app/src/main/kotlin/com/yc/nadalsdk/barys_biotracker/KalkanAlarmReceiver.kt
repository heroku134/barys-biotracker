package com.yc.nadalsdk.barys_biotracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class KalkanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) return
        val id = intent.getIntExtra(KalkanNotify.EXTRA_ID, 1101)
        val title = intent.getStringExtra(KalkanNotify.EXTRA_TITLE) ?: "KALKAN"
        val body = intent.getStringExtra(KalkanNotify.EXTRA_BODY) ?: ""
        val channel = intent.getStringExtra(KalkanNotify.EXTRA_CHANNEL) ?: "morning"
        val hour = CalendarHour.hourFor(id)
        val minute = CalendarHour.minuteFor(id)
        KalkanNotify.show(context, id, title, body, channel)
        KalkanNotify.scheduleDaily(context, id, hour, minute, title, body, channel)
    }
}

private object CalendarHour {
    fun hourFor(id: Int) = when (id) {
        1102 -> 21
        1103 -> 23
        else -> 7
    }

    fun minuteFor(id: Int) = when (id) {
        1102 -> 30
        1103 -> 30
        else -> 0
    }
}
