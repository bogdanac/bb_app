import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tasks_data_models.dart';
import '../../Notifications/notification_service.dart';
import '../../shared/error_logger.dart';
import '../../MenstrualCycle/menstrual_cycle_utils.dart';
import '../../MenstrualCycle/menstrual_cycle_constants.dart';

/// Service responsible for scheduling and managing task notifications.
/// Handles ONLY notification-related operations.
class TaskNotificationService {
  static final TaskNotificationService _instance = TaskNotificationService._internal();
  factory TaskNotificationService() => _instance;
  TaskNotificationService._internal();

  late NotificationService _notificationService;
  bool _isNotificationServiceInitialized = false;

  /// Initialize notification service
  Future<void> ensureNotificationServiceInitialized() async {
    if (!_isNotificationServiceInitialized) {
      _notificationService = NotificationService();
      await _notificationService.initializeNotifications();
      _isNotificationServiceInitialized = true;
    }
  }

  /// Schedule notifications for all tasks with reminder times
  /// Menstrual phase tasks are only scheduled if currently in the correct phase
  Future<void> scheduleAllTaskNotifications(List<Task> tasks) async {
    try {
      // Cancel all existing task notifications
      await cancelAllTaskNotifications();

      // Schedule notifications for all tasks with reminder times
      for (final task in tasks) {
        if (!task.isCompleted && task.reminderTime != null) {
          // Check if this is a menstrual phase task
          if (_isMenstrualCycleTask(task)) {
            // Only schedule if we're in the correct menstrual phase
            final isDueToday = await _isMenstrualTaskDueToday(task);
            if (isDueToday) {
              await scheduleTaskNotification(task);
            }
            // Skip scheduling notification if not in correct phase
          } else {
            // Non-menstrual tasks are scheduled normally
            await scheduleTaskNotification(task);
          }
        }
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskNotificationService.scheduleAllTaskNotifications',
        error: 'Error scheduling task notifications: $e',
        stackTrace: stackTrace.toString(),
        context: {'taskCount': tasks.length},
      );
    }
  }

  /// Check if a task is a menstrual cycle task
  bool _isMenstrualCycleTask(Task task) {
    if (task.recurrence == null) return false;

    const menstrualTypes = [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase,
      RecurrenceType.menstrualStartDay,
      RecurrenceType.ovulationPeakDay,
    ];
    return task.recurrence!.types.any((type) => menstrualTypes.contains(type));
  }

  /// Check if a menstrual task should show today based on current phase
  Future<bool> _isMenstrualTaskDueToday(Task task) async {
    if (task.recurrence == null) return false;

    final recurrenceTypes = task.recurrence!.types;

    // Check if task has regular recurrence in addition to menstrual phases
    final hasRegularRecurrence = recurrenceTypes.any((type) =>
      type == RecurrenceType.daily ||
      type == RecurrenceType.weekly ||
      type == RecurrenceType.monthly ||
      type == RecurrenceType.yearly ||
      type == RecurrenceType.custom
    );

    // If task has NO menstrual phases, use regular due today logic
    if (!_isMenstrualCycleTask(task)) {
      return task.isDueToday();
    }

    // Get menstrual cycle data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    if (lastStartStr == null) return false;

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final lastPeriodEnd = lastEndStr != null ? DateTime.parse(lastEndStr) : null;

    // Get current menstrual cycle phase
    final currentPhase = MenstrualCycleUtils.getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);

    // Check if current phase matches any of the selected menstrual phases
    bool isInCorrectPhase = false;

    if (recurrenceTypes.contains(RecurrenceType.menstrualPhase) &&
        currentPhase == MenstrualCycleConstants.menstrualPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.follicularPhase) &&
        currentPhase == MenstrualCycleConstants.follicularPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.ovulationPhase) &&
        currentPhase == MenstrualCycleConstants.ovulationPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.earlyLutealPhase) &&
        currentPhase == MenstrualCycleConstants.earlyLutealPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.lateLutealPhase) &&
        currentPhase == MenstrualCycleConstants.lateLutealPhase) {
      isInCorrectPhase = true;
    }

    // Handle special day types
    if (recurrenceTypes.contains(RecurrenceType.menstrualStartDay)) {
      final now = DateTime.now();
      final daysSinceStart = now.difference(lastPeriodStart).inDays + 1;
      if (daysSinceStart == 1) {
        isInCorrectPhase = true;
      }
    }
    if (recurrenceTypes.contains(RecurrenceType.ovulationPeakDay)) {
      final now = DateTime.now();
      final daysSinceStart = now.difference(lastPeriodStart).inDays + 1;
      if (daysSinceStart == 14) { // Ovulation peak day
        isInCorrectPhase = true;
      }
    }

    // If not in the correct menstrual phase, don't schedule notification
    if (!isInCorrectPhase) {
      return false;
    }

    // If task has BOTH regular recurrence AND menstrual phases:
    // Must also be due according to regular recurrence
    if (hasRegularRecurrence) {
      return task.isDueToday();
    }

    // If task has ONLY menstrual phases (no regular recurrence):
    // Task is due if we're in the correct phase
    return true;
  }

  /// Schedule a notification for a single task
  Future<void> scheduleTaskNotification(Task task) async {
    try {
      if (task.reminderTime == null) return;

      // Ensure notification service is initialized
      await ensureNotificationServiceInitialized();

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      DateTime scheduledDate = task.reminderTime!;

      // Check if task has a future startDate - don't schedule notifications yet
      if (task.recurrence?.startDate != null) {
        final startDateOnly = DateTime(
          task.recurrence!.startDate!.year,
          task.recurrence!.startDate!.month,
          task.recurrence!.startDate!.day,
        );
        if (startDateOnly.isAfter(todayDate)) {
          // Task hasn't started yet - find the correct first reminder time
          final nextReminderTime = _getNextReminderTime(task, now);
          if (nextReminderTime != null) {
            scheduledDate = nextReminderTime;
          } else {
            return; // No valid reminder time found
          }
        }
      }

      // Check if task has passed its endDate - don't schedule notifications
      if (task.recurrence?.endDate != null) {
        final endDateOnly = DateTime(
          task.recurrence!.endDate!.year,
          task.recurrence!.endDate!.month,
          task.recurrence!.endDate!.day,
        );
        if (todayDate.isAfter(endDateOnly)) {
          return; // Task has ended
        }
      }

      // For recurring tasks, ensure we always schedule for a future time
      if (task.recurrence != null) {
        if (scheduledDate.isBefore(now)) {
          // Reminder time is in the past, find next occurrence
          final nextReminderTime = _getNextReminderTime(task, now);
          if (nextReminderTime != null) {
            scheduledDate = nextReminderTime;
          } else {
            return;
          }
        }
      } else {
        // Non-recurring task - don't schedule if time has passed
        if (scheduledDate.isBefore(now)) {
          return;
        }
      }

      // Cancel existing notification first to avoid duplicates
      await _notificationService.cancelTaskNotification(task.id);

      // Determine recurrence type for proper notification scheduling
      // IMPORTANT: If task is postponed, schedule as one-time notification
      // to prevent today's notification from firing
      // IMPORTANT: Menstrual phase tasks are ALWAYS scheduled as one-time notifications
      // because they need to be re-evaluated when the phase changes
      String? recurrenceType;
      final isMenstrualTask = _isMenstrualCycleTask(task);
      bool shouldScheduleAsRecurring = task.recurrence != null && !task.isPostponed && !isMenstrualTask;

      if (shouldScheduleAsRecurring && task.recurrence!.types.isNotEmpty) {
        final primaryType = task.recurrence!.types.first;
        switch (primaryType) {
          case RecurrenceType.daily:
            recurrenceType = 'daily';
            break;
          case RecurrenceType.weekly:
            recurrenceType = 'weekly';
            break;
          case RecurrenceType.monthly:
            recurrenceType = 'monthly';
            break;
          default:
            recurrenceType = null;
        }
      }

      // Use NotificationService to schedule the notification
      await _notificationService.scheduleTaskNotification(
        task.id,
        task.title,
        scheduledDate,
        isRecurring: shouldScheduleAsRecurring,
        recurrenceType: recurrenceType,
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskNotificationService.scheduleTaskNotification',
        error: 'Error scheduling task notification: $e',
        stackTrace: stackTrace.toString(),
        context: {
          'taskId': task.id,
          'taskTitle': task.title,
          'hasReminderTime': task.reminderTime != null,
        },
      );
    }
  }

  /// Get the next reminder time for a recurring task
  DateTime? _getNextReminderTime(Task task, DateTime now) {
    if (task.reminderTime == null || task.recurrence == null) return null;

    final originalTime = task.reminderTime!;
    final timeOfDay = TimeOfDay(hour: originalTime.hour, minute: originalTime.minute);

    // Use recurrence's reminderTime if available
    final recurrenceReminderTime = task.recurrence!.reminderTime;
    final effectiveTimeOfDay = recurrenceReminderTime ?? timeOfDay;

    // Start checking from today
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    // Look ahead for up to 90 days to find the next occurrence
    for (int i = 0; i < 90; i++) {
      final currentCheck = checkDate.add(Duration(days: i));

      // Check if task is due on this date
      final isDue = task.recurrence!.isDueOn(currentCheck, taskCreatedAt: task.createdAt);

      if (isDue) {
        final reminderDateTime = DateTime(
          currentCheck.year,
          currentCheck.month,
          currentCheck.day,
          effectiveTimeOfDay.hour,
          effectiveTimeOfDay.minute,
        );

        // Only schedule if the reminder time is in the future
        if (reminderDateTime.isAfter(now)) {
          return reminderDateTime;
        }
      }
    }

    return null;
  }

  /// Cancel all task notifications
  Future<void> cancelAllTaskNotifications() async {
    try {
      await ensureNotificationServiceInitialized();
      await _notificationService.cancelAllTaskNotifications();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskNotificationService.cancelAllTaskNotifications',
        error: 'Error canceling task notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Cancel a notification for a specific task
  Future<void> cancelTaskNotification(Task task) async {
    try {
      await ensureNotificationServiceInitialized();
      await _notificationService.cancelTaskNotification(task.id);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskNotificationService.cancelTaskNotification',
        error: 'Error canceling task notification: $e',
        stackTrace: stackTrace.toString(),
        context: {'taskId': task.id, 'taskTitle': task.title},
      );
    }
  }

  /// Force reschedule all task notifications (useful for debugging)
  Future<void> forceRescheduleAllNotifications(List<Task> tasks) async {
    try {
      await ensureNotificationServiceInitialized();
      await scheduleAllTaskNotifications(tasks);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskNotificationService.forceRescheduleAllNotifications',
        error: 'Error force rescheduling notifications: $e',
        stackTrace: stackTrace.toString(),
        context: {'taskCount': tasks.length},
      );
    }
  }
}
