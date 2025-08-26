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

      // Create critical alarm notification channel for motion alerts
      final androidImpl = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
          'motion_alert_loud',
          'Security Motion Alerts',
          description: 'Critical security motion detection alerts that bypass Do Not Disturb',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alarm'),
          enableLights: true,
          enableVibration: true,
          ledColor: Color(0xFFFF0000), // Red
          audioAttributesUsage: AudioAttributesUsage.alarm, // CRITICAL: Use alarm audio stream
        );
        
        await androidImpl.createNotificationChannel(alarmChannel);
            
        if (kDebugMode) {
          print('Created critical alarm notification channel');
        }
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
      
      // Cancel any legacy morning notifications that might still be scheduled
      await _cancelLegacyMorningNotifications();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
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
    } else if (payload.startsWith('routine_reminder_')) {
      // Routine reminder notification tapped
      // You can add navigation logic here if needed
    } else if (payload.contains('water_')) {
      // Water reminder notification tapped
    } else if (payload == 'fasting_progress') {
      // Fasting progress notification tapped - navigate to fasting screen
      // You can add navigation logic here if needed
    } else if (payload == 'fasting_completed') {
      // Fasting completed notification tapped
    }
  }

  // Cancel legacy morning notifications and clean up old preferences
  Future<void> _cancelLegacyMorningNotifications() async {
    try {
      // Cancel notification ID 0 which was used for morning notifications
      await flutterLocalNotificationsPlugin.cancel(0);
      
      // Cancel some other potential legacy IDs, but AVOID water notification IDs (1, 2, 3)
      // and fasting notification ID (100)
      for (int i = 4; i < 10; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }
      
      // Clean up old preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('morning_notification_enabled');
      await prefs.remove('morning_notification_hour');
      await prefs.remove('morning_notification_minute');
      
      // After cleanup, reschedule water notifications to make sure they're active
      await scheduleWaterReminders();
      
      if (kDebugMode) {
        print('Legacy morning notifications cancelled, preferences cleaned up, and water notifications rescheduled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling legacy morning notifications: $e');
      }
    }
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

      // Use local timezone instead of UTC for proper scheduling
      tz.Location location;
      try {
        location = tz.local;
      } catch (e) {
        // Fallback to UTC if local timezone is not available
        location = tz.UTC;
        if (kDebugMode) {
          print('Using UTC fallback for task notification: $e');
        }
      }

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
        matchDateTimeComponents: isRecurring ? DateTimeComponents.time : null,
        payload: 'task_reminder_$taskId',
      );

      if (kDebugMode) {
        print('Scheduled task notification: $title at $scheduledDate (ID: $notificationId) - Location: ${location.name}');
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
  static const int _waterReminder4PM = 4;

  // Schedulează toate notificările de apă
  Future<void> scheduleWaterReminders() async {
    if (kDebugMode) {
      print('Scheduling water reminders...');
    }

    try {
      await _scheduleWaterReminder9AM();
      await _scheduleWaterReminder10AM();
      await _scheduleWaterReminder2PM();
      await _scheduleWaterReminder4PM();
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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

  // Reminder la 16:00 dacă nu s-au băut 1.2L
  Future<void> _scheduleWaterReminder4PM() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder4PM);

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, 16, 0);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Use UTC timezone to avoid initialization issues
      final location = tz.UTC;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        _waterReminder4PM,
        '⚡ Afternoon Hydration Check!',
        'You should have 1.2L by now! Only 300ml left to reach your goal! 💪💧',
        tz.TZDateTime.from(scheduledDate, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_behind',
            'Hydration Progress Reminders',
            channelDescription: 'Reminders when behind daily hydration goals',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: AppColors.waterBlue,
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
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'water_behind_4pm',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling 4PM water reminder: $e');
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

    // Anulează notificarea de la 16:00 dacă s-au băut 1.2L
    if (currentWaterIntake >= 1200 && currentHour <= 16) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder4PM);
      if (kDebugMode) {
        print('Cancelled 4PM water reminder - 1.2L goal reached');
      }
    }
  }

  // Anulează toate notificările de apă
  Future<void> cancelAllWaterNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(_waterReminder9AM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder10AM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder2PM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder4PM);

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

  // Routine notification methods
  Future<void> scheduleRoutineNotification(String routineId, String routineTitle, int hour, int minute) async {
    try {
      final notificationId = 2000 + routineId.hashCode.abs() % 8000; // Keep routine notifications in 2000-9999 range
      
      // Cancel existing notification
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      
      // Schedule new notification
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Use UTC timezone like other notifications
      final location = tz.UTC;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '✨ $routineTitle',
        'Time to start your routine! Let\'s make today amazing! 🌟',
        tz.TZDateTime.from(scheduledDate, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'routine_reminders',
            'Routine Reminders',
            channelDescription: 'Daily reminders for your routines',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFF98834), // Coral color
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'routine_reminder_$routineId',
      );
      
      if (kDebugMode) {
        print('Scheduled routine notification: $routineTitle at $scheduledDate (ID: $notificationId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling routine notification: $e');
      }
    }
  }

  Future<void> cancelRoutineNotification(String routineId) async {
    try {
      final notificationId = 2000 + routineId.hashCode.abs() % 8000;
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      
      if (kDebugMode) {
        print('Cancelled routine notification for routine: $routineId (ID: $notificationId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling routine notification: $e');
      }
    }
  }

  Future<void> cancelAllRoutineNotifications() async {
    try {
      // Cancel all routine notifications (IDs 2000-9999)
      for (int i = 2000; i < 10000; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }

      if (kDebugMode) {
        print('Cancelled all routine notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling routine notifications: $e');
      }
    }
  }

  // Method to clean up all duplicate morning routine notifications
  Future<void> cleanupDuplicateMorningNotifications() async {
    try {
      // Cancel potential duplicate notification IDs, but preserve water (1,2,3) and fasting (100)
      await flutterLocalNotificationsPlugin.cancel(0);
      for (int i = 4; i < 100; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }
      for (int i = 101; i < 200; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }
      
      // Also cancel routine notifications that might contain "morning"
      for (int i = 2000; i < 2100; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }

      // Reschedule water notifications to ensure they're active
      await scheduleWaterReminders();

      if (kDebugMode) {
        print('Cleaned up duplicate morning notifications while preserving water notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up duplicate notifications: $e');
      }
    }
  }

  // Fasting notification methods
  static const int _fastingProgressNotificationId = 100;

  Future<void> showFastingProgressNotification({
    required String fastType,
    required Duration elapsedTime,
    required Duration totalDuration,
    required String currentPhase,
  }) async {
    try {
      final hours = elapsedTime.inHours;
      final minutes = elapsedTime.inMinutes.remainder(60);
      
      final progress = totalDuration.inMinutes > 0 
          ? (elapsedTime.inMinutes / totalDuration.inMinutes * 100).round()
          : 0;

      final title = '🔥 $fastType in Progress';
      final body = '${hours}h ${minutes}m • $currentPhase • $progress%';

      await flutterLocalNotificationsPlugin.show(
        _fastingProgressNotificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_progress',
            'Fasting Progress',
            channelDescription: 'Ongoing fasting progress updates',
            importance: Importance.low,
            priority: Priority.low,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFFF98834), // Orange
            ongoing: true, // Makes it a permanent notification
            autoCancel: false, // Prevents swipe to dismiss
            showProgress: true,
            maxProgress: 100,
            progress: progress,
            enableVibration: false,
            playSound: false,
            actions: [
              const AndroidNotificationAction(
                'stop_fast',
                'Stop Fast',
                titleColor: Color(0xFFFF0000),
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        payload: 'fasting_progress',
      );

      if (kDebugMode) {
        print('Updated fasting progress notification: $progress%');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing fasting progress notification: $e');
      }
    }
  }

  Future<void> cancelFastingProgressNotification() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_fastingProgressNotificationId);
      
      if (kDebugMode) {
        print('Cancelled fasting progress notification');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling fasting progress notification: $e');
      }
    }
  }

  Future<void> showFastingCompletedNotification({
    required String fastType,
    required Duration actualDuration,
  }) async {
    try {
      final hours = actualDuration.inHours;
      final minutes = actualDuration.inMinutes.remainder(60);

      await flutterLocalNotificationsPlugin.show(
        _fastingProgressNotificationId + 1,
        '🎉 Fast Completed!',
        'Congratulations! You completed your $fastType in ${hours}h ${minutes}m',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_completed',
            'Fasting Completed',
            channelDescription: 'Notifications when fasting is completed',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF4CAF50), // Green
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'fasting_completed',
      );

      if (kDebugMode) {
        print('Showed fasting completed notification');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing fasting completed notification: $e');
      }
    }
  }
}