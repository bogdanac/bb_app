import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../shared/timezone_utils.dart';
import '../Routines/routine_service.dart';
import '../Tasks/task_service.dart';
import 'notification_service.dart';

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
      if (kDebugMode) {
        print('CentralizedNotificationManager already initialized');
      }
      return;
    }

    if (kDebugMode) {
      print('Initializing CentralizedNotificationManager...');
    }

    _notificationService = NotificationService();
    await _notificationService.initializeNotifications();

    _isInitialized = true;

    if (kDebugMode) {
      print('CentralizedNotificationManager initialized successfully');
    }
  }

  /// Schedule ALL notifications for the entire app in one place
  Future<void> scheduleAllNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kDebugMode) {
      print('🔔 Scheduling ALL app notifications from centralized manager...');
    }

    try {
      // Check if notifications are enabled before scheduling
      final notificationsEnabled = await _notificationService.areNotificationsEnabled();
      if (!notificationsEnabled) {
        if (kDebugMode) {
          print('⚠️ Notifications are blocked - cannot schedule notifications');
        }
        return; // Don't schedule notifications if they're blocked
      }

      // 1. Schedule water reminders (4 daily notifications)
      await _scheduleWaterReminders();

      // 2. Schedule routine notifications
      await _scheduleRoutineNotifications();

      // 3. Schedule task notifications
      await _scheduleTaskNotifications();

      // 4. Schedule cycle notifications
      await _scheduleCycleNotifications();

      // 5. Schedule food tracking reminder
      await _scheduleFoodTrackingNotifications();

      if (kDebugMode) {
        print('✅ All notifications scheduled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling notifications: $e');
      }
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

  /// Schedule water reminders using timezone utilities
  Future<void> _scheduleWaterReminders() async {
    try {
      if (kDebugMode) {
        print('💧 Scheduling water reminders...');
        print('Current time: ${DateTime.now()}');
      }

      final now = DateTime.now();

      // 9 AM reminder
      var reminder9AM = DateTime(now.year, now.month, now.day, 9, 0);
      if (reminder9AM.isBefore(now)) {
        reminder9AM = reminder9AM.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.cancel(1);
      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        1,
        '💧 Gentle Hydration Reminder',
        'Start your day with some water! Your body will thank you 🌱',
        TimezoneUtils.forWaterReminder(reminder9AM),
        NotificationService.getWaterNotificationDetails('water_gentle'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
      );

      // 10 AM reminder
      var reminder10AM = DateTime(now.year, now.month, now.day, 10, 0);
      if (reminder10AM.isBefore(now)) {
        reminder10AM = reminder10AM.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.cancel(2);
      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        2,
        '🚨 DRINK WATER NOW!',
        'You need at least 300ml by now! Your health depends on it! 💪',
        TimezoneUtils.forWaterReminder(reminder10AM),
        NotificationService.getWaterNotificationDetails('water_aggressive'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
      );

      // 2 PM reminder
      var reminder2PM = DateTime(now.year, now.month, now.day, 14, 0);
      if (reminder2PM.isBefore(now)) {
        reminder2PM = reminder2PM.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.cancel(3);
      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        3,
        '⏰ You\'re Behind on Hydration!',
        'You should have 1L by now! Time to catch up - drink up! 🏃‍♀️💧',
        TimezoneUtils.forWaterReminder(reminder2PM),
        NotificationService.getWaterNotificationDetails('water_behind'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
      );

      // 4 PM reminder
      var reminder4PM = DateTime(now.year, now.month, now.day, 16, 0);
      if (reminder4PM.isBefore(now)) {
        reminder4PM = reminder4PM.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.cancel(4);
      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        4,
        '⚡ Afternoon Hydration Check!',
        'You should have 1.2L by now! Only 300ml left to reach your goal! 💪💧',
        TimezoneUtils.forWaterReminder(reminder4PM),
        NotificationService.getWaterNotificationDetails('water_behind'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
      );

      if (kDebugMode) {
        print('✅ Water reminders scheduled successfully:');
        print('  - 9 AM: $reminder9AM');
        print('  - 10 AM: $reminder10AM');
        print('  - 2 PM: $reminder2PM');
        print('  - 4 PM: $reminder4PM');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling water reminders: $e');
      }
    }
  }

  /// Schedule routine notifications using timezone utilities
  Future<void> _scheduleRoutineNotifications() async {
    try {
      if (kDebugMode) {
        print('⏰ Scheduling routine notifications...');
      }

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

      if (kDebugMode) {
        print('✅ Routine notifications scheduled: $scheduledCount');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling routine notifications: $e');
      }
    }
  }

  /// Schedule task notifications using timezone utilities
  Future<void> _scheduleTaskNotifications() async {
    try {
      if (kDebugMode) {
        print('📋 Scheduling task notifications...');
      }

      final taskService = TaskService();
      await taskService.forceRescheduleAllNotifications();

      if (kDebugMode) {
        print('✅ Task notifications scheduled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling task notifications: $e');
      }
    }
  }


  /// Schedule cycle notifications using timezone utilities
  Future<void> _scheduleCycleNotifications() async {
    try {
      if (kDebugMode) {
        print('🩸 Scheduling cycle notifications...');
      }

      final prefs = await SharedPreferences.getInstance();
      final lastPeriodString = prefs.getString('last_period_start');
      final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

      if (lastPeriodString != null) {
        final lastPeriodStart = DateTime.parse(lastPeriodString);
        final now = DateTime.now();

        if (kDebugMode) {
          print('🩸 Last period: $lastPeriodStart, Cycle length: $averageCycleLength days');
        }

        // Cancel existing notifications
        await _notificationService.flutterLocalNotificationsPlugin.cancel(1001);
        await _notificationService.flutterLocalNotificationsPlugin.cancel(1002);

        // Schedule ovulation notification (day before ovulation)
        final ovulationDay = lastPeriodStart.add(Duration(days: (averageCycleLength / 2).round()));
        final ovulationNotificationDate = ovulationDay.subtract(const Duration(days: 1));

        if (kDebugMode) {
          print('🥚 Ovulation day: $ovulationDay, Notification: $ovulationNotificationDate');
        }

        if (ovulationNotificationDate.isAfter(now)) {
          if (kDebugMode) {
            print('✅ Scheduling ovulation notification for $ovulationNotificationDate');
          }
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
          if (kDebugMode) {
            print('⚠️ Ovulation notification date is in the past, not scheduling');
          }
        }

        // Schedule menstruation notification (day before expected period)
        final nextPeriodDate = lastPeriodStart.add(Duration(days: averageCycleLength));
        final menstruationNotificationDate = nextPeriodDate.subtract(const Duration(days: 1));

        if (kDebugMode) {
          print('🩸 Next period: $nextPeriodDate, Notification: $menstruationNotificationDate');
        }

        if (menstruationNotificationDate.isAfter(now)) {
          if (kDebugMode) {
            print('✅ Scheduling period notification for $menstruationNotificationDate');
          }
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
          if (kDebugMode) {
            print('⚠️ Period notification date is in the past, not scheduling');
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No cycle data found - cannot schedule cycle notifications');
        }
      }

      if (kDebugMode) {
        print('✅ Cycle notifications scheduling completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling cycle notifications: $e');
      }
    }
  }

  /// Force reschedule all notifications (for when settings change)
  Future<void> forceRescheduleAll() async {
    if (kDebugMode) {
      print('🔄 Force rescheduling all notifications...');
    }

    // Cancel all existing notifications
    await _cancelAllNotifications();

    // Reschedule everything
    await scheduleAllNotifications();
  }

  /// Schedule food tracking daily reminder
  Future<void> _scheduleFoodTrackingNotifications() async {
    if (kDebugMode) {
      print('📱 Scheduling food tracking notifications...');
    }

    try {
      await _notificationService.scheduleFoodTrackingReminder();

      if (kDebugMode) {
        print('✅ Food tracking reminder scheduled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling food tracking reminder: $e');
      }
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


      if (kDebugMode) {
        print('✅ All notifications cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cancelling notifications: $e');
      }
    }
  }

  /// Check if water notification should be cancelled based on intake
  Future<void> checkAndCancelWaterNotifications(int waterIntake) async {
    await _notificationService.checkAndCancelWaterNotifications(waterIntake);
  }
}