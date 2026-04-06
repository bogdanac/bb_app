import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/timezone_utils.dart';
import '../shared/error_logger.dart';
import '../Settings/app_customization_service.dart';
import '../FoodTracking/food_tracking_service.dart';
import '../Tasks/task_service.dart';
import '../WaterTracking/water_settings_model.dart';
import 'notification_service.dart';

/// Engagement notifications to encourage app usage:
/// - Food tracking streak (9:45 PM daily)
/// - Weekly insights (Sunday 7 PM)
/// - Gentle check-in (2 PM if app not opened)
/// - Celebration notifications (triggered on completion)
class EngagementNotificationService {
  static const int _foodStreakNotificationId = 6100;
  static const int _weeklyInsightsNotificationId = 6200;
  static const int _checkInNotificationId = 6300;
  static const int _celebrationTasksId = 6400;
  static const int _celebrationWaterId = 6401;
  static const int _windDownNotificationId = 6500;
  static const int _monthlySummaryNotificationId = 6600;

  // SharedPreferences keys
  static const String _foodStreakKey = 'food_tracking_streak_days';
  static const String _lastFoodStreakDateKey = 'food_tracking_streak_last_date';
  static const String _lastAppOpenDateKey = 'engagement_last_app_open_date';

  final NotificationService _notificationService;

  EngagementNotificationService(this._notificationService);

  /// Schedule all engagement notifications
  Future<void> scheduleAll() async {
    await _scheduleFoodStreakNotification();
    await _scheduleWeeklyInsightsNotification();
    await _scheduleCheckInNotification();
    await _scheduleWindDownNotification();
    await _scheduleMonthlySummaryNotification();
  }

  // ============================================================
  // FOOD TRACKING STREAK (9:45 PM daily)
  // ============================================================

  /// Schedule the food tracking streak notification at 9:45 PM daily
  Future<void> _scheduleFoodStreakNotification() async {
    try {
      final foodModuleEnabled = await AppCustomizationService.isModuleEnabled(
        AppCustomizationService.moduleFood,
      );

      await _notificationService.flutterLocalNotificationsPlugin.cancel(_foodStreakNotificationId);

      if (!foodModuleEnabled) return;

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, 21, 45);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Get current streak to include in notification
      final streak = await _getFoodStreak();
      final message = _getFoodStreakMessage(streak);

      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        _foodStreakNotificationId,
        message['title']!,
        message['body']!,
        TimezoneUtils.forNotification(scheduledDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'engagement_streaks',
            'Streak Reminders',
            channelDescription: 'Notifications about your tracking streaks',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notif_food',
            color: Color(0xFF4CAF50),
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
        payload: 'food_tracking_reminder',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService._scheduleFoodStreakNotification',
        error: 'Error scheduling food streak notification: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Get current food tracking streak (consecutive days with logged food)
  Future<int> _getFoodStreak() async {
    try {
      final summaries = await FoodTrackingService.getDailySummaries();
      if (summaries.isEmpty) return 0;

      int streak = 0;
      var checkDate = DateTime.now();

      // Check if today has entries - if checking at 9:45 PM, today should count
      final todayKey = DateTime(checkDate.year, checkDate.month, checkDate.day);
      if (summaries.containsKey(todayKey)) {
        streak = 1;
      } else {
        // If no entry today yet, start checking from yesterday
        // (the notification is at 9:45 PM so give them a chance)
        return 0; // No entry today = streak is 0 or about to break
      }

      // Count consecutive days backwards
      checkDate = checkDate.subtract(const Duration(days: 1));
      while (true) {
        final dayKey = DateTime(checkDate.year, checkDate.month, checkDate.day);
        if (summaries.containsKey(dayKey)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      return 0;
    }
  }

  /// Get streak-appropriate notification message
  Map<String, String> _getFoodStreakMessage(int streak) {
    if (streak == 0) {
      return {
        'title': '🍽️ Don\'t forget!',
        'body': 'You haven\'t logged any food today. Log now to start a streak!',
      };
    } else if (streak == 1) {
      return {
        'title': '🍽️ Great start!',
        'body': 'You logged food today! Do it again tomorrow to build a streak.',
      };
    } else if (streak < 7) {
      return {
        'title': '🔥 $streak-day streak!',
        'body': 'You\'ve logged food $streak days in a row. Keep it going!',
      };
    } else if (streak < 30) {
      return {
        'title': '🔥🔥 $streak-day streak!',
        'body': 'Amazing consistency! $streak days of food tracking. You\'re building a real habit!',
      };
    } else {
      return {
        'title': '🏆 $streak-day streak!',
        'body': 'Incredible! $streak consecutive days of food tracking. You\'re unstoppable!',
      };
    }
  }

  /// Update streak when food is logged (call from food tracking service)
  static Future<void> updateFoodStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastDate = prefs.getString(_lastFoodStreakDateKey);

      if (lastDate == todayStr) return; // Already updated today

      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      int currentStreak = prefs.getInt(_foodStreakKey) ?? 0;

      if (lastDate == yesterdayStr) {
        // Consecutive day - increment streak
        currentStreak++;
      } else {
        // Streak broken or first entry - start at 1
        currentStreak = 1;
      }

      await prefs.setInt(_foodStreakKey, currentStreak);
      await prefs.setString(_lastFoodStreakDateKey, todayStr);
    } catch (e) {
      // Silent fail - streak tracking is non-critical
    }
  }

  // ============================================================
  // WEEKLY INSIGHTS (Sunday 7 PM)
  // ============================================================

  /// Schedule weekly insights notification for Sunday at 7 PM
  Future<void> _scheduleWeeklyInsightsNotification() async {
    try {
      await _notificationService.flutterLocalNotificationsPlugin.cancel(_weeklyInsightsNotificationId);

      final now = DateTime.now();
      // Find next Sunday at 7 PM
      var nextSunday = DateTime(now.year, now.month, now.day, 19, 0);
      while (nextSunday.weekday != DateTime.sunday || nextSunday.isBefore(now)) {
        nextSunday = nextSunday.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        _weeklyInsightsNotificationId,
        '📊 Your Week in Review',
        'Tap to see how your week went — tasks, water, routines & more!',
        TimezoneUtils.forNotification(nextSunday),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'engagement_insights',
            'Weekly Insights',
            channelDescription: 'Weekly summary of your app activity',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notif_review',
            color: Color(0xFF9C27B0),
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
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeat weekly on Sunday
        payload: 'weekly_insights',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService._scheduleWeeklyInsightsNotification',
        error: 'Error scheduling weekly insights notification: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Generate weekly insights summary text
  static Future<Map<String, dynamic>> generateWeeklyInsights() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday % 7)); // Start of week (Sunday)
      final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);

      // Tasks completed this week
      final taskService = TaskService();
      final allTasks = await taskService.loadTasks();
      final tasksCompletedThisWeek = allTasks.where((task) {
        if (!task.isCompleted || task.completedAt == null) return false;
        return task.completedAt!.isAfter(weekStartDay);
      }).length;

      // Food tracking days this week
      final foodSummaries = await FoodTrackingService.getDailySummaries();
      int foodDaysThisWeek = 0;
      for (int i = 0; i < 7; i++) {
        final day = weekStartDay.add(Duration(days: i));
        final dayKey = DateTime(day.year, day.month, day.day);
        if (foodSummaries.containsKey(dayKey)) {
          foodDaysThisWeek++;
        }
      }

      // Water days this week (check SharedPreferences for each day)
      final prefs = await SharedPreferences.getInstance();
      final waterSettings = await WaterSettings.load();
      int waterGoalDays = 0;
      int totalWaterMl = 0;
      for (int i = 0; i < 7; i++) {
        final day = weekStartDay.add(Duration(days: i));
        final dayStr = day.toIso8601String().split('T')[0];
        final intake = prefs.getInt('water_$dayStr') ?? 0;
        totalWaterMl += intake;
        if (intake >= waterSettings.dailyGoal) {
          waterGoalDays++;
        }
      }

      return {
        'tasksCompleted': tasksCompletedThisWeek,
        'foodDaysTracked': foodDaysThisWeek,
        'waterGoalDays': waterGoalDays,
        'totalWaterLiters': (totalWaterMl / 1000).toStringAsFixed(1),
      };
    } catch (e) {
      return {
        'tasksCompleted': 0,
        'foodDaysTracked': 0,
        'waterGoalDays': 0,
        'totalWaterLiters': '0',
      };
    }
  }

  // ============================================================
  // GENTLE CHECK-IN (2 PM if app not opened today)
  // ============================================================

  /// Schedule the check-in notification at 2 PM daily
  Future<void> _scheduleCheckInNotification() async {
    try {
      await _notificationService.flutterLocalNotificationsPlugin.cancel(_checkInNotificationId);

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, 14, 0);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        _checkInNotificationId,
        '👋 Haven\'t seen you today!',
        'Your tasks and routines are waiting. Tap to check in.',
        TimezoneUtils.forNotification(scheduledDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'engagement_checkin',
            'Daily Check-in',
            channelDescription: 'Gentle reminder to open the app',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF2196F3),
            playSound: false,
            enableVibration: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'check_in',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService._scheduleCheckInNotification',
        error: 'Error scheduling check-in notification: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Call this when app is opened to cancel today's check-in notification
  /// and record that the app was opened today
  Future<void> onAppOpened() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final lastOpenDate = prefs.getString(_lastAppOpenDateKey);

      if (lastOpenDate != todayStr) {
        // First open of the day - cancel the check-in notification for today
        await _notificationService.flutterLocalNotificationsPlugin.cancel(_checkInNotificationId);
        await prefs.setString(_lastAppOpenDateKey, todayStr);

        // Reschedule for tomorrow (since we cancelled the repeating one)
        final tomorrow = DateTime(today.year, today.month, today.day + 1, 14, 0);
        await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
          _checkInNotificationId,
          '👋 Haven\'t seen you today!',
          'Your tasks and routines are waiting. Tap to check in.',
          TimezoneUtils.forNotification(tomorrow),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'engagement_checkin',
              'Daily Check-in',
              channelDescription: 'Gentle reminder to open the app',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
              color: Color(0xFF2196F3),
              playSound: false,
              enableVibration: false,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: false,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'check_in',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService.onAppOpened',
        error: 'Error handling app opened: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // CELEBRATION NOTIFICATIONS (triggered immediately)
  // ============================================================

  /// Show celebration when all daily tasks are completed
  static Future<void> showTasksCelebration(int tasksCompleted) async {
    try {
      final notificationService = NotificationService();

      await notificationService.flutterLocalNotificationsPlugin.show(
        _celebrationTasksId,
        '🎉 All Tasks Done!',
        'You crushed it! All $tasksCompleted tasks completed today. Well done! 💪',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'engagement_celebrations',
            'Celebrations',
            channelDescription: 'Celebrate your achievements',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notif_task',
            color: Color(0xFF4CAF50),
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'celebration_tasks',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService.showTasksCelebration',
        error: 'Error showing tasks celebration: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Show celebration when water goal is reached
  static Future<void> showWaterGoalCelebration(int goalMl) async {
    try {
      final notificationService = NotificationService();

      await notificationService.flutterLocalNotificationsPlugin.show(
        _celebrationWaterId,
        '💧🎉 Water Goal Reached!',
        'You hit your ${goalMl}ml goal! Your body thanks you. Stay hydrated! 🌊',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'engagement_celebrations',
            'Celebrations',
            channelDescription: 'Celebrate your achievements',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_water_drop',
            color: Color(0xFF2196F3),
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'celebration_water',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService.showWaterGoalCelebration',
        error: 'Error showing water goal celebration: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // EVENING WIND-DOWN (configurable, default 9:30 PM)
  // ============================================================

  /// Schedule evening wind-down notification
  /// "Time to wind down. Review your day and plan tomorrow's top 3 tasks."
  Future<void> _scheduleWindDownNotification() async {
    try {
      await _notificationService.flutterLocalNotificationsPlugin.cancel(_windDownNotificationId);

      final prefs = await SharedPreferences.getInstance();
      final windDownEnabled = prefs.getBool('wind_down_notification_enabled') ?? true;
      if (!windDownEnabled) return;

      final windDownHour = prefs.getInt('wind_down_notification_hour') ?? 21;
      final windDownMinute = prefs.getInt('wind_down_notification_minute') ?? 30;

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, windDownHour, windDownMinute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        _windDownNotificationId,
        '🌙 Time to Wind Down',
        'Review your day and plan tomorrow\'s top 3 tasks.',
        TimezoneUtils.forNotification(scheduledDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'engagement_winddown',
            'Evening Wind-down',
            channelDescription: 'Evening reminder to review your day and plan tomorrow',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@drawable/ic_notif_review',
            color: Color(0xFF5C6BC0), // Indigo
            playSound: false,
            enableVibration: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'end_of_day_review',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService._scheduleWindDownNotification',
        error: 'Error scheduling wind-down notification: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // MONTHLY PROGRESS SUMMARY (1st of each month, 10 AM)
  // ============================================================

  /// Schedule monthly summary notification on the 1st of each month at 10 AM
  Future<void> _scheduleMonthlySummaryNotification() async {
    try {
      await _notificationService.flutterLocalNotificationsPlugin.cancel(_monthlySummaryNotificationId);

      final now = DateTime.now();
      // Find next 1st of month at 10 AM
      var nextFirstOfMonth = DateTime(now.year, now.month + 1, 1, 10, 0);
      // If we're on the 1st and it's before 10 AM, schedule for today
      if (now.day == 1 && now.hour < 10) {
        nextFirstOfMonth = DateTime(now.year, now.month, 1, 10, 0);
      }

      await _notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        _monthlySummaryNotificationId,
        '📈 Your Monthly Recap',
        'See how last month went — tasks, water, food tracking & more. Tap to view!',
        TimezoneUtils.forNotification(nextFirstOfMonth),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'engagement_monthly',
            'Monthly Summary',
            channelDescription: 'Monthly recap of your progress',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notif_review',
            color: Color(0xFF9C27B0), // Purple
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
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime, // Repeat monthly on 1st
        payload: 'monthly_summary',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EngagementNotificationService._scheduleMonthlySummaryNotification',
        error: 'Error scheduling monthly summary notification: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Generate monthly summary data for the previous month
  static Future<Map<String, dynamic>> generateMonthlySummary() async {
    try {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0); // Last day of previous month
      final daysInMonth = lastMonthEnd.day;

      // Tasks completed last month
      final taskService = TaskService();
      final allTasks = await taskService.loadTasks();
      final tasksCompletedLastMonth = allTasks.where((task) {
        if (!task.isCompleted || task.completedAt == null) return false;
        return task.completedAt!.isAfter(lastMonth) &&
               task.completedAt!.isBefore(DateTime(now.year, now.month, 1));
      }).length;

      // Food tracking days last month
      final foodSummaries = await FoodTrackingService.getDailySummaries();
      int foodDaysLastMonth = 0;
      for (int i = 0; i < daysInMonth; i++) {
        final day = lastMonth.add(Duration(days: i));
        final dayKey = DateTime(day.year, day.month, day.day);
        if (foodSummaries.containsKey(dayKey)) {
          foodDaysLastMonth++;
        }
      }

      // Water goal days last month
      final prefs = await SharedPreferences.getInstance();
      final waterSettings = await WaterSettings.load();
      int waterGoalDays = 0;
      int totalWaterMl = 0;
      for (int i = 0; i < daysInMonth; i++) {
        final day = lastMonth.add(Duration(days: i));
        final dayStr = day.toIso8601String().split('T')[0];
        final intake = prefs.getInt('water_$dayStr') ?? 0;
        totalWaterMl += intake;
        if (intake >= waterSettings.dailyGoal) {
          waterGoalDays++;
        }
      }

      return {
        'monthName': _getMonthName(lastMonth.month),
        'tasksCompleted': tasksCompletedLastMonth,
        'foodDaysTracked': foodDaysLastMonth,
        'daysInMonth': daysInMonth,
        'waterGoalDays': waterGoalDays,
        'totalWaterLiters': (totalWaterMl / 1000).toStringAsFixed(1),
      };
    } catch (e) {
      return {
        'monthName': 'Last month',
        'tasksCompleted': 0,
        'foodDaysTracked': 0,
        'daysInMonth': 30,
        'waterGoalDays': 0,
        'totalWaterLiters': '0',
      };
    }
  }

  static String _getMonthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
}
