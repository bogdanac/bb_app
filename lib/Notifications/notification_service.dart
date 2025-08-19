import 'package:flutter/foundation.dart';
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

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (kDebugMode) {
          print('Notification tapped: ${response.payload}');
        }
      },
    );

    // Request permissions for iOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permissions for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Pentru acum, doar salvăm setările
    await _scheduleDefaultMorningNotification();
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

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      '🌅 Good Morning!',
      'Time to start your morning routine! ☀️',
      tz.TZDateTime.from(scheduledDate, tz.local),
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

    // await flutterLocalNotificationsPlugin.cancel(0);

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

  // Water notification IDs
  static const int _waterReminder9AM = 1;
  static const int _waterReminder10AM = 2;
  static const int _waterReminder2PM = 3;

// Schedulează toate notificările de apă
  Future<void> scheduleWaterReminders() async {
    if (kDebugMode) {
      print('Scheduling water reminders...');
    }

    await _scheduleWaterReminder9AM();
    await _scheduleWaterReminder10AM();
    await _scheduleWaterReminder2PM();
  }

// Reminder gentil la 9:00 dacă nu s-a băut deloc apă
  Future<void> _scheduleWaterReminder9AM() async {
    await flutterLocalNotificationsPlugin.cancel(_waterReminder9AM);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 9, 0);

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      _waterReminder9AM,
      '💧 Gentle Hydration Reminder',
      'Start your day with some water! Your body will thank you 🌱',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_gentle',
          'Gentle Water Reminders',
          channelDescription: 'Gentle reminders to drink water',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          color: Colors.blue,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'water_gentle_9am',
    );
  }

// Reminder agresiv la 10:00 dacă nu s-au băut 300ml
  Future<void> _scheduleWaterReminder10AM() async {
    await flutterLocalNotificationsPlugin.cancel(_waterReminder10AM);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 10, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      _waterReminder10AM,
      '🚨 DRINK WATER NOW!',
      'You need at least 300ml by now! Your health depends on it! 💪',
      tz.TZDateTime.from(scheduledDate, tz.local),
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
  }

// Reminder la 14:00 dacă nu s-a băut 1L
  Future<void> _scheduleWaterReminder2PM() async {
    await flutterLocalNotificationsPlugin.cancel(_waterReminder2PM);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 14, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      _waterReminder2PM,
      '⏰ You\'re Behind on Hydration!',
      'You should have 1L by now! Time to catch up - drink up! 🏃‍♀️💧',
      tz.TZDateTime.from(scheduledDate, tz.local),
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
  }

// Verifică și anulează notificările pe bază de progres
  Future<void> checkAndCancelWaterNotifications(int currentWaterIntake) async {
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;

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

