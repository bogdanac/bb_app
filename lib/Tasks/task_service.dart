import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tasks_data_models.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';
import 'task_list_widget_service.dart';
import '../Services/firebase_backup_service.dart';
import 'repositories/task_repository.dart';
import 'services/task_priority_service.dart';
import 'services/recurrence_calculator.dart';
import 'services/task_notification_service.dart';

/// Facade service that coordinates task operations.
/// Delegates to specialized services for different concerns.
class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  // Delegate services
  final _repository = TaskRepository();
  final _priorityService = TaskPriorityService();
  final _recurrenceCalculator = RecurrenceCalculator();
  final _notificationService = TaskNotificationService();

  // Global task change notifier
  final List<VoidCallback> _taskChangeListeners = [];

  // Add listener for task changes
  void addTaskChangeListener(VoidCallback listener) {
    if (!_taskChangeListeners.contains(listener)) {
      _taskChangeListeners.add(listener);
    }
  }

  // Remove listener for task changes
  void removeTaskChangeListener(VoidCallback listener) {
    _taskChangeListeners.remove(listener);
  }

  // Notify all listeners that tasks have changed
  void _notifyTasksChanged() {
    for (final listener in _taskChangeListeners) {
      listener();
    }
  }

  /// Load tasks with auto-migration logic
  Future<List<Task>> loadTasks() async {
    try {
      final tasks = await _repository.loadTasks();


      // AUTO-MIGRATION: Fix recurring tasks during load
      bool tasksUpdated = false;
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      for (int i = 0; i < tasks.length; i++) {
        // Case 1: New recurring tasks without scheduledDate
        // IMPORTANT: Skip menstrual tasks - they should NOT be auto-scheduled
        // Menstrual tasks with scheduledDate==null and isPostponed==false were intentionally skipped
        final isMenstrualTask = tasks[i].recurrence != null &&
            _isMenstrualCycleTask(tasks[i].recurrence!);

        if (tasks[i].recurrence != null &&
            tasks[i].scheduledDate == null &&
            !tasks[i].isPostponed &&
            !isMenstrualTask) {  // Exclude menstrual tasks
          final updatedTask = await _recurrenceCalculator.calculateNextScheduledDate(tasks[i], prefs);
          if (updatedTask != null) {
            tasks[i] = updatedTask;
            tasksUpdated = true;
          }
        }
        // Case 2a: Postponed tasks that are now due again
        else if (tasks[i].isPostponed &&
                 tasks[i].recurrence != null &&
                 tasks[i].scheduledDate != null &&
                 (tasks[i].scheduledDate!.isBefore(todayDate) ||
                  _isSameDay(tasks[i].scheduledDate!, todayDate)) &&
                 tasks[i].recurrence!.isDueOn(today, taskCreatedAt: tasks[i].createdAt)) {
          tasks[i] = tasks[i].copyWith(isPostponed: false);
          tasksUpdated = true;
        }
        // Case 2b: Overdue recurring tasks
        // NO AUTO-ADVANCE: Tasks stay overdue indefinitely until manually completed
        // This allows users to see and complete tasks that were missed
        // Case 3: Tasks scheduled today with wrong reminderTime
        else if (tasks[i].recurrence != null &&
                 tasks[i].scheduledDate != null &&
                 _isSameDay(tasks[i].scheduledDate!, todayDate)) {
          DateTime? correctReminderTime;

          if (tasks[i].recurrence!.reminderTime != null) {
            correctReminderTime = DateTime(
              todayDate.year,
              todayDate.month,
              todayDate.day,
              tasks[i].recurrence!.reminderTime!.hour,
              tasks[i].recurrence!.reminderTime!.minute,
            );

            if (tasks[i].reminderTime == null ||
                tasks[i].reminderTime!.hour != correctReminderTime.hour ||
                tasks[i].reminderTime!.minute != correctReminderTime.minute ||
                !_isSameDay(tasks[i].reminderTime!, todayDate)) {
              tasks[i] = tasks[i].copyWith(reminderTime: correctReminderTime);
              tasksUpdated = true;
            }
          }
        }
      }

      // Check for menstrual tasks that should be prioritized today
      await _updateMenstrualTaskPriorities(tasks, prefs);

      // AUTO-CLEANUP: Delete completed tasks older than 30 days
      final thirtyDaysAgo = todayDate.subtract(const Duration(days: 30));
      final tasksBeforeCleanup = tasks.length;
      tasks.removeWhere((task) {
        return task.isCompleted &&
               task.completedAt != null &&
               task.completedAt!.isBefore(thirtyDaysAgo);
      });

      final deletedCount = tasksBeforeCleanup - tasks.length;
      if (deletedCount > 0) {
        if (kDebugMode) {
          print('🗑️ Auto-deleted $deletedCount completed tasks older than 30 days');
        }
        tasksUpdated = true;
      }

      // Save tasks if any were updated
      if (tasksUpdated) {
        await _repository.saveTasks(tasks);
        // Reschedule notifications when tasks are auto-updated
        // This ensures notifications are properly updated when isPostponed is cleared
        await _notificationService.scheduleAllTaskNotifications(tasks);
      }

      return tasks;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading tasks: $e');
      }
      return [];
    }
  }

  /// Save tasks with optimized operations
  Future<void> saveTasks(
    List<Task> tasks, {
    bool skipNotificationUpdate = false,
    bool skipWidgetUpdate = false,
  }) async {
    try {
      // Sort tasks before saving - OPTIMIZED: Only sort, don't reload categories
      final categories = await _repository.loadCategories();
      final sortedTasks = _sortTasksForStorage(tasks, categories);

      // Save to repository
      await _repository.saveTasks(sortedTasks);

      // Backup to Firebase (non-blocking)
      FirebaseBackupService.triggerBackup();

      // Only update notifications if needed
      if (!skipNotificationUpdate) {
        await _notificationService.scheduleAllTaskNotifications(sortedTasks);
      }

      // Only update widget if needed
      if (!skipWidgetUpdate) {
        await TaskListWidgetService.updateWidget();
      }

      // Notify all listeners
      _notifyTasksChanged();
    } catch (e) {
      if (kDebugMode) {
        print('ERROR saving tasks: $e');
      }
    }
  }

  /// Sort tasks for storage: incomplete tasks by priority, then completed by date
  List<Task> _sortTasksForStorage(List<Task> tasks, List<TaskCategory> categories) {
    // Separate completed and incomplete tasks
    final incompleteTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    // Sort incomplete tasks by priority
    final prioritizedIncomplete = _priorityService.getPrioritizedTasks(
      incompleteTasks,
      categories,
      incompleteTasks.length,
    );

    // Sort completed tasks by completion date (newest first)
    completedTasks.sort((a, b) {
      if (a.completedAt == null && b.completedAt == null) return 0;
      if (a.completedAt == null) return 1;
      if (b.completedAt == null) return -1;
      return b.completedAt!.compareTo(a.completedAt!);
    });

    // Combine: incomplete first, then completed
    return [...prioritizedIncomplete, ...completedTasks];
  }

  // Delegate to repository
  Future<List<TaskCategory>> loadCategories() async {
    final categories = await _repository.loadCategories();

    if (categories.isEmpty) {
      // Return default categories
      final defaultCategories = [
        TaskCategory(id: '1', name: 'Cleaning', color: const Color(0xFF2196F3), order: 0),
        TaskCategory(id: '2', name: 'At Home', color: const Color(0xFF4CAF50), order: 1),
        TaskCategory(id: '3', name: 'Research', color: const Color(0xFF9C27B0), order: 2),
        TaskCategory(id: '4', name: 'Travel', color: const Color(0xFFFF9800), order: 3),
      ];
      await saveCategories(defaultCategories);
      return defaultCategories;
    }

    return categories;
  }

  Future<void> saveCategories(List<TaskCategory> categories) async {
    await _repository.saveCategories(categories);
  }

  Future<TaskSettings> loadTaskSettings() async {
    return await _repository.loadTaskSettings();
  }

  Future<void> saveTaskSettings(TaskSettings settings) async {
    await _repository.saveTaskSettings(settings);
  }

  Future<List<String>> loadSelectedCategoryFilters() async {
    return await _repository.loadSelectedCategoryFilters();
  }

  Future<void> saveSelectedCategoryFilters(List<String> categoryIds) async {
    await _repository.saveSelectedCategoryFilters(categoryIds);
  }

  // Delegate to priority service
  List<Task> getPrioritizedTasks(
    List<Task> tasks,
    List<TaskCategory> categories,
    int maxTasks, {
    bool includeCompleted = false,
  }) {
    return _priorityService.getPrioritizedTasks(
      tasks,
      categories,
      maxTasks,
      includeCompleted: includeCompleted,
    );
  }

  // Task operations

  /// Helper method to find next occurrence after a specific date
  DateTime? _findNextOccurrenceAfterDate(TaskRecurrence recurrence, DateTime afterDate, {DateTime? taskCreatedAt}) {
    // Search up to 60 days ahead for the next occurrence
    for (int i = 1; i <= 60; i++) {
      final checkDate = afterDate.add(Duration(days: i));
      if (recurrence.isDueOn(checkDate, taskCreatedAt: taskCreatedAt)) {
        return checkDate;
      }
    }
    return null;
  }

  /// Skip to next occurrence (for recurring tasks)
  Future<Task?> skipToNextOccurrence(Task task) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      DateTime? nextOccurrenceDate;
      bool isMenstrualTask = task.recurrence != null &&
          _isMenstrualCycleTask(task.recurrence!);

      // For menstrual phase tasks, clear the scheduled date
      if (isMenstrualTask) {
        nextOccurrenceDate = null;
      }
      // For regular recurring tasks, calculate the NEXT occurrence AFTER today
      else if (task.recurrence != null) {
        // Use the fallback method that searches forward from today
        nextOccurrenceDate = _findNextOccurrenceAfterDate(
          task.recurrence!,
          today,
          taskCreatedAt: task.createdAt,
        );

        // If nothing found within 60 days, default to tomorrow
        nextOccurrenceDate ??= today.add(const Duration(days: 1));
      } else {
        nextOccurrenceDate = today.add(const Duration(days: 1));
      }

      DateTime? newReminderTime;

      if (nextOccurrenceDate != null) {
        if (task.reminderTime != null) {
          newReminderTime = DateTime(
            nextOccurrenceDate.year,
            nextOccurrenceDate.month,
            nextOccurrenceDate.day,
            task.reminderTime!.hour,
            task.reminderTime!.minute,
          );
        } else if (task.recurrence?.reminderTime != null) {
          newReminderTime = DateTime(
            nextOccurrenceDate.year,
            nextOccurrenceDate.month,
            nextOccurrenceDate.day,
            task.recurrence!.reminderTime!.hour,
            task.recurrence!.reminderTime!.minute,
          );
        }
      }

      // For menstrual tasks: clear scheduledDate but DON'T mark as postponed
      // They will naturally reschedule when the phase occurs again
      // For regular tasks: set next occurrence and mark as postponed
      final updatedTask = task.copyWith(
        scheduledDate: isMenstrualTask ? null : nextOccurrenceDate,
        clearScheduledDate: isMenstrualTask,
        reminderTime: newReminderTime,
        isPostponed: !isMenstrualTask, // Only mark regular tasks as postponed
      );

      // Load fresh task list and update it
      // IMPORTANT: Load directly from repository to avoid auto-migration logic
      // that would recalculate scheduledDate for menstrual tasks
      final allTasks = await _repository.loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);

      if (taskIndex != -1) {
        allTasks[taskIndex] = updatedTask;
        // Skip widget and notification updates during skip operation for better performance
        // They will be updated when the task edit screen closes and refreshes the list
        await saveTasks(allTasks, skipNotificationUpdate: true, skipWidgetUpdate: true);
      }

      return updatedTask;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR skipping task to next occurrence: $e');
      }
      rethrow;
    }
  }

  /// Postpone a task to tomorrow
  Future<void> postponeTaskToTomorrow(Task task) async {
    try {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      DateTime? newReminderTime;

      if (task.reminderTime != null) {
        newReminderTime = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          task.reminderTime!.hour,
          task.reminderTime!.minute,
        );
      } else if (task.recurrence?.reminderTime != null) {
        newReminderTime = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          task.recurrence!.reminderTime!.hour,
          task.recurrence!.reminderTime!.minute,
        );
      }

      final updatedTask = task.copyWith(
        scheduledDate: tomorrow,
        reminderTime: newReminderTime,
        isPostponed: true,
      );

      // Load fresh task list and update it
      final allTasks = await loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);

      if (taskIndex != -1) {
        allTasks[taskIndex] = updatedTask;
        await saveTasks(allTasks);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR postponing task: $e');
      }
      rethrow;
    }
  }

  /// Check if a task should show postpone button
  static bool shouldShowPostponeButton(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Tasks with deadlines today or overdue
    if (task.deadline != null) {
      final taskDeadline = DateTime(
        task.deadline!.year,
        task.deadline!.month,
        task.deadline!.day
      );
      if (taskDeadline.isAtSameMomentAs(today) || taskDeadline.isBefore(today)) {
        return true;
      }
    }

    // 2. Recurring tasks that are due today
    if (task.recurrence != null && task.recurrence!.isDueOn(now)) {
      return true;
    }

    // 3. Tasks with reminders today
    if (task.reminderTime != null) {
      final reminderDate = DateTime(
        task.reminderTime!.year,
        task.reminderTime!.month,
        task.reminderTime!.day
      );
      if (reminderDate.isAtSameMomentAs(today)) {
        return true;
      }
    }

    return false;
  }

  // Keep old method for backward compatibility
  static bool isTaskDueToday(Task task) {
    return shouldShowPostponeButton(task);
  }

  // Notification methods - delegate to notification service

  Future<void> scheduleTaskNotification(Task task) async {
    await _notificationService.scheduleTaskNotification(task);
  }

  Future<void> cancelTaskNotification(Task task) async {
    await _notificationService.cancelTaskNotification(task);
  }

  Future<void> forceRescheduleAllNotifications() async {
    final tasks = await loadTasks();
    await _notificationService.forceRescheduleAllNotifications(tasks);
  }

  // Recurrence methods

  /// Public method to recalculate all recurring task scheduled dates
  Future<int> recalculateAllRecurringTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasks = await loadTasks();
      int updatedCount = 0;

      // Pre-calculate menstrual cycle data once
      String? lastPeriodStartStr;
      Map<String, DateTime>? phaseStartDates;

      final hasMenstrualTasks = tasks.any((t) =>
        t.recurrence != null && _isMenstrualCycleTask(t.recurrence!));

      if (hasMenstrualTasks) {
        lastPeriodStartStr = prefs.getString('last_period_start');
        if (lastPeriodStartStr != null) {
          final lastPeriodStart = DateTime.parse(lastPeriodStartStr);
          final averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;
          phaseStartDates = _recurrenceCalculator.calculatePhaseStartDates(
            lastPeriodStart,
            averageCycleLength,
          );
        }
      }

      // Process all recurring tasks
      for (int i = 0; i < tasks.length; i++) {
        if (tasks[i].recurrence != null) {
          Task? updatedTask;

          // Use cached menstrual data if applicable
          if (_isMenstrualCycleTask(tasks[i].recurrence!) && phaseStartDates != null) {
            final scheduledDate = _recurrenceCalculator.calculateMenstrualDateFromCache(
              tasks[i],
              phaseStartDates,
            );
            if (scheduledDate != null && scheduledDate != tasks[i].scheduledDate) {
              DateTime? updatedReminderTime;
              if (tasks[i].reminderTime != null) {
                updatedReminderTime = DateTime(
                  scheduledDate.year,
                  scheduledDate.month,
                  scheduledDate.day,
                  tasks[i].reminderTime!.hour,
                  tasks[i].reminderTime!.minute,
                );
              } else if (tasks[i].recurrence?.reminderTime != null) {
                updatedReminderTime = DateTime(
                  scheduledDate.year,
                  scheduledDate.month,
                  scheduledDate.day,
                  tasks[i].recurrence!.reminderTime!.hour,
                  tasks[i].recurrence!.reminderTime!.minute,
                );
              }

              updatedTask = tasks[i].copyWith(
                scheduledDate: scheduledDate,
                reminderTime: updatedReminderTime,
                isPostponed: false,
              );
            }
          } else {
            updatedTask = await _recurrenceCalculator.calculateNextScheduledDate(
              tasks[i],
              prefs,
            );
          }

          if (updatedTask != null && updatedTask.scheduledDate != tasks[i].scheduledDate) {
            tasks[i] = updatedTask;
            updatedCount++;
          }
        }
      }

      if (updatedCount > 0) {
        await saveTasks(tasks);
      }

      return updatedCount;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR recalculating recurring tasks: $e');
      }
      return 0;
    }
  }

  // Helper methods

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isMenstrualCycleTask(TaskRecurrence recurrence) {
    final menstrualTypes = [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase,
      RecurrenceType.menstrualStartDay,
      RecurrenceType.ovulationPeakDay,
    ];

    // Check if ANY of the types is a menstrual task
    return recurrence.types.any((type) => menstrualTypes.contains(type)) ||
           recurrence.types.any((type) => type == RecurrenceType.custom &&
                                          (recurrence.interval <= -100 || recurrence.interval == -1));
  }

  /// Check menstrual tasks and set scheduledDate for those on their target phaseDay
  Future<void> _updateMenstrualTaskPriorities(
    List<Task> tasks,
    SharedPreferences prefs,
  ) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    if (lastStartStr == null) return;

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final lastPeriodEnd = lastEndStr != null ? DateTime.parse(lastEndStr) : null;

    final currentPhase = MenstrualCycleUtils.getCyclePhase(
      lastPeriodStart,
      lastPeriodEnd,
      averageCycleLength,
    );

    bool tasksUpdated = false;

    for (final task in tasks) {
      if (task.recurrence == null ||
          task.recurrence!.phaseDay == null ||
          !_isMenstrualCycleTask(task.recurrence!)) {
        continue;
      }

      if (task.scheduledDate != null && task.scheduledDate!.isAfter(todayDate)) {
        continue;
      }

      final taskMatchesCurrentPhase = _taskMatchesPhase(task.recurrence!, currentPhase);
      if (!taskMatchesCurrentPhase) continue;

      final targetPhase = _getTaskTargetPhase(task.recurrence!);
      if (targetPhase == null) continue;

      final currentDayInPhase = MenstrualCycleUtils.getCurrentDayInPhase(
        lastPeriodStart,
        averageCycleLength,
        targetPhase,
      );

      if (currentDayInPhase == task.recurrence!.phaseDay) {
        // Only auto-schedule if:
        // 1. Task has a scheduledDate that needs updating
        // Don't reschedule tasks that were intentionally skipped (scheduledDate == null)
        if (task.scheduledDate != null && !_isSameDay(task.scheduledDate!, todayDate)) {
          // Update existing scheduledDate to today
          final taskIndex = tasks.indexOf(task);
          if (taskIndex != -1) {
            tasks[taskIndex] = task.copyWith(scheduledDate: todayDate);
            tasksUpdated = true;
          }
        }
        // Note: We do NOT auto-schedule menstrual tasks with scheduledDate == null
        // This allows skipped tasks to remain unscheduled until the next cycle
      }
    }

    if (tasksUpdated) {
      await saveTasks(tasks);
    }
  }

  bool _taskMatchesPhase(TaskRecurrence recurrence, String currentPhase) {
    return recurrence.types.any((type) {
      switch (type) {
        case RecurrenceType.menstrualPhase:
          return currentPhase == MenstrualCycleConstants.menstrualPhase;
        case RecurrenceType.follicularPhase:
          return currentPhase == MenstrualCycleConstants.follicularPhase;
        case RecurrenceType.ovulationPhase:
          return currentPhase == MenstrualCycleConstants.ovulationPhase;
        case RecurrenceType.earlyLutealPhase:
          return currentPhase == MenstrualCycleConstants.earlyLutealPhase;
        case RecurrenceType.lateLutealPhase:
          return currentPhase == MenstrualCycleConstants.lateLutealPhase;
        default:
          return false;
      }
    });
  }

  String? _getTaskTargetPhase(TaskRecurrence recurrence) {
    for (final type in recurrence.types) {
      switch (type) {
        case RecurrenceType.menstrualPhase:
          return MenstrualCycleConstants.menstrualPhase;
        case RecurrenceType.follicularPhase:
          return MenstrualCycleConstants.follicularPhase;
        case RecurrenceType.ovulationPhase:
          return MenstrualCycleConstants.ovulationPhase;
        case RecurrenceType.earlyLutealPhase:
          return MenstrualCycleConstants.earlyLutealPhase;
        case RecurrenceType.lateLutealPhase:
          return MenstrualCycleConstants.lateLutealPhase;
        default:
          continue;
      }
    }
    return null;
  }
}
