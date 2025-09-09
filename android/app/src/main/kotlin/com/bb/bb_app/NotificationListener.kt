package com.bb.bb_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import android.util.Log
import android.content.SharedPreferences
import android.content.Context
import java.util.Calendar
import org.json.JSONObject

class NotificationListener : NotificationListenerService() {
    
    companion object {
        private const val TAG = "NotificationListener"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        
        sbn?.let { notification ->
            try {
                // FIRST: Quick time and settings check - exit early if not needed
                if (!shouldProcessNotification()) {
                    return // Don't waste battery processing if outside active hours
                }
                
                val packageName = notification.packageName
                val extras = notification.notification.extras
                // Handle SpannableString by converting CharSequence to String
                val title = extras?.getCharSequence("android.title")?.toString() ?: ""
                val text = extras?.getCharSequence("android.text")?.toString() ?: ""
                
                Log.d(TAG, "Processing notification from $packageName: $title - $text")
                
                // Check if this specific notification should trigger alarm
                if (shouldTriggerAlarm(packageName, title, text)) {
                    triggerAlarm(title, text)
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error processing notification: $e")
            }
        }
    }
    
    private fun shouldProcessNotification(): Boolean {
        try {
            // Quick settings check
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val settingsJson = prefs.getString("flutter.notification_alarm_settings", null)
                ?: return false
            
            val settings = JSONObject(settingsJson)
            val isEnabled = settings.optBoolean("enabled", false)
            if (!isEnabled) return false
            
            val nightModeOnly = settings.optBoolean("nightModeOnly", true)
            
            // If night mode only, check time immediately
            if (nightModeOnly) {
                val calendar = Calendar.getInstance()
                val hour = calendar.get(Calendar.HOUR_OF_DAY)
                // Only process between 22:00-08:00
                if (!(hour >= 22 || hour <= 8)) {
                    Log.d(TAG, "Outside night hours ($hour:xx), skipping notification processing")
                    return false
                }
            }
            
            Log.d(TAG, "Within active hours, will process notifications")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if should process: $e")
            return false
        }
    }
    
    private fun shouldTriggerAlarm(packageName: String, title: String, text: String): Boolean {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val settingsJson = prefs.getString("flutter.notification_alarm_settings", null)
                ?: return false
            
            val settings = JSONObject(settingsJson)
            
            // Skip app monitoring - just check for the keyword "detected" in any notification
            val content = "$title $text".lowercase()
            val hasDetected = content.contains("detected")
            
            Log.d(TAG, "Content: '$content', Contains 'detected': $hasDetected")
            
            return hasDetected
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking trigger conditions: $e")
            return false
        }
    }
    
    private fun triggerAlarm(title: String, text: String) {
        Log.d(TAG, "🚨 MOTION ALERT: $title - $text")
        
        // Call MainActivity to trigger Flutter alarm
        try {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                try {
                    MainActivity.instance?.triggerMotionAlarm(title, text)
                    Log.d(TAG, "Called MainActivity.triggerMotionAlarm")
                } catch (e: Exception) {
                    Log.e(TAG, "Error calling MainActivity: $e")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in triggerAlarm: $e")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        // Handle notification removal if needed
    }
}