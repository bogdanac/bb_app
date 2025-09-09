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
            views.setTextViewText(R.id.completed_text, "No routine available for today")
        }
        
        // Set up refresh intent for the whole widget
        val refreshIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        views.setOnClickPendingIntent(R.id.widget_container, 
            PendingIntent.getBroadcast(context, 2, refreshIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun getCurrentRoutine(context: Context): JSONObject? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Try to get the routines data - Flutter shared_preferences stores as StringList
        val routinesJson: Set<String>? = try {
            // First try the correct key format used by Flutter app (without flutter prefix)
            prefs.getStringSet("routines", null)
        } catch (e: ClassCastException) {
            // Flutter might store it differently, try alternative approaches
            try {
                // Check if it's stored as a single string
                val singleString = prefs.getString("routines", null)
                if (singleString != null) {
                    // Convert to set format
                    setOf(singleString)
                } else {
                    // Try with flutter prefix as fallback
                    try {
                        prefs.getStringSet("flutter.routines", null)
                    } catch (e3: ClassCastException) {
                        // Try as single string with prefix
                        val fallbackString = prefs.getString("flutter.routines", null)
                        if (fallbackString != null) setOf(fallbackString) else null
                    }
                }
            } catch (e2: Exception) {
                Log.e("RoutineWidget", "Error reading routines data: ${e2.message}")
                return null
            }
        }
        
        if (routinesJson == null || routinesJson.isEmpty()) {
            Log.d("RoutineWidget", "No routines data found in SharedPreferences")
            return null
        }
        
        Log.d("RoutineWidget", "Found ${routinesJson.size} routine(s) in SharedPreferences")
        
        try {
            // Handle data from Flutter's shared_preferences - try different approaches
            val decodedRoutines = mutableListOf<String>()
            for (routineJsonString in routinesJson) {
                try {
                    // First check if it's already valid JSON
                    if (routineJsonString.trim().startsWith("{") && routineJsonString.trim().endsWith("}")) {
                        // Already valid JSON, use as is
                        decodedRoutines.add(routineJsonString.trim())
                        Log.d("RoutineWidget", "Using raw JSON: ${routineJsonString.take(100)}...")
                        continue
                    }
                    
                    // Try to decode as Base64 only if it looks like Base64
                    if (routineJsonString.matches(Regex("^[A-Za-z0-9+/]*={0,2}$")) && routineJsonString.length % 4 == 0) {
                        try {
                            val decodedBytes = Base64.decode(routineJsonString, Base64.DEFAULT)
                            val decodedString = String(decodedBytes, Charsets.UTF_8)
                            Log.d("RoutineWidget", "Base64 decoded: ${decodedString.take(100)}...")
                            
                            // Check if decoded string is valid JSON
                            if (decodedString.trim().startsWith("{") && decodedString.trim().endsWith("}")) {
                                decodedRoutines.add(decodedString.trim())
                                Log.d("RoutineWidget", "Added Base64 decoded JSON")
                            } else {
                                // Try to find JSON in the string
                                val jsonStart = decodedString.indexOf("{")
                                val jsonEnd = decodedString.lastIndexOf("}") + 1
                                if (jsonStart != -1 && jsonEnd > jsonStart) {
                                    val jsonPart = decodedString.substring(jsonStart, jsonEnd)
                                    decodedRoutines.add(jsonPart)
                                    Log.d("RoutineWidget", "Extracted JSON from Base64: ${jsonPart.take(100)}...")
                                } else {
                                    Log.w("RoutineWidget", "Base64 decoded but no valid JSON found")
                                }
                            }
                        } catch (base64Error: Exception) {
                            Log.w("RoutineWidget", "Base64 decode failed: ${base64Error.message}, using raw")
                            decodedRoutines.add(routineJsonString)
                        }
                    } else {
                        // Not Base64 format, use as is
                        decodedRoutines.add(routineJsonString)
                        Log.d("RoutineWidget", "Not Base64, using raw: ${routineJsonString.take(100)}...")
                    }
                } catch (e: Exception) {
                    Log.e("RoutineWidget", "Error processing routine data: ${e.message}")
                    // As last resort, try using the raw string
                    decodedRoutines.add(routineJsonString)
                }
            }
            
            // First check if there's a manual override for today
            val overrideJson = prefs.getString("active_routine_override", null)
            if (overrideJson != null) {
                val overrideData = JSONObject(overrideJson)
                val savedDate = overrideData.optString("date", "")
                val today = getEffectiveDate()
                
                if (savedDate == today) {
                    val overrideRoutineId = overrideData.optString("routineId", "")
                    if (overrideRoutineId.isNotEmpty()) {
                        // Find the routine with this ID
                        for (routineJsonString in decodedRoutines) {
                            val routine = try {
                                JSONObject(routineJsonString)
                            } catch (e: Exception) {
                                Log.e("RoutineWidget", "Failed to parse override routine JSON: '$routineJsonString', error: ${e.message}")
                                continue
                            }
                            if (routine.optString("id", "") == overrideRoutineId) {
                                return routine
                            }
                        }
                    }
                }
            }
            
            // No override or override not found, use normal logic
            val currentWeekday = getCurrentWeekday()
            
            // First, find all morning routines that are active today
            for (routineJsonString in decodedRoutines) {
                val routine = try {
                    JSONObject(routineJsonString)
                } catch (e: Exception) {
                    Log.e("RoutineWidget", "Failed to parse routine JSON: '$routineJsonString', error: ${e.message}")
                    continue
                }
                val routineTitle = routine.optString("title", "").lowercase()
                val activeDays = routine.optJSONArray("activeDays")
                
                Log.d("RoutineWidget", "Checking routine: '$routineTitle', activeDays: $activeDays, currentWeekday: $currentWeekday")
                
                // Check if it's a morning routine and active today (case-insensitive)
                if (routineTitle.contains("morning") && activeDays != null) {
                    Log.d("RoutineWidget", "Found morning routine: $routineTitle")
                    for (i in 0 until activeDays.length()) {
                        val dayValue = activeDays.getInt(i)
                        Log.d("RoutineWidget", "Checking day $dayValue against current $currentWeekday")
                        if (dayValue == currentWeekday) {
                            Log.d("RoutineWidget", "Morning routine is active today!")
                            return routine
                        }
                    }
                }
            }
            
            // Fallback: find any routine active today
            for (routineJsonString in decodedRoutines) {
                val routine = try {
                    JSONObject(routineJsonString)
                } catch (e: Exception) {
                    Log.e("RoutineWidget", "Failed to parse fallback routine JSON: '$routineJsonString', error: ${e.message}")
                    continue
                }
                val activeDays = routine.optJSONArray("activeDays")
                
                if (activeDays != null) {
                    for (i in 0 until activeDays.length()) {
                        if (activeDays.getInt(i) == currentWeekday) {
                            return routine
                        }
                    }
                }
            }
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
        val today = getTodayString()
        val progressJson = prefs.getString("morning_routine_progress_$today", null)
        
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
        val today = getTodayString()
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
                val progressJson = prefs.getString("morning_routine_progress_$today", null)
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
                
                // Save progress
                val progressData = JSONObject().apply {
                    put("currentStepIndex", nextStepIndex)
                    put("completedSteps", JSONArray(completedSteps))
                    put("skippedSteps", JSONArray(skippedSteps))
                    put("lastUpdated", Date().time)
                }
                
                prefs.edit()
                    .putString("morning_routine_progress_$today", progressData.toString())
                    .putString("morning_routine_last_date", today)
                    .apply()
                    
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun skipCurrentStep(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getTodayString()
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
                
                val progressJson = prefs.getString("morning_routine_progress_$today", null)
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
                
                // Save progress
                val progressData = JSONObject().apply {
                    put("currentStepIndex", nextStepIndex)
                    put("completedSteps", JSONArray(completedSteps))
                    put("skippedSteps", JSONArray(skippedSteps))
                    put("lastUpdated", Date().time)
                }
                
                prefs.edit()
                    .putString("morning_routine_progress_$today", progressData.toString())
                    .putString("morning_routine_last_date", today)
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