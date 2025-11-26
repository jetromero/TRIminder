package com.triminder

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.UserManager
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.concurrent.TimeUnit

class UsageStatsService(private val context: Context) {
    
    private val usageStatsManager: UsageStatsManager? by lazy {
        // Use string literal for API 21+ compatibility
        context.getSystemService("usagestats") as? UsageStatsManager
    }
    
    private val packageManager: PackageManager = context.packageManager
    
    /**
     * Check if PACKAGE_USAGE_STATS permission is granted
     */
    fun isPermissionGranted(): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            val mode = appOps?.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Launch settings intent to request USAGE_STATS permission
     */
    fun requestPermission(): Boolean {
        return try {
            val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Check if device is unlocked (required for Android 11+)
     */
    private fun isDeviceUnlocked(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val userManager = context.getSystemService(Context.USER_SERVICE) as? UserManager
            userManager?.isUserUnlocked ?: true
        } else {
            true
        }
    }
    
    /**
     * Get currently running foreground app package name
     */
    fun getCurrentForegroundApp(): String? {
        if (!isPermissionGranted()) return null
        
        val usageStatsManager = usageStatsManager ?: return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !isDeviceUnlocked()) {
            return null
        }
        
        return try {
            val time = System.currentTimeMillis()
            val events = usageStatsManager.queryEvents(time - TimeUnit.MINUTES.toMillis(1), time)
            
            var lastEvent: UsageEvents.Event? = null
            while (events.hasNextEvent()) {
                val event = UsageEvents.Event()
                if (events.getNextEvent(event)) {
                    if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                        event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                        lastEvent = event
                    }
                }
            }
            
            lastEvent?.packageName
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Query UsageEvents for a time range
     * Returns list of app usage events
     */
    fun queryUsageEvents(startTime: Long, endTime: Long): List<Map<String, Any>> {
        if (!isPermissionGranted()) return emptyList()
        
        val usageStatsManager = usageStatsManager ?: return emptyList()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !isDeviceUnlocked()) {
            return emptyList()
        }
        
        val events = mutableListOf<Map<String, Any>>()
        
        return try {
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            
            while (usageEvents.hasNextEvent()) {
                val event = UsageEvents.Event()
                if (usageEvents.getNextEvent(event)) {
                    // Filter out system apps and our own app
                    if (!isSystemApp(event.packageName) && 
                        event.packageName != context.packageName) {
                        events.add(mapOf(
                            "packageName" to event.packageName,
                            "eventType" to event.eventType,
                            "timestamp" to event.timeStamp,
                            "className" to (event.className ?: "")
                        ))
                    }
                }
            }
            
            events
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    /**
     * Query aggregated usage stats for a time range
     */
    fun queryUsageStats(intervalType: Int, startTime: Long, endTime: Long): Map<String, UsageStats> {
        if (!isPermissionGranted()) return emptyMap()
        
        val usageStatsManager = usageStatsManager ?: return emptyMap()
        
        return try {
            val stats = usageStatsManager.queryUsageStats(intervalType, startTime, endTime)
            stats?.associateBy { it.packageName }?.filterKeys { 
                !isSystemApp(it) && it != context.packageName 
            } ?: emptyMap()
        } catch (e: Exception) {
            emptyMap()
        }
    }
    
    /**
     * Get per-app usage for a specific date
     * Returns map of packageName -> usageMinutes
     */
    fun getAppUsageForDate(dateMillis: Long): Map<String, Int> {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = dateMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis
        
        calendar.add(Calendar.DAY_OF_MONTH, 1)
        val endTime = calendar.timeInMillis
        
        val stats = queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        
        return stats.mapValues { (_, usageStats) ->
            (usageStats.totalTimeInForeground / TimeUnit.MINUTES.toMillis(1)).toInt()
        }
    }
    
    /**
     * Get app name from package name
     */
    fun getAppName(packageName: String): String {
        return try {
            val applicationInfo: ApplicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
    
    /**
     * Get app icon as base64 encoded PNG
     * Returns null if icon cannot be retrieved
     */
    fun getAppIconBase64(packageName: String): String? {
        return try {
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            val drawable = packageManager.getApplicationIcon(applicationInfo)
            val bitmap = drawableToBitmap(drawable)
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val byteArray = outputStream.toByteArray()
            Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Convert Drawable to Bitmap
     */
    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth.coerceAtLeast(1),
            drawable.intrinsicHeight.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
    
    /**
     * Check if an app is a system app
     */
    private fun isSystemApp(packageName: String): Boolean {
        return try {
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (e: Exception) {
            false
        }
    }
}

