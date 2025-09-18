import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../Fasting/fasting_phases.dart';
import '../Data/backup_service.dart';
import '../Tasks/task_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initializeNotifications() async {

    try {
      // Initialize timezone properly
      tz.initializeTimeZones();
      // Set local location with multiple fallback strategies
      try {
        // Try to get the device's timezone
        final String timeZoneName = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        try {
          // Fallback to common timezone names
          DateTime.now().timeZoneOffset.toString();
          // Try UTC as safe fallback
          tz.setLocalLocation(tz.UTC);
        } catch (e2) {
          // Last resort - use a default location
          tz.setLocalLocation(tz.getLocation('America/New_York'));
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

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          _handleNotificationTap(response.payload);
        },
      );


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
        await androidImplementation.requestNotificationsPermission();

        // Request exact alarm permission for Android 12+
        await androidImplementation.requestExactAlarmsPermission();
      }

      // Test immediate notification to verify setup
      //await _sendTestNotification();
      
      // Cancel any legacy morning notifications that might still be scheduled
      await _cancelLegacyMorningNotifications();
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR initializing notifications: $e');
      }
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;


    // Handle different notification types
    if (payload.startsWith('task_reminder_')) {
      // Task reminder notification tapped - need to reschedule if recurring
      final taskId = payload.substring('task_reminder_'.length);
      _handleTaskReminderTriggered(taskId);
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
    } else if (payload == 'fasting_started') {
      // Fasting started notification tapped
    } else if (payload == 'fasting_milestone') {
      // Fasting milestone notification tapped
    } else if (payload == 'fasting_reminder') {
      // Fasting reminder notification tapped
    } else if (payload == 'auto_backup_trigger') {
      // Auto backup notification triggered - perform backup
      _handleAutoBackupTrigger();
    } else if (payload == 'cloud_backup_reminder') {
      // Cloud backup reminder notification tapped
    } else if (payload == 'food_tracking_reminder') {
      // Food tracking reminder notification tapped
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
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling legacy morning notifications: $e');
      }
    }
  }

  // Task notification methods
  Future<void> scheduleTaskNotification(String taskId, String title, DateTime reminderTime, {bool isRecurring = false}) async {
    try {
      final notificationId = 1000 + taskId.hashCode.abs() % 9000; // Keep task notifications in 1000-9999 range

      final now = DateTime.now();
      var scheduledDate = reminderTime;


      // Don't schedule if the time has already passed
      if (scheduledDate.isBefore(now)) {
        return;
      }

      // Use local timezone instead of UTC for proper scheduling
      tz.Location location;
      try {
        location = tz.local;
      } catch (e) {
        // Fallback to UTC if local timezone is not available
        location = tz.UTC;
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
        matchDateTimeComponents: null, // Don't use automatic recurring - TaskService handles the logic
        payload: 'task_reminder_$taskId',
      );

    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling task notification: $e');
      }
    }
  }

  Future<void> cancelTaskNotification(String taskId) async {
    try {
      final notificationId = 1000 + taskId.hashCode.abs() % 9000;
      await flutterLocalNotificationsPlugin.cancel(notificationId);

    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling task notification: $e');
      }
    }
  }

  Future<void> cancelAllTaskNotifications() async {
    try {
      // Cancel all task notifications (IDs 1000-9999)
      for (int i = 1000; i < 10000; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }

    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling task notifications: $e');
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
    }

    try {
      await _scheduleWaterReminder9AM();
      await _scheduleWaterReminder10AM();
      await _scheduleWaterReminder2PM();
      await _scheduleWaterReminder4PM();
    } catch (e) {
      if (kDebugMode) {
        print('ERROR schedule water notifications: $e');
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
        print('ERROR scheduling water reminder: $e');
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
        print('ERROR scheduling water reminder: $e');
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
        print('ERROR scheduling water reminder: $e');
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
        print('ERROR scheduling water reminder: $e');
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
    }

    // Anulează notificarea de la 10 AM dacă s-au băut 300ml
    if (currentWaterIntake >= 300 && currentHour <= 10) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder10AM);
    }

    // Anulează notificarea de la 14:00 dacă s-a băut 1L
    if (currentWaterIntake >= 1000 && currentHour <= 14) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder2PM);
    }

    // Anulează notificarea de la 16:00 dacă s-au băut 1.2L
    if (currentWaterIntake >= 1200 && currentHour <= 16) {
      await flutterLocalNotificationsPlugin.cancel(_waterReminder4PM);
    }
  }

  // Anulează toate notificările de apă
  Future<void> cancelAllWaterNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(_waterReminder9AM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder10AM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder2PM);
    await flutterLocalNotificationsPlugin.cancel(_waterReminder4PM);
  }

  // Reprogramează notificările pentru ziua următoare
  Future<void> rescheduleWaterNotificationsForTomorrow() async {
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
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling routine notification: $e');
      }
    }
  }

  Future<void> cancelRoutineNotification(String routineId) async {
    try {
      final notificationId = 2000 + routineId.hashCode.abs() % 8000;
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling routine notification: $e');
      }
    }
  }

  Future<void> cancelAllRoutineNotifications() async {
    try {
      // Cancel all routine notifications (IDs 2000-9999)
      for (int i = 2000; i < 10000; i++) {
        await flutterLocalNotificationsPlugin.cancel(i);
      }

    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling routine notifications: $e');
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

    } catch (e) {
      if (kDebugMode) {
        print('ERROR cleaning up duplicate notifications: $e');
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

      final title = '🔥 $fastType Fast: $currentPhase';
      final body = '${hours}h ${minutes}m completed • $progress% • Stay strong!';

      await flutterLocalNotificationsPlugin.show(
        _fastingProgressNotificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_progress',
            'Fasting Progress',
            channelDescription: 'Ongoing fasting progress updates',
            importance: Importance.max, // Higher importance to survive overnight
            priority: Priority.high, // High priority to stay active
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFFF98834), // Orange
            ongoing: true, // Makes it a permanent notification
            autoCancel: false, // Prevents swipe to dismiss
            showProgress: true,
            maxProgress: 100,
            progress: progress,
            enableVibration: false,
            playSound: false,
            category: AndroidNotificationCategory.workout, // Workout category for health apps
            visibility: NotificationVisibility.public, // Always visible
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
            categoryIdentifier: 'FASTING_CATEGORY',
          ),
        ),
        payload: 'fasting_progress',
      );

      // Schedule multiple follow-up notifications at different intervals
      await _scheduleProgressReminders(fastType, elapsedTime, totalDuration);

    } catch (e) {
      if (kDebugMode) {
        print('ERROR showing fasting progress notification: $e');
      }
    }
  }

  // Schedule multiple progress reminder notifications
  Future<void> _scheduleProgressReminders(
    String fastType,
    Duration elapsedTime, 
    Duration totalDuration,
  ) async {
    try {
      // Cancel existing scheduled reminders
      for (int i = 1; i <= 20; i++) {
        await flutterLocalNotificationsPlugin.cancel(_fastingProgressNotificationId + i);
      }
      
      final location = tz.UTC;
      
      // Schedule reminders every 30 minutes for the next 10 hours
      for (int i = 1; i <= 20; i++) {
        final reminderTime = DateTime.now().add(Duration(minutes: 30 * i));
        final futureElapsed = elapsedTime + Duration(minutes: 30 * i);
        
        // Don't schedule if past the total duration
        if (futureElapsed >= totalDuration) break;
        
        final futureHours = futureElapsed.inHours;
        final futureMinutes = futureElapsed.inMinutes.remainder(60);
        final futureProgress = totalDuration.inMinutes > 0 
            ? (futureElapsed.inMinutes / totalDuration.inMinutes * 100).round()
            : 0;

        // Determine phase using proper fasting phases utility
        final phaseInfo = FastingPhases.getFastingPhaseInfo(futureElapsed, true);
        String phase = phaseInfo['phase'];

        await flutterLocalNotificationsPlugin.zonedSchedule(
          _fastingProgressNotificationId + i,
          '🔥 $fastType Fast: $phase',
          '${futureHours}h ${futureMinutes}m completed • $futureProgress% • Keep going!',
          tz.TZDateTime.from(reminderTime, location),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'fasting_progress',
              'Fasting Progress',
              channelDescription: 'Ongoing fasting progress updates',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              color: const Color(0xFFF98834),
              ongoing: true,
              autoCancel: false,
              showProgress: true,
              progress: futureProgress.clamp(0, 100),
              maxProgress: 100,
              enableVibration: false,
              playSound: false,
              category: AndroidNotificationCategory.workout,
              visibility: NotificationVisibility.public,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'fasting_progress_reminder',
        );
      }

    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling progress reminders: $e');
      }
    }
  }


  Future<void> cancelFastingProgressNotification() async {
    try {
      // Cancel main progress notification
      await flutterLocalNotificationsPlugin.cancel(_fastingProgressNotificationId);
      
      // Cancel all scheduled reminders
      for (int i = 1; i <= 20; i++) {
        await flutterLocalNotificationsPlugin.cancel(_fastingProgressNotificationId + i);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling fasting progress notification: $e');
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

    } catch (e) {
      if (kDebugMode) {
        print('ERROR showing fasting completed notification: $e');
      }
    }
  }

  Future<void> showFastingStartedNotification({
    required String fastType,
    required Duration totalDuration,
  }) async {
    try {
      final hours = totalDuration.inHours;
      
      await flutterLocalNotificationsPlugin.show(
        _fastingProgressNotificationId + 2,
        '🚀 Fast Started!',
        'Your $fastType has begun! Goal: ${hours}h. You got this! 💪',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_started',
            'Fasting Started',
            channelDescription: 'Notifications when fasting starts',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF2196F3), // Blue
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'fasting_started',
      );

    } catch (e) {
      if (kDebugMode) {
        print('ERROR showing fasting started notification: $e');
      }
    }
  }

  Future<void> showFastingMilestoneNotification({
    required String milestone,
    required String message,
    required Duration elapsedTime,
  }) async {
    try {
      final hours = elapsedTime.inHours;
      final minutes = elapsedTime.inMinutes.remainder(60);
      
      await flutterLocalNotificationsPlugin.show(
        _fastingProgressNotificationId + 3,
        '🔥 Milestone Reached!',
        '$milestone achieved after ${hours}h ${minutes}m! $message',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_milestone',
            'Fasting Milestones',
            channelDescription: 'Notifications for fasting phase milestones',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFFF9800), // Orange
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'fasting_milestone',
      );

    } catch (e) {
      if (kDebugMode) {
        print('ERROR showing fasting milestone notification: $e');
      }
    }
  }

  Future<void> scheduleFastingReminderNotification({
    required String fastType,
    required DateTime reminderTime,
  }) async {
    try {
      final notificationId = _fastingProgressNotificationId + 10;
      
      // Cancel existing reminder
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      
      final now = DateTime.now();
      if (reminderTime.isBefore(now)) {
        if (kDebugMode) {
          print('Fasting reminder time has passed, not scheduling');
        }
        return;
      }

      final location = tz.UTC;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '⏰ Time to Fast!',
        'Your scheduled $fastType is about to begin. Are you ready? 🚀',
        tz.TZDateTime.from(reminderTime, location),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_reminder',
            'Fasting Reminders',
            channelDescription: 'Reminders for scheduled fasting sessions',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF9C27B0), // Purple
            enableVibration: true,
            playSound: true,
            actions: [
              AndroidNotificationAction(
                'start_fast',
                'Start Now',
              ),
              AndroidNotificationAction(
                'postpone_fast', 
                'Postpone',
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'fasting_reminder',
      );

    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling fasting reminder notification: $e');
      }
    }
  }

  Future<void> cancelFastingReminderNotification() async {
    try {
      final notificationId = _fastingProgressNotificationId + 10;
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling fasting reminder notification: $e');
      }
    }
  }

  // Handle auto backup trigger from notification
  void _handleAutoBackupTrigger() async {
    try {
      
      // Perform the backup
      await BackupService.performAutoBackup();
      
      // Show completion notification
      await flutterLocalNotificationsPlugin.show(
        8889, // Different ID for completion notification
        '✅ Backup Complete',
        'Nightly backup completed successfully',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'auto_backup',
            'Automatic Backups',
            channelDescription: 'Automatic nightly data backups',
            importance: Importance.low,
            priority: Priority.low,
            showWhen: false,
            playSound: false,
            enableVibration: false,
            timeoutAfter: 5000, // Auto dismiss after 5 seconds
          ),
        ),
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR handling auto backup trigger: $e');
      }
      
      // Show error notification
      await flutterLocalNotificationsPlugin.show(
        8890, // ERROR notification ID
        '⚠️ Backup Error',
        'Nightly backup failed. Try manual backup.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'auto_backup',
            'Automatic Backups',
            channelDescription: 'Automatic nightly data backups',
            importance: Importance.low,
            priority: Priority.low,
            showWhen: false,
            playSound: false,
            enableVibration: false,
            timeoutAfter: 10000, // Auto dismiss after 10 seconds
          ),
        ),
      );
    }
  }

  // Schedule daily food tracking reminder at 8 PM
  Future<void> scheduleFoodTrackingReminder() async {
    try {
      // Cancel any existing food tracking reminder
      await flutterLocalNotificationsPlugin.cancel(7777);
      
      // Schedule for 8 PM today (or tomorrow if it's already past 8 PM)
      final now = DateTime.now();
      final reminderTime = DateTime(now.year, now.month, now.day, 20, 0); // 8:00 PM
      final scheduledTime = reminderTime.isBefore(now) 
          ? reminderTime.add(const Duration(days: 1))
          : reminderTime;
      
      const androidDetails = AndroidNotificationDetails(
        'food_tracking',
        'Food Tracking Reminders',
        channelDescription: 'Daily reminders to track your food intake',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_restaurant',
      );
      
      const notificationDetails = NotificationDetails(android: androidDetails);
      
      // Convert to timezone-aware datetime  
      final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        7777, // Unique ID for food tracking reminders
        '🍽️ Food Tracking Time',
        'Don\'t forget to log what you ate today! Tap to track your meals.',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'food_tracking_reminder',
      );
      
      
      // Schedule the next day's reminder
      await _scheduleNextFoodTrackingReminder();
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling food tracking reminder: $e');
      }
    }
  }

  // Schedule the next food tracking reminder (for tomorrow)
  Future<void> _scheduleNextFoodTrackingReminder() async {
    try {
      // Schedule for tomorrow at 8 PM
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final reminderTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20, 0);
      
      const androidDetails = AndroidNotificationDetails(
        'food_tracking',
        'Food Tracking Reminders',
        channelDescription: 'Daily reminders to track your food intake',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_restaurant',
      );
      
      const notificationDetails = NotificationDetails(android: androidDetails);
      
      // Convert to timezone-aware datetime
      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        7776, // Different ID for next day's reminder
        '🍽️ Food Tracking Time',
        'Don\'t forget to log what you ate today! Tap to track your meals.',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'food_tracking_reminder',
      );
      
      
    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling next food tracking reminder: $e');
      }
    }
  }

  // Cancel food tracking reminders
  Future<void> cancelFoodTrackingReminders() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(7777);
      await flutterLocalNotificationsPlugin.cancel(7776);

    } catch (e) {
      if (kDebugMode) {
        print('ERROR cancelling food tracking reminders: $e');
      }
    }
  }

  // Handle task reminder notification triggered - reschedule next occurrence for recurring tasks
  Future<void> _handleTaskReminderTriggered(String taskId) async {
    try {

      // Import TaskService to reschedule recurring tasks
      // Note: We need to be careful about circular dependencies here
      // For now, we'll use a simple approach and let the TaskService handle the logic

      // Schedule a delayed call to reschedule the task after app startup
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          // This will trigger a reschedule of all task notifications
          // which will include the next occurrence of this recurring task
          _rescheduleAllTaskNotifications();
        } catch (e) {
          if (kDebugMode) {
            print('ERROR rescheduling task notifications: $e');
          }
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('ERROR handling task reminder triggered: $e');
      }
    }
  }

  // Method to trigger rescheduling of all task notifications
  Future<void> _rescheduleAllTaskNotifications() async {
    try {
      // Get TaskService instance and trigger reschedule
      final taskService = TaskService();
      await taskService.forceRescheduleAllNotifications();

    } catch (e) {
      if (kDebugMode) {
        print('ERROR rescheduling all task notifications: $e');
      }
    }
  }
}