package com.yc.nadalsdk.barys_biotracker

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.text.TextUtils
import com.yc.nadalsdk.bean.MessageInfo
import com.yc.nadalsdk.constants.MessageType

/**
 * Service for forwarding incoming phone calls and app push notifications
 * to the screenless KALKAN (Whoop-style) band, triggering tactical vibration feedback.
 */
class KalkanNotificationListenerService : NotificationListenerService() {

    companion object {
        @Volatile
        private var isListenerBound = false

        fun isConnected(): Boolean = isListenerBound

        fun isNotificationAccessGranted(context: Context): Boolean {
            val pkgName = context.packageName
            val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            if (!TextUtils.isEmpty(flat)) {
                val names = flat.split(":").toTypedArray()
                for (name in names) {
                    val cn = ComponentName.unflattenFromString(name)
                    if (cn != null && TextUtils.equals(pkgName, cn.packageName)) {
                        return true
                    }
                }
            }
            return false
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isListenerBound = true
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isListenerBound = false
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        if (pkg == applicationContext.packageName) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
            ?: ""

        val isCallCategory = notification.category == Notification.CATEGORY_CALL

        // Skip non-call ongoing notifications (e.g. media player, system download bars)
        if (sbn.isOngoing && !isCallCategory) {
            return
        }

        if (title.isEmpty() && text.isEmpty()) {
            return
        }

        // 1. Handle incoming phone calls -> trigger persistent call vibration on Whoop band
        if (isCallCategory) {
            val caller = if (title.isNotEmpty()) title else "Входящий звонок"
            val number = text
            KalkanBleManager.notifyIncomingCall(caller, number)
            return
        }

        // 2. Handle app messages -> trigger haptic buzz on the screenless band
        val msgType = resolveMessageType(pkg)
        val msg = MessageInfo().apply {
            this.appName = getAppName(pkg)
            this.sourcePackage = pkg
            this.title = title
            this.content = text
            this.type = msgType
            this.vibrate = true // Essential for screenless band tactile alert
            this.id = sbn.id and 0xFFFF
        }

        KalkanBleManager.sendMessageToWatch(msg)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn == null) return

        if (sbn.notification?.category == Notification.CATEGORY_CALL) {
            KalkanBleManager.notifyCallEnded()
        }
    }

    private fun resolveMessageType(pkg: String): Int {
        val lower = pkg.lowercase()
        return when {
            lower.contains("telegram") -> MessageType.MESSAGE_TYPE_TELEGRAM
            lower.contains("whatsapp") -> MessageType.MESSAGE_TYPE_WHATSAPP
            lower.contains("viber") || lower.contains("line") -> MessageType.MESSAGE_TYPE_NAVER_LINE
            lower.contains("instagram") -> MessageType.MESSAGE_TYPE_INSTAGRAM
            lower.contains("mms") || lower.contains("sms") || lower.contains("messaging") -> MessageType.MESSAGE_TYPE_SHORT_MESSAGE
            lower.contains("mail") || lower.contains("gmail") || lower.contains("outlook") -> MessageType.MESSAGE_TYPE_EMAIL
            lower.contains("dialer") || lower.contains("telecom") || lower.contains("phone") -> MessageType.MESSAGE_TYPE_INCOMING_CALL
            else -> MessageType.MESSAGE_TYPE_UNKNOWN
        }
    }

    private fun getAppName(pkg: String): String {
        return try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(pkg, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            pkg
        }
    }
}
