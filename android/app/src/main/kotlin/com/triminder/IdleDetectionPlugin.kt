package com.triminder

import android.app.KeyguardManager
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class IdleDetectionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "idle_detection")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isDeviceLocked" -> {
        try {
          val km = appContext.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
          val locked = try { km.isDeviceLocked } catch (_: Throwable) { km.isKeyguardLocked }
          result.success(locked)
        } catch (e: Exception) {
          result.error("LOCK_CHECK_ERROR", e.message, null)
        }
      }
      "isDeviceMoving" -> result.success(false)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}