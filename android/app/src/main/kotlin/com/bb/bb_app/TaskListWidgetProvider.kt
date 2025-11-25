package com.bb.bb_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import android.util.Base64

class TaskListWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val ACTION_OPEN_APP = "com.bb.bb_app.OPEN_APP"
        private const val ACTION_COMPLETE_TASK = "com.bb.bb_app.COMPLETE_TASK"
        private const val MAX_TASKS_DISPLAY = 2
    }

    private fun logWidgetDebug(prefs: android.content.SharedPreferences, message: String, context: Map<String, String> = emptyMap()) {
        try {
            val timestamp = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US).format(java.util.Date())
            val logEntry = org.json.JSONObject().apply {
                put("source", "TaskListWidgetProvider")
                put("message", message)
                put("context", org.json.JSONObject(context))
                put("timestamp", timestamp)
            }

            val existingLogs = prefs.getString("flutter.widget_debug_logs", "[]")
            val logsArray = org.json.JSONArray(existingLogs)
            logsArray.put(logEntry)

            // Clean up logs older than 7 days
            val sevenDaysAgo = java.util.Date(System.currentTimeMillis() - (7 * 24 * 60 * 60 * 1000))
            val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)

            val filteredLogs = org.json.JSONArray()
            for (i in 0 until logsArray.length()) {
                try {
                    val log = logsArray.getJSONObject(i)
                    val logTimestamp = dateFormat.parse(log.getString("timestamp"))
                    if (logTimestamp != null && logTimestamp.after(sevenDaysAgo)) {
                        filteredLogs.put(log)
                    }
                } catch (e: Exception) {
                    filteredLogs.put(logsArray.get(i)) // Keep if can't parse
                }
            }

            // Keep only last 500 logs as backup limit
            while (filteredLogs.length() > 500) {
                filteredLogs.remove(0)
            }

            prefs.edit().putString("flutter.widget_debug_logs", filteredLogs.toString()).apply()
        } catch (e: Exception) {
            // Silently fail
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                android.util.Log.e("TaskListWidget", "Error updating widget $appWidgetId: $e")
                e.printStackTrace()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_OPEN_APP -> {
                openApp(context)
            }
            ACTION_COMPLETE_TASK -> {
                val taskId = intent.getStringExtra("task_id")
                if (taskId != null) {
                    completeTask(context, taskId)
                    refreshAllWidgets(context)
                }
            }
        }
    }

    private fun openApp(context: Context) {
        // Launch the main app and navigate to task list (without showing add dialog)
        val packageManager = context.packageManager
        val launchIntent = packageManager.getLaunchIntentForPackage(context.packageName)

        if (launchIntent != null) {
            launchIntent.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("open_task_list", true)
            }

            try {
                context.startActivity(launchIntent)
            } catch (e: Exception) {
                android.util.Log.e("TaskListWidget", "Failed to launch app: $e")
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {

        try {
            val views = RemoteViews(context.packageName, R.layout.task_list_widget)

            // Apply custom background color
            applyCustomBackgroundColor(context, views)

            // Set click intent to open app when clicking widget background
            val intent = Intent(context, TaskListWidgetProvider::class.java).apply {
                action = ACTION_OPEN_APP
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.task_list_container, pendingIntent)

            // Load and display tasks
            val tasks = loadTasks(context)
            displayTasks(context, views, tasks)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            android.util.Log.e("TaskListWidget", "Error in updateAppWidget for widget $appWidgetId: $e")
            e.printStackTrace()
        }
    }

    private fun applyCustomBackgroundColor(context: Context, views: RemoteViews) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val defaultColor = 0xB3202020.toInt() // Default transparent dark grey (70% opacity)

            // Try different possible keys for task list widget color
            var customColor = defaultColor
            val possibleKeys = listOf(
                "flutter.widget_tasklist_color",
                "widget_tasklist_color",
                "flutter.widget_background_color",
                "widget_background_color"
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

            // Set the background color of the widget root (outer container with padding)
            views.setInt(R.id.task_list_widget_root, "setBackgroundColor", customColor)
        } catch (e: Exception) {
            android.util.Log.e("TaskListWidget", "Error applying custom background color: $e")
        }
    }

    private fun loadTasks(context: Context): List<TaskData> {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Force reload from disk to get latest Flutter changes
            prefs.all

            val allKeys = prefs.all.keys

            // Log to SharedPreferences for Flutter to upload to Firebase
            logWidgetDebug(prefs, "Loading tasks", mapOf(
                "availableKeys" to allKeys.size.toString()
            ))

            // Flutter's shared_preferences stores List<String> with a special encoding
            var tasksJsonStringList: List<String>? = null

            // PRIORITY 1: Try reading filtered widget tasks (pre-filtered with menstrual phase ON)
            val widgetTasksRawValue = prefs.all["flutter.widget_filtered_tasks"]

            if (widgetTasksRawValue != null) {
                when (widgetTasksRawValue) {
                    is String -> {
                        val LIST_IDENTIFIER = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

                        if (widgetTasksRawValue.startsWith(LIST_IDENTIFIER)) {
                            try {
                                var encodedData = widgetTasksRawValue.substring(LIST_IDENTIFIER.length)
                                if (encodedData.startsWith("!")) {
                                    encodedData = encodedData.substring(1)
                                }
                                val jsonArray = JSONArray(encodedData)
                                tasksJsonStringList = (0 until jsonArray.length()).map { jsonArray.getString(it) }
                            } catch (e: Exception) {
                                // Failed to decode
                            }
                        } else {
                            try {
                                val jsonArray = JSONArray(widgetTasksRawValue)
                                tasksJsonStringList = (0 until jsonArray.length()).map { jsonArray.getString(it) }
                            } catch (e: Exception) {
                                // Failed to parse
                            }
                        }
                    }
                    is Set<*> -> {
                        tasksJsonStringList = widgetTasksRawValue.filterIsInstance<String>()
                    }
                    is List<*> -> {
                        tasksJsonStringList = widgetTasksRawValue.filterIsInstance<String>()
                    }
                }
            }

            // NO FALLBACK: Widget should ONLY show pre-filtered tasks from flutter.widget_filtered_tasks
            // This ensures menstrual phase filtering is always active (flower icon ON behavior)
            if (tasksJsonStringList == null || tasksJsonStringList.isEmpty()) {
                // Log to SharedPreferences for Flutter to upload to Firebase
                logWidgetDebug(prefs, "TaskListWidget: No tasks to display", mapOf(
                    "keyExists" to (widgetTasksRawValue != null).toString(),
                    "isEmpty" to (tasksJsonStringList?.isEmpty()?.toString() ?: "null"),
                    "totalKeys" to allKeys.size.toString()
                ))
            }

            if (tasksJsonStringList == null || tasksJsonStringList.isEmpty()) {
                return emptyList()
            }

            val tasks = mutableListOf<TaskData>()

            for (taskJsonString in tasksJsonStringList) {
                try {
                    val taskJson = JSONObject(taskJsonString)

                    val isCompleted = taskJson.optBoolean("isCompleted", false)
                    if (isCompleted) {
                        continue
                    }

                    val task = parseTask(taskJson)
                    if (task != null) {
                        tasks.add(task)
                    }
                } catch (e: Exception) {
                    // Skip invalid task
                }
            }

            // Return first MAX_TASKS_DISPLAY tasks (already sorted by priority in storage)
            return tasks.take(MAX_TASKS_DISPLAY)

        } catch (e: Exception) {
            android.util.Log.e("TaskListWidget", "Error loading tasks: $e")
            e.printStackTrace()
            return emptyList()
        }
    }

    private fun parseTask(taskJson: JSONObject): TaskData? {
        return try {
            TaskData(
                id = taskJson.getString("id"),
                title = taskJson.getString("title"),
                isImportant = taskJson.optBoolean("isImportant", false)
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun displayTasks(context: Context, views: RemoteViews, tasks: List<TaskData>) {
        if (tasks.isEmpty()) {
            views.setViewVisibility(R.id.no_tasks_message, View.VISIBLE)
            views.setViewVisibility(R.id.task_list_container, View.GONE)
            return
        }

        views.setViewVisibility(R.id.no_tasks_message, View.GONE)
        views.setViewVisibility(R.id.task_list_container, View.VISIBLE)

        // Task view IDs
        val taskContainerIds = listOf(
            R.id.task_1_container,
            R.id.task_2_container,
            R.id.task_3_container,
            R.id.task_4_container,
            R.id.task_5_container
        )

        val taskTitleIds = listOf(
            R.id.task_1_title,
            R.id.task_2_title,
            R.id.task_3_title,
            R.id.task_4_title,
            R.id.task_5_title
        )

        val taskCompleteButtonIds = listOf(
            R.id.task_1_complete,
            R.id.task_2_complete,
            R.id.task_3_complete,
            R.id.task_4_complete,
            R.id.task_5_complete
        )

        // Display up to MAX_TASKS_DISPLAY tasks
        for (i in 0 until MAX_TASKS_DISPLAY) {
            if (i < tasks.size) {
                views.setViewVisibility(taskContainerIds[i], View.VISIBLE)
                val taskTitle = if (tasks[i].isImportant) "⭐ ${tasks[i].title}" else tasks[i].title
                views.setTextViewText(taskTitleIds[i], taskTitle)

                // Set up complete button click
                val completeIntent = Intent(context, TaskListWidgetProvider::class.java).apply {
                    action = ACTION_COMPLETE_TASK
                    putExtra("task_id", tasks[i].id)
                }
                val completePendingIntent = PendingIntent.getBroadcast(
                    context,
                    tasks[i].id.hashCode(), // Use unique request code per task
                    completeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(taskCompleteButtonIds[i], completePendingIntent)
            } else {
                views.setViewVisibility(taskContainerIds[i], View.GONE)
            }
        }

        // Show "more tasks" indicator if needed
        if (tasks.size > MAX_TASKS_DISPLAY) {
            views.setViewVisibility(R.id.more_tasks, View.VISIBLE)
            views.setTextViewText(R.id.more_tasks, "+${tasks.size - MAX_TASKS_DISPLAY} more")
        } else {
            views.setViewVisibility(R.id.more_tasks, View.GONE)
        }
    }

    private fun completeTask(context: Context, taskId: String) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Try to load tasks using the same approach as loadTasks()
            var tasksJsonStringList: List<String>? = null
            val LIST_IDENTIFIER = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

            val rawValue = prefs.all["flutter.tasks"]
            if (rawValue is String) {
                if (rawValue.startsWith(LIST_IDENTIFIER)) {
                    // Flutter's encoded format: PREFIX + "!" + JSON
                    try {
                        var encodedData = rawValue.substring(LIST_IDENTIFIER.length)
                        if (encodedData.startsWith("!")) {
                            encodedData = encodedData.substring(1)
                        }
                        val jsonArray = JSONArray(encodedData)
                        tasksJsonStringList = (0 until jsonArray.length()).map { jsonArray.getString(it) }
                    } catch (e: Exception) {
                        android.util.Log.e("TaskListWidget", "Failed to decode tasks: $e")
                    }
                } else {
                    // Plain JSON array
                    try {
                        val jsonArray = JSONArray(rawValue)
                        tasksJsonStringList = (0 until jsonArray.length()).map { jsonArray.getString(it) }
                    } catch (e: Exception) {
                        android.util.Log.e("TaskListWidget", "Failed to parse tasks: $e")
                    }
                }
            } else if (rawValue is Set<*>) {
                tasksJsonStringList = rawValue.filterIsInstance<String>()
            }

            if (tasksJsonStringList == null) {
                android.util.Log.e("TaskListWidget", "No tasks found to complete")
                return
            }

            val updatedTasksList = mutableListOf<String>()
            var taskCompleted = false

            for (taskJsonString in tasksJsonStringList) {
                val taskJson = JSONObject(taskJsonString)
                val id = taskJson.getString("id")

                if (id == taskId) {
                    // Mark task as completed
                    taskJson.put("isCompleted", true)
                    taskJson.put("completedAt", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date()))
                    taskCompleted = true
                }

                updatedTasksList.add(taskJson.toString())
            }

            if (taskCompleted) {
                // Save back to SharedPreferences using Flutter's encoding format: PREFIX + "!" + JSON
                val jsonArray = JSONArray(updatedTasksList)
                val encodedValue = LIST_IDENTIFIER + "!" + jsonArray.toString()

                prefs.edit()
                    .putString("flutter.tasks", encodedValue)
                    .apply()

                // ALSO update the filtered widget tasks list
                updateFilteredWidgetTasks(context, taskId)
            }
        } catch (e: Exception) {
            android.util.Log.e("TaskListWidget", "Error completing task: $e")
            e.printStackTrace()
        }
    }

    private fun updateFilteredWidgetTasks(context: Context, completedTaskId: String) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Load the filtered widget tasks
            val widgetTasksRawValue = prefs.all["flutter.widget_filtered_tasks"]
            var widgetTasksList: MutableList<String>? = null
            val LIST_IDENTIFIER = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

            if (widgetTasksRawValue != null) {
                when (widgetTasksRawValue) {
                    is String -> {
                        if (widgetTasksRawValue.startsWith(LIST_IDENTIFIER)) {
                            try {
                                var encodedData = widgetTasksRawValue.substring(LIST_IDENTIFIER.length)
                                if (encodedData.startsWith("!")) {
                                    encodedData = encodedData.substring(1)
                                }
                                val jsonArray = JSONArray(encodedData)
                                widgetTasksList = (0 until jsonArray.length()).map { jsonArray.getString(it) }.toMutableList()
                            } catch (e: Exception) {
                                android.util.Log.e("TaskListWidget", "Failed to decode widget tasks: $e")
                            }
                        } else {
                            try {
                                val jsonArray = JSONArray(widgetTasksRawValue)
                                widgetTasksList = (0 until jsonArray.length()).map { jsonArray.getString(it) }.toMutableList()
                            } catch (e: Exception) {
                                android.util.Log.e("TaskListWidget", "Failed to parse widget tasks: $e")
                            }
                        }
                    }
                    is Set<*> -> {
                        widgetTasksList = widgetTasksRawValue.filterIsInstance<String>().toMutableList()
                    }
                    is List<*> -> {
                        widgetTasksList = widgetTasksRawValue.filterIsInstance<String>().toMutableList()
                    }
                }
            }

            if (widgetTasksList == null) {
                return
            }

            // Remove the completed task from the filtered list
            val updatedWidgetTasks = mutableListOf<String>()
            var taskRemoved = false

            for (taskJsonString in widgetTasksList) {
                val taskJson = JSONObject(taskJsonString)
                val id = taskJson.getString("id")

                if (id == completedTaskId) {
                    // Skip this task - don't add to updated list
                    taskRemoved = true
                } else {
                    // Keep this task
                    updatedWidgetTasks.add(taskJson.toString())
                }
            }

            if (taskRemoved) {
                // Save updated filtered tasks back to SharedPreferences
                val jsonArray = JSONArray(updatedWidgetTasks)
                val encodedValue = LIST_IDENTIFIER + "!" + jsonArray.toString()

                prefs.edit()
                    .putString("flutter.widget_filtered_tasks", encodedValue)
                    .apply()
            }
        } catch (e: Exception) {
            android.util.Log.e("TaskListWidget", "Error updating filtered widget tasks: $e")
            e.printStackTrace()
        }
    }

    private fun refreshAllWidgets(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, TaskListWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        } catch (e: Exception) {
            android.util.Log.e("TaskListWidget", "Error refreshing widgets: $e")
            e.printStackTrace()
        }
    }

    private data class TaskData(
        val id: String,
        val title: String,
        val isImportant: Boolean
    )
}
