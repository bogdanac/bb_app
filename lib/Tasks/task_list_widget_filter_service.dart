import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'tasks_data_models.dart';
import 'task_service.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';
import '../shared/error_logger.dart';

/// Service to manage task data specifically for the Android task list widget
/// Stores pre-filtered and prioritized tasks to keep widget logic simple
///
/// Widget behavior:
/// The widget displays the first 5 tasks from TODO screen (flower icon ON by default).
///
/// Implementation:
/// 1. Filter: Include non-menstrual tasks + menstrual tasks matching current phase
/// 2. Prioritize: TaskService.getPrioritizedTasks() orders by due dates, reminders, deadlines, importance
/// 3. Display: Show first 5 from prioritized list
///
/// Separation of concerns:
/// Filtering = which tasks to include (phase match)
/// Prioritization = what order to display them (due dates, reminders, etc.)
class TaskListWidgetFilterService {
  static const String _widgetTasksKey = 'flutter.widget_filtered_tasks';
  static const int _maxWidgetTasks = 5;

  /// Update the widget's task list with filtered and prioritized tasks
  /// This applies menstrual phase filtering (as if flower icon is ON)
  ///
  /// Widget shows the first 5 tasks from TODO screen.
  /// Step 1: Filter by menstrual phase (current phase + non-menstrual tasks)
  /// Step 2: Get prioritized list from TaskService (handles due today, reminders, deadlines, importance)
  /// Step 3: Take first 5 tasks
  /// Note: Prioritization is separate from filtering - both are needed
  static Future<void> updateWidgetTasks() async {
    int? taskCount;
    int? filteredCount;
    int? prioritizedCount;
    int? incompleteCount;

    try {
      final taskService = TaskService();
      final allTasks = await taskService.loadTasks();
      final categories = await taskService.loadCategories();
      taskCount = allTasks.length;

      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Step 1: Loaded tasks',
        context: {'totalTasks': taskCount},
      );

      // Apply menstrual phase filtering (flower icon ON behavior)
      final filteredTasks = await _applyMenstrualFiltering(allTasks);
      filteredCount = filteredTasks.length;

      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Step 2: After menstrual filter',
        context: {'filteredTasks': filteredCount},
      );

      // Get prioritized incomplete tasks
      final incompleteTasks = filteredTasks.where((t) => !t.isCompleted).toList();
      incompleteCount = incompleteTasks.length;

      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Step 3: After incomplete filter',
        context: {'incompleteTasks': incompleteCount},
      );

      final prioritizedTasks = await taskService.getPrioritizedTasks(
        incompleteTasks,
        categories,
        _maxWidgetTasks,
      );
      prioritizedCount = prioritizedTasks.length;

      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Step 4: After prioritization',
        context: {'prioritizedTasks': prioritizedCount},
      );

      // Take only first 5 tasks for widget
      final widgetTasks = prioritizedTasks.take(_maxWidgetTasks).toList();

      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Step 5: Saving to widget',
        context: {'widgetTasks': widgetTasks.length},
      );

      // Save to SharedPreferences for widget to read
      await _saveWidgetTasks(widgetTasks);
    } catch (e, stackTrace) {
      // Log error to Firebase for debugging
      await ErrorLogger.logWidgetError(
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        taskCount: taskCount,
        filteredCount: filteredCount,
        prioritizedCount: prioritizedCount,
      );

      // Don't save on error - keep previous widget data
    }
  }

  /// Apply menstrual phase filtering to tasks
  /// Same logic as TodoScreen with flower icon ON (default state)
  ///
  /// This method filters by menstrual phase only.
  /// Filtering determines which tasks to include (phase match).
  /// Prioritization determines display order (handled by TaskService.getPrioritizedTasks).
  /// This separation is intentional - tasks matching the phase are included regardless of
  /// due dates, reminders, or deadlines. Those factors affect priority order, not inclusion.
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

      // Filter by phase only
      // Include: non-menstrual tasks + menstrual tasks matching current phase
      final filtered = <Task>[];
      for (final task in tasks) {
        try {
          if (task.recurrence == null || !_isMenstrualTask(task.recurrence!)) {
            // Task has no menstrual phase settings - always include
            filtered.add(task);
          } else {
            // Task has menstrual phase settings - check if it matches current phase
            if (_taskMatchesPhase(task.recurrence!, currentPhase)) {
              filtered.add(task);
            }
          }
        } catch (e) {
          // If a single task fails, log it but continue with other tasks
          await ErrorLogger.logError(
            source: 'TaskListWidget',
            error: 'Failed to filter task: ${task.id}',
            context: {'taskTitle': task.title, 'error': e.toString()},
          );
        }
      }

      return filtered;
    } catch (e, stackTrace) {
      // Log filtering failure but return all tasks as fallback
      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Menstrual filtering failed: ${e.toString()}',
        stackTrace: stackTrace.toString(),
        context: {'taskCount': tasks.length},
      );
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
    } catch (e, stackTrace) {
      // Log save error - this will be caught by updateWidgetTasks catch block
      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Failed to save widget tasks: ${e.toString()}',
        stackTrace: stackTrace.toString(),
        context: {'taskCount': tasks.length},
      );
      rethrow; // Re-throw so updateWidgetTasks knows save failed
    }
  }

  /// Clear widget tasks
  static Future<void> clearWidgetTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_widgetTasksKey);
    } catch (e) {
      // Error clearing widget tasks
    }
  }
}
