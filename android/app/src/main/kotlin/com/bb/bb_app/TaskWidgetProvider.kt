package com.bb.bb_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class TaskWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val ACTION_ADD_TASK = "com.bb.bb_app.ADD_TASK"
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
        
        android.util.Log.d("TaskWidget", "Received intent: ${intent.action}")
        
        if (ACTION_ADD_TASK == intent.action) {
            android.util.Log.d("TaskWidget", "Processing ADD_TASK action")
            openTaskDialog(context)
        }
    }

    private fun openTaskDialog(context: Context) {
        // Launch the main app with a special intent to open task creation dialog
        val packageManager = context.packageManager
        val launchIntent = packageManager.getLaunchIntentForPackage(context.packageName)
        
        if (launchIntent != null) {
            launchIntent.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("action", "create_task")
                putExtra("widget_trigger", true)
            }
            
            try {
                context.startActivity(launchIntent)
                android.util.Log.d("TaskWidget", "Launched app for task creation")
            } catch (e: Exception) {
                android.util.Log.e("TaskWidget", "Failed to launch app: $e")
            }
        } else {
            android.util.Log.e("TaskWidget", "Could not get launch intent for app")
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.task_widget)

        // Set click intent to add task
        val intent = Intent(context, TaskWidgetProvider::class.java).apply {
            action = ACTION_ADD_TASK
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.task_button, pendingIntent)

        android.util.Log.d("TaskWidget", "Set up click listener for task widget $appWidgetId")

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}