import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import '../Notifications/centralized_notification_manager.dart';
import 'routine_widget_service.dart';
import 'routine_progress_service.dart';
import '../shared/timezone_utils.dart';

class RoutineService {
  static const String _routinesKey = 'routines';
  static const String _routineProgressPrefix = 'routine_progress_';
  static const String _routineLastDateKey = 'routine_last_date';

  /// Get today's date in yyyy-MM-dd format
  static String getTodayString() {
    return TimezoneUtils.getTodayString();
  }

  /// Get the effective date for routine purposes (after 2 AM)
  static String getEffectiveDate() {
    return TimezoneUtils.getEffectiveDateString();
  }

  /// Load all routines from SharedPreferences
  static Future<List<Routine>> loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> routinesJson;
    try {
      routinesJson = prefs.getStringList(_routinesKey) ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Routines data type mismatch, clearing corrupted data');
      }
      await prefs.remove(_routinesKey);
      routinesJson = [];
    }

    if (routinesJson.isEmpty) {
      // Return default routine
      return [
        Routine(
          id: '1',
          title: 'Daily Routine',
          items: [
            RoutineItem(id: '1', text: '☀️ Stretch and breathe', isCompleted: false),
            RoutineItem(id: '2', text: '💧 Drink a glass of water', isCompleted: false),
            RoutineItem(id: '3', text: '🧘 5 minutes meditation', isCompleted: false),
            RoutineItem(id: '4', text: '📝 Write 3 gratitudes', isCompleted: false),
          ],
        ),
      ];
    }

    return routinesJson
        .map((json) => Routine.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Save routines to SharedPreferences and update notifications
  static Future<void> saveRoutines(List<Routine> routines) async {
    final prefs = await SharedPreferences.getInstance();
    final routinesJson = routines
        .map((routine) => jsonEncode(routine.toJson()))
        .toList();
    await prefs.setStringList(_routinesKey, routinesJson);
    
    // Update Android widget
    await RoutineWidgetService.updateWidget();
    
    // Update notification schedules through centralized manager
    final notificationManager = CentralizedNotificationManager();
    await notificationManager.forceRescheduleAll();
  }


  /// Get the currently active routine (unified method for all screens)
  /// This method considers:
  /// 1. Routine with progress today (in-progress or has saved progress)
  /// 2. Routines scheduled for today
  /// 3. Fallback logic
  static Future<Routine?> getCurrentActiveRoutine(List<Routine> routines) async {
    try {
      if (routines.isEmpty) return null;

      // First priority: Check if there's a routine with progress today
      final inProgressRoutineId = await RoutineProgressService.getInProgressRoutineId();
      if (inProgressRoutineId != null) {
        try {
          final inProgressRoutine = routines.firstWhere(
            (routine) => routine.id == inProgressRoutineId,
          );
          return inProgressRoutine;
        } catch (e) {
          // In-progress routine not found, clear the stale reference
          await RoutineProgressService.clearInProgressStatus();
        }
      }

      // Check all routines for any with progress today
      for (final routine in routines) {
        final progress = await RoutineProgressService.loadRoutineProgress(routine.id);
        if (progress != null) {
          final completedSteps = List<bool>.from(progress['completedSteps'] ?? []);
          final allCompleted = completedSteps.isNotEmpty && completedSteps.every((step) => step);
          if (!allCompleted) {
            return routine;
          }
        }
      }

      // Second priority: Find routines scheduled for today
      final now = DateTime.now();
      final today = now.weekday; // 1=Monday, 7=Sunday

      // Find routines that are active today
      final activeRoutines = routines.where((routine) =>
        routine.activeDays.contains(today)
      ).toList();

      if (activeRoutines.isNotEmpty) {
        return activeRoutines.first;
      }

      // Find any routine active today
      final anyActiveRoutine = routines.where((routine) =>
        routine.activeDays.contains(today)
      ).toList();

      if (anyActiveRoutine.isNotEmpty) {
        return anyActiveRoutine.first;
      }

      // Third priority: Fallback to first routine regardless of day
      try {
        return routines.first;
      } catch (e) {
        return routines.isNotEmpty ? routines.first : null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in getCurrentActiveRoutine: $e');
      }
      return routines.isNotEmpty ? routines.first : null;
    }
  }

  /// Find routine from a list of routines that is active today
  /// @deprecated Use getCurrentActiveRoutine instead for consistency
  static Future<Routine?> findRoutine(List<Routine> routines) async {
    // Just delegate to the new unified method
    return getCurrentActiveRoutine(routines);
  }


  /// Save routine progress for today
  static Future<void> saveRoutineProgress({
    required int currentStepIndex,
    required List<RoutineItem> items,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();

    final progressData = {
      'currentStepIndex': currentStepIndex,
      'completedSteps': items.map((item) => item.isCompleted).toList(),
      'skippedSteps': items.map((item) => item.isSkipped).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    await prefs.setString('$_routineProgressPrefix$today', jsonEncode(progressData));
    await prefs.setString(_routineLastDateKey, today);
    
    // Update Android widget with new progress
    await RoutineWidgetService.updateWidget();
  }

  /// Load routine progress for today
  static Future<Map<String, dynamic>?> loadRoutineProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();
    final lastSavedDate = prefs.getString(_routineLastDateKey);
    
    if (lastSavedDate != today) {
      return null; // Progress is from a different day
    }
    
    final progressJson = prefs.getString('$_routineProgressPrefix$today');
    if (progressJson == null) {
      return null;
    }
    
    return jsonDecode(progressJson);
  }

  /// Clear routine progress for today
  static Future<void> clearRoutineProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();
    
    await prefs.remove('$_routineProgressPrefix$today');
    await prefs.setString(_routineLastDateKey, today);
  }
}