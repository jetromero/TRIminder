package com.triminder

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.ResolveInfo
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.content.pm.PackageInfo
import android.os.Build
import android.os.UserManager
import android.util.Base64
import android.util.Log
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.concurrent.TimeUnit

class UsageStatsService(private val context: Context) {
    
    private val usageStatsManager: UsageStatsManager? by lazy {
        // Use string literal for API 21+ compatibility
        context.getSystemService("usagestats") as? UsageStatsManager
    }
    
    private val packageManager: PackageManager = context.packageManager
    
    // LauncherApps API for Android 5.0+ (alternative method for app info)
    private val launcherApps: LauncherApps? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            context.getSystemService(Context.LAUNCHER_APPS_SERVICE) as? LauncherApps
        } else {
            null
        }
    }
    
    // Cache for launchable apps (queryIntentActivities result)
    private var cachedLaunchableApps: Map<String, ResolveInfo>? = null
    private var cacheTimestamp: Long = 0
    private val CACHE_DURATION_MS = 60000L // Cache for 1 minute
    
    /**
     * Get cached or fresh list of launchable apps
     */
    private fun getLaunchableApps(): Map<String, ResolveInfo> {
        val now = System.currentTimeMillis()
        if (cachedLaunchableApps != null && (now - cacheTimestamp) < CACHE_DURATION_MS) {
            return cachedLaunchableApps!!
        }
        
        return try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            
            // Query all apps that can be launched (no flags needed - queryIntentActivities doesn't use PackageManager flags)
            val resolveInfoList: List<ResolveInfo> = packageManager.queryIntentActivities(intent, 0)
            val map = resolveInfoList.associateBy { it.activityInfo?.packageName ?: "" }
                .filterKeys { it.isNotEmpty() }
            
            cachedLaunchableApps = map
            cacheTimestamp = now
            Log.w("UsageStatsService", "📦 Cached ${map.size} launchable apps (looking for: ${context.packageName})")
            map
        } catch (e: Exception) {
            Log.e("UsageStatsService", "Error querying launchable apps: ${e.message}")
            emptyMap()
        }
    }
    
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
                    val isYouTube = event.packageName == "com.google.android.youtube"
                    
                    // Filter out system apps and our own app
                    val isSystem = isSystemApp(event.packageName)
                    val isOwnApp = event.packageName == context.packageName
                    
                    if (isYouTube) {
                        Log.w("UsageStatsService", "📱 YouTube event: type=${event.eventType}, isSystem=$isSystem, isOwnApp=$isOwnApp")
                    }
                    
                    if (!isSystem && !isOwnApp) {
                        if (isYouTube) {
                            Log.w("UsageStatsService", "✅ YouTube event: INCLUDED in results")
                        }
                        events.add(mapOf(
                            "packageName" to event.packageName,
                            "eventType" to event.eventType,
                            "timestamp" to event.timeStamp,
                            "className" to (event.className ?: "")
                        ))
                    } else {
                        if (isYouTube) {
                            Log.w("UsageStatsService", "❌ YouTube event: FILTERED OUT (isSystem=$isSystem, isOwnApp=$isOwnApp)")
                        }
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
     * Get per-app usage for a specific date using event-based aggregation
     * This provides accurate usage statistics for exact date ranges, unlike INTERVAL_DAILY
     * which can reset at unexpected times and return incorrect aggregated data.
     * 
     * Returns map of packageName -> usageMinutes
     */
    fun getAppUsageForDate(dateMillis: Long): Map<String, Int> {
        if (!isPermissionGranted()) return emptyMap()
        
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = dateMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis
        
        calendar.add(Calendar.DAY_OF_MONTH, 1)
        val endTime = calendar.timeInMillis
        
        // Query usage events instead of aggregated stats for accurate results
        val events = queryUsageEvents(startTime, endTime)
        
        // Track foreground start time for each app
        val foregroundStartTimes = mutableMapOf<String, Long>()
        // Track total usage time for each app (in milliseconds)
        val appUsageTimes = mutableMapOf<String, Long>()
        
        // Process events chronologically
        val sortedEvents = events.sortedBy { it["timestamp"] as Long }
        
        for (event in sortedEvents) {
            val packageName = event["packageName"] as String
            val eventType = event["eventType"] as Int
            val timestamp = event["timestamp"] as Long
            
            when (eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    // App moved to foreground - record start time
                    foregroundStartTimes[packageName] = timestamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    // App moved to background - calculate duration and add to total
                    val foregroundStart = foregroundStartTimes.remove(packageName)
                    if (foregroundStart != null) {
                        // Calculate duration (clamp to date range boundaries)
                        // If app started before our date range, only count from startTime
                        val actualStart = maxOf(foregroundStart, startTime)
                        // If app ended after our date range, only count until endTime
                        val actualEnd = minOf(timestamp, endTime)
                        val duration = maxOf(0, actualEnd - actualStart)
                        
                        appUsageTimes[packageName] = appUsageTimes.getOrDefault(packageName, 0L) + duration
                    }
                }
            }
        }
        
        // Handle apps still in foreground at end of day
        for ((packageName, foregroundStart) in foregroundStartTimes) {
            // Clamp to date range boundaries
            val actualStart = maxOf(foregroundStart, startTime)
            // Use current time or endTime, whichever is earlier
            val currentTime = System.currentTimeMillis()
            val actualEnd = minOf(currentTime, endTime)
            val duration = maxOf(0, actualEnd - actualStart)
            
            appUsageTimes[packageName] = appUsageTimes.getOrDefault(packageName, 0L) + duration
        }
        
        // Convert milliseconds to minutes and return
        return appUsageTimes.mapValues { (_, millis) ->
            (millis / TimeUnit.MINUTES.toMillis(1)).toInt()
        }
    }
    
    /**
     * Try to get ApplicationInfo using QUERY_ALL_PACKAGES permission (Android 11+)
     * This is the simplest and most reliable method when QUERY_ALL_PACKAGES permission is available
     * Returns ApplicationInfo if successful, null otherwise
     */
    private fun tryGetAppInfoWithQueryAllPackages(packageName: String): ApplicationInfo? {
        // Only works on Android 11+ (API 30+) with QUERY_ALL_PACKAGES permission
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }
        
        return try {
            // With QUERY_ALL_PACKAGES permission, we can use simple flags (0)
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            Log.d("UsageStatsService", "✅ Successfully retrieved ApplicationInfo for $packageName using QUERY_ALL_PACKAGES")
            applicationInfo
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d("UsageStatsService", "Package not found with QUERY_ALL_PACKAGES: $packageName")
            null
        } catch (e: SecurityException) {
            Log.d("UsageStatsService", "Security exception with QUERY_ALL_PACKAGES for $packageName: ${e.message}")
            null
        } catch (e: Exception) {
            Log.d("UsageStatsService", "Exception with QUERY_ALL_PACKAGES for $packageName: ${e.javaClass.simpleName} - ${e.message}")
            null
        }
    }
    
    /**
     * Get app name from package name
     * Uses QUERY_ALL_PACKAGES permission as primary strategy for Android 11+, with fallback strategies for compatibility
     */
    fun getAppName(packageName: String): String {
        Log.w("UsageStatsService", "🔍 Starting app name retrieval for: $packageName")
        
        // PRIORITY: Strategy 1 - Try QUERY_ALL_PACKAGES first (Android 11+)
        // This is the simplest and most reliable method when the permission is available
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val appInfo = tryGetAppInfoWithQueryAllPackages(packageName)
            if (appInfo != null) {
                try {
                    val appLabel = packageManager.getApplicationLabel(appInfo)
                    if (appLabel != null && appLabel.toString().isNotEmpty() && appLabel.toString() != packageName) {
                        Log.w("UsageStatsService", "✅ SUCCESS: Retrieved app name for $packageName using QUERY_ALL_PACKAGES: ${appLabel.toString()}")
                        return appLabel.toString()
                    }
                } catch (e: Exception) {
                    Log.d("UsageStatsService", "Failed to get label from ApplicationInfo: ${e.message}")
                }
            }
            Log.w("UsageStatsService", "❌ Strategy 1 (QUERY_ALL_PACKAGES) failed for $packageName, trying fallbacks...")
        }
        
        // Fallback strategies for Android 10 and below, or if QUERY_ALL_PACKAGES failed
        // Strategy 2: Try queryIntentActivities (bypasses package visibility restrictions)
        var result = tryGetAppNameViaQueryIntent(packageName)
        if (result != null && result != packageName && result.isNotEmpty()) {
            Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using QueryIntent: $result")
            return result
        }
        
        // Strategy 3: Try using resolveActivity with MAIN/LAUNCHER intent
        result = tryGetAppNameViaIntent(packageName)
        if (result != null && result != packageName && result.isNotEmpty()) {
            Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using Intent: $result")
            return result
        }
        
        // Strategy 4: Try with version-specific flags
        result = tryGetAppNameWithFlags(packageName, getVersionSpecificFlags())
        if (result != null && result != packageName && result.isNotEmpty()) {
            Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using version-specific flags: $result")
            return result
        }
        
        // Strategy 5: Try with MATCH_ANY_USER flag (Android 11+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            result = tryGetAppNameWithFlags(packageName, 0x00200000) // MATCH_ANY_USER
            if (result != null && result != packageName && result.isNotEmpty()) {
                Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using MATCH_ANY_USER: $result")
                return result
            }
        }
        
        // Strategy 6: Try with MATCH_UNINSTALLED_PACKAGES flag (Android 6.0-10)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            try {
                @Suppress("DEPRECATION")
                val flags = PackageManager.MATCH_UNINSTALLED_PACKAGES
                result = tryGetAppNameWithFlags(packageName, flags)
                if (result != null && result != packageName && result.isNotEmpty()) {
                    Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using MATCH_UNINSTALLED_PACKAGES: $result")
                    return result
                }
            } catch (e: Exception) {
                Log.w("UsageStatsService", "Failed to get app name with MATCH_UNINSTALLED_PACKAGES: ${e.message}")
            }
        }
        
        // Strategy 7: Try with default flags (no special flags)
        result = tryGetAppNameWithFlags(packageName, 0)
        if (result != null && result != packageName && result.isNotEmpty()) {
            Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using default flags: $result")
            return result
        }
        
        // Strategy 8: Try using getPackageInfo as alternative approach
        result = tryGetAppNameViaPackageInfo(packageName)
        if (result != null && result != packageName && result.isNotEmpty()) {
            Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using PackageInfo: $result")
            return result
        }
        
        // Strategy 9: Try using GET_META_DATA flag
        result = tryGetAppNameAlternative(packageName)
        if (result != null && result != packageName && result.isNotEmpty()) {
            Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using alternative method: $result")
            return result
        }
        
        // Strategy 10: Try using LauncherApps API (Android 5.0+)
        result = tryGetAppNameViaLauncherApps(packageName)
        if (result != null && result != packageName && result.isNotEmpty()) {
            Log.d("UsageStatsService", "✅ Successfully retrieved app name for $packageName using LauncherApps: $result")
            return result
        }
        
        Log.e("UsageStatsService", "❌❌❌ ALL STRATEGIES FAILED for $packageName - returning package name as fallback")
        return packageName
    }
    
    /**
     * Try to get app name using specific flags
     */
    private fun tryGetAppNameWithFlags(packageName: String, flags: Int): String? {
        return try {
            val applicationInfo: ApplicationInfo = packageManager.getApplicationInfo(packageName, flags)
            val appLabel = packageManager.getApplicationLabel(applicationInfo)
            
            if (appLabel == null || appLabel.toString().isEmpty() || appLabel.toString() == packageName) {
                Log.d("UsageStatsService", "App label invalid for $packageName: label=$appLabel")
                return null
            }
            
            val labelStr = appLabel.toString()
            Log.d("UsageStatsService", "Successfully got app name for $packageName: $labelStr (flags=0x${flags.toString(16)})")
            return labelStr
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d("UsageStatsService", "Package not found: $packageName (flags=0x${flags.toString(16)})")
            null // Package not found, try next strategy
        } catch (e: SecurityException) {
            Log.d("UsageStatsService", "Security exception for $packageName (flags=0x${flags.toString(16)}): ${e.message}")
            null // Security restriction, try next strategy
        } catch (e: Exception) {
            Log.d("UsageStatsService", "Exception getting app name for $packageName (flags=0x${flags.toString(16)}): ${e.javaClass.simpleName} - ${e.message}")
            null // Other error, try next strategy
        }
    }
    
    /**
     * Try to get app name using PackageInfo (alternative approach)
     */
    private fun tryGetAppNameViaPackageInfo(packageName: String): String? {
        return try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                0x00200000 // MATCH_ANY_USER
            } else {
                0
            }
            
            val packageInfo: PackageInfo = packageManager.getPackageInfo(packageName, flags)
            val applicationInfo = packageInfo.applicationInfo
            
            // Check if applicationInfo is null
            if (applicationInfo == null) {
                return null
            }
            
            val appLabel = packageManager.getApplicationLabel(applicationInfo)
            
            if (appLabel == null || appLabel.toString().isEmpty() || appLabel.toString() == packageName) {
                return null
            }
            
            appLabel.toString()
        } catch (e: Exception) {
            null // Failed, return null
        }
    }
    
    /**
     * Try alternative methods to get app name
     */
    private fun tryGetAppNameAlternative(packageName: String): String? {
        return try {
            // Try with GET_META_DATA flag combined with version-specific flags
            val flags = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                    // Android 11+: Combine MATCH_ANY_USER with GET_META_DATA
                    0x00200000 or PackageManager.GET_META_DATA // MATCH_ANY_USER | GET_META_DATA
                }
                else -> {
                    // Older versions: Use GET_META_DATA
                    PackageManager.GET_META_DATA
                }
            }
            
            val applicationInfo: ApplicationInfo = packageManager.getApplicationInfo(packageName, flags)
            val appLabel = packageManager.getApplicationLabel(applicationInfo)
            
            if (appLabel == null || appLabel.toString().isEmpty() || appLabel.toString() == packageName) {
                return null
            }
            
            appLabel.toString()
        } catch (e: Exception) {
            null // Failed, return null
        }
    }
    
    /**
     * Try to get app name using LauncherApps API (Android 5.0+)
     * This is an alternative method that might work better on some devices
     */
    private fun tryGetAppNameViaLauncherApps(packageName: String): String? {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP || launcherApps == null) {
                return null
            }
            
            // Get application info first
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                0x00200000 // MATCH_ANY_USER
            } else {
                0
            }
            
            val applicationInfo: ApplicationInfo = packageManager.getApplicationInfo(packageName, flags)
            val appLabel = packageManager.getApplicationLabel(applicationInfo)
            
            if (appLabel == null || appLabel.toString().isEmpty() || appLabel.toString() == packageName) {
                return null
            }
            
            appLabel.toString()
        } catch (e: Exception) {
            null // Failed, return null
        }
    }
    
    /**
     * Try to get app name using resolveActivity with MAIN/LAUNCHER intent
     * This method can sometimes bypass package visibility restrictions
     */
    private fun tryGetAppNameViaIntent(packageName: String): String? {
        return try {
            // Create intent for main launcher activity
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent == null) {
                Log.d("UsageStatsService", "No launch intent found for $packageName")
                return null
            }
            
            // Resolve the activity
            val resolveInfo: ResolveInfo? = packageManager.resolveActivity(intent, 0)
            if (resolveInfo == null || resolveInfo.activityInfo == null) {
                Log.d("UsageStatsService", "Could not resolve activity for $packageName")
                return null
            }
            
            // Get application info from resolved activity
            val applicationInfo = resolveInfo.activityInfo.applicationInfo
            val appLabel = packageManager.getApplicationLabel(applicationInfo)
            
            if (appLabel == null || appLabel.toString().isEmpty() || appLabel.toString() == packageName) {
                return null
            }
            
            appLabel.toString()
        } catch (e: Exception) {
            Log.d("UsageStatsService", "Exception in tryGetAppNameViaIntent for $packageName: ${e.javaClass.simpleName} - ${e.message}")
            null // Failed, return null
        }
    }
    
    /**
     * Try to get app name by querying all launchable apps
     * This queries by intent filter, which bypasses package visibility restrictions
     */
    private fun tryGetAppNameViaQueryIntent(packageName: String): String? {
        return try {
            // Use cached launchable apps for better performance
            val launchableApps = getLaunchableApps()
            val resolveInfo = launchableApps[packageName]
            
            if (resolveInfo != null && resolveInfo.activityInfo != null) {
                val applicationInfo = resolveInfo.activityInfo.applicationInfo
                val appLabel = packageManager.getApplicationLabel(applicationInfo)
                
            if (appLabel != null && appLabel.toString().isNotEmpty() && appLabel.toString() != packageName) {
                Log.w("UsageStatsService", "✅ Found app name via queryIntent: $packageName -> ${appLabel.toString()}")
                return appLabel.toString()
            } else {
                Log.w("UsageStatsService", "⚠️ App label invalid: package=$packageName, label=$appLabel")
            }
        } else {
            Log.w("UsageStatsService", "❌ Package $packageName NOT FOUND in launchable apps cache (${launchableApps.size} apps cached)")
        }
            
            null
        } catch (e: Exception) {
            Log.e("UsageStatsService", "Exception in tryGetAppNameViaQueryIntent for $packageName: ${e.javaClass.simpleName} - ${e.message}")
            null // Failed, return null
        }
    }
    
    /**
     * Get app icon as base64 encoded PNG
     * Returns null if icon cannot be retrieved
     * Uses QUERY_ALL_PACKAGES permission as primary strategy for Android 11+, with fallback strategies for compatibility
     */
    fun getAppIconBase64(packageName: String): String? {
        Log.w("UsageStatsService", "🖼️ Starting icon retrieval for: $packageName")
        
        // PRIORITY: Strategy 1 - Try QUERY_ALL_PACKAGES first (Android 11+)
        // This is the simplest and most reliable method when the permission is available
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val appInfo = tryGetAppInfoWithQueryAllPackages(packageName)
            if (appInfo != null) {
                try {
                    val drawable = packageManager.getApplicationIcon(appInfo)
                    if (drawable != null) {
                        val result = convertDrawableToBase64(drawable, packageName)
                        if (result != null) {
                            Log.w("UsageStatsService", "✅ SUCCESS: Retrieved icon for $packageName using QUERY_ALL_PACKAGES")
                            return result
                        }
                    }
                } catch (e: Exception) {
                    Log.d("UsageStatsService", "Failed to get icon from ApplicationInfo: ${e.message}")
                }
            }
            Log.w("UsageStatsService", "❌ Strategy 1 (QUERY_ALL_PACKAGES) failed for icon: $packageName, trying fallbacks...")
        }
        
        // Fallback strategies for Android 10 and below, or if QUERY_ALL_PACKAGES failed
        // Strategy 2: Try queryIntentActivities (bypasses package visibility restrictions)
        var result = tryGetIconViaQueryIntent(packageName)
        if (result != null) {
            Log.d("UsageStatsService", "✅ Successfully retrieved icon for $packageName using QueryIntent")
            return result
        }
        
        // Strategy 3: Try using resolveActivity with MAIN/LAUNCHER intent
        result = tryGetIconViaIntent(packageName)
        if (result != null) {
            Log.d("UsageStatsService", "✅ Successfully retrieved icon for $packageName using Intent")
            return result
        }
        
        // Strategy 4: Try with version-specific flags (Android 11+)
        result = tryGetIconWithFlags(packageName, getVersionSpecificFlags())
        if (result != null) {
            Log.d("UsageStatsService", "✅ Successfully retrieved icon for $packageName using version-specific flags")
            return result
        }
        
        // Strategy 5: Try with MATCH_ANY_USER flag (Android 11+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            result = tryGetIconWithFlags(packageName, 0x00200000) // MATCH_ANY_USER
            if (result != null) {
                Log.d("UsageStatsService", "✅ Successfully retrieved icon for $packageName using MATCH_ANY_USER")
                return result
            }
        }
        
        // Strategy 6: Try with MATCH_UNINSTALLED_PACKAGES flag (Android 6.0-10)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            try {
                @Suppress("DEPRECATION")
                val flags = PackageManager.MATCH_UNINSTALLED_PACKAGES
                result = tryGetIconWithFlags(packageName, flags)
                if (result != null) {
                    Log.d("UsageStatsService", "✅ Successfully retrieved icon for $packageName using MATCH_UNINSTALLED_PACKAGES")
                    return result
                }
            } catch (e: Exception) {
                Log.w("UsageStatsService", "Failed to get icon with MATCH_UNINSTALLED_PACKAGES: ${e.message}")
            }
        }
        
        // Strategy 7: Try with default flags (no special flags)
        result = tryGetIconWithFlags(packageName, 0)
        if (result != null) {
            Log.d("UsageStatsService", "✅ Successfully retrieved icon for $packageName using default flags")
            return result
        }
        
        // Strategy 8: Try using getPackageInfo as alternative approach
        result = tryGetIconViaPackageInfo(packageName)
        if (result != null) {
            Log.d("UsageStatsService", "✅ Successfully retrieved icon for $packageName using PackageInfo")
            return result
        }
        
        Log.e("UsageStatsService", "❌❌❌ ALL STRATEGIES FAILED for icon: $packageName - returning null")
        return null
    }
    
    /**
     * Get version-specific flags for package queries
     */
    private fun getVersionSpecificFlags(): Int {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                // Android 11+ (API 30+): Use MATCH_ANY_USER
                0x00200000 // PackageManager.MATCH_ANY_USER
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                // Android 6.0-10 (API 23-29): Use MATCH_UNINSTALLED_PACKAGES
                @Suppress("DEPRECATION")
                PackageManager.MATCH_UNINSTALLED_PACKAGES
            }
            else -> {
                // Older versions: Use default flags
                0
            }
        }
    }
    
    /**
     * Try to get icon using specific flags
     */
    private fun tryGetIconWithFlags(packageName: String, flags: Int): String? {
        return try {
            val applicationInfo = packageManager.getApplicationInfo(packageName, flags)
            val drawable = packageManager.getApplicationIcon(applicationInfo)
            
            if (drawable == null) {
                Log.d("UsageStatsService", "Drawable is null for $packageName (flags=0x${flags.toString(16)})")
                return null
            }
            
            val result = convertDrawableToBase64(drawable, packageName)
            if (result != null) {
                Log.d("UsageStatsService", "Successfully got icon for $packageName (flags=0x${flags.toString(16)})")
            }
            return result
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d("UsageStatsService", "Package not found when getting icon: $packageName (flags=0x${flags.toString(16)})")
            null // Package not found, try next strategy
        } catch (e: SecurityException) {
            Log.d("UsageStatsService", "Security exception getting icon for $packageName (flags=0x${flags.toString(16)}): ${e.message}")
            null // Security restriction, try next strategy
        } catch (e: Exception) {
            Log.d("UsageStatsService", "Exception getting icon for $packageName (flags=0x${flags.toString(16)}): ${e.javaClass.simpleName} - ${e.message}")
            null // Other error, try next strategy
        }
    }
    
    /**
     * Try to get icon using PackageInfo (alternative approach)
     */
    private fun tryGetIconViaPackageInfo(packageName: String): String? {
        return try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                0x00200000 // MATCH_ANY_USER
            } else {
                0
            }
            
            val packageInfo: PackageInfo = packageManager.getPackageInfo(packageName, flags)
            val applicationInfo = packageInfo.applicationInfo
            
            // Check if applicationInfo is null
            if (applicationInfo == null) {
                return null
            }
            
            val drawable = packageManager.getApplicationIcon(applicationInfo)
            
            if (drawable == null) {
                return null
            }
            
            convertDrawableToBase64(drawable, packageName)
        } catch (e: Exception) {
            null // Failed, return null
        }
    }
    
    /**
     * Try to get icon using resolveActivity with MAIN/LAUNCHER intent
     * This method can sometimes bypass package visibility restrictions
     */
    private fun tryGetIconViaIntent(packageName: String): String? {
        return try {
            // Create intent for main launcher activity
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent == null) {
                Log.d("UsageStatsService", "No launch intent found for icon: $packageName")
                return null
            }
            
            // Resolve the activity
            val resolveInfo: ResolveInfo? = packageManager.resolveActivity(intent, 0)
            if (resolveInfo == null || resolveInfo.activityInfo == null) {
                Log.d("UsageStatsService", "Could not resolve activity for icon: $packageName")
                return null
            }
            
            // Get application info from resolved activity
            val applicationInfo = resolveInfo.activityInfo.applicationInfo
            val drawable = packageManager.getApplicationIcon(applicationInfo)
            
            if (drawable == null) {
                return null
            }
            
            convertDrawableToBase64(drawable, packageName)
        } catch (e: Exception) {
            Log.d("UsageStatsService", "Exception in tryGetIconViaIntent for $packageName: ${e.javaClass.simpleName} - ${e.message}")
            null // Failed, return null
        }
    }
    
    /**
     * Try to get icon by querying all launchable apps
     * This queries by intent filter, which bypasses package visibility restrictions
     */
    private fun tryGetIconViaQueryIntent(packageName: String): String? {
        return try {
            // Use cached launchable apps for better performance
            val launchableApps = getLaunchableApps()
            val resolveInfo = launchableApps[packageName]
            
            if (resolveInfo != null && resolveInfo.activityInfo != null) {
                val applicationInfo = resolveInfo.activityInfo.applicationInfo
                val drawable = packageManager.getApplicationIcon(applicationInfo)
                
                if (drawable != null) {
                    Log.d("UsageStatsService", "Found app icon via queryIntent: $packageName")
                    return convertDrawableToBase64(drawable, packageName)
                }
            } else {
                Log.d("UsageStatsService", "Package $packageName not found in launchable apps cache for icon")
            }
            
            null
        } catch (e: Exception) {
            Log.e("UsageStatsService", "Exception in tryGetIconViaQueryIntent for $packageName: ${e.javaClass.simpleName} - ${e.message}")
            null // Failed, return null
        }
    }
    
    /**
     * Convert drawable to base64 string
     */
    private fun convertDrawableToBase64(drawable: Drawable, packageName: String): String? {
        return try {
            val bitmap = drawableToBitmap(drawable)
            
            if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0) {
                Log.w("UsageStatsService", "Invalid bitmap dimensions for package: $packageName")
                return null
            }
            
            val outputStream = ByteArrayOutputStream()
            val compressed = bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            
            if (!compressed) {
                Log.w("UsageStatsService", "Failed to compress bitmap for package: $packageName")
                return null
            }
            
            val byteArray = outputStream.toByteArray()
            
            if (byteArray.isEmpty()) {
                Log.w("UsageStatsService", "Empty byte array for package: $packageName")
                return null
            }
            
            Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: OutOfMemoryError) {
            Log.e("UsageStatsService", "Out of memory converting drawable for $packageName: ${e.message}")
            null
        } catch (e: Exception) {
            Log.e("UsageStatsService", "Error converting drawable to base64 for $packageName: ${e.javaClass.simpleName} - ${e.message}")
            null
        }
    }
    
    /**
     * Convert Drawable to Bitmap
     * Enhanced with dimension validation and fallback size handling
     */
    private fun drawableToBitmap(drawable: Drawable): Bitmap? {
        if (drawable == null) {
            Log.w("UsageStatsService", "Drawable is null in drawableToBitmap")
            return null
        }
        
        // If drawable is already a BitmapDrawable with a valid bitmap, return it directly
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        
        // Get intrinsic dimensions
        var width = drawable.intrinsicWidth
        var height = drawable.intrinsicHeight
        
        // Handle zero or negative dimensions with fallback size (48dp equivalent in pixels)
        // Convert dp to pixels: 48dp * density = pixels
        val fallbackSizePx = (48 * context.resources.displayMetrics.density).toInt()
        
        if (width <= 0) {
            width = fallbackSizePx
            Log.d("UsageStatsService", "Drawable width is invalid, using fallback: $fallbackSizePx")
        }
        
        if (height <= 0) {
            height = fallbackSizePx
            Log.d("UsageStatsService", "Drawable height is invalid, using fallback: $fallbackSizePx")
        }
        
        return try {
            // Create bitmap with validated dimensions
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            
            // Create canvas and draw drawable onto it
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            
            bitmap
        } catch (e: OutOfMemoryError) {
            Log.e("UsageStatsService", "Out of memory creating bitmap: ${e.message}")
            null
        } catch (e: IllegalArgumentException) {
            Log.e("UsageStatsService", "Invalid argument creating bitmap: ${e.message}")
            null
        } catch (e: Exception) {
            Log.e("UsageStatsService", "Error converting drawable to bitmap: ${e.javaClass.simpleName} - ${e.message}")
            null
        }
    }
    
    /**
     * Check if an app is a system app
     * Uses version-specific flags and fallback to handle package visibility restrictions on Android 11+
     * 
     * Only filters out true system apps (like Settings, Phone dialer), not pre-installed user apps
     * (like YouTube, Gmail) which should be tracked in app usage statistics.
     */
    private fun isSystemApp(packageName: String): Boolean {
        // Debug logging for YouTube specifically
        val isYouTube = packageName == "com.google.android.youtube"
        
        return try {
            // Try with version-specific flags first (more reliable on Android 11+)
            val flags = getVersionSpecificFlags()
            val applicationInfo = packageManager.getApplicationInfo(packageName, flags)
            
            val isSystemFlag = (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isUpdatedSystemApp = (applicationInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            
            if (isYouTube) {
                Log.w("UsageStatsService", "🔍 YouTube check: isSystemFlag=$isSystemFlag, isUpdatedSystemApp=$isUpdatedSystemApp")
            }
            
            // If it's an updated system app, treat it as a user app (don't filter)
            if (isUpdatedSystemApp) {
                if (isYouTube) {
                    Log.w("UsageStatsService", "✅ YouTube: Updated system app - NOT filtering (allowing)")
                }
                return false
            }
            
            // Check if app is launchable (has MAIN/LAUNCHER intent)
            // Launchable apps are user-facing and should be tracked
            val launchableApps = getLaunchableApps()
            if (launchableApps.containsKey(packageName)) {
                // App is launchable, so it's a user app - don't filter
                if (isYouTube) {
                    Log.w("UsageStatsService", "✅ YouTube: Launchable app - NOT filtering (allowing)")
                }
                return false
            }
            
            if (isYouTube) {
                Log.w("UsageStatsService", "⚠️ YouTube: isSystemFlag=$isSystemFlag, launchable=${launchableApps.containsKey(packageName)}")
            }
            
            // Only filter if it's a true system app (not updated, not launchable)
            val result = isSystemFlag
            if (isYouTube) {
                Log.w("UsageStatsService", "📊 YouTube isSystemApp result: $result")
            }
            result
        } catch (e: SecurityException) {
            // Security exception on Android 11+ - use fallback method (same as getAppName/getAppIconBase64)
            val isYouTube = packageName == "com.google.android.youtube"
            if (isYouTube) {
                Log.w("UsageStatsService", "⚠️ YouTube: SecurityException, using fallback method")
            }
            try {
                val launchableApps = getLaunchableApps()
                val resolveInfo = launchableApps[packageName]
                if (resolveInfo != null && resolveInfo.activityInfo != null) {
                    val applicationInfo = resolveInfo.activityInfo.applicationInfo
                    val isSystemFlag = (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                    val isUpdatedSystemApp = (applicationInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                    
                    if (isYouTube) {
                        Log.w("UsageStatsService", "🔍 YouTube fallback: isSystemFlag=$isSystemFlag, isUpdatedSystemApp=$isUpdatedSystemApp, launchable=${launchableApps.containsKey(packageName)}")
                    }
                    
                    // Don't filter updated system apps or launchable apps
                    if (isUpdatedSystemApp || launchableApps.containsKey(packageName)) {
                        if (isYouTube) {
                            Log.w("UsageStatsService", "✅ YouTube fallback: NOT filtering (allowing)")
                        }
                        return false
                    }
                    
                    val result = isSystemFlag
                    if (isYouTube) {
                        Log.w("UsageStatsService", "📊 YouTube fallback isSystemApp result: $result")
                    }
                    return result
                } else {
                    // Can't determine - assume not a system app to avoid filtering out user apps
                    if (isYouTube) {
                        Log.w("UsageStatsService", "✅ YouTube fallback: Can't determine - NOT filtering (allowing)")
                    }
                    false
                }
            } catch (_: Exception) {
                // If fallback fails, assume not a system app
                if (isYouTube) {
                    Log.w("UsageStatsService", "✅ YouTube fallback: Exception - NOT filtering (allowing)")
                }
                false
            }
        } catch (e: Exception) {
            // Other exceptions - assume not a system app
            val isYouTube = packageName == "com.google.android.youtube"
            if (isYouTube) {
                Log.w("UsageStatsService", "✅ YouTube: Exception ($e) - NOT filtering (allowing)")
            }
            false
        }
    }
}

