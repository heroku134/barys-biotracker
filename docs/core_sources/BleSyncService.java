package com.yc.nadalsdkdemo.services;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import com.yc.nadalsdkdemo.BleDeviceActivity;
import com.yc.nadalsdkdemo.R;

public class BleSyncService extends Service {

    public static final String CHANNEL_ID = "circa_ble_sync_channel";
    public static final int NOTIFICATION_ID = 9041;
    public static final String ACTION_START = "ACTION_START_SYNC";
    public static final String ACTION_STOP = "ACTION_STOP_SYNC";

    private static boolean isRunning = false;

    public static boolean isServiceRunning() {
        return isRunning;
    }

    public static void start(Context context) {
        if (context == null) return;
        Intent intent = new Intent(context, BleSyncService.class);
        intent.setAction(ACTION_START);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    public static void stop(Context context) {
        if (context == null) return;
        Intent intent = new Intent(context, BleSyncService.class);
        intent.setAction(ACTION_STOP);
        context.stopService(intent);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopForeground(true);
            stopSelf();
            isRunning = false;
            return START_NOT_STICKY;
        }

        isRunning = true;
        Notification notification = buildSyncNotification("Пульс: 72 bpm · 8 432 шагов · Связь BLE стабильна");

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }

        com.yc.nadalsdkdemo.widget.CircaGlanceWidget.updateAll(this);

        return START_STICKY;
    }

    private Notification buildSyncNotification(String statusText) {
        Intent notificationIntent = new Intent(this, BleDeviceActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this, 0, notificationIntent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("CIRCA One · Активен")
                .setContentText(statusText)
                .setSmallIcon(R.drawable.ic_watch)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(pendingIntent)
                .build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "CIRCA One Мониторинг в фоне",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Непрерывный сбор данных с браслета CIRCA без экрана");
            channel.setShowBadge(false);

            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        isRunning = false;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
