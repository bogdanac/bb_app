package com.bb.bb_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class RoutineWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_COMPLETE_STEP = "com.bb.bb_app.COMPLETE_STEP"
        const val ACTION_SKIP_STEP = "com.bb.bb_app.SKIP_STEP"
        const val ACTION_REFRESH = "com.bb.bb_app.REFRESH_ROUTINE"
        
        private fun getTodayString(): String {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            return dateFormat.format(Date())
        }
        
        private fun getEffectiveDate(): String {
            val calendar = Calendar.getInstance()
            val hour = calendar.get(Calendar.HOUR_OF_DAY)
            
            // If it's before 2 AM, consider it as the previous day
            if (hour < 2) {
                calendar.add(Calendar.DAY_OF_MONTH, -1)
            }
            
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            return dateFormat.format(calendar.time)
        }
        
        private fun getCurrentWeekday(): Int {
            val calendar = Calendar.getInstance()
            val hour = calendar.get(Calendar.HOUR_OF_DAY)

            // If it's before 2 AM, consider it as the previous day
            if (hour < 2) {
                calendar.add(Calendar.DAY_OF_MONTH, -1)
            }

            // Convert to Monday=1, Sunday=7 format
            return when (calendar.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 1
                Calendar.TUESDAY -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY -> 4
                Calendar.FRIDAY -> 5
                Calendar.SATURDAY -> 6
                Calendar.SUNDAY -> 7
                else -> 1
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_COMPLETE_STEP -> {
                completeCurrentStep(context)
                refreshAllWidgets(context)
            }
            ACTION_SKIP_STEP -> {
                skipCurrentStep(context)
                refreshAllWidgets(context)
            }
            ACTION_REFRESH -> {
                refreshAllWidgets(context)
            }
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.routine_widget)
        
        // Apply custom background color
        applyCustomBackgroundColor(context, views)
        
        val routineData = getCurrentRoutine(context)
        
        if (routineData != null) {
            val currentStep = getCurrentStep(context, routineData)
            val routineTitle = routineData.optString("title", "Morning Routine")
            val totalSteps = routineData.optJSONArray("items")?.length() ?: 0
            val currentStepIndex = getCurrentStepIndex(context) + 1
            
            // Set routine title
            views.setTextViewText(R.id.routine_title, routineTitle)
            
            // Set progress text
            views.setTextViewText(R.id.routine_progress, "$currentStepIndex/$totalSteps")
            
            if (currentStep != null) {
                // Show current step
                views.setTextViewText(R.id.current_step, currentStep.optString("text", ""))
                views.setViewVisibility(R.id.step_container, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.completed_container, android.view.View.GONE)
                
                // Set up complete button
                val completeIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
                    action = ACTION_COMPLETE_STEP
                }
                views.setOnClickPendingIntent(R.id.complete_button, 
                    PendingIntent.getBroadcast(context, 0, completeIntent, 
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                
                // Set up skip button
                val skipIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
                    action = ACTION_SKIP_STEP
                }
                views.setOnClickPendingIntent(R.id.skip_button, 
                    PendingIntent.getBroadcast(context, 1, skipIntent, 
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                        
            } else {
                // All steps completed
                views.setViewVisibility(R.id.step_container, android.view.View.GONE)
                views.setViewVisibility(R.id.completed_container, android.view.View.VISIBLE)
                views.setTextViewText(R.id.completed_text, "All steps completed! 🎉")
            }
        } else {
            // No routine available
            views.setTextViewText(R.id.routine_title, "No Routine")
            views.setTextViewText(R.id.routine_progress, "0/0")
            views.setViewVisibility(R.id.step_container, android.view.View.GONE)
            views.setViewVisibility(R.id.completed_container, android.view.View.VISIBLE)
            views.setTextViewText(R.id.completed_text, "Tap refresh to reload routines")
        }
        
        // Set up refresh intent for the refresh button
        val refreshIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        views.setOnClickPendingIntent(R.id.refresh_button, 
            PendingIntent.getBroadcast(context, 2, refreshIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun applyCustomBackgroundColor(context: Context, views: RemoteViews) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val defaultColor = 0xFF4CAF50.toInt() // Default vibrant green
            
            // Try different possible keys
            var customColor = defaultColor
            val possibleKeys = listOf(
                "flutter.widget_background_color",
                "widget_background_color",
                "flutter.widget_color",
                "widget_color"
            )
            
            for (key in possibleKeys) {
                try {
                    val colorValue = prefs.getInt(key, -1)
                    if (colorValue != -1) {
                        customColor = colorValue
                        break
                    }
                } catch (e: Exception) {
                    // Try as long if int fails
                    try {
                        val colorValue = prefs.getLong(key, -1L)
                        if (colorValue != -1L) {
                            customColor = colorValue.toInt()
                            break
                        }
                    } catch (e2: Exception) {
                        // Key not found or invalid type, continue to next key
                    }
                }
            }
            
            // Set the background color of the widget container
            views.setInt(R.id.widget_container, "setBackgroundColor", customColor)
        } catch (e: Exception) {
            // Silent failure - use default color
        }
    }

    private fun getCurrentRoutine(context: Context): JSONObject? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Flutter shared_preferences plugin stores StringList values with special formatting
        // Try multiple approaches to read the data
        val routinesJson: List<String>? = try {
            val allPrefs = prefs.all
            
            // Method 1: Try numbered routine keys (routine_0, routine_1, etc.) - our new approach  
            val routinesCount = try {
                prefs.getInt("flutter.routines_count", -1)
            } catch (e: ClassCastException) {
                // Handle case where it's stored as Long instead of Int
                try {
                    prefs.getLong("flutter.routines_count", -1).toInt()
                } catch (e2: Exception) {
                    -1
                }
            }
            if (routinesCount > 0) {
                val numberedRoutines = mutableListOf<String>()
                for (i in 0 until routinesCount) {
                    val routineJson = prefs.getString("flutter.routine_$i", null)
                    if (routineJson != null) {
                        numberedRoutines.add(routineJson)
                    }
                }
                if (numberedRoutines.isNotEmpty()) {
                    numberedRoutines
                } else null
            } else {
                // Method 2: Try to get as StringSet (legacy widget format)
                val stringSet = prefs.getStringSet("flutter.routines", null)
                if (stringSet != null && stringSet.isNotEmpty()) {
                    stringSet.toList()
                } else {
                    // Method 3: Flutter stores StringList with flutter. prefix and special encoding
                    val flutterRoutinesKey = allPrefs.keys.find { it.startsWith("flutter.routines") }
                    if (flutterRoutinesKey != null) {
                        val value = allPrefs[flutterRoutinesKey]
                        when (value) {
                            is Set<*> -> {
                                value.filterIsInstance<String>()
                            }
                            is String -> {
                                listOf(value)
                            }
                            else -> {
                                null
                            }
                        }
                    } else {
                        // Method 4: Direct string access for routines key
                        val directString = prefs.getString("flutter.routines", null)
                        if (directString != null) {
                            listOf(directString)
                        } else {
                            null
                        }
                    }
                }
            }
        } catch (e: Exception) {
            null
        }
        
        if (routinesJson == null || routinesJson.isEmpty()) {
            return null
        }
        
        try {
            // Process each routine JSON string
            val validRoutines = mutableListOf<JSONObject>()
            
            for (routineJsonString in routinesJson) {
                try {
                    // Try to parse as direct JSON first
                    val routine = JSONObject(routineJsonString)
                    validRoutines.add(routine)
                } catch (directParseError: Exception) {
                    // Try Base64 decode if it looks like Base64
                    if (routineJsonString.matches(Regex("^[A-Za-z0-9+/]*={0,2}$")) && routineJsonString.length % 4 == 0) {
                        try {
                            val decodedBytes = Base64.decode(routineJsonString, Base64.DEFAULT)
                            val decodedString = String(decodedBytes, Charsets.UTF_8)
                            val routine = JSONObject(decodedString)
                            validRoutines.add(routine)
                        } catch (base64Error: Exception) {
                            // Skip this routine
                        }
                    }
                }
            }
            
            if (validRoutines.isEmpty()) {
                return null
            }
            
            // First check if there's a manual override for today
            val overrideJson = prefs.getString("flutter.active_routine_override", null)
            if (overrideJson != null) {
                try {
                    val overrideData = JSONObject(overrideJson)
                    val savedDate = overrideData.optString("date", "")
                    val today = getEffectiveDate()
                    
                    if (savedDate == today) {
                        val overrideRoutineId = overrideData.optString("routineId", "")
                        if (overrideRoutineId.isNotEmpty()) {
                            // Find the routine with this ID
                            val overrideRoutine = validRoutines.find { routine ->
                                routine.optString("id", "") == overrideRoutineId
                            }
                            if (overrideRoutine != null) {
                                return overrideRoutine
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Skip override processing
                }
            }
            
            // No override or override not found, use normal logic
            // This mirrors the logic from Flutter's getCurrentActiveRoutine method

            val currentWeekday = getCurrentWeekday()

            // Find routines scheduled for today
            for (routine in validRoutines) {
                val activeDays = routine.optJSONArray("activeDays")

                if (activeDays != null) {
                    for (i in 0 until activeDays.length()) {
                        if (activeDays.getInt(i) == currentWeekday) {
                            return routine
                        }
                    }
                }
            }

            // No routine scheduled for today
            return null
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return null
    }

    private fun getCurrentStepIndex(context: Context): Int {
        val routine = getCurrentRoutine(context) ?: return 0
        val routineId = routine.optString("id", "")
        if (routineId.isEmpty()) return 0

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getEffectiveDate()  // Use effective date (considers <2 AM as previous day)
        
        // Try routine-specific progress first
        var progressJson = prefs.getString("flutter.routine_progress_${routineId}_$today", null)
        
        // Fallback to morning routine progress
        if (progressJson == null) {
            progressJson = prefs.getString("flutter.morning_routine_progress_$today", null)
        }
        
        if (progressJson != null) {
            try {
                val progress = JSONObject(progressJson)
                return progress.optInt("currentStepIndex", 0)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        
        return 0
    }

    private fun getCurrentStep(context: Context, routine: JSONObject): JSONObject? {
        val items = routine.optJSONArray("items") ?: return null
        val currentIndex = getCurrentStepIndex(context)
        
        if (currentIndex >= 0 && currentIndex < items.length()) {
            return items.optJSONObject(currentIndex)
        }
        
        return null
    }

    private fun completeCurrentStep(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getEffectiveDate()  // Use effective date (considers <2 AM as previous day)
        val routine = getCurrentRoutine(context) ?: return
        val routineId = routine.optString("id", "") 
        if (routineId.isEmpty()) return
        val items = routine.optJSONArray("items") ?: return
        val currentIndex = getCurrentStepIndex(context)
        
        if (currentIndex >= 0 && currentIndex < items.length()) {
            try {
                // Mark current step as completed
                val completedSteps = mutableListOf<Boolean>()
                val skippedSteps = mutableListOf<Boolean>()
                
                // Load existing progress
                val progressJson = prefs.getString("flutter.morning_routine_progress_$today", null)
                if (progressJson != null) {
                    val progress = JSONObject(progressJson)
                    val completedArray = progress.optJSONArray("completedSteps")
                    val skippedArray = progress.optJSONArray("skippedSteps")
                    
                    if (completedArray != null) {
                        for (i in 0 until completedArray.length()) {
                            completedSteps.add(completedArray.optBoolean(i, false))
                        }
                    }
                    
                    if (skippedArray != null) {
                        for (i in 0 until skippedArray.length()) {
                            skippedSteps.add(skippedArray.optBoolean(i, false))
                        }
                    }
                }
                
                // Ensure lists are the right size
                while (completedSteps.size < items.length()) {
                    completedSteps.add(false)
                }
                while (skippedSteps.size < items.length()) {
                    skippedSteps.add(false)
                }
                
                // Mark current step as completed
                completedSteps[currentIndex] = true
                skippedSteps[currentIndex] = false

                // Find next uncompleted step
                var nextStepIndex = currentIndex + 1
                while (nextStepIndex < items.length() && completedSteps[nextStepIndex]) {
                    nextStepIndex++
                }

                // If we've gone past all steps, check for skipped steps to show again
                if (nextStepIndex >= items.length()) {
                    for (i in 0 until items.length()) {
                        if (skippedSteps[i] && !completedSteps[i]) {
                            nextStepIndex = i
                            break
                        }
                    }
                }

                // Save progress
                val progressData = JSONObject().apply {
                    put("currentStepIndex", nextStepIndex)
                    put("completedSteps", JSONArray(completedSteps))
                    put("skippedSteps", JSONArray(skippedSteps))
                    put("lastUpdated", Date().time)
                }
                
                prefs.edit()
                    .putString("flutter.routine_progress_${routineId}_$today", progressData.toString())
                    .putString("flutter.morning_routine_progress_$today", progressData.toString())
                    .putString("flutter.morning_routine_last_date", today)
                    .apply()
                    
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun skipCurrentStep(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getEffectiveDate()  // Use effective date (considers <2 AM as previous day)
        val routine = getCurrentRoutine(context) ?: return
        val routineId = routine.optString("id", "")
        if (routineId.isEmpty()) return
        val items = routine.optJSONArray("items") ?: return
        val currentIndex = getCurrentStepIndex(context)
        
        if (currentIndex >= 0 && currentIndex < items.length()) {
            try {
                // Load existing progress
                val completedSteps = mutableListOf<Boolean>()
                val skippedSteps = mutableListOf<Boolean>()
                
                var progressJson = prefs.getString("flutter.routine_progress_${routineId}_$today", null)
                if (progressJson == null) {
                    progressJson = prefs.getString("flutter.morning_routine_progress_$today", null)
                }
                if (progressJson != null) {
                    val progress = JSONObject(progressJson)
                    val completedArray = progress.optJSONArray("completedSteps")
                    val skippedArray = progress.optJSONArray("skippedSteps")
                    
                    if (completedArray != null) {
                        for (i in 0 until completedArray.length()) {
                            completedSteps.add(completedArray.optBoolean(i, false))
                        }
                    }
                    
                    if (skippedArray != null) {
                        for (i in 0 until skippedArray.length()) {
                            skippedSteps.add(skippedArray.optBoolean(i, false))
                        }
                    }
                }
                
                // Ensure lists are the right size
                while (completedSteps.size < items.length()) {
                    completedSteps.add(false)
                }
                while (skippedSteps.size < items.length()) {
                    skippedSteps.add(false)
                }
                
                // Mark current step as skipped
                skippedSteps[currentIndex] = true

                // Find next uncompleted step
                var nextStepIndex = currentIndex + 1
                while (nextStepIndex < items.length() && completedSteps[nextStepIndex]) {
                    nextStepIndex++
                }

                // If we've gone past all steps, check for skipped steps to show again
                if (nextStepIndex >= items.length()) {
                    for (i in 0 until items.length()) {
                        if (skippedSteps[i] && !completedSteps[i]) {
                            nextStepIndex = i
                            break
                        }
                    }
                }

                // Save progress
                val progressData = JSONObject().apply {
                    put("currentStepIndex", nextStepIndex)
                    put("completedSteps", JSONArray(completedSteps))
                    put("skippedSteps", JSONArray(skippedSteps))
                    put("lastUpdated", Date().time)
                }
                
                prefs.edit()
                    .putString("flutter.routine_progress_${routineId}_$today", progressData.toString())
                    .putString("flutter.morning_routine_progress_$today", progressData.toString())
                    .putString("flutter.morning_routine_last_date", today)
                    .apply()
                    
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun refreshAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, RoutineWidgetProvider::class.java)
        )
        onUpdate(context, appWidgetManager, appWidgetIds)
    }
}