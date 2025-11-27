import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Tasks/services/task_priority_service.dart';
import 'package:flutter/material.dart';

void main() {
  late TaskPriorityService service;
  late List<TaskCategory> categories;

  setUp(() {
    service = TaskPriorityService();
    categories = [
      TaskCategory(id: '1', name: 'Work', color: Colors.blue, order: 0),
      TaskCategory(id: '2', name: 'Personal', color: Colors.green, order: 1),
    ];
  });

  group('Task Date Ordering', () {
    test('tasks with same priority score should be ordered by scheduled date', () {
      // GIVEN: Multiple tasks with same priority but different scheduled dates
      final nov25Task = Task(
        id: '1',
        title: 'Task scheduled Nov 25',
        scheduledDate: DateTime(2025, 11, 25),
        createdAt: DateTime(2025, 11, 1),
      );

      final nov28Task = Task(
        id: '2',
        title: 'Task scheduled Nov 28',
        scheduledDate: DateTime(2025, 11, 28),
        createdAt: DateTime(2025, 11, 1),
      );

      final dec1Task = Task(
        id: '3',
        title: 'Task scheduled Dec 1',
        scheduledDate: DateTime(2025, 12, 1),
        createdAt: DateTime(2025, 11, 1),
      );

      final dec5Task = Task(
        id: '4',
        title: 'Task scheduled Dec 5',
        scheduledDate: DateTime(2025, 12, 5),
        createdAt: DateTime(2025, 11, 1),
      );

      // WHEN: Tasks are prioritized
      final tasks = [dec5Task, nov28Task, dec1Task, nov25Task]; // Intentionally out of order
      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // THEN: Tasks should be ordered by scheduled date (earliest first)
      expect(prioritized[0].id, equals('1'), reason: 'Nov 25 should be first');
      expect(prioritized[1].id, equals('2'), reason: 'Nov 28 should be second');
      expect(prioritized[2].id, equals('3'), reason: 'Dec 1 should be third');
      expect(prioritized[3].id, equals('4'), reason: 'Dec 5 should be fourth');
    });

    test('future scheduled tasks with same priority should maintain date order', () {
      // GIVEN: Future tasks with same priority score (score = ~105-120 for near future)
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dayAfter = DateTime.now().add(const Duration(days: 2));
      final threeDays = DateTime.now().add(const Duration(days: 3));
      final fourDays = DateTime.now().add(const Duration(days: 4));

      final tomorrowTask = Task(
        id: 't1',
        title: 'Tomorrow task',
        scheduledDate: tomorrow,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      final dayAfterTask = Task(
        id: 't2',
        title: 'Day after task',
        scheduledDate: dayAfter,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      final threeDaysTask = Task(
        id: 't3',
        title: 'Three days task',
        scheduledDate: threeDays,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      final fourDaysTask = Task(
        id: 't4',
        title: 'Four days task',
        scheduledDate: fourDays,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      // WHEN: Tasks are prioritized (submit out of order)
      final tasks = [threeDaysTask, tomorrowTask, fourDaysTask, dayAfterTask];
      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // THEN: Tasks should be ordered chronologically
      expect(prioritized[0].id, equals('t1'), reason: 'Tomorrow should be first');
      expect(prioritized[1].id, equals('t2'), reason: 'Day after should be second');
      expect(prioritized[2].id, equals('t3'), reason: 'Three days should be third');
      expect(prioritized[3].id, equals('t4'), reason: 'Four days should be fourth');
    });

    test('tasks with different priority scores ignore date ordering', () {
      // GIVEN: Tasks with different priority scores
      final highPriorityLateTask = Task(
        id: 'high',
        title: 'High priority Dec task',
        scheduledDate: DateTime(2025, 12, 10),
        deadline: DateTime.now(), // Deadline today = high priority (800)
        createdAt: DateTime(2025, 11, 1),
      );

      final lowPriorityEarlyTask = Task(
        id: 'low',
        title: 'Low priority Nov task',
        scheduledDate: DateTime(2025, 11, 20),
        createdAt: DateTime(2025, 11, 1),
      );

      // WHEN: Tasks are prioritized
      final tasks = [lowPriorityEarlyTask, highPriorityLateTask];
      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // THEN: High priority task comes first regardless of scheduled date
      expect(prioritized[0].id, equals('high'),
          reason: 'Priority score trumps scheduled date');
      expect(prioritized[1].id, equals('low'));
    });

    test('recurring tasks with same priority maintain chronological order', () {
      // GIVEN: Daily recurring tasks scheduled in the future (same priority score)
      final now = DateTime.now();
      final fiveDays = now.add(const Duration(days: 5));
      final tenDays = now.add(const Duration(days: 10));
      final fifteenDays = now.add(const Duration(days: 15));

      final firstRecurring = Task(
        id: 'r1',
        title: 'Daily task 5 days',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: fiveDays,
        createdAt: now.subtract(const Duration(days: 10)),
      );

      final secondRecurring = Task(
        id: 'r2',
        title: 'Daily task 10 days',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: tenDays,
        createdAt: now.subtract(const Duration(days: 10)),
      );

      final thirdRecurring = Task(
        id: 'r3',
        title: 'Daily task 15 days',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: fifteenDays,
        createdAt: now.subtract(const Duration(days: 10)),
      );

      // WHEN: Tasks are prioritized (out of order)
      final tasks = [thirdRecurring, firstRecurring, secondRecurring];
      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // THEN: Tasks should be ordered by scheduled date (earliest first)
      expect(prioritized[0].id, equals('r1'), reason: '5 days recurring should be first');
      expect(prioritized[1].id, equals('r2'), reason: '10 days recurring should be second');
      expect(prioritized[2].id, equals('r3'), reason: '15 days recurring should be third');
    });

    test('month boundary ordering is correct', () {
      // GIVEN: Tasks spanning month boundaries
      final nov28 = Task(
        id: '1',
        title: 'Nov 28',
        scheduledDate: DateTime(2025, 11, 28),
        createdAt: DateTime(2025, 11, 1),
      );

      final nov29 = Task(
        id: '2',
        title: 'Nov 29',
        scheduledDate: DateTime(2025, 11, 29),
        createdAt: DateTime(2025, 11, 1),
      );

      final nov30 = Task(
        id: '3',
        title: 'Nov 30',
        scheduledDate: DateTime(2025, 11, 30),
        createdAt: DateTime(2025, 11, 1),
      );

      final dec1 = Task(
        id: '4',
        title: 'Dec 1',
        scheduledDate: DateTime(2025, 12, 1),
        createdAt: DateTime(2025, 11, 1),
      );

      final dec2 = Task(
        id: '5',
        title: 'Dec 2',
        scheduledDate: DateTime(2025, 12, 2),
        createdAt: DateTime(2025, 11, 1),
      );

      // WHEN: Tasks are scrambled
      final tasks = [dec2, nov29, dec1, nov28, nov30];
      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // THEN: Should maintain strict chronological order across month boundary
      expect(prioritized[0].id, equals('1'), reason: 'Nov 28 first');
      expect(prioritized[1].id, equals('2'), reason: 'Nov 29 second');
      expect(prioritized[2].id, equals('3'), reason: 'Nov 30 third');
      expect(prioritized[3].id, equals('4'), reason: 'Dec 1 fourth');
      expect(prioritized[4].id, equals('5'), reason: 'Dec 2 fifth');
    });
  });
}
