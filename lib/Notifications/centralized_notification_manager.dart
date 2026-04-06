import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../shared/timezone_utils.dart';
import '../Routines/routine_service.dart';
import '../Tasks/task_service.dart';
import '../MenstrualCycle/friend_notification_service.dart';
import '../Settings/app_customization_service.dart';
import 'notification_service.dart';
import 'engagement_notification_service.dart';
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
      return;
    }

    _notificationService = NotificationService();
    await _notificationService.initializeNotifications();

    _isInitialized = true;
  }

  /// Schedule ALL notifications for the entire app in one place
  Future<void> scheduleAllNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check if notifications are enabled before scheduling
      final notificationsEnabled = await _notificationService.areNotificationsEnabled();
      if (!notificationsEnabled) {
        return; // Don't schedule notifications if they're blocked
      }

      // 1. Schedule routine notifications (requires routines module)
      await _scheduleRoutineNotifications();

      // 2. Schedule task notifications (requires tasks module)
      await _scheduleTaskNotifications();

      // 3. Schedule cycle notifications (requires menstrual module)
      await _scheduleCycleNotifications();

      // 4. Schedule food tracking reminder (requires food module)
      await _scheduleFoodTrackingNotifications();

      // 5. Schedule friend notifications (low battery and birthday reminders)
      await _scheduleFriendNotifications();

      // 6. Schedule end of day review notification
      await _scheduleEndOfDayReviewNotification();

      // 7. Schedule morning routine notification (requires routines module)
      await _scheduleMorningRoutineNotification();

      // 8. Schedule engagement notifications (streaks, insights, check-in)
      await _scheduleEngagementNotifications();

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
      final routines = await RoutineService.loadRoutines();

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
        }
      }

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
      final taskService = TaskService();
      await taskService.forceRescheduleAllNotifications();

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleTaskNotifications',
        error: 'Error scheduling task notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }


  // Cycle notification IDs - using 5000+ range to avoid collisions with water (1001-1004)
  static const int _ovulationPhaseStartId = 5001;
  static const int _ovulationDayId = 5002;
  static const int _periodIn3DaysId = 5003;
  static const int _periodExpectedTodayId = 5004;

  /// Schedule cycle notifications using timezone utilities
  Future<void> _scheduleCycleNotifications() async {
    try {
      // Check if menstrual module is enabled (use module key, not legacy key)
      final menstrualModuleEnabled = await AppCustomizationService.isModuleEnabled(
        AppCustomizationService.moduleMenstrual,
      );
      if (!menstrualModuleEnabled) {
        // Cancel any existing cycle notifications (both old and new IDs)
        for (final id in [1001, 1002, 1003, _ovulationPhaseStartId, _ovulationDayId, _periodIn3DaysId, _periodExpectedTodayId]) {
          await _notificationService.flutterLocalNotificationsPlugin.cancel(id);
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastPeriodString = prefs.getString('last_period_start');
      final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

      if (lastPeriodString != null) {
        final lastPeriodStart = DateTime.parse(lastPeriodString);
        final now = DateTime.now();

        // Cancel existing notifications (both legacy IDs and new IDs)
        for (final id in [1001, 1002, 1003, _ovulationPhaseStartId, _ovulationDayId, _periodIn3DaysId, _periodExpectedTodayId]) {
          await _notificationService.flutterLocalNotificationsPlugin.cancel(id);
        }

        // Calculate the NEXT period date (could be multiple cycles from lastPeriodStart)
        var nextPeriodDate = lastPeriodStart.add(Duration(days: averageCycleLength));
        while (nextPeriodDate.isBefore(now) || nextPeriodDate.difference(now).inDays < 0) {
          nextPeriodDate = nextPeriodDate.add(Duration(days: averageCycleLength));
        }

        // Ovulation is ~cycle/2 days before next period
        final ovulationDay = nextPeriodDate.subtract(Duration(days: (averageCycleLength / 2).round()));

        // 1. Ovulation phase started (day before ovulation day)
        final ovulationPhaseDate = ovulationDay.subtract(const Duration(days: 1));
        if (ovulationPhaseDate.isAfter(now)) {
          await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
            _ovulationPhaseStartId,
            'Ovulation Phase Starting 🥚',
            'Your ovulation window is starting tomorrow. Time to pay attention to your body!',
            TimezoneUtils.forNotification(DateTime(ovulationPhaseDate.year, ovulationPhaseDate.month, ovulationPhaseDate.day, 8, 0)),
            NotificationService.getCycleNotificationDetails(),
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }

        // 2. It's ovulation day
        if (ovulationDay.isAfter(now) || _isSameDay(ovulationDay, now)) {
          final ovulationDayNotifTime = DateTime(ovulationDay.year, ovulationDay.month, ovulationDay.day, 8, 0);
          if (ovulationDayNotifTime.isAfter(now)) {
            await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
              _ovulationDayId,
              'It\'s Ovulation Day! 🥚✨',
              'Today is your ovulation day. Peak fertility window!',
              TimezoneUtils.forNotification(ovulationDayNotifTime),
              NotificationService.getCycleNotificationDetails(),
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            );
          }
        }

        // 3. Period expected in 3 days
        final threeDaysBefore = nextPeriodDate.subtract(const Duration(days: 3));
        if (threeDaysBefore.isAfter(now)) {
          await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
            _periodIn3DaysId,
            'Period in 3 Days 🩸',
            'Period expected in 3 days — wear dark underwear. Eat more fat, less carbs.',
            TimezoneUtils.forNotification(DateTime(threeDaysBefore.year, threeDaysBefore.month, threeDaysBefore.day, 8, 0)),
            NotificationService.getCycleNotificationDetails(),
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }

        // 4. Menstruation expected today
        if (nextPeriodDate.isAfter(now) || _isSameDay(nextPeriodDate, now)) {
          final periodTodayNotifTime = DateTime(nextPeriodDate.year, nextPeriodDate.month, nextPeriodDate.day, 8, 0);
          if (periodTodayNotifTime.isAfter(now)) {
            await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
              _periodExpectedTodayId,
              'Menstruation Expected Today 🩸',
              'Your period is expected to start today. Make sure you\'re prepared!',
              TimezoneUtils.forNotification(periodTodayNotifTime),
              NotificationService.getCycleNotificationDetails(),
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            );
          }
        }
      }

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleCycleNotifications',
        error: 'Error scheduling cycle notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Force reschedule all notifications (for when settings change)
  Future<void> forceRescheduleAll() async {
    // Cancel all existing notifications
    await _cancelAllNotifications();

    // Reschedule everything
    await scheduleAllNotifications();
  }

  /// Schedule food tracking daily reminder (only if food module is enabled)
  Future<void> _scheduleFoodTrackingNotifications() async {
    try {
      final foodModuleEnabled = await AppCustomizationService.isModuleEnabled(
        AppCustomizationService.moduleFood,
      );

      if (!foodModuleEnabled) {
        await _notificationService.cancelFoodTrackingReminders();
        return;
      }

      await _notificationService.scheduleFoodTrackingReminder();

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleFoodTrackingNotifications',
        error: 'Error scheduling food tracking reminder: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Schedule friend notifications (low battery and birthday reminders)
  Future<void> _scheduleFriendNotifications() async {
    try {
      // Check if the Social/Friends module is enabled
      final socialModuleEnabled = await AppCustomizationService.isModuleEnabled(
        AppCustomizationService.moduleFriends
      );

      if (!socialModuleEnabled) {
        // Cancel any existing friend notifications if module is disabled
        final friendNotificationService = FriendNotificationService();
        await friendNotificationService.cancelAllFriendNotifications();
        return;
      }

      final friendNotificationService = FriendNotificationService();
      await friendNotificationService.scheduleAllFriendNotifications();

      // Check for low battery notifications only once per day
      // Use SharedPreferences to track last check time
      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = 'friend_battery_last_check';
      final lastCheckMs = prefs.getInt(lastCheckKey) ?? 0;
      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
      final now = DateTime.now();

      // Only check once per day (24 hours between checks)
      if (now.difference(lastCheck).inHours >= 24) {
        await friendNotificationService.checkLowBatteryNotifications();
        await prefs.setInt(lastCheckKey, now.millisecondsSinceEpoch);
      }

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleFriendNotifications',
        error: 'Error scheduling friend notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Schedule end of day review notification
  Future<void> _scheduleEndOfDayReviewNotification() async {
    try {
      final enabled = await AppCustomizationService.isEndOfDayReviewEnabled();

      // Cancel existing notification (ID 9000)
      await _notificationService.flutterLocalNotificationsPlugin.cancel(9000);

      if (!enabled) return;

      final (hour, minute) = await AppCustomizationService.getEndOfDayReviewTime();
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        9000, // Unique ID for end of day review
        'Daily Review',
        'Your day at a glance - tap to see your summary',
        TimezoneUtils.forNotification(scheduledDate),
        NotificationService.getEndOfDayReviewNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'end_of_day_review',
      );

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleEndOfDayReviewNotification',
        error: 'Error scheduling end of day review notification: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Schedule engagement notifications (streaks, insights, check-in)
  Future<void> _scheduleEngagementNotifications() async {
    try {
      final engagementService = EngagementNotificationService(_notificationService);
      await engagementService.scheduleAll();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleEngagementNotifications',
        error: 'Error scheduling engagement notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // Morning routine notification ID
  static const int _morningRoutineNotificationId = 6000;

  /// Schedule morning routine notification (only if routines module is enabled)
  Future<void> _scheduleMorningRoutineNotification() async {
    try {
      final routinesModuleEnabled = await AppCustomizationService.isModuleEnabled(
        AppCustomizationService.moduleRoutines,
      );

      // Cancel existing morning routine notification
      await _notificationService.flutterLocalNotificationsPlugin.cancel(_morningRoutineNotificationId);

      if (!routinesModuleEnabled) return;

      // Check if user has any routines with reminders
      final routines = await RoutineService.loadRoutines();
      if (routines.isEmpty) return;

      // Check if morning routine notification is enabled
      final prefs = await SharedPreferences.getInstance();
      final morningRoutineEnabled = prefs.getBool('morning_routine_notification_enabled') ?? true;
      if (!morningRoutineEnabled) return;

      final morningHour = prefs.getInt('morning_routine_notification_hour') ?? 7;
      final morningMinute = prefs.getInt('morning_routine_notification_minute') ?? 0;

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, morningHour, morningMinute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        _morningRoutineNotificationId,
        '🌅 Good Morning!',
        'Time to start your morning routine. A great day begins with great habits!',
        TimezoneUtils.forNotification(scheduledDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'routine_reminders',
            'Routine Reminders',
            channelDescription: 'Daily routine reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notif_routine',
            color: Color(0xFFF98834),
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'morning_routine',
      );

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._scheduleMorningRoutineNotification',
        error: 'Error scheduling morning routine notification: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Cancel all notifications
  Future<void> _cancelAllNotifications() async {
    try {
      // Get all pending notifications and cancel them efficiently
      final pendingNotifications = await _notificationService.flutterLocalNotificationsPlugin.pendingNotificationRequests();

      for (final notification in pendingNotifications) {
        await _notificationService.flutterLocalNotificationsPlugin.cancel(notification.id);
      }

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CentralizedNotificationManager._cancelAllNotifications',
        error: 'Error cancelling notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

}