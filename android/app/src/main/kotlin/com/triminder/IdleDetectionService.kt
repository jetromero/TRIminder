package com.triminder

import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class IdleDetectionService : Service(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var lastMotionTime: Long = 0
    private var methodChannel: MethodChannel? = null
    
    companion object {
        private const val TAG = "IdleDetectionService"
        private const val MOTION_THRESHOLD = 1.5f
        private const val MOTION_TIMEOUT = 15000L // 15 seconds
    }
    
    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        
        // Start motion detection
        accelerometer?.let { sensor ->
            sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }

        
        
        Log.d(TAG, "IdleDetectionService created")
    }
    
    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            
            // Calculate movement magnitude
            val movement = kotlin.math.sqrt((x * x + y * y + z * z).toDouble()).toFloat()
            
            if (movement > MOTION_THRESHOLD) {
                lastMotionTime = System.currentTimeMillis()
                Log.d(TAG, "Significant motion detected: $movement")
            }
        }
    }
    
    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
    
    fun isDeviceMoving(): Boolean {
        val timeSinceLastMotion = System.currentTimeMillis() - lastMotionTime
        return timeSinceLastMotion < MOTION_TIMEOUT
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        sensorManager?.unregisterListener(this)
        Log.d(TAG, "IdleDetectionService destroyed")
    }
}