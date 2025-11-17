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

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        android.util.Log.d("TaskListWidget", "onUpdate called with ${appWidgetIds.size} widget(s)")
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

        android.util.Log.d("TaskListWidget", "Received intent: ${intent.action}")

        when (intent.action) {
            ACTION_OPEN_APP -> {
                android.util.Log.d("TaskListWidget", "Processing OPEN_APP action")
                openApp(context)
            }
            ACTION_COMPLETE_TASK -> {
                val taskId = intent.getStringExtra("task_id")
                android.util.Log.d("TaskListWidget", "Processing COMPLETE_TASK action for task: $taskId")
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
                putExtra("open_task_list", true)  // Changed from "widget_trigger" to "open_task_list"
            }

            try {
                context.startActivity(launchIntent)
                android.util.Log.d("TaskListWidget", "Launched app with open_task_list intent")
            } catch (e: Exception) {
                android.util.Log.e("TaskListWidget", "Failed to launch app: $e")
            }
        } else {
            android.util.Log.e("TaskListWidget", "Could not get launch intent for app")
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        android.util.Log.d("TaskListWidget", "Updating widget $appWidgetId")

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

            android.util.Log.d("TaskListWidget", "Successfully updated widget $appWidgetId with ${tasks.size} tasks")

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
            android.util.Log.d("TaskListWidget", "Loading tasks from SharedPreferences")
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Debug: Log all keys in SharedPreferences
            val allKeys = prefs.all.keys
            android.util.Log.d("TaskListWidget", "Available keys: ${allKeys.joinToString(", ")}")

            // Flutter's shared_preferences stores List<String> with a special encoding
            var tasksJsonStringList: List<String>? = null

            // PRIORITY 1: Try reading filtered widget tasks (pre-filtered with menstrual phase ON)
            val widgetTasksRawValue = prefs.all["flutter.widget_filtered_tasks"]
            android.util.Log.d("TaskListWidget", "Attempting to load flutter.widget_filtered_tasks: type=${widgetTasksRawValue?.javaClass?.simpleName}")

            if (widgetTasksRawValue != null) {
                when (widgetTasksRawValue) {
                    is String -> {
                        android.util.Log.d("TaskListWidget", "Widget tasks is String, length=${widgetTasksRawValue.length}")
                        val LIST_IDENTIFIER = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

                        if (widgetTasksRawValue.startsWith(LIST_IDENTIFIER)) {
                            try {
                                var encodedData = widgetTasksRawValue.substring(LIST_IDENTIFIER.length)
                                if (encodedData.startsWith("!")) {
                                    encodedData = encodedData.substring(1)
                                }
                                val jsonArray = JSONArray(encodedData)
                                tasksJsonStringList = (0 until jsonArray.length()).map { jsonArray.getString(it) }
                                android.util.Log.d("TaskListWidget", "Successfully loaded ${tasksJsonStringList.size} filtered widget tasks")
                            } catch (e: Exception) {
                                android.util.Log.e("TaskListWidget", "Failed to decode widget tasks: $e")
                            }
                        } else {
                            try {
                                val jsonArray = JSONArray(widgetTasksRawValue)
                                tasksJsonStringList = (0 until jsonArray.length()).map { jsonArray.getString(it) }
                                android.util.Log.d("TaskListWidget", "Successfully loaded ${tasksJsonStringList.size} widget tasks from JSON")
                            } catch (e: Exception) {
                                android.util.Log.e("TaskListWidget", "Failed to parse widget tasks: $e")
                            }
                        }
                    }
                    is Set<*> -> {
                        tasksJsonStringList = widgetTasksRawValue.filterIsInstance<String>()
                        android.util.Log.d("TaskListWidget", "Loaded ${tasksJsonStringList.size} widget tasks from Set")
                    }
                    is List<*> -> {
                        tasksJsonStringList = widgetTasksRawValue.filterIsInstance<String>()
                        android.util.Log.d("TaskListWidget", "Loaded ${tasksJsonStringList.size} widget tasks from List")
                    }
                }
            }

            // NO FALLBACK: Widget should ONLY show pre-filtered tasks from flutter.widget_filtered_tasks
            // This ensures menstrual phase filtering is always active (flower icon ON behavior)
            if (tasksJsonStringList == null || tasksJsonStringList.isEmpty()) {
                android.util.Log.d("TaskListWidget", "No widget_filtered_tasks found - showing empty list (menstrual filter active)")
            }

            if (tasksJsonStringList == null || tasksJsonStringList.isEmpty()) {
                android.util.Log.w("TaskListWidget", "No tasks found in SharedPreferences")
                return emptyList()
            }

            val tasks = mutableListOf<TaskData>()

            android.util.Log.d("TaskListWidget", "Found ${tasksJsonStringList.size} total tasks in storage")

            for ((index, taskJsonString) in tasksJsonStringList.withIndex()) {
                try {
                    val taskJson = JSONObject(taskJsonString)

                    val isCompleted = taskJson.optBoolean("isCompleted", false)
                    if (isCompleted) {
                        android.util.Log.d("TaskListWidget", "Task $index is completed, skipping")
                        continue
                    }

                    val task = parseTask(taskJson)
                    if (task != null) {
                        tasks.add(task)
                        android.util.Log.d("TaskListWidget", "Added task: ${task.title}")
                    } else {
                        android.util.Log.w("TaskListWidget", "Failed to parse task $index")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("TaskListWidget", "Error parsing task $index: $e")
                }
            }

            android.util.Log.d("TaskListWidget", "Loaded ${tasks.size} incomplete tasks")

            // Return first MAX_TASKS_DISPLAY tasks (already sorted by priority in storage)
            val result = tasks.take(MAX_TASKS_DISPLAY)
            android.util.Log.d("TaskListWidget", "Returning ${result.size} tasks for display")
            return result

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
            android.util.Log.e("TaskListWidget", "Error parsing task: $e")
            null
        }
    }

    private fun displayTasks(context: Context, views: RemoteViews, tasks: List<TaskData>) {
        android.util.Log.d("TaskListWidget", "Displaying ${tasks.size} tasks")

        if (tasks.isEmpty()) {
            android.util.Log.d("TaskListWidget", "No tasks to display, showing 'No tasks' message")
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
            android.util.Log.d("TaskListWidget", "Completing task: $taskId")
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
                    android.util.Log.d("TaskListWidget", "Marked task as completed: $taskId")
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
                android.util.Log.d("TaskListWidget", "Saved updated tasks with Flutter encoding")

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
            android.util.Log.d("TaskListWidget", "Updating filtered widget tasks after completing: $completedTaskId")
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
                android.util.Log.d("TaskListWidget", "No filtered widget tasks found - will refresh on next app open")
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
                    android.util.Log.d("TaskListWidget", "Removed completed task from widget list: $completedTaskId")
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
                android.util.Log.d("TaskListWidget", "Saved updated filtered widget tasks (${updatedWidgetTasks.size} remaining)")
            } else {
                android.util.Log.d("TaskListWidget", "Task not found in filtered list - may have already been removed")
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
            android.util.Log.d("TaskListWidget", "Refreshing ${appWidgetIds.size} widgets")
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
