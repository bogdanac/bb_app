import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Tasks/services/task_priority_service.dart';
import 'package:flutter/material.dart';

void main() {
  late TaskPriorityService service;
  late List<TaskCategory> categories;
  late DateTime now;
  late DateTime today;

  setUp(() {
    service = TaskPriorityService();
    categories = [
      TaskCategory(id: '1', name: 'Work', color: Colors.blue, order: 0),
      TaskCategory(id: '2', name: 'Personal', color: Colors.green, order: 1),
    ];
    now = DateTime(2025, 11, 10, 14, 0); // Nov 10 at 2 PM
    today = DateTime(now.year, now.month, now.day);
  });

  int score(Task task) => service.calculateTaskPriorityScore(task, now, today, categories);

  group('Overdue Recurring Tasks - Grace Period', () {
    test('recurring task overdue by 1 day gets high priority (750)', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 9), // Yesterday
        isPostponed: false,
        createdAt: DateTime(2025, 11, 1),
      );

      expect(score(task), equals(750),
          reason: 'Overdue by 1 day should get priority 750');
    });

    test('recurring task overdue by 2 days gets high priority (725)', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 8), // 2 days ago
        isPostponed: false,
        createdAt: DateTime(2025, 11, 1),
      );

      expect(score(task), equals(725),
          reason: 'Overdue by 2 days should get priority 725');
    });

    test('recurring task overdue by 3 days gets priority 700 (grace exceeded)', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 7), // 3 days ago
        isPostponed: false,
        createdAt: DateTime(2025, 11, 1),
      );

      // Note: In practice, this shouldn't happen because auto-advance
      // kicks in after 2 days, but we handle it gracefully
      expect(score(task), equals(700),
          reason: 'Overdue by 3+ days should get priority 700');
    });

    test('overdue recurring task beats scheduled today non-recurring', () {
      final overdueRecurring = Task(
        id: '1',
        title: 'Overdue Recurring',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 9), // Yesterday (overdue by 1)
        isPostponed: false,
        createdAt: DateTime(2025, 11, 1),
      );

      final todayNonRecurring = Task(
        id: '2',
        title: 'Today Non-Recurring',
        scheduledDate: today,
        createdAt: now,
      );

      // Overdue recurring: 750
      // Scheduled today: 600
      expect(score(overdueRecurring), greaterThan(score(todayNonRecurring)),
          reason: 'Overdue recurring tasks should beat scheduled today');
    });

    test('overdue recurring by 2 days beats recurring due today', () {
      final overdueBy2 = Task(
        id: '1',
        title: 'Overdue by 2 Days',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: DateTime(2025, 11, 8), // 2 days ago
        isPostponed: false,
        createdAt: DateTime(2025, 11, 1),
      );

      final dueToday = Task(
        id: '2',
        title: 'Due Today',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today,
        isPostponed: false,
        createdAt: now,
      );

      // Overdue by 2: 725
      // Due today: 700
      expect(score(overdueBy2), greaterThan(score(dueToday)),
          reason: 'Overdue by 2 days should beat due today');
    });

    test('postponed overdue recurring task does NOT get overdue bonus', () {
      final postponedOverdue = Task(
        id: '1',
        title: 'Postponed Overdue',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 9), // Yesterday
        isPostponed: true, // KEY: postponed flag set
        createdAt: DateTime(2025, 11, 1),
      );

      // Should NOT get overdue recurring bonus (750)
      // Should get unscheduled/future priority instead
      expect(score(postponedOverdue), lessThan(700),
          reason: 'Postponed tasks should not get overdue recurring bonus');
    });
  });

  group('Overdue Recurring vs Overdue Non-Recurring', () {
    test('overdue recurring (1 day) beats overdue non-recurring (1 day)', () {
      final overdueRecurring = Task(
        id: '1',
        title: 'Overdue Recurring',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 9), // Yesterday
        isPostponed: false,
        createdAt: DateTime(2025, 11, 1),
      );

      final overdueNonRecurring = Task(
        id: '2',
        title: 'Overdue Non-Recurring',
        scheduledDate: DateTime(2025, 11, 9), // Yesterday
        createdAt: DateTime(2025, 11, 1),
      );

      // Overdue recurring: 750
      // Overdue non-recurring: 595 (595 - 1*5)
      expect(score(overdueRecurring), greaterThan(score(overdueNonRecurring)),
          reason: 'Overdue recurring should have higher priority than overdue non-recurring');
    });

    test('overdue non-recurring priority decreases over time', () {
      final overdue1Day = Task(
        id: '1',
        title: 'Overdue 1 Day',
        scheduledDate: DateTime(2025, 11, 9),
        createdAt: DateTime(2025, 11, 1),
      );

      final overdue2Days = Task(
        id: '2',
        title: 'Overdue 2 Days',
        scheduledDate: DateTime(2025, 11, 8),
        createdAt: DateTime(2025, 11, 1),
      );

      final overdue3Days = Task(
        id: '3',
        title: 'Overdue 3 Days',
        scheduledDate: DateTime(2025, 11, 7),
        createdAt: DateTime(2025, 11, 1),
      );

      // 1 day: 595 - (1 * 5) = 590
      // 2 days: 595 - (2 * 5) = 585
      // 3 days: 595 - (3 * 5) = 580
      expect(score(overdue1Day), equals(590));
      expect(score(overdue2Days), equals(585));
      expect(score(overdue3Days), equals(580));
      expect(score(overdue1Day), greaterThan(score(overdue2Days)));
      expect(score(overdue2Days), greaterThan(score(overdue3Days)));
    });

    test('overdue non-recurring has minimum priority of 550', () {
      final overdueVeryOld = Task(
        id: '1',
        title: 'Overdue 20 Days',
        scheduledDate: DateTime(2025, 10, 21), // 20 days ago
        createdAt: DateTime(2025, 10, 1),
      );

      // 595 - (20 * 5) = 495, but minimum is 550
      expect(score(overdueVeryOld), equals(550),
          reason: 'Overdue non-recurring tasks should have minimum priority of 550');
    });
  });

  group('Priority Hierarchy with Overdue Recurring', () {
    test('overdue recurring tasks sorted correctly', () {
      final tasks = [
        Task(
          id: 'overdue_recurring_1',
          title: 'Overdue Recurring 1 Day',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: DateTime(2025, 11, 9),
          isPostponed: false,
          createdAt: DateTime(2025, 11, 1),
        ),
        Task(
          id: 'overdue_recurring_2',
          title: 'Overdue Recurring 2 Days',
          recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
          scheduledDate: DateTime(2025, 11, 8),
          isPostponed: false,
          createdAt: DateTime(2025, 11, 1),
        ),
        Task(
          id: 'recurring_today',
          title: 'Recurring Due Today',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: today,
          createdAt: today, // Due today
        ),
      ];

      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // Expected order:
      // Overdue 1 Day: 750
      // Overdue 2 Days: 725
      // Due Today: 700
      expect(prioritized[0].id, equals('overdue_recurring_1'));
      expect(prioritized[1].id, equals('overdue_recurring_2'));
      expect(prioritized[2].id, equals('recurring_today'));
    });
  });

  group('Edge Cases', () {
    test('non-recurring task does not get recurring overdue priority', () {
      final nonRecurring = Task(
        id: '1',
        title: 'Non-Recurring Overdue',
        scheduledDate: DateTime(2025, 11, 9), // Yesterday
        createdAt: DateTime(2025, 11, 1),
      );

      // Should get non-recurring overdue priority (590), not recurring (750)
      expect(score(nonRecurring), equals(590),
          reason: 'Non-recurring tasks should use different overdue calculation');
    });
  });
}
