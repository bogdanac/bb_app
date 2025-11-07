import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Tasks/task_list_widget_service.dart';
import 'timezone_utils.dart';

/// Service to manage widget updates, especially on new day detection
class WidgetUpdateService {
  static const MethodChannel _waterChannel = MethodChannel('com.bb.bb_app/water_widget');

  /// Check if it's a new day and update all widgets if needed
  /// Uses effective date logic (5 AM cutoff) to determine day boundaries
  static Future<void> checkAndUpdateWidgetsOnNewDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getEffectiveDateString();
      final lastUpdateDate = prefs.getString('widget_last_update_date');

      if (lastUpdateDate != today) {
        if (kDebugMode) {
          print('New day detected! Last update: $lastUpdateDate, Today: $today');
          print('Updating all widgets...');
        }

        // Update all widgets
        await Future.wait([
          _updateTaskWidget(),
          _updateWaterWidget(),
        ]);

        // Save the new date
        await prefs.setString('widget_last_update_date', today);

        if (kDebugMode) {
          print('All widgets updated for new day');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR checking/updating widgets on new day: $e');
      }
    }
  }

  /// Force update all widgets (useful for manual refresh)
  static Future<void> updateAllWidgets() async {
    try {
      await Future.wait([
        _updateTaskWidget(),
        _updateWaterWidget(),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR updating all widgets: $e');
      }
    }
  }

  /// Update task list widget
  static Future<void> _updateTaskWidget() async {
    try {
      await TaskListWidgetService.updateWidget();
      if (kDebugMode) {
        print('Task widget updated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR updating task widget: $e');
      }
    }
  }

  /// Update water widget by triggering AppWidgetManager.notifyAppWidgetViewDataChanged
  static Future<void> _updateWaterWidget() async {
    try {
      await _waterChannel.invokeMethod('updateWaterWidget');
      if (kDebugMode) {
        print('Water widget updated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR updating water widget: $e');
      }
    }
  }

  /// Get today's effective date as a string (YYYY-MM-DD format)
  /// Uses 2 AM cutoff - times before 2 AM are considered part of previous day
  static String _getEffectiveDateString() {
    return TimezoneUtils.getEffectiveDateString();
  }
}
