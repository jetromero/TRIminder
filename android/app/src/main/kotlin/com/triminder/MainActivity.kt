package com.triminder
import android.app.KeyguardManager
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity


class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure notification channel exists for foreground service notifications
        // Attempting IMPORTANCE_NONE to hide notification completely (may not work on all devices)
        // Android requires foreground services to show notifications, but IMPORTANCE_NONE might hide it
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "triminder_tracking"
            val channelName = "TRIminder Tracking"
            val notificationManager = getSystemService(NotificationManager::class.java)
            val existing = notificationManager.getNotificationChannel(channelId)
            if (existing == null) {
                // Try IMPORTANCE_NONE - this might completely hide the notification on some devices
                // Note: This is experimental and may not work on all Android versions/devices
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_NONE  // Attempt to hide completely (experimental)
                )
                channel.description = "Foreground service for automatic screen time tracking"
                channel.enableVibration(false)  // No vibration
                channel.setSound(null, null)  // No sound
                channel.setShowBadge(false)  // No badge
                // Set lockscreen visibility to hide from lock screen
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    channel.setLockscreenVisibility(android.app.Notification.VISIBILITY_SECRET)
                }
                notificationManager.createNotificationChannel(channel)
            } else {
                // Update existing channel to ensure it's minimal and silent
                existing.enableVibration(false)
                existing.setSound(null, null)
                existing.setShowBadge(false)
                // Note: Can't change importance of existing channel, user would need to uninstall/reinstall
                // For existing users: Delete the channel manually in Settings → Apps → TRIminder → Notifications
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(IdleDetectionPlugin())
        flutterEngine.plugins.add(UsageStatsPlugin())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.triminder/settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppDetailsSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openUnusedAppsList" -> {
                    // Best-effort: open Special app access or App info as a fallback
                    try {
                        val intent = Intent("android.settings.MANAGE_UNUSED_APPS")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent("android.settings.APPLICATION_SETTINGS")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        // Open battery optimization settings page directly
                        val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fallback to app details settings if battery optimization intent fails
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
