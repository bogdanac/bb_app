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

  int score(Task task) => service.calculateTaskPriorityScore(
    task,
    now,
    today,
    categories,
    currentMenstrualPhase: null,
  );

  group('Overdue Recurring Tasks - Grace Period', () {
    // NOTE: Daily interval=1 tasks are EXCLUDED from overdue scoring because they
    // always recur every day. Use weekly tasks to test overdue scoring.

    test('weekly recurring task overdue by 1 day gets high priority (950)', () {
      final task = Task(
        id: '1',
        title: 'Weekly Task',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(950),
          reason: 'Weekly task overdue by 1 day should get priority 950');
    });

    test('weekly recurring task overdue by 2 days gets high priority (940)', () {
      final task = Task(
        id: '1',
        title: 'Weekly Task',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 2)), // 2 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(940),
          reason: 'Weekly task overdue by 2 days should get priority 940');
    });

    test('weekly recurring task overdue by 3 days gets priority 930', () {
      final task = Task(
        id: '1',
        title: 'Weekly Task',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 3)), // 3 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(930),
          reason: 'Weekly task overdue by 3 days should get priority 930');
    });

    test('weekly recurring task overdue by 7 days gets priority 900', () {
      final task = Task(
        id: '1',
        title: 'Weekly Task',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 7)), // 7 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(900),
          reason: 'Weekly task overdue by 7 days should get priority 900');
    });

    test('weekly recurring task overdue by 8+ days gets priority 895 (grace exceeded)', () {
      final task = Task(
        id: '1',
        title: 'Weekly Task',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 8)), // 8 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      expect(score(task), equals(895),
          reason: 'Weekly task overdue by 8+ days should get priority 895');
    });

    test('overdue weekly recurring task beats scheduled today non-recurring', () {
      final overdueRecurring = Task(
        id: '1',
        title: 'Overdue Weekly',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      final todayNonRecurring = Task(
        id: '2',
        title: 'Today Non-Recurring',
        scheduledDate: today,
        createdAt: now,
      );

      // Overdue recurring: 950
      // Scheduled today: ~710-810 depending on energy
      expect(score(overdueRecurring), greaterThan(score(todayNonRecurring)),
          reason: 'Overdue recurring tasks should beat scheduled today');
    });

    test('overdue recurring by 2 days beats recurring due today', () {
      final overdueBy2 = Task(
        id: '1',
        title: 'Overdue by 2 Days',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 2)), // 2 days ago
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Create a task that's due today via recurrence pattern (not overdue)
      final dueToday = Task(
        id: '2',
        title: 'Due Today',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [today.weekday]),
        scheduledDate: today,
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Overdue by 2: 940
      // Due today via recurrence: ~810 (700 base + energy boost)
      expect(score(overdueBy2), greaterThan(score(dueToday)),
          reason: 'Overdue by 2 days should beat due today');
    });

    test('postponed overdue recurring task still gets overdue priority', () {
      // With the fix to isDueToday(), postponed overdue tasks now return true for isDueToday
      // and are treated as "due today" - they go through the due-today scoring path
      final postponedOverdue = Task(
        id: '1',
        title: 'Postponed Overdue',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        isPostponed: true, // KEY: postponed flag set
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Postponed overdue tasks still get overdue scoring (950)
      // because the scheduledDate is in the past
      expect(score(postponedOverdue), equals(950),
          reason: 'Postponed overdue tasks should still get overdue priority');
    });
  });

  group('Overdue Recurring vs Overdue Non-Recurring', () {
    test('overdue recurring (1 day) beats overdue non-recurring (1 day)', () {
      final overdueRecurring = Task(
        id: '1',
        title: 'Overdue Recurring',
        recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      final overdueNonRecurring = Task(
        id: '2',
        title: 'Overdue Non-Recurring',
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Overdue recurring: 950
      // Overdue non-recurring: 875 (max(850, 880 - 5))
      expect(score(overdueRecurring), greaterThan(score(overdueNonRecurring)),
          reason: 'Overdue recurring should have higher priority than overdue non-recurring');
    });

    test('overdue non-recurring priority decreases over time', () {
      final overdue1Day = Task(
        id: '1',
        title: 'Overdue 1 Day',
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        createdAt: today.subtract(const Duration(days: 30)),
      );

      final overdue2Days = Task(
        id: '2',
        title: 'Overdue 2 Days',
        scheduledDate: today.subtract(const Duration(days: 2)),
        createdAt: today.subtract(const Duration(days: 30)),
      );

      final overdue3Days = Task(
        id: '3',
        title: 'Overdue 3 Days',
        scheduledDate: today.subtract(const Duration(days: 3)),
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Formula: max(850, 880 - (daysOverdue * 5))
      // 1 day: max(850, 880 - 5) = 875
      // 2 days: max(850, 880 - 10) = 870
      // 3 days: max(850, 880 - 15) = 865
      expect(score(overdue1Day), equals(875),
          reason: 'Non-recurring overdue 1 day should be max(850, 880-5) = 875');
      expect(score(overdue2Days), equals(870),
          reason: 'Non-recurring overdue 2 days should be max(850, 880-10) = 870');
      expect(score(overdue3Days), equals(865),
          reason: 'Non-recurring overdue 3 days should be max(850, 880-15) = 865');
      expect(score(overdue1Day), greaterThan(score(overdue2Days)));
      expect(score(overdue2Days), greaterThan(score(overdue3Days)));
    });

    test('overdue non-recurring has minimum priority of 850', () {
      final overdueVeryOld = Task(
        id: '1',
        title: 'Overdue 20 Days',
        scheduledDate: today.subtract(const Duration(days: 20)), // 20 days ago
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // max(850, 880 - (20 * 5)) = max(850, 780) = 850
      expect(score(overdueVeryOld), equals(850),
          reason: 'Overdue non-recurring tasks should have minimum priority of 850');
    });
  });

  group('Priority Hierarchy with Overdue Recurring', () {
    test('overdue recurring tasks sorted correctly', () {
      final tasks = [
        Task(
          id: 'overdue_recurring_1',
          title: 'Overdue Recurring 1 Day',
          recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.monday]),
          scheduledDate: today.subtract(const Duration(days: 1)),
          isPostponed: false,
          createdAt: today.subtract(const Duration(days: 30)),
        ),
        Task(
          id: 'overdue_recurring_2',
          title: 'Overdue Recurring 2 Days',
          recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.saturday]),
          scheduledDate: today.subtract(const Duration(days: 2)),
          isPostponed: false,
          createdAt: today.subtract(const Duration(days: 30)),
        ),
        Task(
          id: 'recurring_today',
          title: 'Recurring Due Today',
          recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [today.weekday]),
          scheduledDate: today,
          createdAt: today.subtract(const Duration(days: 30)),
        ),
      ];

      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // Expected order:
      // Overdue 1 Day: 950
      // Overdue 2 Days: 940
      // Due Today: ~810
      expect(prioritized[0].id, equals('overdue_recurring_1'));
      expect(prioritized[1].id, equals('overdue_recurring_2'));
      expect(prioritized[2].id, equals('recurring_today'));
    });
  });

  group('Daily Tasks Special Handling', () {
    // Daily interval=1 tasks are excluded from overdue scoring because they
    // always recur every day. They're handled by the "due today" path instead.

    test('daily task with past scheduledDate is treated as due today', () {
      final dailyTask = Task(
        id: '1',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        isPostponed: false,
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Daily tasks get "due today" scoring (700 base + ~110 energy boost = ~810)
      // NOT the overdue scoring (950, 940, etc.)
      final taskScore = score(dailyTask);
      expect(taskScore, greaterThan(700));
      expect(taskScore, lessThan(900)); // Below overdue scoring
    });
  });

  group('Edge Cases', () {
    test('non-recurring task does not get recurring overdue priority', () {
      final nonRecurring = Task(
        id: '1',
        title: 'Non-Recurring Overdue',
        scheduledDate: today.subtract(const Duration(days: 1)), // Yesterday
        createdAt: today.subtract(const Duration(days: 30)),
      );

      // Should get non-recurring overdue priority (875), not recurring (950)
      expect(score(nonRecurring), equals(875),
          reason: 'Non-recurring tasks overdue 1 day should score 875, not 950 like recurring tasks');
    });
  });
}
