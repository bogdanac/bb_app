import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../Notifications/notification_service.dart';

class TimerNotificationHelper {
  static const int _timerNotificationId = 200;
  static final NotificationService _notificationService = NotificationService();

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
}
