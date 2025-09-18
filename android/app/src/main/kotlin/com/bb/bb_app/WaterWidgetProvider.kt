package com.bb.bb_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.*

class WaterWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val ACTION_ADD_WATER = "com.bb.bb_app.ADD_WATER"
        private const val WATER_GOAL = 1500
        private const val DEFAULT_WATER_INCREMENT = 125
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
        if (currentIntake >= WATER_GOAL) {
            android.util.Log.d("WaterWidget", "Goal already reached: $currentIntake >= $WATER_GOAL")
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
        val currentIntake = getCurrentWaterIntake(context)
        val isGoalReached = currentIntake >= WATER_GOAL
        
        val views = RemoteViews(context.packageName, R.layout.water_widget)
        
        // Update button appearance based on goal status
        if (isGoalReached) {
            views.setImageViewResource(R.id.water_button, R.drawable.ic_check)
            views.setInt(R.id.water_button, "setBackgroundResource", R.drawable.water_button_background_complete)
        } else {
            views.setImageViewResource(R.id.water_button, R.drawable.ic_water_drop)
            views.setInt(R.id.water_button, "setBackgroundResource", R.drawable.water_button_background)
        }
        
        // Set click intent - only if goal not reached
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
            views.setOnClickPendingIntent(R.id.water_button, pendingIntent)
            android.util.Log.d("WaterWidget", "Set up click listener for widget $appWidgetId")
        } else {
            // Remove click listener when goal is reached
            views.setOnClickPendingIntent(R.id.water_button, null)
        }
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}