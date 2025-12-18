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
        const val ACTION_POSTPONE_STEP = "com.bb.bb_app.POSTPONE_STEP"
        const val ACTION_SKIP_STEP = "com.bb.bb_app.SKIP_STEP"
        const val ACTION_SKIP_ROUTINE = "com.bb.bb_app.SKIP_ROUTINE"
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
            ACTION_POSTPONE_STEP -> {
                postponeCurrentStep(context)
                refreshAllWidgets(context)
            }
            ACTION_SKIP_STEP -> {
                skipCurrentStep(context)
                refreshAllWidgets(context)
            }
            ACTION_SKIP_ROUTINE -> {
                skipRoutine(context)
                refreshAllWidgets(context)
            }
            ACTION_REFRESH -> {
                // App requested widget refresh (e.g., after saving progress)
                android.util.Log.d("RoutineSync", "🔄 Widget: Received REFRESH_ROUTINE from app")
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

            // Set routine title
            views.setTextViewText(R.id.routine_title, routineTitle)
            
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

                // Set up postpone button
                val postponeIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
                    action = ACTION_POSTPONE_STEP
                }
                views.setOnClickPendingIntent(R.id.postpone_button,
                    PendingIntent.getBroadcast(context, 1, postponeIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

                // Set up skip button
                val skipIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
                    action = ACTION_SKIP_STEP
                }
                views.setOnClickPendingIntent(R.id.skip_button,
                    PendingIntent.getBroadcast(context, 2, skipIntent,
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
            views.setViewVisibility(R.id.step_container, android.view.View.GONE)
            views.setViewVisibility(R.id.completed_container, android.view.View.VISIBLE)
            views.setTextViewText(R.id.completed_text, "No routines scheduled for today")
        }
        
        // Set up skip routine button
        val skipRoutineIntent = Intent(context, RoutineWidgetProvider::class.java).apply {
            action = ACTION_SKIP_ROUTINE
        }
        views.setOnClickPendingIntent(R.id.skip_routine_button,
            PendingIntent.getBroadcast(context, 3, skipRoutineIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun applyCustomBackgroundColor(context: Context, views: RemoteViews) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val defaultColor = 0xB3202020.toInt() // Default transparent dark grey (70% opacity)

            // Try different possible keys (prioritize new key, fallback to old)
            var customColor = defaultColor
            val possibleKeys = listOf(
                "flutter.widget_routine_color",
                "widget_routine_color",
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
            // Find first uncompleted routine scheduled for today

            val currentWeekday = getCurrentWeekday()
            val today = getEffectiveDate()

            // Find routines scheduled for today that are not completed
            for (routine in validRoutines) {
                val activeDays = routine.optJSONArray("activeDays")
                val routineId = routine.optString("id", "")

                if (activeDays != null && routineId.isNotEmpty()) {
                    for (i in 0 until activeDays.length()) {
                        if (activeDays.getInt(i) == currentWeekday) {
                            // Check if this routine is completed today
                            val completedKey = "flutter.routine_completed_${routineId}_$today"
                            val isCompleted = prefs.getBoolean(completedKey, false)

                            if (!isCompleted) {
                                return routine
                            }
                            break
                        }
                    }
                }
            }

            // No uncompleted routine scheduled for today
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
        android.util.Log.d("RoutineSync", "🔄 Widget: Complete button clicked")
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getEffectiveDate()  // Use effective date (considers <2 AM as previous day)
        val routine = getCurrentRoutine(context) ?: return
        val routineId = routine.optString("id", "")
        if (routineId.isEmpty()) return
        val items = routine.optJSONArray("items") ?: return
        val currentIndex = getCurrentStepIndex(context)
        android.util.Log.d("RoutineSync", "🔄 Widget: Completing step $currentIndex for routine $routineId")

        if (currentIndex >= 0 && currentIndex < items.length()) {
            try {
                val completedSteps = mutableListOf<Boolean>()
                val skippedSteps = mutableListOf<Boolean>()
                val postponedSteps = mutableListOf<Boolean>()

                // Load existing progress - try routine-specific key first
                var progressJson = prefs.getString("flutter.routine_progress_${routineId}_$today", null)
                // Fallback to legacy key
                if (progressJson == null) {
                    progressJson = prefs.getString("flutter.morning_routine_progress_$today", null)
                }
                if (progressJson != null) {
                    val progress = JSONObject(progressJson)
                    val completedArray = progress.optJSONArray("completedSteps")
                    val skippedArray = progress.optJSONArray("skippedSteps")
                    val postponedArray = progress.optJSONArray("postponedSteps")

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
                    if (postponedArray != null) {
                        for (i in 0 until postponedArray.length()) {
                            postponedSteps.add(postponedArray.optBoolean(i, false))
                        }
                    }
                }

                // Ensure lists are the right size
                while (completedSteps.size < items.length()) completedSteps.add(false)
                while (skippedSteps.size < items.length()) skippedSteps.add(false)
                while (postponedSteps.size < items.length()) postponedSteps.add(false)

                // Mark current step as completed
                completedSteps[currentIndex] = true
                skippedSteps[currentIndex] = false
                postponedSteps[currentIndex] = false

                // Find next step that is not completed, not skipped, not postponed
                var nextStepIndex = currentIndex + 1
                while (nextStepIndex < items.length() &&
                       (completedSteps[nextStepIndex] || skippedSteps[nextStepIndex] || postponedSteps[nextStepIndex])) {
                    nextStepIndex++
                }

                // If all regular steps done, go back to postponed steps (but never to skipped)
                // Start from the next index to cycle through postponed steps
                if (nextStepIndex >= items.length()) {
                    for (i in 0 until items.length()) {
                        val checkIndex = (currentIndex + 1 + i) % items.length()
                        if (postponedSteps[checkIndex] && !completedSteps[checkIndex] && !skippedSteps[checkIndex]) {
                            nextStepIndex = checkIndex
                            // Clear postponed flag so it can be postponed again
                            postponedSteps[checkIndex] = false
                            break
                        }
                    }
                }

                // Save progress
                val progressData = JSONObject().apply {
                    put("currentStepIndex", nextStepIndex)
                    put("completedSteps", JSONArray(completedSteps))
                    put("skippedSteps", JSONArray(skippedSteps))
                    put("postponedSteps", JSONArray(postponedSteps))
                    put("lastUpdated", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.format(Date()))
                    put("routineId", routineId)
                    put("itemCount", items.length())
                }

                val commitResult = prefs.edit()
                    .putString("flutter.routine_progress_${routineId}_$today", progressData.toString())
                    .putString("flutter.morning_routine_progress_$today", progressData.toString())
                    .putString("flutter.morning_routine_last_date", today)
                    .commit()
                android.util.Log.d("RoutineSync", "🔄 Widget: Saved progress (commit=$commitResult): nextStep=$nextStepIndex, data=${progressData.toString()}")

                // Check if all steps are done (completed or permanently skipped, but not postponed)
                val allDone = completedSteps.indices.all { i -> completedSteps[i] || skippedSteps[i] }
                if (allDone) {
                    // Mark this routine as completed for today
                    prefs.edit()
                        .putBoolean("flutter.routine_completed_${routineId}_$today", true)
                        .commit()

                    // Try to load next routine
                    loadNextRoutine(context, routineId)
                }

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun loadNextRoutine(context: Context, currentRoutineId: String) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val today = getEffectiveDate()

            // Get all routines
            val routinesCount = try {
                prefs.getInt("flutter.routines_count", -1)
            } catch (e: ClassCastException) {
                try {
                    prefs.getLong("flutter.routines_count", -1).toInt()
                } catch (e2: Exception) {
                    -1
                }
            }

            if (routinesCount <= 0) return

            val validRoutines = mutableListOf<JSONObject>()
            for (i in 0 until routinesCount) {
                val routineJson = prefs.getString("flutter.routine_$i", null)
                if (routineJson != null) {
                    try {
                        validRoutines.add(JSONObject(routineJson))
                    } catch (e: Exception) {
                        // Skip invalid routine
                    }
                }
            }

            val currentWeekday = getCurrentWeekday()
            val activeRoutines = validRoutines.filter { routine ->
                val activeDays = routine.optJSONArray("activeDays")
                if (activeDays != null) {
                    for (i in 0 until activeDays.length()) {
                        if (activeDays.getInt(i) == currentWeekday) {
                            return@filter true
                        }
                    }
                }
                false
            }

            // Find current routine index
            val currentIndex = activeRoutines.indexOfFirst { it.optString("id", "") == currentRoutineId }

            // Search for next uncompleted routine
            for (i in (currentIndex + 1) until activeRoutines.size) {
                val routine = activeRoutines[i]
                val routineId = routine.optString("id", "")
                val completedKey = "flutter.routine_completed_${routineId}_$today"
                val isCompleted = prefs.getBoolean(completedKey, false)

                if (!isCompleted) {
                    // Set this as the active routine
                    val overrideData = JSONObject().apply {
                        put("routineId", routineId)
                        put("date", today)
                    }
                    prefs.edit()
                        .putString("flutter.active_routine_override", overrideData.toString())
                        .remove("flutter.morning_routine_progress_$today")
                        .remove("flutter.routine_progress_${routineId}_$today")
                        .commit()
                    return
                }
            }

            // No more uncompleted routines, clear override
            prefs.edit()
                .remove("flutter.active_routine_override")
                .commit()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun postponeCurrentStep(context: Context) {
        android.util.Log.d("RoutineSync", "🔄 Widget: Postpone button clicked")
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getEffectiveDate()
        val routine = getCurrentRoutine(context) ?: return
        val routineId = routine.optString("id", "")
        if (routineId.isEmpty()) return
        val items = routine.optJSONArray("items") ?: return
        val currentIndex = getCurrentStepIndex(context)
        android.util.Log.d("RoutineSync", "🔄 Widget: Postponing step $currentIndex for routine $routineId")

        if (currentIndex >= 0 && currentIndex < items.length()) {
            try {
                val completedSteps = mutableListOf<Boolean>()
                val skippedSteps = mutableListOf<Boolean>()
                val postponedSteps = mutableListOf<Boolean>()

                // Load existing progress
                var progressJson = prefs.getString("flutter.routine_progress_${routineId}_$today", null)
                if (progressJson == null) {
                    progressJson = prefs.getString("flutter.morning_routine_progress_$today", null)
                }
                if (progressJson != null) {
                    val progress = JSONObject(progressJson)
                    val completedArray = progress.optJSONArray("completedSteps")
                    val skippedArray = progress.optJSONArray("skippedSteps")
                    val postponedArray = progress.optJSONArray("postponedSteps")

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
                    if (postponedArray != null) {
                        for (i in 0 until postponedArray.length()) {
                            postponedSteps.add(postponedArray.optBoolean(i, false))
                        }
                    }
                }

                // Ensure lists are the right size
                while (completedSteps.size < items.length()) completedSteps.add(false)
                while (skippedSteps.size < items.length()) skippedSteps.add(false)
                while (postponedSteps.size < items.length()) postponedSteps.add(false)

                // Mark current step as postponed
                postponedSteps[currentIndex] = true
                skippedSteps[currentIndex] = false
                completedSteps[currentIndex] = false

                // Find next step that is not completed, not skipped, not postponed
                var nextStepIndex = currentIndex + 1
                while (nextStepIndex < items.length() &&
                       (completedSteps[nextStepIndex] || skippedSteps[nextStepIndex] || postponedSteps[nextStepIndex])) {
                    nextStepIndex++
                }

                // If all regular steps done, go back to postponed steps
                // Start from the next index to cycle through postponed steps
                if (nextStepIndex >= items.length()) {
                    for (i in 0 until items.length()) {
                        val checkIndex = (currentIndex + 1 + i) % items.length()
                        if (postponedSteps[checkIndex] && !completedSteps[checkIndex]) {
                            nextStepIndex = checkIndex
                            // Clear postponed flag so it can be postponed again
                            postponedSteps[checkIndex] = false
                            break
                        }
                    }
                }

                // Save progress
                val progressData = JSONObject().apply {
                    put("currentStepIndex", nextStepIndex)
                    put("completedSteps", JSONArray(completedSteps))
                    put("skippedSteps", JSONArray(skippedSteps))
                    put("postponedSteps", JSONArray(postponedSteps))
                    put("lastUpdated", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.format(Date()))
                    put("routineId", routineId)
                    put("itemCount", items.length())
                }

                val commitResult = prefs.edit()
                    .putString("flutter.routine_progress_${routineId}_$today", progressData.toString())
                    .putString("flutter.morning_routine_progress_$today", progressData.toString())
                    .putString("flutter.morning_routine_last_date", today)
                    .commit()
                android.util.Log.d("RoutineSync", "🔄 Widget: Saved postpone (commit=$commitResult): nextStep=$nextStepIndex")

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun skipCurrentStep(context: Context) {
        android.util.Log.d("RoutineSync", "🔄 Widget: Skip button clicked")
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getEffectiveDate()
        val routine = getCurrentRoutine(context) ?: return
        val routineId = routine.optString("id", "")
        if (routineId.isEmpty()) return
        val items = routine.optJSONArray("items") ?: return
        val currentIndex = getCurrentStepIndex(context)
        android.util.Log.d("RoutineSync", "🔄 Widget: Skipping step $currentIndex (permanent) for routine $routineId")

        if (currentIndex >= 0 && currentIndex < items.length()) {
            try {
                val completedSteps = mutableListOf<Boolean>()
                val skippedSteps = mutableListOf<Boolean>()
                val postponedSteps = mutableListOf<Boolean>()

                // Load existing progress
                var progressJson = prefs.getString("flutter.routine_progress_${routineId}_$today", null)
                if (progressJson == null) {
                    progressJson = prefs.getString("flutter.morning_routine_progress_$today", null)
                }
                if (progressJson != null) {
                    val progress = JSONObject(progressJson)
                    val completedArray = progress.optJSONArray("completedSteps")
                    val skippedArray = progress.optJSONArray("skippedSteps")
                    val postponedArray = progress.optJSONArray("postponedSteps")

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
                    if (postponedArray != null) {
                        for (i in 0 until postponedArray.length()) {
                            postponedSteps.add(postponedArray.optBoolean(i, false))
                        }
                    }
                }

                // Ensure lists are the right size
                while (completedSteps.size < items.length()) completedSteps.add(false)
                while (skippedSteps.size < items.length()) skippedSteps.add(false)
                while (postponedSteps.size < items.length()) postponedSteps.add(false)

                // Mark current step as permanently skipped
                skippedSteps[currentIndex] = true
                postponedSteps[currentIndex] = false
                completedSteps[currentIndex] = false

                // Find next step that is not completed, not skipped, not postponed
                var nextStepIndex = currentIndex + 1
                while (nextStepIndex < items.length() &&
                       (completedSteps[nextStepIndex] || skippedSteps[nextStepIndex] || postponedSteps[nextStepIndex])) {
                    nextStepIndex++
                }

                // If all regular steps done, go back to postponed steps (but never to skipped)
                // Start from the next index to cycle through postponed steps
                if (nextStepIndex >= items.length()) {
                    for (i in 0 until items.length()) {
                        val checkIndex = (currentIndex + 1 + i) % items.length()
                        if (postponedSteps[checkIndex] && !completedSteps[checkIndex] && !skippedSteps[checkIndex]) {
                            nextStepIndex = checkIndex
                            // Clear postponed flag so it can be postponed again
                            postponedSteps[checkIndex] = false
                            break
                        }
                    }
                }

                // Save progress
                val progressData = JSONObject().apply {
                    put("currentStepIndex", nextStepIndex)
                    put("completedSteps", JSONArray(completedSteps))
                    put("skippedSteps", JSONArray(skippedSteps))
                    put("postponedSteps", JSONArray(postponedSteps))
                    put("lastUpdated", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.format(Date()))
                    put("routineId", routineId)
                    put("itemCount", items.length())
                }

                val commitResult = prefs.edit()
                    .putString("flutter.routine_progress_${routineId}_$today", progressData.toString())
                    .putString("flutter.morning_routine_progress_$today", progressData.toString())
                    .putString("flutter.morning_routine_last_date", today)
                    .commit()
                android.util.Log.d("RoutineSync", "🔄 Widget: Saved skip (commit=$commitResult): nextStep=$nextStepIndex")

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun skipRoutine(context: Context) {
        android.util.Log.d("RoutineSync", "🔄 Widget: Skip routine button clicked")
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = getEffectiveDate()
        val routine = getCurrentRoutine(context) ?: return
        val routineId = routine.optString("id", "")
        if (routineId.isEmpty()) return

        // Mark current routine as completed (skipped)
        prefs.edit()
            .putBoolean("flutter.routine_completed_${routineId}_$today", true)
            .commit()

        // Load next routine
        loadNextRoutine(context, routineId)
    }

    private fun refreshAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, RoutineWidgetProvider::class.java)
        )
        onUpdate(context, appWidgetManager, appWidgetIds)
    }
}