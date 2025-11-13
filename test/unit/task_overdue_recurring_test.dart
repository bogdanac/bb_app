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
    // Use actual current time for tests since getPrioritizedTasks uses DateTime.now()
    now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
  });

  int score(Task task) => service.calculateTaskPriorityScore(task, now, today, categories);

  group('Overdue Recurring Tasks - Grace Period', () {
    test('recurring task overdue by 1 day gets high priority (750)', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(750),
          reason: 'Overdue by 1 day should get priority 750');
    });

    test('recurring task overdue by 2 days gets high priority (740)', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today.subtract(const Duration(days: 2)), // 2 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(740),
          reason: 'Overdue by 2 days should get priority 740');
    });

    test('recurring task overdue by 3 days gets priority 730', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today.subtract(const Duration(days: 3)), // 3 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(730),
          reason: 'Overdue by 3 days should get priority 730');
    });

    test('recurring task overdue by 7 days gets priority 700', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today.subtract(const Duration(days: 7)), // 7 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(700),
          reason: 'Overdue by 7 days should get priority 700');
    });

    test('recurring task overdue by 8+ days gets priority 695 (grace exceeded)', () {
      final task = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today.subtract(const Duration(days: 8)), // 8 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Note: In practice, this shouldn't happen because auto-advance
      // kicks in after 7 days, but we handle it gracefully
      expect(score(task), equals(695),
          reason: 'Overdue by 8+ days should get priority 695');
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

      // Overdue by 2: 740
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
          recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.saturday]),
          scheduledDate: DateTime(2025, 11, 8), // Saturday, 2 days ago
          isPostponed: false,
          createdAt: DateTime(2025, 11, 1),
        ),
        Task(
          id: 'recurring_today',
          title: 'Recurring Due Today',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: today,
          createdAt: DateTime(2025, 11, 1), // Created in the past, due today
        ),
      ];

      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // Debug: Print scores
      for (final task in tasks) {
        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        print('${task.id}: score=$score, isDueToday=${task.isDueToday()}');
      }

      print('\nPrioritized order:');
      for (int i = 0; i < prioritized.length; i++) {
        final score = service.calculateTaskPriorityScore(prioritized[i], now, today, categories);
        print('$i: ${prioritized[i].id} (score=$score)');
      }

      // Expected order:
      // Overdue 1 Day: 750
      // Overdue 2 Days: 740
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
