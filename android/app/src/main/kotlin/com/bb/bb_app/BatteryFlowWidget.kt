package com.bb.bb_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class BatteryFlowWidget : AppWidgetProvider() {
    companion object {
        private const val ACTION_BATTERY_MINUS = "com.bb.bb_app.BATTERY_MINUS"
        private const val ACTION_BATTERY_PLUS = "com.bb.bb_app.BATTERY_PLUS"
        private const val ACTION_FLOW_PLUS_1 = "com.bb.bb_app.FLOW_PLUS_1"
        private const val ACTION_FLOW_PLUS_2 = "com.bb.bb_app.FLOW_PLUS_2"
        private const val ACTION_OPEN_APP = "com.bb.bb_app.OPEN_APP_ENERGY"
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

        when (intent.action) {
            ACTION_BATTERY_MINUS -> adjustBattery(context, -10)
            ACTION_BATTERY_PLUS -> adjustBattery(context, 10)
            ACTION_FLOW_PLUS_1 -> addFlowPoints(context, 1)
            ACTION_FLOW_PLUS_2 -> addFlowPoints(context, 2)
        }

        // Update all widgets after any action
        if (intent.action in listOf(ACTION_BATTERY_MINUS, ACTION_BATTERY_PLUS, ACTION_FLOW_PLUS_1, ACTION_FLOW_PLUS_2)) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, BatteryFlowWidget::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun adjustBattery(context: Context, change: Int) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val dateKey = getTodayKey()

            // Get today's record
            val recordJson = prefs.getString("flutter.$dateKey", null)
            if (recordJson != null) {
                val record = JSONObject(recordJson)
                val currentBattery = record.optInt("currentBattery", 100)
                val newBattery = currentBattery + change

                // Update battery
                record.put("currentBattery", newBattery)

                prefs.edit()
                    .putString("flutter.$dateKey", record.toString())
                    .apply()
            }
        } catch (e: Exception) {
            android.util.Log.e("BatteryFlowWidget", "Error adjusting battery: ${e.message}", e)
        }
    }

    private fun addFlowPoints(context: Context, points: Int) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val dateKey = getTodayKey()

            // Get today's record
            val recordJson = prefs.getString("flutter.$dateKey", null)
            if (recordJson != null) {
                val record = JSONObject(recordJson)
                val currentFlowPoints = record.optInt("flowPoints", 0)
                val flowGoal = record.optInt("flowGoal", 10)
                val newFlowPoints = currentFlowPoints + points

                // Update flow points
                record.put("flowPoints", newFlowPoints)

                // Check if goal is met
                val isGoalMet = newFlowPoints >= flowGoal
                record.put("isGoalMet", isGoalMet)

                prefs.edit()
                    .putString("flutter.$dateKey", record.toString())
                    .apply()
            }
        } catch (e: Exception) {
            android.util.Log.e("BatteryFlowWidget", "Error adding flow points: ${e.message}", e)
        }
    }

    private fun getEnergyData(context: Context): EnergyData {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val dateKey = getTodayKey()

            // Get today's record
            val recordJson = prefs.getString("flutter.$dateKey", null)
            if (recordJson != null) {
                val record = JSONObject(recordJson)
                val currentBattery = record.optInt("currentBattery", 100)
                val flowPoints = record.optInt("flowPoints", 0)
                val flowGoal = record.optInt("flowGoal", 10)

                // Get streak from settings
                val settingsJson = prefs.getString("flutter.energy_settings", null)
                val currentStreak = if (settingsJson != null) {
                    val settings = JSONObject(settingsJson)
                    settings.optInt("currentStreak", 0)
                } else {
                    0
                }

                return EnergyData(currentBattery, flowPoints, flowGoal, currentStreak)
            }
        } catch (e: Exception) {
            android.util.Log.e("BatteryFlowWidget", "Error loading energy data: ${e.message}", e)
        }

        return EnergyData(100, 0, 10, 0)
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val energyData = getEnergyData(context)
            val views = RemoteViews(context.packageName, R.layout.battery_flow_widget)

            // Get background color from SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val defaultColor = 0xB3202020.toInt() // Transparent dark grey (70% opacity)
            val backgroundColor = prefs.getInt("flutter.widget_battery_flow_color", defaultColor)

            // Apply background color to widget
            views.setInt(R.id.widget_body, "setBackgroundColor", backgroundColor)

            // Update battery display
            views.setTextViewText(R.id.battery_text, "${energyData.battery}%")

            // Update flow display (compact format for horizontal layout)
            views.setTextViewText(R.id.flow_text, "${energyData.flowPoints}/${energyData.flowGoal}")

            // Update streak display
            if (energyData.streak > 0) {
                views.setTextViewText(R.id.streak_text, "\uD83D\uDD25 ${energyData.streak}")
                views.setViewVisibility(R.id.streak_text, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.streak_text, android.view.View.GONE)
            }

            // Set up button intents
            setupButtonIntent(context, views, R.id.button_battery_minus, ACTION_BATTERY_MINUS, appWidgetId)
            setupButtonIntent(context, views, R.id.button_battery_plus, ACTION_BATTERY_PLUS, appWidgetId)
            setupButtonIntent(context, views, R.id.button_flow_plus_1, ACTION_FLOW_PLUS_1, appWidgetId)
            setupButtonIntent(context, views, R.id.button_flow_plus_2, ACTION_FLOW_PLUS_2, appWidgetId)

            // Set up tap on widget body to open app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_energy_card", true)
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 1000,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_body, openAppPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            android.util.Log.e("BatteryFlowWidget", "Error updating widget: ${e.message}", e)
        }
    }

    private fun setupButtonIntent(
        context: Context,
        views: RemoteViews,
        buttonId: Int,
        action: String,
        appWidgetId: Int
    ) {
        val intent = Intent(context, BatteryFlowWidget::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            buttonId + appWidgetId * 100, // Unique request code
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(buttonId, pendingIntent)
    }

    private fun getTodayKey(): String {
        val now = Calendar.getInstance()
        val year = now.get(Calendar.YEAR)
        val month = now.get(Calendar.MONTH) + 1 // Calendar.MONTH is 0-based
        val day = now.get(Calendar.DAY_OF_MONTH)
        return "energy_today_${year}_${month}_$day"
    }

    private data class EnergyData(
        val battery: Int,
        val flowPoints: Int,
        val flowGoal: Int,
        val streak: Int
    )
}
