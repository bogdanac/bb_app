package com.bb.bb_app

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.AudioManager
import android.content.Context

class MainActivity: FlutterActivity() {
    private val CHANNEL = "notification_listener"
    private val WATER_CHANNEL = "com.bb.bb_app/water_widget"
    private val TASK_CHANNEL = "com.bb.bb_app/task_widget"
    private val ROUTINE_CHANNEL = "com.bb.bb_app/routine_widget"
    
    companion object {
        var instance: MainActivity? = null
    }
    
    private var originalAlarmVolume: Int = -1
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        
        // Create separate method channels for different purposes
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Existing notification listener channel for receiving calls from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "requestPermission" -> {
                    requestNotificationListenerPermission()
                    result.success(null)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "setMaxAlarmVolume" -> {
                    setMaximumAlarmVolume()
                    result.success(null)
                }
                "restoreAlarmVolume" -> {
                    restoreOriginalAlarmVolume()
                    result.success(null)
                }
                "testMethodChannel" -> {
                    android.util.Log.d("MainActivity", "Test method channel called from Flutter")
                    result.success("Method channel is working!")
                }
                "showSystemAlert" -> {
                    val title = call.argument<String>("title") ?: "Alert"
                    val message = call.argument<String>("message") ?: "System Alert"
                    android.util.Log.d("MainActivity", "System alert: $title - $message")
                    result.success(null)
                }
                "vibrateLong" -> {
                    try {
                        val vibrator = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                            vibratorManager.defaultVibrator
                        } else {
                            @Suppress("DEPRECATION")
                            getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                        }
                        
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            vibrator.vibrate(android.os.VibrationEffect.createOneShot(1000, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator.vibrate(1000)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error vibrating: $e")
                        result.error("VIBRATION_ERROR", "Failed to vibrate", e.toString())
                    }
                }
                "initialize" -> {
                    android.util.Log.d("MainActivity", "NotificationListener service initialized via Flutter")
                    result.success("Initialized")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Water widget synchronization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WATER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncWaterData" -> {
                    val intake = call.argument<Int>("intake") ?: 0
                    val date = call.argument<String>("date") ?: ""
                    syncWaterWithWidget(intake, date)
                    result.success(true)
                }
                "getWaterFromWidget" -> {
                    val date = call.argument<String>("date") ?: ""
                    val intake = getWaterFromWidget(date)
                    result.success(intake)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Task widget channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkWidgetIntent" -> {
                    val hasWidgetIntent = intent?.getBooleanExtra("widget_trigger", false) ?: false
                    // Clear the flag after checking to prevent multiple triggers
                    if (hasWidgetIntent) {
                        intent?.removeExtra("widget_trigger")
                    }
                    result.success(hasWidgetIntent)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Routine widget channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROUTINE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateRoutineWidget" -> {
                    updateRoutineWidget()
                    result.success(true)
                }
                "refreshRoutineWidget" -> {
                    refreshRoutineWidget()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        this.intent = intent
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val cn = ComponentName(this, NotificationListener::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    private fun requestNotificationListenerPermission() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val packageManager = packageManager
        val apps = mutableListOf<Map<String, String>>()
        
        try {
            val packages = packageManager.getInstalledApplications(0)
            for (packageInfo in packages) {
                try {
                    val appName = packageManager.getApplicationLabel(packageInfo).toString()
                    val packageName = packageInfo.packageName
                    
                    // Skip our own app, but include all other apps (including system apps that users might want to monitor)
                    if (packageName != this.packageName) {
                        // Only include apps that have a launcher intent (user-facing apps)
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            apps.add(mapOf(
                                "appName" to appName,
                                "packageName" to packageName
                            ))
                        }
                    }
                } catch (e: Exception) {
                    // Skip apps that can't be processed
                    android.util.Log.w("MainActivity", "Skipping app due to error: $e")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting installed apps: $e")
        }
        
        android.util.Log.d("MainActivity", "Found ${apps.size} apps")
        return apps.sortedBy { it["appName"] }
    }
    
    private fun syncWaterWithWidget(intake: Int, date: String) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit()
                .putLong("flutter.water_$date", intake.toLong())
                .putString("flutter.last_water_reset_date", date)
                .apply()
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to sync water data: $e")
        }
    }
    
    private fun getWaterFromWidget(date: String): Int {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val intake = prefs.getLong("flutter.water_$date", 0L).toInt()
            intake
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to get water data: $e")
            0
        }
    }
    
    private fun setMaximumAlarmVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // Store original volume if not already stored
            if (originalAlarmVolume == -1) {
                originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                android.util.Log.d("MainActivity", "Stored original alarm volume: $originalAlarmVolume")
            }
            
            // Set alarm volume to maximum
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
            android.util.Log.d("MainActivity", "Set alarm volume to maximum: $maxVolume")
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error setting maximum alarm volume: $e")
        }
    }
    
    private fun restoreOriginalAlarmVolume() {
        try {
            if (originalAlarmVolume != -1) {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalAlarmVolume, 0)
                android.util.Log.d("MainActivity", "Restored original alarm volume: $originalAlarmVolume")
                originalAlarmVolume = -1 // Reset
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error restoring alarm volume: $e")
        }
    }
    
    // Method to trigger alarm from NotificationListener service
    fun triggerMotionAlarm(title: String, text: String) {
        try {
            android.util.Log.d("MainActivity", "Triggering Flutter alarm: $title - $text")
            android.util.Log.d("MainActivity", "methodChannel available: ${methodChannel != null}")
            
            if (methodChannel != null) {
                methodChannel!!.invokeMethod("onNotificationReceived", mapOf(
                    "packageName" to "com.tplink.iot",
                    "title" to title,
                    "text" to text,
                    "timestamp" to System.currentTimeMillis()
                ), object : io.flutter.plugin.common.MethodChannel.Result {
                    override fun success(result: Any?) {
                        android.util.Log.d("MainActivity", "Flutter method call succeeded")
                    }
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        android.util.Log.e("MainActivity", "Flutter method call failed: $errorCode - $errorMessage")
                    }
                    override fun notImplemented() {
                        android.util.Log.w("MainActivity", "Flutter method not implemented")
                    }
                })
                android.util.Log.d("MainActivity", "Method call sent to Flutter")
            } else {
                android.util.Log.w("MainActivity", "methodChannel is null - Flutter not ready")
                // Fall back to using a broadcast or shared preferences
                val intent = android.content.Intent("MOTION_ALARM_TRIGGER")
                intent.putExtra("title", title)
                intent.putExtra("text", text)
                sendBroadcast(intent)
                android.util.Log.d("MainActivity", "Sent broadcast as fallback")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error triggering Flutter alarm: $e")
        }
    }
    
    private fun updateRoutineWidget() {
        try {
            val intent = Intent(this, RoutineWidgetProvider::class.java)
            intent.action = "com.bb.bb_app.REFRESH_ROUTINE"
            sendBroadcast(intent)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error updating routine widget: $e")
        }
    }
    
    private fun refreshRoutineWidget() {
        try {
            val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(this)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                ComponentName(this, RoutineWidgetProvider::class.java)
            )
            val provider = RoutineWidgetProvider()
            provider.onUpdate(this, appWidgetManager, appWidgetIds)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error refreshing routine widget: $e")
        }
    }
}
