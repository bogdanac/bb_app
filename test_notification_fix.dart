import 'package:flutter/foundation.dart';
import 'lib/Tasks/tasks_data_models.dart';
import 'lib/Notifications/notification_service.dart';

void main() async {
  if (kDebugMode) {
    print('Testing task notification scheduling...');
    
    // Create a test task with reminder
    final testTask = Task(
      id: 'test_task_123',
      title: 'Test Reminder Task',
      description: 'This is a test task to verify reminders work',
      categoryIds: [],
      deadline: null,
      reminderTime: DateTime.now().add(Duration(minutes: 1)), // 1 minute from now
      isImportant: true,
      recurrence: null,
      isCompleted: false,
      completedAt: null,
      createdAt: DateTime.now(),
    );
    
    // Test notification service
    final notificationService = NotificationService();
    await notificationService.initializeNotifications();
    
    // Schedule the test notification
    await notificationService.scheduleTaskNotification(
      testTask.id,
      testTask.title,
      testTask.reminderTime!,
      isRecurring: false,
    );
    
    print('Test notification scheduled for: ${testTask.reminderTime}');
    print('Notification should appear in 1 minute.');
    print('Test completed successfully!');
  }
}