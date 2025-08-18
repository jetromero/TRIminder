package com.triminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Boot receiver that automatically starts TRIminder tracking
 * when the device boots up or the app is updated
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "TRIminder_BootReceiver"
        private const val CHANNEL = "triminder.tracking/boot"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Boot receiver triggered: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "🔄 Device boot completed - starting TRIminder tracking")
                startTrackingService(context)
            }
            
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                Log.i(TAG, "📦 App updated - restarting TRIminder tracking")
                startTrackingService(context)
            }
            
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
            }
        }
    }
    
    /**
     * Start the TRIminder background tracking service
     */
    private fun startTrackingService(context: Context) {
        try {
            Log.d(TAG, "🚀 Attempting to start background tracking service")
            
            // Create Flutter engine for background execution
            val flutterEngine = FlutterEngine(context)
            
            // Initialize Dart VM and execute background service
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            // Send message to Flutter to start tracking
            val channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL
            )
            
            channel.invokeMethod("startBackgroundTracking", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.i(TAG, "✅ Background tracking started successfully")
                }
                
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "❌ Failed to start tracking: $errorCode - $errorMessage")
                }
                
                override fun notImplemented() {
                    Log.w(TAG, "⚠️ Background tracking method not implemented")
                }
            })
            
        } catch (e: Exception) {
            Log.e(TAG, "💥 Exception starting tracking service", e)
        }
    }
}
