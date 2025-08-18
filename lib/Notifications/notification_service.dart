import 'package:flutter/foundation.dart';
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

    // Pentru implementare reală, decomentează:

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
}

