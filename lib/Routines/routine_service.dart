import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import '../Notifications/centralized_notification_manager.dart';
import 'routine_widget_service.dart';
import '../shared/timezone_utils.dart';
import '../Services/firebase_backup_service.dart';
import '../shared/error_logger.dart';

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
      await ErrorLogger.logError(
        source: 'RoutineService.getRoutines',
        error: 'Warning: Routines data type mismatch, clearing corrupted data: $e',
        stackTrace: '',
      );
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

    // Backup to Firebase
    FirebaseBackupService.triggerBackup();

    // Update Android widget
    await RoutineWidgetService.updateWidget();

    // Update notification schedules through centralized manager
    final notificationManager = CentralizedNotificationManager();
    await notificationManager.forceRescheduleAll();
  }


  /// Get the currently active routine (unified method for all screens)
  /// Returns the first routine scheduled for today's day of week.
  /// Each day starts fresh - returns the routine scheduled for today regardless of progress.
  /// Manual overrides (set via setActiveRoutineOverride) take priority and last until the next day.
  static Future<Routine?> getCurrentActiveRoutine(List<Routine> routines) async {
    try {
      if (routines.isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      final today = getEffectiveDate();

      // First check if there's a manual override for today
      final overrideJson = prefs.getString('active_routine_override');
      if (overrideJson != null) {
        try {
          final overrideData = jsonDecode(overrideJson);
          final savedDate = overrideData['date'];

          if (savedDate == today) {
            final overrideRoutineId = overrideData['routineId'];
            if (overrideRoutineId != null) {
              // Find the routine with this ID
              try {
                final overrideRoutine = routines.firstWhere(
                  (routine) => routine.id == overrideRoutineId,
                );
                return overrideRoutine;
              } catch (e) {
                // Override routine not found, continue to normal logic
              }
            }
          }
        } catch (e) {
          // Skip override processing
        }
      }

      // Use effective date to determine current day
      final effectiveDate = TimezoneUtils.getEffectiveDateTime();
      final todayWeekday = effectiveDate.weekday; // 1=Monday, 7=Sunday

      // Find routines that are scheduled for today
      final activeRoutines = routines.where((routine) =>
        routine.activeDays.contains(todayWeekday)
      ).toList();

      if (activeRoutines.isNotEmpty) {
        return activeRoutines.first;
      }

      // No routine scheduled for today
      return null;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RoutineService.getCurrentActiveRoutine',
        error: 'Error in getCurrentActiveRoutine: $e',
        stackTrace: stackTrace.toString(),
      );
      return null;
    }
  }

  /// Set a manual override for which routine should be active today
  /// This override lasts until the next day (uses effective date with 2 AM cutoff)
  static Future<void> setActiveRoutineOverride(String routineId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = getEffectiveDate();

    final overrideData = {
      'routineId': routineId,
      'date': today,
    };

    await prefs.setString('active_routine_override', jsonEncode(overrideData));

    // Update Android widget
    await RoutineWidgetService.updateWidget();
  }

  /// Clear any manual routine override
  static Future<void> clearActiveRoutineOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_routine_override');

    // Update Android widget
    await RoutineWidgetService.updateWidget();
  }

  /// Get the next routine from the list based on priority (top to bottom) and day of week
  /// Returns the next routine that is scheduled for today and not yet completed
  static Future<Routine?> getNextRoutine(List<Routine> routines, String? currentRoutineId) async {
    try {
      if (routines.isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      final today = getEffectiveDate();

      // Use effective date to determine current day
      final effectiveDate = TimezoneUtils.getEffectiveDateTime();
      final todayWeekday = effectiveDate.weekday; // 1=Monday, 7=Sunday

      // Find routines that are scheduled for today
      final activeRoutines = routines.where((routine) =>
        routine.activeDays.contains(todayWeekday)
      ).toList();

      if (activeRoutines.isEmpty) return null;

      // Find the index of the current routine
      final currentIndex = currentRoutineId != null
          ? activeRoutines.indexWhere((r) => r.id == currentRoutineId)
          : -1;

      // Search for next uncompleted routine starting after current
      for (int i = currentIndex + 1; i < activeRoutines.length; i++) {
        final routine = activeRoutines[i];
        final completedKey = 'routine_completed_${routine.id}_$today';
        final isCompleted = prefs.getBool(completedKey) ?? false;

        if (!isCompleted) {
          return routine;
        }
      }

      // No uncompleted routine found after current, search from beginning
      for (int i = 0; i <= currentIndex; i++) {
        final routine = activeRoutines[i];
        final completedKey = 'routine_completed_${routine.id}_$today';
        final isCompleted = prefs.getBool(completedKey) ?? false;

        if (!isCompleted && routine.id != currentRoutineId) {
          return routine;
        }
      }

      // All routines completed or only current routine available
      return null;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RoutineService.getNextRoutine',
        error: 'Error in getNextRoutine: $e',
        stackTrace: stackTrace.toString(),
        context: {'currentRoutineId': currentRoutineId},
      );
      return null;
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
    final today = getEffectiveDate();  // Use effective date for consistency

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
    final today = getEffectiveDate();  // Use effective date for consistency
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

}