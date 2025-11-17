import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'tasks_data_models.dart';
import 'task_service.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';

/// Service to manage task data specifically for the Android task list widget
/// Stores pre-filtered and prioritized tasks to keep widget logic simple
/// Always applies menstrual phase filtering (flower icon ON behavior)
class TaskListWidgetFilterService {
  static const String _widgetTasksKey = 'flutter.widget_filtered_tasks';
  static const int _maxWidgetTasks = 5;

  /// Update the widget's task list with filtered and prioritized tasks
  /// This applies menstrual phase filtering (as if flower icon is ON)
  static Future<void> updateWidgetTasks() async {
    try {
      final taskService = TaskService();
      final allTasks = await taskService.loadTasks();
      final categories = await taskService.loadCategories();

      // Apply menstrual phase filtering (flower icon ON behavior)
      final filteredTasks = await _applyMenstrualFiltering(allTasks);

      // Get prioritized incomplete tasks
      final incompleteTasks = filteredTasks.where((t) => !t.isCompleted).toList();

      final prioritizedTasks = taskService.getPrioritizedTasks(
        incompleteTasks,
        categories,
        _maxWidgetTasks,
      );

      // Take only first 5 tasks for widget
      final widgetTasks = prioritizedTasks.take(_maxWidgetTasks).toList();

      // Save to SharedPreferences for widget to read
      await _saveWidgetTasks(widgetTasks);
    } catch (e) {
      if (kDebugMode) {
        print('TaskListWidgetFilter ERROR: $e');
      }
    }
  }

  /// Apply menstrual phase filtering to tasks
  /// Same logic as TodoScreen with flower icon ON
  static Future<List<Task>> _applyMenstrualFiltering(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastStartStr = prefs.getString('last_period_start');
      final averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;

      if (lastStartStr == null) {
        // No cycle data - return all tasks
        return tasks;
      }

      final lastPeriodStart = DateTime.parse(lastStartStr);
      final currentPhase = MenstrualCycleUtils.getCyclePhase(
        lastPeriodStart,
        null,
        averageCycleLength,
      );

      // Filter tasks: match TodoScreen's exact filtering logic when flower is ON
      final filtered = <Task>[];
      for (final task in tasks) {
        // Show non-menstrual tasks (same as TodoScreen line 1331-1333)
        if (task.recurrence == null || !_isMenstrualTask(task.recurrence!)) {
          filtered.add(task);
        }
        // For menstrual tasks, use same logic as TodoScreen's _isMenstrualTaskDueToday
        else {
          // Check if we're in the correct phase
          if (!_taskMatchesPhase(task.recurrence!, currentPhase)) {
            continue; // Wrong phase, skip this task
          }

          // Check if task has regular recurrence (daily/weekly/etc) in addition to menstrual
          final hasRegularRecurrence = task.recurrence!.types.any((type) =>
            type == RecurrenceType.daily ||
            type == RecurrenceType.weekly ||
            type == RecurrenceType.monthly ||
            type == RecurrenceType.yearly ||
            type == RecurrenceType.custom
          );

          // Check if task has a specific phaseDay set
          final hasPhaseDay = task.recurrence!.phaseDay != null;

          // For tasks with phaseDay, check if we're on the correct day of the phase
          if (hasPhaseDay) {
            final currentPhaseDay = _getCurrentPhaseDay(lastPeriodStart, currentPhase, averageCycleLength);
            if (currentPhaseDay == task.recurrence!.phaseDay) {
              // Also check if regular recurrence matches (if present)
              if (hasRegularRecurrence) {
                if (task.isDueToday()) {
                  filtered.add(task);
                }
              } else {
                // No regular recurrence, just phaseDay matches
                filtered.add(task);
              }
            }
          }
          // If task has regular recurrence (but no phaseDay):
          // Must also be due today (TodoScreen line 1474-1476)
          else if (hasRegularRecurrence) {
            if (task.isDueToday()) {
              filtered.add(task);
            }
          } else {
            // Task has ONLY menstrual phases (no phaseDay, no regular recurrence):
            // Show all days during correct phase (TodoScreen line 1478-1480)
            filtered.add(task);
          }
        }
      }

      return filtered;
    } catch (e) {
      if (kDebugMode) {
        print('TaskListWidgetFilter: Error filtering, returning all tasks: $e');
      }
      return tasks;
    }
  }

  /// Check if a task has menstrual phase settings
  static bool _isMenstrualTask(TaskRecurrence recurrence) {
    return recurrence.types.any((type) => [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase,
      RecurrenceType.menstrualStartDay,
      RecurrenceType.ovulationPeakDay,
    ].contains(type));
  }

  /// Check if task's recurrence matches the current menstrual phase
  static bool _taskMatchesPhase(TaskRecurrence recurrence, String currentPhase) {
    for (final type in recurrence.types) {
      final taskPhase = _getPhaseFromRecurrenceType(type);
      if (taskPhase != null && taskPhase == currentPhase) {
        return true;
      }
    }
    return false;
  }

  /// Calculate what day of the current phase we're on (1-indexed)
  static int _getCurrentPhaseDay(DateTime lastPeriodStart, String currentPhase, int cycleLength) {
    final now = DateTime.now();
    final dayOfCycle = now.difference(DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day)).inDays + 1;

    // Phase boundaries (same as MenstrualCycleUtils)
    final menstrualDays = 5;
    final follicularDays = ((cycleLength - 14) * 0.7).round();
    final ovulationDays = 3;
    final earlyLutealDays = 6;

    if (currentPhase == MenstrualCycleConstants.menstrualPhase) {
      return dayOfCycle; // Days 1-5
    } else if (currentPhase == MenstrualCycleConstants.follicularPhase) {
      return dayOfCycle - menstrualDays; // Day of follicular phase
    } else if (currentPhase == MenstrualCycleConstants.ovulationPhase) {
      return dayOfCycle - menstrualDays - follicularDays; // Day of ovulation
    } else if (currentPhase == MenstrualCycleConstants.earlyLutealPhase) {
      return dayOfCycle - menstrualDays - follicularDays - ovulationDays; // Day of early luteal
    } else if (currentPhase == MenstrualCycleConstants.lateLutealPhase) {
      return dayOfCycle - menstrualDays - follicularDays - ovulationDays - earlyLutealDays; // Day of late luteal
    }

    return 1; // Default to day 1
  }

  /// Convert RecurrenceType to phase string
  /// MUST match the phase names returned by MenstrualCycleUtils.getCyclePhase()
  static String? _getPhaseFromRecurrenceType(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.menstrualPhase:
      case RecurrenceType.menstrualStartDay:
        return MenstrualCycleConstants.menstrualPhase;
      case RecurrenceType.follicularPhase:
        return MenstrualCycleConstants.follicularPhase;
      case RecurrenceType.ovulationPhase:
      case RecurrenceType.ovulationPeakDay:
        return MenstrualCycleConstants.ovulationPhase;
      case RecurrenceType.earlyLutealPhase:
        return MenstrualCycleConstants.earlyLutealPhase;
      case RecurrenceType.lateLutealPhase:
        return MenstrualCycleConstants.lateLutealPhase;
      default:
        return null;
    }
  }

  /// Save widget tasks to SharedPreferences
  static Future<void> _saveWidgetTasks(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = tasks.map((task) => jsonEncode(task.toJson())).toList();
      await prefs.setStringList(_widgetTasksKey, tasksJson);
    } catch (e) {
      if (kDebugMode) {
        print('TaskListWidgetFilter: Error saving widget tasks: $e');
      }
    }
  }

  /// Clear widget tasks
  static Future<void> clearWidgetTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_widgetTasksKey);
    } catch (e) {
      if (kDebugMode) {
        print('TaskListWidgetFilter: Error clearing widget tasks: $e');
      }
    }
  }
}
