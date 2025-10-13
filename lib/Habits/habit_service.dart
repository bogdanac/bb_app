import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'habit_data_models.dart';

class HabitService {
  static const String _habitsKey = 'habits';

  /// Load all habits from SharedPreferences
  static Future<List<Habit>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> habitsJson;
    try {
      habitsJson = prefs.getStringList(_habitsKey) ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Habits data type mismatch, clearing corrupted data');
      }
      await prefs.remove(_habitsKey);
      habitsJson = [];
    }

    return habitsJson
        .map((json) => Habit.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Save habits to SharedPreferences
  static Future<void> saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = habits
        .map((habit) => jsonEncode(habit.toJson()))
        .toList();
    await prefs.setStringList(_habitsKey, habitsJson);
  }

  /// Get only active habits
  static Future<List<Habit>> getActiveHabits() async {
    final habits = await loadHabits();
    return habits.where((habit) => habit.isActive).toList();
  }

  /// Check if there are any uncompleted active habits for today
  static Future<bool> hasUncompletedHabitsToday() async {
    final activeHabits = await getActiveHabits();
    return activeHabits.any((habit) => !habit.isCompletedToday());
  }

  /// Toggle habit completion for today
  /// Returns a map with completion info: {'cycleCompleted': bool, 'habit': Habit?}
  static Future<Map<String, dynamic>> toggleHabitCompletion(String habitId) async {
    final habits = await loadHabits();
    final habitIndex = habits.indexWhere((h) => h.id == habitId);

    if (habitIndex != -1) {
      final habit = habits[habitIndex];
      bool cycleCompleted = false;

      if (habit.isCompletedToday()) {
        habit.markUncompleted();
      } else {
        habit.markCompleted();

        // Check if this completion completed the 21-day cycle
        if (habit.getCurrentCycleProgress() >= 21) {
          cycleCompleted = true;
        }
      }

      await saveHabits(habits);

      return {
        'cycleCompleted': cycleCompleted,
        'habit': cycleCompleted ? habit : null,
      };
    }

    return {
      'cycleCompleted': false,
      'habit': null,
    };
  }

  /// Toggle habit completion for a specific date
  static Future<void> toggleHabitCompletionOnDate(String habitId, DateTime date) async {
    final habits = await loadHabits();
    final habitIndex = habits.indexWhere((h) => h.id == habitId);

    if (habitIndex != -1) {
      habits[habitIndex].toggleCompletionOnDate(date);
      await saveHabits(habits);
    }
  }

  /// Add new habit
  static Future<void> addHabit(Habit habit) async {
    final habits = await loadHabits();
    habits.add(habit);
    await saveHabits(habits);
  }

  /// Update existing habit
  static Future<void> updateHabit(Habit updatedHabit) async {
    final habits = await loadHabits();
    final index = habits.indexWhere((h) => h.id == updatedHabit.id);
    
    if (index != -1) {
      habits[index] = updatedHabit;
      await saveHabits(habits);
    }
  }

  /// Delete habit
  static Future<void> deleteHabit(String habitId) async {
    final habits = await loadHabits();
    habits.removeWhere((h) => h.id == habitId);
    await saveHabits(habits);
  }

  /// Start a new 21-day cycle for a habit
  static Future<void> startNewCycle(String habitId) async {
    final habits = await loadHabits();
    final habitIndex = habits.indexWhere((h) => h.id == habitId);

    if (habitIndex != -1) {
      final habit = habits[habitIndex];
      habit.continueToNextCycle(); // Use the model's method which clears dates and updates cycle counter
      await saveHabits(habits);
    }
  }

  /// Clean up old completed dates (older than 1 year) to keep storage size manageable
  static Future<void> cleanupOldData() async {
    final habits = await loadHabits();
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    final cutoffDate = "${oneYearAgo.year}-${oneYearAgo.month.toString().padLeft(2, '0')}-${oneYearAgo.day.toString().padLeft(2, '0')}";

    var hasChanges = false;
    for (final habit in habits) {
      final originalCount = habit.completedDates.length;
      habit.completedDates.removeWhere((date) => date.compareTo(cutoffDate) < 0);
      if (habit.completedDates.length != originalCount) {
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await saveHabits(habits);
    }
  }
}