package com.bb.bb_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import androidx.core.app.NotificationManagerCompat
import java.text.SimpleDateFormat
import java.util.*

class WaterWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val ACTION_ADD_WATER = "com.bb.bb_app.ADD_WATER"
        private const val DEFAULT_WATER_GOAL = 1500
        private const val DEFAULT_WATER_INCREMENT = 125

        // Water notification IDs (must match Flutter's WaterNotificationService)
        private const val NOTIFICATION_20_ID = 1001
        private const val NOTIFICATION_40_ID = 1002
        private const val NOTIFICATION_60_ID = 1003
        private const val NOTIFICATION_80_ID = 1004
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        android.util.Log.d("WaterWidget", "Received intent: ${intent.action}")
        
        if (ACTION_ADD_WATER == intent.action) {
            android.util.Log.d("WaterWidget", "Processing ADD_WATER action")
            addWater(context)
            
            // Update all widgets
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, WaterWidgetProvider::class.java)
            )
            android.util.Log.d("WaterWidget", "Updating ${appWidgetIds.size} widgets")
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun getWaterAmountPerTap(context: Context): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Try multiple key formats that Flutter might use - order matters!
        // Try flutter. prefix first as that's what we explicitly save
        val possibleKeys = listOf(
            "flutter.water_amount_per_tap",
            "water_amount_per_tap"
        )

        android.util.Log.d("WaterWidget", "=== WATER AMOUNT LOOKUP START ===")

        // Debug: List all water-related keys
        val allKeys = prefs.all.keys
        android.util.Log.d("WaterWidget", "All keys containing 'water': ${allKeys.filter { it.contains("water") }}")

        for (key in possibleKeys) {
            try {
                // Try as Int first
                val value = prefs.getInt(key, -1)
                if (value > 0 && value <= 1000) { // Validate range
                    android.util.Log.d("WaterWidget", "✓ Found water amount setting (Int): ${value}ml for key: $key")
                    return value
                }
                android.util.Log.d("WaterWidget", "Key $key returned invalid int: $value")
            } catch (e: ClassCastException) {
                android.util.Log.d("WaterWidget", "Key $key not an int, trying Long...")
                try {
                    // Flutter might store as Long, try that
                    val longValue = prefs.getLong(key, -1L)
                    if (longValue > 0 && longValue <= 1000) { // Validate range
                        android.util.Log.d("WaterWidget", "✓ Found water amount setting (Long): ${longValue}ml for key: $key")
                        return longValue.toInt()
                    }
                    android.util.Log.d("WaterWidget", "Key $key returned invalid long: $longValue")
                } catch (e2: ClassCastException) {
                    android.util.Log.d("WaterWidget", "Key $key failed both Int and Long: $e2")
                }
            }
        }

        android.util.Log.d("WaterWidget", "⚠ No water amount setting found, using default: ${DEFAULT_WATER_INCREMENT}ml")
        android.util.Log.d("WaterWidget", "=== WATER AMOUNT LOOKUP END ===")
        return DEFAULT_WATER_INCREMENT
    }

    private fun getWaterGoal(context: Context): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Try multiple key formats that Flutter might use
        val possibleKeys = listOf(
            "flutter.water_goal",
            "water_goal"
        )

        for (key in possibleKeys) {
            try {
                // Try as Int first
                val value = prefs.getInt(key, -1)
                if (value > 0 && value <= 5000) { // Validate range
                    android.util.Log.d("WaterWidget", "✓ Found water goal setting (Int): ${value}ml for key: $key")
                    return value
                }
            } catch (e: ClassCastException) {
                try {
                    // Flutter might store as Long, try that
                    val longValue = prefs.getLong(key, -1L)
                    if (longValue > 0 && longValue <= 5000) { // Validate range
                        android.util.Log.d("WaterWidget", "✓ Found water goal setting (Long): ${longValue}ml for key: $key")
                        return longValue.toInt()
                    }
                } catch (e2: ClassCastException) {
                    // Continue to next key
                }
            }
        }

        android.util.Log.d("WaterWidget", "⚠ No water goal setting found, using default: ${DEFAULT_WATER_GOAL}ml")
        return DEFAULT_WATER_GOAL
    }

    private fun addWater(context: Context) {
        // Try Flutter's actual SharedPreferences file
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        // Get customizable water amount
        val waterIncrement = getWaterAmountPerTap(context)

        // Try multiple key formats to find the correct one
        val possibleKeys = listOf(
            "flutter.water_$today",
            "water_$today"
        )

        var currentIntake = 0
        var correctKey = ""

        for (key in possibleKeys) {
            try {
                // Try as Int first
                val value = prefs.getInt(key, -1)
                if (value >= 0) {
                    currentIntake = value
                    correctKey = key
                    android.util.Log.d("WaterWidget", "Found water data (Int) with key: $key, value: $value")
                    break
                }
            } catch (e: ClassCastException) {
                try {
                    // Flutter might store as Long, try that
                    val longValue = prefs.getLong(key, -1L)
                    if (longValue >= 0) {
                        currentIntake = longValue.toInt()
                        correctKey = key
                        android.util.Log.d("WaterWidget", "Found water data (Long) with key: $key, value: $longValue")
                        break
                    }
                } catch (e2: ClassCastException) {
                    android.util.Log.d("WaterWidget", "Failed to read key $key as Int or Long: $e2")
                }
            }
        }

        if (correctKey.isEmpty()) {
            // No existing data found, use the flutter. prefixed key
            correctKey = "flutter.water_$today"
            android.util.Log.d("WaterWidget", "No existing data found, using key: $correctKey")
        }

        // Don't add water if goal is already reached
        val waterGoal = getWaterGoal(context)
        if (currentIntake >= waterGoal) {
            android.util.Log.d("WaterWidget", "Goal already reached: $currentIntake >= $waterGoal")
            return
        }

        val newIntake = currentIntake + waterIncrement

        // Save as Long to match Flutter's format
        prefs.edit()
            .putLong(correctKey, newIntake.toLong())
            .putString("flutter.last_water_reset_date", today)
            .apply()

        android.util.Log.d("WaterWidget", "Water added: $currentIntake -> $newIntake (+${waterIncrement}ml)")
        android.util.Log.d("WaterWidget", "Saved to key: $correctKey")

        // Cancel notifications for thresholds already met
        cancelNotificationsForReachedThresholds(context, newIntake, waterGoal)
    }

    private fun cancelNotificationsForReachedThresholds(context: Context, currentIntake: Int, waterGoal: Int) {
        val percentage = (currentIntake.toFloat() / waterGoal.toFloat() * 100).toInt()
        val notificationManager = NotificationManagerCompat.from(context)

        android.util.Log.d("WaterWidget", "Checking notifications to cancel: intake=$currentIntake, goal=$waterGoal, percentage=$percentage%")

        if (percentage >= 20) {
            notificationManager.cancel(NOTIFICATION_20_ID)
            android.util.Log.d("WaterWidget", "Cancelled 20% notification")
        }
        if (percentage >= 40) {
            notificationManager.cancel(NOTIFICATION_40_ID)
            android.util.Log.d("WaterWidget", "Cancelled 40% notification")
        }
        if (percentage >= 60) {
            notificationManager.cancel(NOTIFICATION_60_ID)
            android.util.Log.d("WaterWidget", "Cancelled 60% notification")
        }
        if (percentage >= 80) {
            notificationManager.cancel(NOTIFICATION_80_ID)
            android.util.Log.d("WaterWidget", "Cancelled 80% notification")
        }
        if (percentage >= 100) {
            // Cancel all water notifications
            notificationManager.cancel(NOTIFICATION_20_ID)
            notificationManager.cancel(NOTIFICATION_40_ID)
            notificationManager.cancel(NOTIFICATION_60_ID)
            notificationManager.cancel(NOTIFICATION_80_ID)
            android.util.Log.d("WaterWidget", "Goal reached! Cancelled all water notifications")
        }
    }

    private fun getCurrentWaterIntake(context: Context): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        // Try multiple key formats to find the correct one
        val possibleKeys = listOf(
            "flutter.water_$today",
            "water_$today"
        )
        
        for (key in possibleKeys) {
            try {
                // Try as Int first
                val value = prefs.getInt(key, -1)
                if (value >= 0) {
                    android.util.Log.d("WaterWidget", "Found water intake (Int): $value for key: $key")
                    return value
                }
            } catch (e: ClassCastException) {
                try {
                    // Flutter might store as Long, try that
                    val longValue = prefs.getLong(key, -1L)
                    if (longValue >= 0) {
                        android.util.Log.d("WaterWidget", "Found water intake (Long): $longValue for key: $key")
                        return longValue.toInt()
                    }
                } catch (e2: ClassCastException) {
                    android.util.Log.d("WaterWidget", "Failed to read key $key as Int or Long: $e2")
                }
            }
        }
        
        android.util.Log.d("WaterWidget", "No water data found for today")
        android.util.Log.d("WaterWidget", "=== WIDGET DEBUG END ===")
        return 0
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val currentIntake = getCurrentWaterIntake(context)
            val waterGoal = getWaterGoal(context)
            val waterLevel = (currentIntake.toFloat() / waterGoal.toFloat()).coerceIn(0f, 1f)
            val isGoalReached = currentIntake >= waterGoal

            val views = RemoteViews(context.packageName, R.layout.water_widget)

            // Generate body bitmap
            val bodyBitmap = WaterBodyDrawable.createBitmap(300, 300, waterLevel)
            views.setImageViewBitmap(R.id.water_body_image, bodyBitmap)

            // Set click intent
            if (!isGoalReached) {
                val intent = Intent(context, WaterWidgetProvider::class.java).apply {
                    action = ACTION_ADD_WATER
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    appWidgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.water_click_area, pendingIntent)
            } else {
                views.setOnClickPendingIntent(R.id.water_click_area, null)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            android.util.Log.d("WaterWidget", "Widget updated: ${waterLevel * 100}% water")
        } catch (e: Exception) {
            android.util.Log.e("WaterWidget", "Error: ${e.message}", e)
            // Fallback: create a simple colored square so widget doesn't fail completely
            val views = RemoteViews(context.packageName, R.layout.water_widget)
            val fallbackBitmap = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
            Canvas(fallbackBitmap).drawColor(Color.parseColor("#4A90E2"))
            views.setImageViewBitmap(R.id.water_body_image, fallbackBitmap)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}