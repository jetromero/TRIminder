package com.triminder
import android.app.KeyguardManager
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity


class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure notification channel exists for foreground service notifications
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "triminder_tracking"
            val channelName = "TRIminder Tracking"
            val notificationManager = getSystemService(NotificationManager::class.java)
            val existing = notificationManager.getNotificationChannel(channelId)
            if (existing == null) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_DEFAULT
                )
                channel.description = "Foreground service for automatic screen time tracking"
                notificationManager.createNotificationChannel(channel)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(IdleDetectionPlugin())
    }
}
