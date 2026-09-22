package com.yc.nadalsdk.barys_biotracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.Calendar

class KalkanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) return
        val id = intent.getIntExtra(KalkanNotify.EXTRA_ID, 1101)
        val title = intent.getStringExtra(KalkanNotify.EXTRA_TITLE) ?: "KALKAN"
        val body = intent.getStringExtra(KalkanNotify.EXTRA_BODY) ?: ""
        KalkanNotify.show(context, id, title, body)
        val hour = if (id == 1102) 21 else 7
        val minute = if (id == 1102) 30 else 0
        KalkanNotify.scheduleDaily(context, id, hour, minute, title, body)
    }
}
