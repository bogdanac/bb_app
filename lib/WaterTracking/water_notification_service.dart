import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'water_settings_model.dart';
import 'dart:developer' as developer;
import '../shared/timezone_utils.dart';
import '../Settings/app_customization_service.dart';

class WaterNotificationService {
  static const int notification20Id = 1001;
  static const int notification40Id = 1002;
  static const int notification60Id = 1003;
  static const int notification80Id = 1004;

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

          // Only schedule if the time is in the future today
          final now = DateTime.now();
          developer.log('$threshold% - Amount: ${amount}ml, Time: ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}');

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
            // Schedule for tomorrow
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
    DateTime scheduledTime,
  ) async {
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
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
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
      await plugin.cancel(notification20Id);
      await plugin.cancel(notification40Id);
      await plugin.cancel(notification60Id);
      await plugin.cancel(notification80Id);
      developer.log('All water notifications cancelled');
    } catch (e) {
      developer.log('Error cancelling water notifications: $e');
    }
  }

  /// Check current water intake and cancel notifications for reached thresholds
  static Future<void> checkAndUpdateNotifications(int currentIntake, WaterSettings settings) async {
    try {
      final plugin = await _getNotificationsPlugin();
      final percentage = (currentIntake / settings.dailyGoal * 100).round();

      // Cancel notifications for thresholds we've already passed
      if (percentage >= 20) {
        await plugin.cancel(notification20Id);
      }
      if (percentage >= 40) {
        await plugin.cancel(notification40Id);
      }
      if (percentage >= 60) {
        await plugin.cancel(notification60Id);
      }
      if (percentage >= 80) {
        await plugin.cancel(notification80Id);
      }

      // If goal reached, cancel all
      if (percentage >= 100) {
        await cancelAllNotifications();
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

      // Load settings and schedule notifications
      final settings = await WaterSettings.load();
      await scheduleNotifications(settings);

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
