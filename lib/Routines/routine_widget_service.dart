import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routine_service.dart';

class RoutineWidgetService {
  static const MethodChannel _platform = MethodChannel('com.bb.bb_app/routine_widget');

  /// Update routine widget with current data
  static Future<void> updateWidget() async {
    try {
      // Get current routines from SharedPreferences and save them in the format the widget expects
      final routines = await RoutineService.loadRoutines();
      final prefs = await SharedPreferences.getInstance();

      if (routines.isEmpty) {
        return;
      }

      // Use the same method as the main app to identify the active routine
      final activeRoutine = await RoutineService.getCurrentActiveRoutine(routines);

      // Convert routines to JSON format that Android can read
      final routinesJson = routines.map((routine) => jsonEncode(routine.toJson())).toList();

      // Save routines for Android widget to read
      // Flutter automatically adds 'flutter.' prefix to all keys
      await prefs.setStringList('routines', routinesJson);

      // Also save individual routines for easier Android access
      await prefs.setInt('routines_count', routinesJson.length);
      for (int i = 0; i < routinesJson.length; i++) {
        await prefs.setString('routine_$i', routinesJson[i]);
      }

      // Save the active routine ID and data for the widget to use
      if (activeRoutine != null) {
        await prefs.setString('active_routine_id', activeRoutine.id);
        await prefs.setString('active_routine_data', jsonEncode(activeRoutine.toJson()));
        if (kDebugMode) {
          print('Widget: Set active routine to ${activeRoutine.title}');
        }
      } else {
        await prefs.remove('active_routine_id');
        await prefs.remove('active_routine_data');
        if (kDebugMode) {
          print('Widget: No active routine found');
        }
      }

      // Trigger widget update via platform channel
      await _platform.invokeMethod('updateRoutineWidget');
    } catch (e) {
      debugPrint('updateWidget - Error: $e');
    }
  }

  /// Sync widget progress with app progress
  static Future<void> syncWithWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getTodayString();
      
      // Check if widget has made progress
      final widgetProgressJson = prefs.getString('flutter.morning_routine_progress_$today');
      final appProgressJson = await RoutineService.loadRoutineProgress();
      
      if (widgetProgressJson != null && appProgressJson != null) {
        final widgetProgress = jsonDecode(widgetProgressJson);
        final widgetLastUpdated = DateTime.tryParse(widgetProgress['lastUpdated']?.toString() ?? '');
        final appLastUpdated = DateTime.tryParse(appProgressJson['lastUpdated']?.toString() ?? '');
        
        // If widget progress is newer, we don't need to sync back
        if (widgetLastUpdated != null && appLastUpdated != null && 
            widgetLastUpdated.isAfter(appLastUpdated)) {
          // Widget has newer data, no need to sync
          return;
        }
      }
      
      // Update widget with current app progress
      await updateWidget();
    } catch (e) {
      // Silent fail - synchronization is not critical
    }
  }

  /// Check if routine has changed since last widget update
  static Future<bool> shouldUpdateWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routines = await RoutineService.loadRoutines();
      
      final lastWidgetUpdate = prefs.getString('last_widget_routine_update');
      final currentRoutinesHash = _generateRoutinesHash(routines);
      
      if (lastWidgetUpdate != currentRoutinesHash) {
        await prefs.setString('last_widget_routine_update', currentRoutinesHash);
        return true;
      }
      
      return false;
    } catch (e) {
      return true; // Update on error to be safe
    }
  }

  /// Generate a simple hash of routines for change detection
  static String _generateRoutinesHash(List<dynamic> routines) {
    final relevantData = routines.map((routine) {
      final title = routine.title;
      final activeDays = routine.activeDays.toList()..sort();
      final itemsCount = routine.items.length;
      return '$title-$activeDays-$itemsCount';
    }).join('|');
    
    return relevantData.hashCode.toString();
  }

  /// Force refresh widget
  static Future<void> forceRefreshWidget() async {
    try {
      await updateWidget();
      await _platform.invokeMethod('refreshRoutineWidget');
    } catch (e) {
      debugPrint('forceRefreshWidget - Error: $e');
    }
  }

  /// Refresh widget when color changes
  static Future<void> refreshWidgetColor() async {
    try {
      // Just trigger a widget refresh, no need to update routine data
      await _platform.invokeMethod('refreshRoutineWidget');
    } catch (e) {
      debugPrint('refreshWidgetColor - Error: $e');
    }
  }

  /// Check if widget needs daily reset
  static Future<void> checkDailyReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getTodayString();
      final lastResetDate = prefs.getString('routine_widget_last_reset');
      
      if (lastResetDate != today) {
        // New day - update widget and save reset date
        await updateWidget();
        await prefs.setString('routine_widget_last_reset', today);
      }
    } catch (e) {
      // Silent fail
    }
  }
}