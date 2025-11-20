import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Tasks/task_list_widget_service.dart';
import 'timezone_utils.dart';
import 'error_logger.dart';

/// Service to manage widget updates, especially on new day detection
class WidgetUpdateService {
  static const MethodChannel _waterChannel = MethodChannel('com.bb.bb_app/water_widget');

  /// Check if it's a new day and update all widgets if needed
  /// Uses effective date logic (5 AM cutoff) to determine day boundaries
  /// Also ensures task widget is always refreshed on app startup
  static Future<void> checkAndUpdateWidgetsOnNewDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getEffectiveDateString();
      final lastUpdateDate = prefs.getString('widget_last_update_date');

      // Check if task widget data exists
      final widgetTasksExist = prefs.containsKey('flutter.widget_filtered_tasks');

      if (lastUpdateDate != today || !widgetTasksExist) {
        // Update all widgets
        await Future.wait([
          _updateTaskWidget(),
          _updateWaterWidget(),
        ]);

        // Save the new date
        await prefs.setString('widget_last_update_date', today);
      } else {
        // Not a new day, but still refresh task widget to ensure it has current phase filtering
        await _updateTaskWidget();
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'WidgetUpdateService.checkAndUpdateWidgetsOnNewDay',
        error: 'Error checking/updating widgets on new day: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Force update all widgets (useful for manual refresh)
  static Future<void> updateAllWidgets() async {
    try {
      await Future.wait([
        _updateTaskWidget(),
        _updateWaterWidget(),
      ]);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'WidgetUpdateService.updateAllWidgets',
        error: 'Error updating all widgets: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Update task list widget
  static Future<void> _updateTaskWidget() async {
    try {
      await TaskListWidgetService.updateWidget();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'WidgetUpdateService._updateTaskWidget',
        error: 'Error updating task widget: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Update water widget by triggering AppWidgetManager.notifyAppWidgetViewDataChanged
  static Future<void> _updateWaterWidget() async {
    try {
      await _waterChannel.invokeMethod('updateWaterWidget');
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'WidgetUpdateService._updateWaterWidget',
        error: 'Error updating water widget: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Get today's effective date as a string (YYYY-MM-DD format)
  /// Uses 2 AM cutoff - times before 2 AM are considered part of previous day
  static String _getEffectiveDateString() {
    return TimezoneUtils.getEffectiveDateString();
  }
}
