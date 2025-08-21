import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initializeNotifications() async {
    if (kDebugMode) {
      print('Initializing notifications...');
    }

    try {
      // Initialize timezone properly
      tz.initializeTimeZones();
      // Set local location with multiple fallback strategies
      try {
        // Try to get the device's timezone
        final String timeZoneName = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        if (kDebugMode) {
          print('Set timezone to: $timeZoneName');
        }
      } catch (e) {
        try {
          // Fallback to common timezone names
          final String timeZoneOffset = DateTime.now().timeZoneOffset.toString();
          if (kDebugMode) {
            print('Failed to set timezone by name, trying offset: $timeZoneOffset');
          }
          // Try UTC as safe fallback
          tz.setLocalLocation(tz.UTC);
        } catch (e2) {
          // Last resort - use a default location
          tz.setLocalLocation(tz.getLocation('America/New_York'));
          if (kDebugMode) {
            print('Using default timezone America/New_York: $e2');
          }
        }
      }

      // Wait a moment for timezone to be fully initialized
      await Future.delayed(const Duration(milliseconds: 100));

      // Android initialization with more settings
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
        requestCriticalPermission: true,
      );

      const InitializationSettings initializationSettings =
      InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      final bool? initialized = await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          if (kDebugMode) {
            print('Notification tapped: ${response.payload}');
          }
          _handleNotificationTap(response.payload);
        },
      );

      if (kDebugMode) {
        print('Notifications initialized: $initialized');
      }

      // Request permissions for iOS
      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Request permissions for Android 13+
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        if (kDebugMode) {
          print('Android notification permission granted: $granted');
        }
        
        // Request exact alarm permission for Android 12+
        final bool? exactAlarmGranted = await androidImplementation.requestExactAlarmsPermission();
        if (kDebugMode) {
          print('Exact alarm permission granted: $exactAlarmGranted');
        }
      }

      // Test immediate notification to verify setup
      //await _sendTestNotification();
      
      // Schedule default notifications
      await _scheduleDefaultMorningNotification();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await flutterLocalNotificationsPlugin.show(
        999,
        '✅ Notifications Setup Complete',
        'Your notifications are working! You should see reminders soon.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'setup_test',
            'Setup Test',
            channelDescription: 'Test notification to verify setup',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test_notification',
      );
      
      if (kDebugMode) {
        print('Test notification sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending test notification: $e');
      }
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    if (kDebugMode) {
      print('Handling notification tap: $payload');
    }

    // Handle different notification types
    if (payload.startsWith('task_reminder_')) {
      // Task reminder notification tapped
      // You can add navigation logic here if needed
    } else if (payload == 'morning_routine') {
      // Morning routine notification tapped
    } else if (payload.contains('water_')) {
      // Water reminder notification tapped
    }
  }

  Future<void> _scheduleDefaultMorningNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('morning_notification_enabled') ?? true;
    final hour = prefs.getInt('morning_notification_hour') ?? 8;
    final minute = prefs.getInt('morning_notification_minute') ?? 0;

    if (isEnabled) {
      await scheduleMorningNotification(hour, minute);
    }
  }

  Future<void> scheduleMorningNotification(int hour, int minute) async {
    if (kDebugMode) {
      print('Scheduling morning notification for $hour:${minute.toString().padLeft(2, '0')}');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_notification_enabled', true);
    await prefs.setInt('morning_notification_hour', hour);
    await prefs.setInt('morning_notification_minute', minute);

    // Cancel existing notifications
    await flutterLocalNotificationsPlugin.cancel(0);

    // Schedule new notification
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Use UTC timezone to avoid initialization issues
    final location = tz.UTC;
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      '🌅 Good Morning!',
      'Time to start your morning routine! ☀️',
      tz.TZDateTime.from(scheduledDate, location),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_routine',
          'Morning Routine',
          channelDescription: 'Daily morning routine reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: 'morning_routine',
    );

    if (kDebugMode) {
      print('Morning notification scheduled successfully!');
    }
  }

  Future<void> cancelMorningNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_notification_enabled', false);

    await flutterLocalNotificationsPlugin.cancel(0);

    if (kDebugMode) {
      print('Morning notification cancelled');
    }
  }

  Future<bool> isMorningNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('morning_notification_enabled') ?? true;
  }

  Future<Map<String, int>> getMorningNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt('morning_notification_hour') ?? 8,
      'minute': prefs.getInt('morning_notification_minute') ?? 0,
    };
  }

  // Task notification methods
  Future<void> scheduleTaskNotification(String taskId, String title, DateTime reminderTime, {bool isRecurring = false}) async {
    try {
      final notificationId = 1000 + taskId.hashCode.abs() % 9000; // Keep task notifications in 1000-9999 range

      final now = DateTime.now();
      var scheduledDate = reminderTime;

      // Don't schedule if the time has already passed and it's not recurring
      if (scheduledDate.isBefore(now) && !isRecurring) {
        if (kDebugMode) {
          print('Task reminder time has passed, not scheduling: $title');
        }
        return;
      }

      // If recurring and time has passed today, schedule for tomorrow
      if (isRecurring && scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Use UTC timezone to avoid initialization issues
      final location = tz.UTC;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '📋 Task Reminder',
        title,
        tz.TZDateTime.from(scheduledDate, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Reminders for scheduled tasks',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFF98834), // Orange
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: isRecurring ? DateTimeComponents.time : null,
        payload: 'task_reminder_$taskId',
      );

      if (kDebugMode) {
        print('Scheduled task notification: $title at $scheduledDate (ID: $notificationId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling task notification: $e');
      }
    }
  }

  Future<void> cancelTaskNotification(String taskId) async {
    try {
      final notificationId = 1000 + taskId.hashCode.abs() % 9000;
      await flutterLocalNotificationsPlugin.cancel(notificationId);

      if (kDebugMode) {
        print('Cancelled task notification for task: $taskId (ID: $notificationId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling task notification: $e');
      }
    }
  }

  Future<void> cancelAllTaskNotifications() async {
    try {
      // Cancel all task notifications (IDs 1000-9999)
      for (int i = 1000; i < 10000; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }

      if (kDebugMode) {
        print('Cancelled all task notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling task notifications: $e');
      }
    }
  }

  // Water notification IDs
  static const int _waterReminder9AM = 1;
  static const int _waterReminder10AM = 2;
  static const int _waterReminder2PM = 3;

  // Schedulează toate notificările de apă
  Future<void> scheduleWaterReminders() async {
    if (kDebugMode) {
      print('Scheduling water reminders...');
    }

    try {
      await _scheduleWaterReminder9AM();
      await _scheduleWaterReminder10AM();
      await _scheduleWaterReminder2PM();
      if (kDebugMode) {
        print('All water reminders scheduled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to schedule water notifications: $e');
        print('App will continue without water reminders');
      }
      // Don't rethrow - let the app continue without water notifications
    }
  }

  // Reminder gentil la 9:00 dacă nu s-a băut deloc apă
  Future<void> _scheduleWaterReminder9AM() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder9AM);

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, 9, 0);

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Use UTC timezone to avoid initialization issues
      final location = tz.UTC;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        _waterReminder9AM,
        '💧 Gentle Hydration Reminder',
        'Start your day with some water! Your body will thank you 🌱',
        tz.TZDateTime.from(scheduledDate, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_gentle',
            'Gentle Water Reminders',
            channelDescription: 'Gentle reminders to drink water',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            color: AppColors.purple, // Purple for info
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'water_gentle_9am',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling 9AM water reminder: $e');
      }
      rethrow; // Let parent method handle the error
    }
  }

  // Reminder agresiv la 10:00 dacă nu s-au băut 300ml
  Future<void> _scheduleWaterReminder10AM() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder10AM);

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, 10, 0);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Use UTC timezone to avoid initialization issues
      final location = tz.UTC;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        _waterReminder10AM,
        '🚨 DRINK WATER NOW!',
        'You need at least 300ml by now! Your health depends on it! 💪',
        tz.TZDateTime.from(scheduledDate, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_aggressive',
            'Urgent Water Reminders',
            channelDescription: 'Urgent reminders when behind on water intake',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Colors.red,
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
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'water_aggressive_10am',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling 10AM water reminder: $e');
      }
      rethrow; // Let parent method handle the error
    }
  }

  // Reminder la 14:00 dacă nu s-a băut 1L
  Future<void> _scheduleWaterReminder2PM() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder2PM);

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, 14, 0);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Use UTC timezone to avoid initialization issues
      final location = tz.UTC;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        _waterReminder2PM,
        '⏰ You\'re Behind on Hydration!',
        'You should have 1L by now! Time to catch up - drink up! 🏃‍♀️💧',
        tz.TZDateTime.from(scheduledDate, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_behind',
            'Hydration Progress Reminders',
            channelDescription: 'Reminders when behind daily hydration goals',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Colors.orange,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'water_behind_2pm',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling 2PM water reminder: $e');
      }
      rethrow; // Let parent method handle the error
    }
  }

  // Verifică și anulează notificările pe bază de progres
  Future<void> checkAndCancelWaterNotifications(int currentWaterIntake) async {
    final now = DateTime.now();
    final currentHour = now.hour;

    // Anulează notificarea de la 9 AM dacă s-a băut apă
    if (currentWaterIntake > 0 && currentHour <= 9) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder9AM);
      if (kDebugMode) {
        print('Cancelled 9AM water reminder - water consumed');
      }
    }

    // Anulează notificarea de la 10 AM dacă s-au băut 300ml
    if (currentWaterIntake >= 300 && currentHour <= 10) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder10AM);
      if (kDebugMode) {
        print('Cancelled 10AM water reminder - 300ml goal reached');
      }
    }

    // Anulează notificarea de la 14:00 dacă s-a băut 1L
    if (currentWaterIntake >= 1000 && currentHour <= 14) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder2PM);
      if (kDebugMode) {
        print('Cancelled 2PM water reminder - 1L goal reached');
      }
    }
  }

  // Anulează toate notificările de apă
  Future<void> cancelAllWaterNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(_waterReminder9AM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder10AM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder2PM);

    if (kDebugMode) {
      print('All water notifications cancelled');
    }
  }

  // Reprogramează notificările pentru ziua următoare
  Future<void> rescheduleWaterNotificationsForTomorrow() async {
    if (kDebugMode) {
      print('Rescheduling water notifications for tomorrow...');
    }
    await scheduleWaterReminders();
  }
}