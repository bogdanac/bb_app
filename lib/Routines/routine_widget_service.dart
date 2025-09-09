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
      
      debugPrint('DEBUG: updateWidget - Found ${routines.length} routines');
      
      // Convert routines to JSON format that Android can read
      final routinesJson = routines.map((routine) => jsonEncode(routine.toJson())).toList();
      await prefs.setStringList('routines', routinesJson);
      
      // Debug: Check what we saved
      final savedRoutines = prefs.getStringList('routines');
      debugPrint('DEBUG: updateWidget - Saved ${savedRoutines?.length ?? 0} routines to SharedPreferences');
      
      // Also log all SharedPreferences keys to see what's actually stored
      debugPrint('DEBUG: updateWidget - All SharedPreferences keys: ${prefs.getKeys()}');
      
      // Trigger widget update via platform channel
      await _platform.invokeMethod('updateRoutineWidget');
    } catch (e) {
      // Silent fail - widget updates are not critical
    }
  }

  /// Sync widget progress with app progress
  static Future<void> syncWithWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getTodayString();
      
      // Check if widget has made progress
      final widgetProgressJson = prefs.getString('flutter.morning_routine_progress_$today');
      final appProgressJson = await RoutineService.loadMorningRoutineProgress();
      
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
      debugPrint('DEBUG: forceRefreshWidget - Starting force refresh');
      await updateWidget();
      await _platform.invokeMethod('refreshRoutineWidget');
      debugPrint('DEBUG: forceRefreshWidget - Completed force refresh');
    } catch (e) {
      debugPrint('DEBUG: forceRefreshWidget - Error: $e');
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