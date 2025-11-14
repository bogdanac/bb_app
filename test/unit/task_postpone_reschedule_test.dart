import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:flutter/material.dart';

void main() {
  group('Postponed Task Auto-Rescheduling', () {
    test('postponed task scheduled for today should clear isPostponed flag', () {
      // GIVEN: A postponed daily recurring task scheduled for today
      final today = DateTime(2025, 11, 10);
      final task = Task(
        id: '1',
        title: 'Daily Task - Postponed to Today',
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        ),
        scheduledDate: today,
        reminderTime: DateTime(today.year, today.month, today.day, 9, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 5),
      );

      // WHEN: We check if the task should have isPostponed cleared
      // This simulates the logic in task_service.dart Case 2a
      final todayDate = DateTime(today.year, today.month, today.day);
      final shouldClearPostponed = task.isPostponed &&
          task.recurrence != null &&
          task.scheduledDate != null &&
          (task.scheduledDate!.isBefore(todayDate) ||
              _isSameDay(task.scheduledDate!, todayDate)) &&
          task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt);

      // THEN: isPostponed should be cleared
      expect(shouldClearPostponed, isTrue,
          reason: 'Postponed tasks scheduled for today should have isPostponed cleared');
    });

    test('postponed task scheduled before today should clear isPostponed flag', () {
      // GIVEN: A postponed task scheduled in the past
      final today = DateTime(2025, 11, 10);
      final yesterday = DateTime(2025, 11, 9);
      final task = Task(
        id: '2',
        title: 'Daily Task - Postponed to Yesterday',
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        ),
        scheduledDate: yesterday,
        reminderTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 5),
      );

      // WHEN: We check if the task should have isPostponed cleared
      final todayDate = DateTime(today.year, today.month, today.day);
      final shouldClearPostponed = task.isPostponed &&
          task.recurrence != null &&
          task.scheduledDate != null &&
          (task.scheduledDate!.isBefore(todayDate) ||
              _isSameDay(task.scheduledDate!, todayDate)) &&
          task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt);

      // THEN: isPostponed should be cleared
      expect(shouldClearPostponed, isTrue,
          reason: 'Postponed tasks scheduled before today should have isPostponed cleared');
    });

    test('postponed task scheduled for tomorrow should NOT clear isPostponed flag', () {
      // GIVEN: A postponed task scheduled for tomorrow
      final today = DateTime(2025, 11, 10);
      final tomorrow = DateTime(2025, 11, 11);
      final task = Task(
        id: '3',
        title: 'Daily Task - Postponed to Tomorrow',
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        ),
        scheduledDate: tomorrow,
        reminderTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 5),
      );

      // WHEN: We check if the task should have isPostponed cleared
      final todayDate = DateTime(today.year, today.month, today.day);
      final shouldClearPostponed = task.isPostponed &&
          task.recurrence != null &&
          task.scheduledDate != null &&
          (task.scheduledDate!.isBefore(todayDate) ||
              _isSameDay(task.scheduledDate!, todayDate)) &&
          task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt);

      // THEN: isPostponed should NOT be cleared (task is still in the future)
      expect(shouldClearPostponed, isFalse,
          reason: 'Postponed tasks scheduled for future should keep isPostponed flag');
    });

    test('weekly recurring task postponed to today should clear isPostponed', () {
      // GIVEN: A postponed weekly recurring task scheduled for today
      final today = DateTime(2025, 11, 10); // Monday
      final task = Task(
        id: '4',
        title: 'Weekly Task - Postponed to Today',
        recurrence: TaskRecurrence(
          type: RecurrenceType.weekly,
          weekDays: [DateTime.monday],
          reminderTime: const TimeOfDay(hour: 10, minute: 0),
        ),
        scheduledDate: today,
        reminderTime: DateTime(today.year, today.month, today.day, 10, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 3), // Last Monday
      );

      // WHEN: We check if the task should have isPostponed cleared
      final todayDate = DateTime(today.year, today.month, today.day);
      final shouldClearPostponed = task.isPostponed &&
          task.recurrence != null &&
          task.scheduledDate != null &&
          (task.scheduledDate!.isBefore(todayDate) ||
              _isSameDay(task.scheduledDate!, todayDate)) &&
          task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt);

      // THEN: isPostponed should be cleared
      expect(shouldClearPostponed, isTrue,
          reason: 'Postponed weekly tasks scheduled for today should have isPostponed cleared');
    });

    test('monthly recurring task postponed to today should clear isPostponed', () {
      // GIVEN: A postponed monthly recurring task scheduled for today
      final today = DateTime(2025, 11, 10);
      final task = Task(
        id: '5',
        title: 'Monthly Task - Postponed to Today',
        recurrence: TaskRecurrence(
          type: RecurrenceType.monthly,
          dayOfMonth: 10,
          reminderTime: const TimeOfDay(hour: 12, minute: 0),
        ),
        scheduledDate: today,
        reminderTime: DateTime(today.year, today.month, today.day, 12, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 10, 10), // Last month
      );

      // WHEN: We check if the task should have isPostponed cleared
      final todayDate = DateTime(today.year, today.month, today.day);
      final shouldClearPostponed = task.isPostponed &&
          task.recurrence != null &&
          task.scheduledDate != null &&
          (task.scheduledDate!.isBefore(todayDate) ||
              _isSameDay(task.scheduledDate!, todayDate)) &&
          task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt);

      // THEN: isPostponed should be cleared
      expect(shouldClearPostponed, isTrue,
          reason: 'Postponed monthly tasks scheduled for today should have isPostponed cleared');
    });

    test('non-recurring postponed task should NOT auto-clear isPostponed', () {
      // GIVEN: A postponed non-recurring task scheduled for today
      final today = DateTime(2025, 11, 10);
      final task = Task(
        id: '6',
        title: 'One-Time Task - Postponed to Today',
        scheduledDate: today,
        reminderTime: DateTime(today.year, today.month, today.day, 14, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 9),
      );

      // WHEN: We check if the task should have isPostponed cleared
      final todayDate = DateTime(today.year, today.month, today.day);
      final shouldClearPostponed = task.isPostponed &&
          task.recurrence != null && // This will be false for non-recurring tasks
          task.scheduledDate != null &&
          (task.scheduledDate!.isBefore(todayDate) ||
              _isSameDay(task.scheduledDate!, todayDate));

      // THEN: isPostponed should NOT be cleared (non-recurring tasks don't auto-clear)
      expect(shouldClearPostponed, isFalse,
          reason: 'Non-recurring postponed tasks should keep isPostponed flag');
    });

    test('cleared isPostponed flag should enable recurring notifications', () {
      // GIVEN: A task that was postponed but now has isPostponed cleared
      final task = Task(
        id: '7',
        title: 'Task with Cleared Postpone Flag',
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        ),
        scheduledDate: DateTime(2025, 11, 10),
        reminderTime: DateTime(2025, 11, 10, 9, 0),
        isPostponed: false, // Cleared
        createdAt: DateTime(2025, 11, 5),
      );

      // WHEN: We check if notifications should be scheduled as recurring
      final shouldScheduleAsRecurring = task.recurrence != null && !task.isPostponed;

      // THEN: Notifications should be scheduled as recurring
      expect(shouldScheduleAsRecurring, isTrue,
          reason: 'Tasks with cleared isPostponed should resume recurring notifications');
    });
  });
}

// Helper function to check if two dates are the same day
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
