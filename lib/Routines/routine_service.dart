import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import '../Notifications/notification_service.dart';
import 'routine_widget_service.dart';

class RoutineService {
  static const String _routinesKey = 'routines';
  static const String _morningRoutineProgressPrefix = 'morning_routine_progress_';
  static const String _morningRoutineLastDateKey = 'morning_routine_last_date';
  static const String _activeRoutineOverrideKey = 'active_routine_override';

  /// Get today's date in yyyy-MM-dd format
  static String getTodayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// Get the effective date for routine purposes (after 2 AM)
  static String getEffectiveDate() {
    final now = DateTime.now();
    
    // If it's before 2 AM, consider it as the previous day
    if (now.hour < 2) {
      final previousDay = now.subtract(const Duration(days: 1));
      return DateFormat('yyyy-MM-dd').format(previousDay);
    }
    
    return DateFormat('yyyy-MM-dd').format(now);
  }

  /// Load all routines from SharedPreferences
  static Future<List<Routine>> loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final routinesJson = prefs.getStringList(_routinesKey) ?? [];

    if (routinesJson.isEmpty) {
      // Return default morning routine
      return [
        Routine(
          id: '1',
          title: 'Morning Routine',
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
    
    // Update notification schedules
    final notificationService = NotificationService();
    for (final routine in routines) {
      if (routine.reminderEnabled) {
        await notificationService.scheduleRoutineNotification(
          routine.id,
          routine.title,
          routine.reminderHour,
          routine.reminderMinute,
        );
      } else {
        await notificationService.cancelRoutineNotification(routine.id);
      }
    }
  }

  /// Set a routine as active for today (manual override)
  static Future<void> setActiveRoutineForToday(String routineId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = getEffectiveDate();
    
    final overrideData = {
      'routineId': routineId,
      'date': today,
    };
    
    await prefs.setString(_activeRoutineOverrideKey, jsonEncode(overrideData));
  }

  /// Clear the active routine override
  static Future<void> clearActiveRoutineOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRoutineOverrideKey);
  }

  /// Get the overridden active routine for today
  static Future<String?> getActiveRoutineOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final overrideJson = prefs.getString(_activeRoutineOverrideKey);
      
      if (overrideJson == null) return null;
      
      try {
        final overrideData = jsonDecode(overrideJson);
        final savedDate = overrideData['date'];
        final today = getEffectiveDate();
        
        if (savedDate == today) {
          return overrideData['routineId'];
        } else {
          // Override is from a different effective day (after 2 AM), clear it
          await clearActiveRoutineOverride();
          return null;
        }
      } catch (jsonError) {
        if (kDebugMode) {
          print('Error parsing override JSON: $jsonError');
        }
        // Clear corrupted data
        await clearActiveRoutineOverride();
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in getActiveRoutineOverride: $e');
      }
      return null;
    }
  }

  /// Find morning routine from a list of routines that is active today
  static Future<Routine?> findMorningRoutine(List<Routine> routines) async {
    try {
      if (routines.isEmpty) return null;
      
      // Check if there's a manual override for today
      final overrideRoutineId = await getActiveRoutineOverride();
      if (overrideRoutineId != null && overrideRoutineId.isNotEmpty) {
        try {
          final overrideRoutine = routines.firstWhere(
            (routine) => routine.id == overrideRoutineId,
          );
          return overrideRoutine;
        } catch (e) {
          if (kDebugMode) {
            print('Override routine with ID $overrideRoutineId not found, falling back to normal logic');
          }
          // Clear the invalid override
          await clearActiveRoutineOverride();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking routine override: $e');
      }
    }
    
    final now = DateTime.now();
    final today = now.weekday; // 1=Monday, 7=Sunday
    
    // First, find all morning routines that are active today
    final activeMorningRoutines = routines.where((routine) =>
      routine.title.toLowerCase().contains('morning') && 
      routine.activeDays.contains(today)
    ).toList();
    
    if (activeMorningRoutines.isNotEmpty) {
      return activeMorningRoutines.first;
    }
    
    // If no active morning routine found, look for any routine active today
    final anyActiveRoutine = routines.where((routine) =>
      routine.activeDays.contains(today)
    ).toList();
    
    if (anyActiveRoutine.isNotEmpty) {
      return anyActiveRoutine.first;
    }
    
    // Fallback to first morning routine regardless of day
    if (routines.isEmpty) {
      // Return a default routine if none exist
      return Routine(
        id: 'default',
        title: 'No Routine',
        items: [],
        reminderEnabled: false,
        activeDays: {},
      );
    }
    
    try {
      return routines.firstWhere(
        (routine) => routine.title.toLowerCase().contains('morning'),
        orElse: () => routines.first,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in final fallback routine selection: $e');
      }
      return routines.isNotEmpty ? routines.first : null;
    }
  }

  /// Save morning routine progress for today
  static Future<void> saveMorningRoutineProgress({
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

    await prefs.setString('$_morningRoutineProgressPrefix$today', jsonEncode(progressData));
    await prefs.setString(_morningRoutineLastDateKey, today);
    
    // Update Android widget with new progress
    await RoutineWidgetService.updateWidget();
  }

  /// Load morning routine progress for today
  static Future<Map<String, dynamic>?> loadMorningRoutineProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();
    final lastSavedDate = prefs.getString(_morningRoutineLastDateKey);
    
    if (lastSavedDate != today) {
      return null; // Progress is from a different day
    }
    
    final progressJson = prefs.getString('$_morningRoutineProgressPrefix$today');
    if (progressJson == null) {
      return null;
    }
    
    return jsonDecode(progressJson);
  }

  /// Clear morning routine progress for today
  static Future<void> clearMorningRoutineProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();
    
    await prefs.remove('$_morningRoutineProgressPrefix$today');
    await prefs.setString(_morningRoutineLastDateKey, today);
  }
}