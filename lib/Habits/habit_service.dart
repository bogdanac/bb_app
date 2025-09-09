import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'habit_data_models.dart';

class HabitService {
  static const String _habitsKey = 'habits';

  /// Load all habits from SharedPreferences
  static Future<List<Habit>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = prefs.getStringList(_habitsKey) ?? [];

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
  static Future<void> toggleHabitCompletion(String habitId) async {
    final habits = await loadHabits();
    final habitIndex = habits.indexWhere((h) => h.id == habitId);
    
    if (habitIndex != -1) {
      if (habits[habitIndex].isCompletedToday()) {
        habits[habitIndex].markUncompleted();
      } else {
        habits[habitIndex].markCompleted();
      }
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