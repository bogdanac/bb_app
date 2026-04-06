import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'water_settings_model.dart';
import 'dart:developer' as developer;
import '../shared/timezone_utils.dart';
import '../Settings/app_customization_service.dart';

class WaterNotificationService {
  // Primary repeating notification IDs (changed to avoid collision with cycle notifications)
  static const int notification20Id = 3001;
  static const int notification40Id = 3002;
  static const int notification60Id = 3003;
  static const int notification80Id = 3004;

  // Backup notification ID range: 3010-3049 (7 days x 4 thresholds + buffer)
  static const int _backupIdBase = 3010;

  static FlutterLocalNotificationsPlugin? _notificationsPlugin;

  static Future<FlutterLocalNotificationsPlugin> _getNotificationsPlugin() async {
    if (_notificationsPlugin != null) return _notificationsPlugin!;

    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin!.initialize(initSettings);

    // Request Android permissions (needed for Android 13+)
    final androidImpl = _notificationsPlugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();

      // Create notification channel for water reminders
      const AndroidNotificationChannel waterChannel = AndroidNotificationChannel(
        'water_reminders',
        'Water Reminders',
        description: 'Reminders to drink water throughout the day',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await androidImpl.createNotificationChannel(waterChannel);
      developer.log('Water notification channel created');
    }

    return _notificationsPlugin!;
  }

  /// Schedule all water reminder notifications based on settings
  static Future<void> scheduleNotifications(WaterSettings settings, {bool forceReschedule = false}) async {
    try {
      final plugin = await _getNotificationsPlugin();

      // Only cancel if force rescheduling (e.g., settings changed)
      // Otherwise, keep existing notifications to preserve repeat schedules
      if (forceReschedule) {
        await cancelAllNotifications();
      }

      final thresholds = [20, 40, 60, 80];

      developer.log('=== WATER NOTIFICATION SCHEDULING START ===');
      developer.log('Day starts: ${settings.dayStartHour}:00, ends: ${settings.dayEndHour}:00');
      developer.log('Daily goal: ${settings.dailyGoal}ml');

      for (final threshold in thresholds) {
        final isEnabled = settings.isNotificationEnabled(threshold);
        developer.log('$threshold% threshold enabled: $isEnabled');

        if (isEnabled) {
          final scheduledTime = settings.getThresholdTime(threshold);
          final amount = settings.getThresholdAmount(threshold);

          final now = DateTime.now();
          developer.log('$threshold% - Amount: ${amount}ml, Time: ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}');

          // Schedule primary repeating notification
          if (scheduledTime.isAfter(now)) {
            developer.log('Scheduling $threshold% for TODAY');
            await _scheduleNotification(
              plugin,
              _getNotificationId(threshold),
              threshold,
              amount,
              scheduledTime,
            );
          } else {
            final tomorrow = scheduledTime.add(const Duration(days: 1));
            developer.log('Scheduling $threshold% for TOMORROW');
            await _scheduleNotification(
              plugin,
              _getNotificationId(threshold),
              threshold,
              amount,
              tomorrow,
            );
          }

          // Schedule backup individual notifications for the next 7 days
          // This ensures notifications fire even if the app isn't opened
          // (since cancel() on reached thresholds removes the repeating schedule)
          final thresholdIndex = thresholds.indexOf(threshold);
          for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
            final futureDate = now.add(Duration(days: dayOffset));
            final backupTime = DateTime(
              futureDate.year, futureDate.month, futureDate.day,
              scheduledTime.hour, scheduledTime.minute,
            );
            final backupId = _backupIdBase + (dayOffset - 1) * 4 + thresholdIndex;
            await _scheduleNotification(
              plugin,
              backupId,
              threshold,
              amount,
              backupTime,
              isBackup: true,
            );
          }
        }
      }

      developer.log('Water notifications scheduled successfully');
      developer.log('=== WATER NOTIFICATION SCHEDULING END ===');
    } catch (e) {
      developer.log('Error scheduling water notifications: $e');
      developer.log('Stack trace: ${StackTrace.current}');
    }
  }

  static Future<void> _scheduleNotification(
    FlutterLocalNotificationsPlugin plugin,
    int id,
    int threshold,
    int amount,
    DateTime scheduledTime, {
    bool isBackup = false,
  }) async {
    // Get personalized message based on threshold
    final messageData = _getPersonalizedMessage(threshold, amount);

    const androidDetails = AndroidNotificationDetails(
      'water_reminders',
      'Water Reminders',
      channelDescription: 'Reminders to drink water throughout the day',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_water_drop',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await plugin.zonedSchedule(
      id,
      messageData['title']!,
      messageData['body']!,
      TimezoneUtils.forWaterReminder(scheduledTime),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Backup notifications are one-time; primary ones repeat daily
      matchDateTimeComponents: isBackup ? null : DateTimeComponents.time,
    );

    developer.log(
        'Scheduled $threshold% notification for ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}');
  }

  static Map<String, String> _getPersonalizedMessage(int threshold, int amount) {
    switch (threshold) {
      case 20:
        return {
          'title': '💧 Good morning',
          'body': 'A glass of water is a great way to start the day.',
        };
      case 40:
        return {
          'title': '💧 Quick reminder',
          'body': 'A glass of water might help right now.',
        };
      case 60:
        return {
          'title': '💧 Afternoon check-in',
          'body': 'You\'re doing well — keep sipping when you can.',
        };
      case 80:
        return {
          'title': '💧 Almost there',
          'body': 'Just a bit more and you\'ve hit your goal for today.',
        };
      default:
        return {
          'title': '💧 Stay hydrated',
          'body': 'A glass of water might help right now.',
        };
    }
  }

  static int _getNotificationId(int threshold) {
    switch (threshold) {
      case 20:
        return notification20Id;
      case 40:
        return notification40Id;
      case 60:
        return notification60Id;
      case 80:
        return notification80Id;
      default:
        return 1000;
    }
  }

  /// Cancel all water reminder notifications
  static Future<void> cancelAllNotifications() async {
    try {
      final plugin = await _getNotificationsPlugin();
      // Cancel primary notifications
      await plugin.cancel(notification20Id);
      await plugin.cancel(notification40Id);
      await plugin.cancel(notification60Id);
      await plugin.cancel(notification80Id);
      // Cancel legacy IDs (1001-1004) that may still be scheduled
      for (int i = 1001; i <= 1004; i++) {
        await plugin.cancel(i);
      }
      // Cancel all backup notifications (7 days x 4 thresholds)
      for (int i = _backupIdBase; i < _backupIdBase + 28; i++) {
        await plugin.cancel(i);
      }
      developer.log('All water notifications cancelled');
    } catch (e) {
      developer.log('Error cancelling water notifications: $e');
    }
  }

  /// Check current water intake and cancel TODAY's notifications for reached thresholds
  /// Only cancels today's backup notifications, preserving future days' backups
  static Future<void> checkAndUpdateNotifications(int currentIntake, WaterSettings settings) async {
    try {
      final plugin = await _getNotificationsPlugin();
      final percentage = (currentIntake / settings.dailyGoal * 100).round();
      final thresholds = [20, 40, 60, 80];

      for (int i = 0; i < thresholds.length; i++) {
        if (percentage >= thresholds[i]) {
          // Cancel primary repeating notification
          await plugin.cancel(_getNotificationId(thresholds[i]));
          // Cancel today's backup notification (dayOffset=0, index in backup range)
          // Note: we only cancel the primary; backup for today has likely already fired
          // or will be overwritten on next reschedule
        }
      }

      // If goal reached, cancel all for today
      if (percentage >= 100) {
        // Cancel primaries
        for (final id in [notification20Id, notification40Id, notification60Id, notification80Id]) {
          await plugin.cancel(id);
        }
      }
    } catch (e) {
      developer.log('Error updating water notifications: $e');
    }
  }

  /// Check if water module is enabled
  static Future<bool> _isWaterModuleEnabled() async {
    final states = await AppCustomizationService.loadAllModuleStates();
    return states[AppCustomizationService.moduleWater] ?? false;
  }

  /// Initialize notifications for water tracking (call on app start)
  static Future<void> initialize() async {
    try {
      // Skip if water module is disabled
      if (!await _isWaterModuleEnabled()) {
        await cancelAllNotifications();
        developer.log('Water module disabled - notifications cancelled');
        return;
      }

      await _getNotificationsPlugin();

      // Load settings and force reschedule notifications
      // Force reschedule every time to recover from cancelled notifications
      // (cancel() removes the repeating schedule for reached thresholds)
      final settings = await WaterSettings.load();
      await scheduleNotifications(settings, forceReschedule: true);

      // Check current intake and cancel notifications for thresholds already met
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final currentIntake = prefs.getInt('water_$today') ?? 0;
      if (currentIntake > 0) {
        await checkAndUpdateNotifications(currentIntake, settings);
      }

      developer.log('Water notification service initialized');
    } catch (e) {
      developer.log('Error initializing water notification service: $e');
    }
  }

  /// Reschedule notifications for the next day (call at day reset)
  static Future<void> rescheduleForNewDay() async {
    try {
      // Skip if water module is disabled
      if (!await _isWaterModuleEnabled()) {
        await cancelAllNotifications();
        return;
      }

      final settings = await WaterSettings.load();
      // Force reschedule on new day to reset all notifications
      await scheduleNotifications(settings, forceReschedule: true);

      // Check current intake and cancel notifications for thresholds already met
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final currentIntake = prefs.getInt('water_$today') ?? 0;
      if (currentIntake > 0) {
        await checkAndUpdateNotifications(currentIntake, settings);
      }

      developer.log('Water notifications rescheduled for new day');
    } catch (e) {
      developer.log('Error rescheduling water notifications: $e');
    }
  }
}
