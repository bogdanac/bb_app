import 'dart:io';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../Notifications/notification_service.dart';

class TimerNotificationHelper {
  static const int _timerNotificationId = 200;
  static const int _completionNotificationId = 201;
  static final NotificationService _notificationService = NotificationService();

  /// Check if we're on a desktop platform
  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Check if we're on a mobile platform
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<void> showTimerNotification({
    required String activityName,
    required Duration remaining,
    required bool isPomodoro,
    required bool isBreak,
    required bool isPaused,
  }) async {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);

    String title;
    if (isPaused) {
      title = 'Timer Paused';
    } else if (isPomodoro && isBreak) {
      title = 'Break Time';
    } else if (isPomodoro) {
      title = 'Focus Time';
    } else {
      title = 'Countdown';
    }

    final body = '$activityName — ${minutes}m ${seconds}s remaining';

    await _notificationService.flutterLocalNotificationsPlugin.show(
      _timerNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'timer_progress',
          'Timer Progress',
          channelDescription: 'Ongoing timer progress updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xE4E33B95),
          ongoing: true,
          autoCancel: false,
          enableVibration: false,
          playSound: false,
          category: AndroidNotificationCategory.progress,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
      payload: 'timer_progress',
    );
  }

  static Future<void> showFlowNotification({
    required String activityName,
    required Duration flowExtra,
    required Duration totalTime,
    required bool isPaused,
  }) async {
    final extraMinutes = flowExtra.inMinutes;
    final extraSeconds = flowExtra.inSeconds.remainder(60);
    final totalMinutes = totalTime.inMinutes;

    final title = isPaused ? 'Flow Paused' : 'IN THE FLOW 🔥';
    final body = '$activityName — +${extraMinutes}m ${extraSeconds}s (${totalMinutes}m total)';

    await _notificationService.flutterLocalNotificationsPlugin.show(
      _timerNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'timer_progress',
          'Timer Progress',
          channelDescription: 'Ongoing timer progress updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFFF9800), // Orange for flow
          ongoing: true,
          autoCancel: false,
          enableVibration: false,
          playSound: false,
          category: AndroidNotificationCategory.progress,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
      payload: 'timer_progress',
    );
  }

  static Future<void> showActivityTimerNotification({
    required String activityName,
    required Duration elapsed,
  }) async {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);

    final body = hours > 0
        ? '$activityName — ${hours}h ${minutes}m elapsed'
        : '$activityName — ${minutes}m ${seconds}s elapsed';

    await _notificationService.flutterLocalNotificationsPlugin.show(
      _timerNotificationId,
      'Activity Timer',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'timer_progress',
          'Timer Progress',
          channelDescription: 'Ongoing timer progress updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xE4E33B95),
          ongoing: true,
          autoCancel: false,
          enableVibration: false,
          playSound: false,
          category: AndroidNotificationCategory.progress,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
      payload: 'timer_progress',
    );
  }

  static Future<void> cancelTimerNotification() async {
    await _notificationService.flutterLocalNotificationsPlugin
        .cancel(_timerNotificationId);
  }

  /// Show a completion notification with sound/vibration
  /// This is more prominent than the progress notification
  static Future<void> showCompletionNotification({
    required String title,
    required String body,
    bool isBreakComplete = false,
  }) async {
    // Cancel the ongoing progress notification first
    await cancelTimerNotification();

    // On desktop, notifications work differently - we still show them
    // but the app should also show an in-app alert
    await _notificationService.flutterLocalNotificationsPlugin.show(
      _completionNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'timer_complete',
          'Timer Complete',
          channelDescription: 'Alerts when a timer finishes',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: isBreakComplete
              ? const Color(0xFF4CAF50) // Green for break
              : const Color(0xFFE91E63), // Pink for work
          ongoing: false,
          autoCancel: true,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'timer_complete',
    );
  }

  /// Cancel the completion notification (if user tapped it or dismissed it)
  static Future<void> cancelCompletionNotification() async {
    await _notificationService.flutterLocalNotificationsPlugin
        .cancel(_completionNotificationId);
  }
}
