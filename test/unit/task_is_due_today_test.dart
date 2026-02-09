import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

void main() {
  late DateTime today;
  late DateTime yesterday;
  late DateTime tomorrow;
  late DateTime twoDaysAgo;

  setUp(() {
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    yesterday = today.subtract(const Duration(days: 1));
    tomorrow = today.add(const Duration(days: 1));
    twoDaysAgo = today.subtract(const Duration(days: 2));
  });

  group('isDueToday - Non-recurring tasks', () {
    test('task with deadline today is due today', () {
      final task = Task(
        id: '1',
        title: 'Deadline Today',
        deadline: today,
        createdAt: yesterday,
      );

      expect(task.isDueToday(), isTrue);
    });

    test('task with deadline yesterday (overdue) is due today', () {
      final task = Task(
        id: '1',
        title: 'Overdue Deadline',
        deadline: yesterday,
        createdAt: twoDaysAgo,
      );

      expect(task.isDueToday(), isTrue);
    });

    test('task scheduled for today is due today', () {
      final task = Task(
        id: '1',
        title: 'Scheduled Today',
        scheduledDate: today,
        createdAt: yesterday,
      );

      expect(task.isDueToday(), isTrue);
    });

    test('task scheduled for tomorrow is NOT due today', () {
      final task = Task(
        id: '1',
        title: 'Scheduled Tomorrow',
        scheduledDate: tomorrow,
        createdAt: today,
      );

      expect(task.isDueToday(), isFalse);
    });
  });

  group('isDueToday - Recurring tasks', () {
    test('recurring task scheduled for today is due today', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today,
        createdAt: yesterday,
      );

      expect(task.isDueToday(), isTrue);
    });

    test('recurring task scheduled for future is NOT due today', () {
      final task = Task(
        id: '1',
        title: 'Daily Task Scheduled Future',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: tomorrow,
        createdAt: today,
      );

      expect(task.isDueToday(), isFalse);
    });

    test('recurring task with recurrence pattern matching today is due today', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        createdAt: yesterday,
      );

      expect(task.isDueToday(), isTrue);
    });
  });

  group('isDueToday - Postponed recurring tasks (BUG FIX)', () {
    test('postponed recurring task scheduled for today is due today', () {
      final task = Task(
        id: '1',
        title: 'Postponed to Today',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today,
        isPostponed: true,
        createdAt: twoDaysAgo,
      );

      expect(task.isDueToday(), isTrue,
          reason: 'Postponed task scheduled for today should be due');
    });

    test('postponed recurring task with OVERDUE scheduledDate is due today', () {
      // This is the key bug fix test case:
      // User has weekly Monday task, postpones to Wednesday
      // Today is Thursday - the scheduledDate (Wednesday) is in the past
      // The task should still show as "due today" because it's overdue
      final task = Task(
        id: '1',
        title: 'Postponed Overdue',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: yesterday, // Postponed to yesterday, now overdue
        isPostponed: true,
        createdAt: twoDaysAgo,
      );

      expect(task.isDueToday(), isTrue,
          reason: 'Postponed task with overdue scheduledDate should be due today');
    });

    test('postponed recurring task with scheduledDate 2 days ago is due today', () {
      final task = Task(
        id: '1',
        title: 'Postponed Very Overdue',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: twoDaysAgo, // Postponed to 2 days ago
        isPostponed: true,
        createdAt: today.subtract(const Duration(days: 5)),
      );

      expect(task.isDueToday(), isTrue,
          reason: 'Overdue postponed task should still be due today');
    });

    test('postponed recurring task scheduled for future is NOT due today', () {
      final task = Task(
        id: '1',
        title: 'Postponed to Future',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: tomorrow, // Postponed to tomorrow
        isPostponed: true,
        createdAt: twoDaysAgo,
      );

      expect(task.isDueToday(), isFalse,
          reason: 'Task postponed to future should NOT be due today');
    });
  });

  group('isDueToday - Edge cases', () {
    test('task with no dates is NOT due today', () {
      final task = Task(
        id: '1',
        title: 'No Dates',
        createdAt: today,
      );

      expect(task.isDueToday(), isFalse);
    });

    test('recurring task without scheduledDate but matching today is due', () {
      final task = Task(
        id: '1',
        title: 'Daily No ScheduledDate',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        createdAt: yesterday,
      );

      expect(task.isDueToday(), isTrue);
    });

    test('completed task is still reported as due today if it matches', () {
      // isDueToday doesn't check completion status - that's handled elsewhere
      final task = Task(
        id: '1',
        title: 'Completed Today',
        scheduledDate: today,
        isCompleted: true,
        completedAt: today,
        createdAt: yesterday,
      );

      expect(task.isDueToday(), isTrue);
    });
  });
}
