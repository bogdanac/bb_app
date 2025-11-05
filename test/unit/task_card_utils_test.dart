import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/task_card_utils.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/theme/app_colors.dart';

void main() {
  group('TaskCardUtils - Priority Reason', () {
    test('deadline today should return "today"', () {
      final today = DateTime.now();
      final task = Task(
        id: 'test1',
        title: 'Test Task',
        deadline: DateTime(today.year, today.month, today.day, 23, 59),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('today'));
    });

    test('deadline tomorrow (non-recurring) should return "tomorrow"', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test2',
        title: 'Test Task',
        deadline: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('tomorrow'));
    });

    test('scheduled today should return "Scheduled today"', () {
      final today = DateTime.now();
      final task = Task(
        id: 'test3',
        title: 'Test Task',
        scheduledDate: DateTime(today.year, today.month, today.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('Scheduled today'));
    });

    test('scheduled today with reminder in 10 minutes should return "Reminder in 10m"', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final reminderTime = now.add(const Duration(minutes: 10));

      final task = Task(
        id: 'test_reminder1',
        title: 'Test Task',
        scheduledDate: today,
        reminderTime: reminderTime,
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('Reminder in 10m'));
    });

    test('scheduled today with reminder now should return "Reminder now"', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final task = Task(
        id: 'test_reminder2',
        title: 'Test Task',
        scheduledDate: today,
        reminderTime: now,
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('Reminder now'));
    });

    test('scheduled today with reminder in 2 hours should return "Scheduled today"', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final reminderTime = now.add(const Duration(hours: 2));

      final task = Task(
        id: 'test_reminder3',
        title: 'Test Task',
        scheduledDate: today,
        reminderTime: reminderTime,
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('Scheduled today'));
    });

    test('scheduled tomorrow with reminder should return empty (not today)', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final reminderTime = tomorrow.add(const Duration(hours: 10));

      final task = Task(
        id: 'test_reminder4',
        title: 'Test Task',
        scheduledDate: tomorrow,
        reminderTime: reminderTime,
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals(''));
    });

    test('recurring task scheduled tomorrow should return "tomorrow"', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test4',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          interval: 1,
        ),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('tomorrow'));
    });

    test('postponed task scheduled tomorrow should return "tomorrow"', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test5',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        isPostponed: true,
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('tomorrow'));
    });

    test('simple task scheduled tomorrow (no recurrence, not postponed) should return empty', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test6',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('')); // Should be empty - chip will show instead
    });

    test('overdue deadline should return overdue message', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final task = Task(
        id: 'test7',
        title: 'Test Task',
        deadline: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getTaskPriorityReason(task);
      expect(result, equals('overdue (1 day)'));
    });
  });

  group('TaskCardUtils - Priority Color', () {
    test('deadline today should return red color', () {
      final color = TaskCardUtils.getPriorityColor('today');
      expect(color, equals(AppColors.red));
    });

    test('scheduled today should return green color', () {
      final color = TaskCardUtils.getPriorityColor('Scheduled today');
      expect(color, equals(AppColors.successGreen));
    });

    test('tomorrow should return yellow color', () {
      final color = TaskCardUtils.getPriorityColor('tomorrow');
      expect(color, equals(AppColors.yellow));
    });

    test('overdue should return red color', () {
      final color = TaskCardUtils.getPriorityColor('overdue');
      expect(color, equals(AppColors.red));
    });

    test('overdue (1 day) should return red color', () {
      final color = TaskCardUtils.getPriorityColor('overdue (1 day)');
      expect(color, equals(AppColors.red));
    });
  });

  group('TaskCardUtils - Scheduled Date Text', () {
    test('should return null when scheduledDate is null', () {
      final task = Task(
        id: 'test8',
        title: 'Test Task',
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getScheduledDateText(task, '');
      expect(result, isNull);
    });

    test('should return null when priority already says "Scheduled today"', () {
      final today = DateTime.now();
      final task = Task(
        id: 'test9',
        title: 'Test Task',
        scheduledDate: DateTime(today.year, today.month, today.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getScheduledDateText(task, 'Scheduled today');
      expect(result, isNull); // Prevents duplicate chip
    });

    test('should return null when priority says "tomorrow" and task scheduled tomorrow', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test10',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          interval: 1,
        ),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getScheduledDateText(task, 'tomorrow');
      expect(result, isNull); // Prevents duplicate chip
    });

    test('should return "Tomorrow" for simple task scheduled tomorrow', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test11',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getScheduledDateText(task, '');
      expect(result, equals('Tomorrow'));
    });

    test('should return "Today" for scheduled today when no priority conflict', () {
      final today = DateTime.now();
      final task = Task(
        id: 'test12',
        title: 'Test Task',
        scheduledDate: DateTime(today.year, today.month, today.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getScheduledDateText(task, 'important');
      expect(result, equals('Today'));
    });

    test('should return formatted date for future dates', () {
      final today = DateTime.now();
      final future = today.add(const Duration(days: 5));
      final task = Task(
        id: 'test13',
        title: 'Test Task',
        scheduledDate: DateTime(future.year, future.month, future.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getScheduledDateText(task, '');
      expect(result, isNotNull);
      expect(result, isNot(equals('Today')));
      expect(result, isNot(equals('Tomorrow')));
    });

    test('should return null for recurring task with past scheduled date', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final task = Task(
        id: 'test14',
        title: 'Test Task',
        scheduledDate: DateTime(yesterday.year, yesterday.month, yesterday.day),
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          interval: 1,
        ),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final result = TaskCardUtils.getScheduledDateText(task, '');
      expect(result, isNull); // Don't show past dates for recurring tasks
    });
  });

  group('TaskCardUtils - Chip Display Logic Integration', () {
    test('deadline today: should show priority "today" (red), no scheduled chip', () {
      final today = DateTime.now();
      final task = Task(
        id: 'test15',
        title: 'Test Task',
        deadline: DateTime(today.year, today.month, today.day, 23, 59),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final priorityReason = TaskCardUtils.getTaskPriorityReason(task);
      final priorityColor = TaskCardUtils.getPriorityColor(priorityReason);
      final scheduledText = TaskCardUtils.getScheduledDateText(task, priorityReason);

      expect(priorityReason, equals('today'));
      expect(priorityColor, equals(AppColors.red));
      expect(scheduledText, isNull);
    });

    test('deadline tomorrow (no scheduled): should show no priority, deadline chip only', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test16',
        title: 'Test Task',
        deadline: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final priorityReason = TaskCardUtils.getTaskPriorityReason(task);
      final scheduledText = TaskCardUtils.getScheduledDateText(task, priorityReason);

      expect(priorityReason, equals('tomorrow'));
      expect(scheduledText, isNull); // No scheduled date
      // In widget: priority chip should be hidden for deadline-only "tomorrow"
    });

    test('scheduled today: should show priority "Scheduled today" (green), no scheduled chip', () {
      final today = DateTime.now();
      final task = Task(
        id: 'test17',
        title: 'Test Task',
        scheduledDate: DateTime(today.year, today.month, today.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final priorityReason = TaskCardUtils.getTaskPriorityReason(task);
      final priorityColor = TaskCardUtils.getPriorityColor(priorityReason);
      final scheduledText = TaskCardUtils.getScheduledDateText(task, priorityReason);

      expect(priorityReason, equals('Scheduled today'));
      expect(priorityColor, equals(AppColors.successGreen));
      expect(scheduledText, isNull); // Prevented duplicate
    });

    test('simple task scheduled tomorrow: should show no priority, scheduled chip "Tomorrow" (green)', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test18',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final priorityReason = TaskCardUtils.getTaskPriorityReason(task);
      final scheduledText = TaskCardUtils.getScheduledDateText(task, priorityReason);

      expect(priorityReason, equals('')); // No priority
      expect(scheduledText, equals('Tomorrow')); // Shows scheduled chip
    });

    test('postponed task tomorrow: should show priority "tomorrow" (yellow), no scheduled chip', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test19',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        isPostponed: true,
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final priorityReason = TaskCardUtils.getTaskPriorityReason(task);
      final priorityColor = TaskCardUtils.getPriorityColor(priorityReason);
      final scheduledText = TaskCardUtils.getScheduledDateText(task, priorityReason);

      expect(priorityReason, equals('tomorrow'));
      expect(priorityColor, equals(AppColors.yellow));
      expect(scheduledText, isNull); // Prevented duplicate
    });

    test('recurring task tomorrow: should show priority "tomorrow" (yellow), no scheduled chip', () {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final task = Task(
        id: 'test20',
        title: 'Test Task',
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
          interval: 1,
        ),
        categoryIds: [],
        createdAt: DateTime.now(),
      );

      final priorityReason = TaskCardUtils.getTaskPriorityReason(task);
      final priorityColor = TaskCardUtils.getPriorityColor(priorityReason);
      final scheduledText = TaskCardUtils.getScheduledDateText(task, priorityReason);

      expect(priorityReason, equals('tomorrow'));
      expect(priorityColor, equals(AppColors.yellow));
      expect(scheduledText, isNull); // Prevented duplicate
    });
  });
}
