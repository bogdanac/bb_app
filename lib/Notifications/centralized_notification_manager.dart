import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../shared/timezone_utils.dart';
import '../Routines/routine_service.dart';
import '../Tasks/task_service.dart';
import 'notification_service.dart';
import '../shared/error_logger.dart';

/// Centralized notification manager - schedules ALL notifications in one place
///
/// This eliminates duplicate scheduling and ensures consistent timezone handling
/// across the entire app using the shared timezone utilities.
class CentralizedNotificationManager {
  static final CentralizedNotificationManager _instance = CentralizedNotificationManager._internal();
  factory CentralizedNotificationManager() => _instance;
  CentralizedNotificationManager._internal();

  static bool _isInitialized = false;
  late NotificationService _notificationService;

  /// Initialize the centralized notification manager
  Future<void> initialize() async {
    if (_isInitialized) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager.initialize',
        error: 'CentralizedNotificationManager already initialized',
        stackTrace: '',
      );
      return;
    }

    await ErrorLogger.logError(
      source: 'CentralizedNotificationManager.initialize',
      error: 'Initializing CentralizedNotificationManager...',
      stackTrace: '',
    );

    _notificationService = NotificationService();
    await _notificationService.initializeNotifications();

    _isInitialized = true;

    await ErrorLogger.logError(
      source: 'CentralizedNotificationManager.initialize',
      error: 'CentralizedNotificationManager initialized successfully',
      stackTrace: '',
    );
  }

  /// Schedule ALL notifications for the entire app in one place
  Future<void> scheduleAllNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    await ErrorLogger.logError(
      source: 'CentralizedNotificationManager.scheduleAllNotifications',
      error: 'Scheduling ALL app notifications from centralized manager...',
      stackTrace: '',
    );

    try {
      // Check if notifications are enabled before scheduling
      final notificationsEnabled = await _notificationService.areNotificationsEnabled();
      if (!notificationsEnabled) {
        await ErrorLogger.logError(
          source: 'CentralizedNotificationManager.scheduleAllNotifications',
          error: 'Notifications are blocked - cannot schedule notifications',
          stackTrace: '',
        );
        return; // Don't schedule notifications if they're blocked
      }

      // 1. Schedule routine notifications
      await _scheduleRoutineNotifications();

      // 2. Schedule task notifications
      await _scheduleTaskNotifications();

      // 3. Schedule cycle notifications
      await _scheduleCycleNotifications();

      // 4. Schedule food tracking reminder
      await _scheduleFoodTrackingNotifications();

      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager.scheduleAllNotifications',
        error: 'All notifications scheduled successfully',
        stackTrace: '',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager.scheduleAllNotifications',
        error: 'Error scheduling all notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Check if notifications are enabled and show warning if blocked
  Future<bool> checkNotificationPermissions(BuildContext? context) async {
    if (!_isInitialized) {
      await initialize();
    }

    final notificationsEnabled = await _notificationService.areNotificationsEnabled();

    if (!notificationsEnabled && context != null && context.mounted) {
      // Show warning dialog after a brief delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          _notificationService.showNotificationBlockedDialog(context);
        }
      });
    }

    return notificationsEnabled;
  }

  /// Schedule routine notifications using timezone utilities
  Future<void> _scheduleRoutineNotifications() async {
    try {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleRoutineNotifications',
        error: 'Scheduling routine notifications...',
        stackTrace: '',
      );

      final routines = await RoutineService.loadRoutines();
      int scheduledCount = 0;

      for (final routine in routines) {
        if (routine.reminderEnabled) {
          final notificationId = 2000 + routine.id.hashCode.abs() % 8000;

          // Cancel existing notification
          await _notificationService.flutterLocalNotificationsPlugin.cancel(notificationId);

          // Schedule new notification
          final now = DateTime.now();
          var scheduledDate = DateTime(now.year, now.month, now.day, routine.reminderHour, routine.reminderMinute);
          if (scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
            notificationId,
            '✨ ${routine.title}',
            'Time to start your routine! Let\'s make today amazing! 🌟',
            TimezoneUtils.forRoutineReminder(scheduledDate),
            NotificationService.getRoutineNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
          );

          scheduledCount++;
        }
      }

      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleRoutineNotifications',
        error: 'Routine notifications scheduled: $scheduledCount',
        stackTrace: '',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleRoutineNotifications',
        error: 'Error scheduling routine notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Schedule task notifications using timezone utilities
  Future<void> _scheduleTaskNotifications() async {
    try {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleTaskNotifications',
        error: 'Scheduling task notifications...',
        stackTrace: '',
      );

      final taskService = TaskService();
      await taskService.forceRescheduleAllNotifications();

      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleTaskNotifications',
        error: 'Task notifications scheduled',
        stackTrace: '',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleTaskNotifications',
        error: 'Error scheduling task notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }


  /// Schedule cycle notifications using timezone utilities
  Future<void> _scheduleCycleNotifications() async {
    try {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleCycleNotifications',
        error: 'Scheduling cycle notifications...',
        stackTrace: '',
      );

      final prefs = await SharedPreferences.getInstance();
      final lastPeriodString = prefs.getString('last_period_start');
      final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

      if (lastPeriodString != null) {
        final lastPeriodStart = DateTime.parse(lastPeriodString);
        final now = DateTime.now();

        await ErrorLogger.logError(
          source: 'CentralizedNotificationManager._scheduleCycleNotifications',
          error: 'Last period: $lastPeriodStart, Cycle length: $averageCycleLength days',
          stackTrace: '',
        );

        // Cancel existing notifications
        await _notificationService.flutterLocalNotificationsPlugin.cancel(1001);
        await _notificationService.flutterLocalNotificationsPlugin.cancel(1002);

        // Schedule ovulation notification (day before ovulation)
        final ovulationDay = lastPeriodStart.add(Duration(days: (averageCycleLength / 2).round()));
        final ovulationNotificationDate = ovulationDay.subtract(const Duration(days: 1));

        await ErrorLogger.logError(
          source: 'CentralizedNotificationManager._scheduleCycleNotifications',
          error: 'Ovulation day: $ovulationDay, Notification: $ovulationNotificationDate',
          stackTrace: '',
        );

        if (ovulationNotificationDate.isAfter(now)) {
          await ErrorLogger.logError(
            source: 'CentralizedNotificationManager._scheduleCycleNotifications',
            error: 'Scheduling ovulation notification for $ovulationNotificationDate',
            stackTrace: '',
          );
          await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
            1001,
            'Ovulation Tomorrow! 🥚',
            'Your ovulation window is starting tomorrow. Time to pay attention to your body!',
            TimezoneUtils.forNotification(ovulationNotificationDate),
            NotificationService.getCycleNotificationDetails(),
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } else {
          await ErrorLogger.logError(
            source: 'CentralizedNotificationManager._scheduleCycleNotifications',
            error: 'Ovulation notification date is in the past, not scheduling',
            stackTrace: '',
          );
        }

        // Schedule menstruation notification (day before expected period)
        final nextPeriodDate = lastPeriodStart.add(Duration(days: averageCycleLength));
        final menstruationNotificationDate = nextPeriodDate.subtract(const Duration(days: 1));

        await ErrorLogger.logError(
          source: 'CentralizedNotificationManager._scheduleCycleNotifications',
          error: 'Next period: $nextPeriodDate, Notification: $menstruationNotificationDate',
          stackTrace: '',
        );

        if (menstruationNotificationDate.isAfter(now)) {
          await ErrorLogger.logError(
            source: 'CentralizedNotificationManager._scheduleCycleNotifications',
            error: 'Scheduling period notification for $menstruationNotificationDate',
            stackTrace: '',
          );
          await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
            1002,
            'Period Expected Tomorrow 🩸',
            'Your period is expected to start tomorrow. Make sure you\'re prepared!',
            TimezoneUtils.forNotification(menstruationNotificationDate),
            NotificationService.getCycleNotificationDetails(),
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } else {
          await ErrorLogger.logError(
            source: 'CentralizedNotificationManager._scheduleCycleNotifications',
            error: 'Period notification date is in the past, not scheduling',
            stackTrace: '',
          );
        }
      } else {
        await ErrorLogger.logError(
          source: 'CentralizedNotificationManager._scheduleCycleNotifications',
          error: 'No cycle data found - cannot schedule cycle notifications',
          stackTrace: '',
        );
      }

      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleCycleNotifications',
        error: 'Cycle notifications scheduling completed',
        stackTrace: '',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleCycleNotifications',
        error: 'Error scheduling cycle notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Force reschedule all notifications (for when settings change)
  Future<void> forceRescheduleAll() async {
    await ErrorLogger.logError(
      source: 'CentralizedNotificationManager.forceRescheduleAll',
      error: 'Force rescheduling all notifications...',
      stackTrace: '',
    );

    // Cancel all existing notifications
    await _cancelAllNotifications();

    // Reschedule everything
    await scheduleAllNotifications();
  }

  /// Schedule food tracking daily reminder
  Future<void> _scheduleFoodTrackingNotifications() async {
    await ErrorLogger.logError(
      source: 'CentralizedNotificationManager._scheduleFoodTrackingNotifications',
      error: 'Scheduling food tracking notifications...',
      stackTrace: '',
    );

    try {
      await _notificationService.scheduleFoodTrackingReminder();

      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleFoodTrackingNotifications',
        error: 'Food tracking reminder scheduled successfully',
        stackTrace: '',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleFoodTrackingNotifications',
        error: 'Error scheduling food tracking reminder: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Cancel all notifications
  Future<void> _cancelAllNotifications() async {
    try {
      // Cancel water reminders
      for (int i = 1; i <= 4; i++) {
        await _notificationService.flutterLocalNotificationsPlugin.cancel(i);
      }

      // Cancel cycle notifications
      await _notificationService.flutterLocalNotificationsPlugin.cancel(1001);
      await _notificationService.flutterLocalNotificationsPlugin.cancel(1002);

      // Cancel routine notifications (range 2000-9999)
      for (int i = 2000; i < 10000; i++) {
        await _notificationService.flutterLocalNotificationsPlugin.cancel(i);
      }

      // Cancel food tracking notifications
      await _notificationService.flutterLocalNotificationsPlugin.cancel(7777);
      await _notificationService.flutterLocalNotificationsPlugin.cancel(7776);

      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._cancelAllNotifications',
        error: 'All notifications cancelled',
        stackTrace: '',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._cancelAllNotifications',
        error: 'Error cancelling notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

}