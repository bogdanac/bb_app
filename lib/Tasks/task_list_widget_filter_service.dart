import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'tasks_data_models.dart';
import 'task_service.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';

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
      if (kDebugMode) {
        print('TaskListWidgetFilter: Updating widget task list');
      }

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

      if (kDebugMode) {
        print('TaskListWidgetFilter: Saved ${widgetTasks.length} tasks for widget');
        for (var task in widgetTasks) {
          print('  - ${task.title}');
        }
      }
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

      if (kDebugMode) {
        print('TaskListWidgetFilter: Filtering for phase: $currentPhase');
      }

      // Filter tasks: include tasks matching current phase + tasks without menstrual settings
      final filtered = <Task>[];
      for (final task in tasks) {
        if (task.recurrence == null || !_isMenstrualTask(task.recurrence!)) {
          // Task has no menstrual phase settings - always include
          filtered.add(task);
        } else {
          // Check if task matches current phase
          if (_taskMatchesPhase(task.recurrence!, currentPhase)) {
            filtered.add(task);
          }
        }
      }

      if (kDebugMode) {
        print('TaskListWidgetFilter: Filtered ${tasks.length} -> ${filtered.length} tasks');
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

  /// Convert RecurrenceType to phase string
  static String? _getPhaseFromRecurrenceType(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.menstrualPhase:
      case RecurrenceType.menstrualStartDay:
        return 'Menstrual';
      case RecurrenceType.follicularPhase:
        return 'Follicular';
      case RecurrenceType.ovulationPhase:
      case RecurrenceType.ovulationPeakDay:
        return 'Ovulation';
      case RecurrenceType.earlyLutealPhase:
        return 'Early Luteal';
      case RecurrenceType.lateLutealPhase:
        return 'Late Luteal';
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
