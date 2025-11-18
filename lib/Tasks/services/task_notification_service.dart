import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../tasks_data_models.dart';
import '../../Notifications/notification_service.dart';
import '../../shared/error_logger.dart';

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
  Future<void> scheduleAllTaskNotifications(List<Task> tasks) async {
    try {
      // Cancel all existing task notifications
      await cancelAllTaskNotifications();

      // Schedule notifications for all tasks with reminder times
      for (final task in tasks) {
        if (!task.isCompleted && task.reminderTime != null) {
          await scheduleTaskNotification(task);
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

  /// Schedule a notification for a single task
  Future<void> scheduleTaskNotification(Task task) async {
    try {
      if (task.reminderTime == null) return;

      // Ensure notification service is initialized
      await ensureNotificationServiceInitialized();

      final now = DateTime.now();
      DateTime scheduledDate = task.reminderTime!;

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
      String? recurrenceType;
      bool shouldScheduleAsRecurring = task.recurrence != null && !task.isPostponed;

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
