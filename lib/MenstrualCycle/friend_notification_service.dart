import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../Notifications/notification_service.dart';
import '../shared/timezone_utils.dart';
import '../shared/error_logger.dart';
import 'friend_data_models.dart';
import 'friend_service.dart';

class FriendNotificationService {
  static final FriendNotificationService _instance = FriendNotificationService._internal();
  factory FriendNotificationService() => _instance;
  FriendNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = NotificationService().flutterLocalNotificationsPlugin;

  // Notification ID ranges for friends: 8000-8999
  static const int _lowBatteryBaseId = 8000;
  static const int _birthdayBaseId = 8500;

  /// Schedule all friend notifications (low battery and birthday)
  /// Call this on app startup and when friends are updated
  Future<void> scheduleAllFriendNotifications() async {
    try {
      final friends = await FriendService.loadFriends();

      // Cancel all existing friend notifications first
      await cancelAllFriendNotifications();

      for (final friend in friends) {
        if (friend.isArchived) continue;

        // Schedule low battery check
        if (friend.notifyLowBattery) {
          await _scheduleLowBatteryCheck(friend);
        }

        // Schedule birthday reminder
        if (friend.notifyBirthday && friend.birthday != null) {
          await _scheduleBirthdayReminder(friend);
        }
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendNotificationService.scheduleAllFriendNotifications',
        error: 'Error scheduling friend notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Check and show low battery notifications immediately
  /// Call this on app startup to check current battery levels
  Future<void> checkLowBatteryNotifications() async {
    try {
      final friends = await FriendService.loadFriends();

      for (final friend in friends) {
        if (friend.isArchived) continue;
        if (!friend.notifyLowBattery) continue;

        final batteryLevel = friend.currentBattery;

        // Show notification if battery is below 30%
        if (batteryLevel < 0.30) {
          await _showLowBatteryNotification(friend, batteryLevel);
        }
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendNotificationService.checkLowBatteryNotifications',
        error: 'Error checking low battery notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Schedule a daily check for low battery at 10 AM
  Future<void> _scheduleLowBatteryCheck(Friend friend) async {
    try {
      final notificationId = _lowBatteryBaseId + friend.id.hashCode.abs() % 500;

      // Check current battery - if already low, show notification
      final batteryLevel = friend.currentBattery;
      if (batteryLevel < 0.30) {
        // Schedule a reminder for tomorrow at 10 AM if battery is low
        final now = DateTime.now();
        var reminderTime = DateTime(now.year, now.month, now.day, 10, 0);
        if (reminderTime.isBefore(now)) {
          reminderTime = reminderTime.add(const Duration(days: 1));
        }

        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '💛 Friendship Reminder',
          '${friend.name}\'s friendship battery is at ${friend.batteryPercentage}%. Time to reconnect!',
          TimezoneUtils.forNotification(reminderTime),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'friend_low_battery',
              'Friendship Reminders',
              channelDescription: 'Reminders when friendship battery is low',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              color: friend.color,
              enableVibration: true,
              playSound: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'friend_low_battery_${friend.id}',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendNotificationService._scheduleLowBatteryCheck',
        error: 'Error scheduling low battery check: $e',
        stackTrace: stackTrace.toString(),
        context: {'friendId': friend.id, 'friendName': friend.name},
      );
    }
  }

  /// Show immediate low battery notification
  Future<void> _showLowBatteryNotification(Friend friend, double batteryLevel) async {
    try {
      final notificationId = _lowBatteryBaseId + friend.id.hashCode.abs() % 500;
      final percentage = (batteryLevel * 100).round();

      String urgency;
      if (percentage <= 10) {
        urgency = 'Critical! ';
      } else if (percentage <= 20) {
        urgency = 'Low! ';
      } else {
        urgency = '';
      }

      await _notificationsPlugin.show(
        notificationId,
        '💛 ${urgency}Friendship Reminder',
        '${friend.name}\'s friendship battery is at $percentage%. Time to reconnect!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'friend_low_battery',
            'Friendship Reminders',
            channelDescription: 'Reminders when friendship battery is low',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: friend.color,
            enableVibration: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'friend_low_battery_${friend.id}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendNotificationService._showLowBatteryNotification',
        error: 'Error showing low battery notification: $e',
        stackTrace: stackTrace.toString(),
        context: {'friendId': friend.id, 'friendName': friend.name},
      );
    }
  }

  /// Schedule birthday reminder 3 days before
  Future<void> _scheduleBirthdayReminder(Friend friend) async {
    try {
      if (friend.birthday == null) return;

      final notificationId = _birthdayBaseId + friend.id.hashCode.abs() % 500;

      final now = DateTime.now();
      final birthday = friend.birthday!;

      // Calculate next birthday
      var nextBirthday = DateTime(now.year, birthday.month, birthday.day);
      if (nextBirthday.isBefore(now) || nextBirthday.difference(now).inDays < 3) {
        // Birthday has passed or is within 3 days, schedule for next year
        nextBirthday = DateTime(now.year + 1, birthday.month, birthday.day);
      }

      // Reminder 3 days before at 10 AM
      final reminderDate = nextBirthday.subtract(const Duration(days: 3));
      final reminderTime = DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 10, 0);

      if (reminderTime.isBefore(now)) {
        return; // Don't schedule past reminders
      }

      final months = ['January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December'];
      final birthdayStr = '${months[birthday.month - 1]} ${birthday.day}';

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '🎂 Birthday Coming Up!',
        '${friend.name}\'s birthday is in 3 days ($birthdayStr). Don\'t forget to wish them!',
        TimezoneUtils.forNotification(reminderTime),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'friend_birthday',
            'Birthday Reminders',
            channelDescription: 'Reminders for upcoming friend birthdays',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: friend.color,
            enableVibration: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'friend_birthday_${friend.id}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendNotificationService._scheduleBirthdayReminder',
        error: 'Error scheduling birthday reminder: $e',
        stackTrace: stackTrace.toString(),
        context: {'friendId': friend.id, 'friendName': friend.name},
      );
    }
  }

  /// Cancel all friend notifications
  Future<void> cancelAllFriendNotifications() async {
    try {
      // Cancel low battery notifications (8000-8499)
      for (int i = _lowBatteryBaseId; i < _birthdayBaseId; i++) {
        await _notificationsPlugin.cancel(i);
      }

      // Cancel birthday notifications (8500-8999)
      for (int i = _birthdayBaseId; i < 9000; i++) {
        await _notificationsPlugin.cancel(i);
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendNotificationService.cancelAllFriendNotifications',
        error: 'Error cancelling friend notifications: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Cancel notifications for a specific friend
  Future<void> cancelFriendNotifications(String friendId) async {
    try {
      final lowBatteryId = _lowBatteryBaseId + friendId.hashCode.abs() % 500;
      final birthdayId = _birthdayBaseId + friendId.hashCode.abs() % 500;

      await _notificationsPlugin.cancel(lowBatteryId);
      await _notificationsPlugin.cancel(birthdayId);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendNotificationService.cancelFriendNotifications',
        error: 'Error cancelling friend notifications: $e',
        stackTrace: stackTrace.toString(),
        context: {'friendId': friendId},
      );
    }
  }
}
