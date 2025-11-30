package com.triminder

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class UsageStatsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: android.content.Context
    private lateinit var usageStatsService: UsageStatsService

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        usageStatsService = UsageStatsService(appContext)
        channel = MethodChannel(binding.binaryMessenger, "usage_stats")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isUsageStatsPermissionGranted" -> {
                try {
                    val granted = usageStatsService.isPermissionGranted()
                    result.success(granted)
                } catch (e: Exception) {
                    result.error("PERMISSION_CHECK_ERROR", e.message, null)
                }
            }
            
            "requestUsageStatsPermission" -> {
                try {
                    val launched = usageStatsService.requestPermission()
                    result.success(launched)
                } catch (e: Exception) {
                    result.error("PERMISSION_REQUEST_ERROR", e.message, null)
                }
            }
            
            "getCurrentForegroundApp" -> {
                try {
                    val packageName = usageStatsService.getCurrentForegroundApp()
                    result.success(packageName)
                } catch (e: Exception) {
                    result.error("FOREGROUND_APP_ERROR", e.message, null)
                }
            }
            
            "queryUsageEvents" -> {
                try {
                    val startTime = call.argument<Long>("startTime") ?: 0L
                    val endTime = call.argument<Long>("endTime") ?: 0L
                    
                    val events = usageStatsService.queryUsageEvents(startTime, endTime)
                    val jsonArray = JSONArray()
                    events.forEach { event ->
                        val jsonObject = JSONObject()
                        jsonObject.put("packageName", event["packageName"])
                        jsonObject.put("eventType", event["eventType"])
                        jsonObject.put("timestamp", event["timestamp"])
                        jsonObject.put("className", event["className"])
                        jsonArray.put(jsonObject)
                    }
                    result.success(jsonArray.toString())
                } catch (e: Exception) {
                    result.error("QUERY_EVENTS_ERROR", e.message, null)
                }
            }
            
            "queryUsageStats" -> {
                try {
                    val intervalType = call.argument<Int>("intervalType") ?: 0
                    val startTime = call.argument<Long>("startTime") ?: 0L
                    val endTime = call.argument<Long>("endTime") ?: 0L
                    
                    val stats = usageStatsService.queryUsageStats(intervalType, startTime, endTime)
                    val jsonObject = JSONObject()
                    stats.forEach { (packageName, usageStats) ->
                        val appStats = JSONObject()
                        appStats.put("packageName", packageName)
                        appStats.put("totalTimeInForeground", usageStats.totalTimeInForeground)
                        appStats.put("lastTimeUsed", usageStats.lastTimeUsed)
                        appStats.put("appName", usageStatsService.getAppName(packageName))
                        jsonObject.put(packageName, appStats)
                    }
                    result.success(jsonObject.toString())
                } catch (e: Exception) {
                    result.error("QUERY_STATS_ERROR", e.message, null)
                }
            }
            
            "getAppUsageForDate" -> {
                try {
                    val dateMillis = call.argument<Long>("dateMillis") ?: 0L
                    val usageMap = usageStatsService.getAppUsageForDate(dateMillis)
                    
                    val jsonObject = JSONObject()
                    usageMap.forEach { (packageName, minutes) ->
                        jsonObject.put(packageName, minutes)
                    }
                    result.success(jsonObject.toString())
                } catch (e: Exception) {
                    result.error("GET_APP_USAGE_ERROR", e.message, null)
                }
            }
            
            "getAppName" -> {
                try {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val appName = usageStatsService.getAppName(packageName)
                    result.success(appName)
                } catch (e: Exception) {
                    result.error("GET_APP_NAME_ERROR", e.message, null)
                }
            }
            
            "getAppIconBase64" -> {
                try {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val iconBase64 = usageStatsService.getAppIconBase64(packageName)
                    result.success(iconBase64)
                } catch (e: Exception) {
                    result.error("GET_APP_ICON_ERROR", e.message, null)
                }
            }
            
            "getTodayUnlockCount" -> {
                try {
                    val count = usageStatsService.getTodayUnlockCount()
                    result.success(count)
                } catch (e: Exception) {
                    result.error("GET_UNLOCK_COUNT_ERROR", e.message, null)
                }
            }
            
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

