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
    now = DateTime(2025, 11, 5, 14, 0);
    today = DateTime(now.year, now.month, now.day);
  });

  int score(Task task) => service.calculateTaskPriorityScore(task, now, today, categories);

  group('30-Minute Reminder Threshold', () {
    test('reminder < 30 min away gets full priority bonuses', () {
      final task = Task(
        id: '1',
        title: 'Soon Reminder',
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 5, 14, 20), // 20 min away
        categoryIds: ['1'],
        isImportant: true,
        createdAt: now,
      );

      // Should get: 1100 (reminder) + 600 (scheduled today) + 100 (cat) + 100 (important)
      expect(score(task), greaterThan(1800));
    });

    test('reminder > 30 min away on task scheduled today gets flat 125', () {
      final task = Task(
        id: '1',
        title: 'Distant Reminder',
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 5, 18, 0), // 4 hours away
        categoryIds: ['1'],
        isImportant: true,
        createdAt: now,
      );

      expect(score(task), equals(125));
    });

    test('unscheduled task with reminder > 30 min gets no priority', () {
      final task = Task(
        id: '1',
        title: 'Unscheduled Distant Reminder',
        reminderTime: DateTime(2025, 11, 5, 18, 0), // 4 hours away
        categoryIds: ['1'],
        isImportant: true,
        createdAt: now,
      );

      expect(score(task), equals(0));
    });
  });

  group('Future Scheduled Tasks vs Today', () {
    test('today task beats future important task', () {
      final todayTask = Task(
        id: '1',
        title: 'Today Regular',
        scheduledDate: today,
        createdAt: now,
      );

      final futureImportantTask = Task(
        id: '2',
        title: 'Future Important',
        scheduledDate: today.add(const Duration(days: 10)),
        isImportant: true,
        categoryIds: ['1'],
        createdAt: now,
      );

      expect(score(todayTask), greaterThan(score(futureImportantTask)));
    });

    test('future tasks do NOT get category or important bonuses', () {
      final futureImportantCat1 = Task(
        id: '1',
        title: 'Future Important Cat1',
        scheduledDate: today.add(const Duration(days: 10)),
        isImportant: true,
        categoryIds: ['1'],
        createdAt: now,
      );

      final futurePlain = Task(
        id: '2',
        title: 'Future Plain',
        scheduledDate: today.add(const Duration(days: 10)),
        createdAt: now,
      );

      expect(score(futureImportantCat1), equals(score(futurePlain)));
    });

    test('recurring task scheduled in future gets minimal priority', () {
      final recurringFuture = Task(
        id: '1',
        title: 'Recurring Future',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: today.add(const Duration(days: 5)),
        isImportant: true,
        createdAt: now,
      );

      expect(score(recurringFuture), equals(1));
    });
  });

  group('Unscheduled vs Future Scheduled', () {
    test('unscheduled task beats future scheduled task', () {
      final unscheduled = Task(
        id: '1',
        title: 'Unscheduled',
        createdAt: now,
      );

      final future = Task(
        id: '2',
        title: 'Future',
        scheduledDate: today.add(const Duration(days: 5)),
        createdAt: now,
      );

      expect(score(unscheduled), greaterThan(score(future)));
    });

    test('unscheduled with categories beats future with same categories', () {
      final unscheduledCat1 = Task(
        id: '1',
        title: 'Unscheduled Cat1',
        categoryIds: ['1'],
        createdAt: now,
      );

      final futureCat1 = Task(
        id: '2',
        title: 'Future Cat1',
        scheduledDate: today.add(const Duration(days: 5)),
        categoryIds: ['1'],
        createdAt: now,
      );

      // Unscheduled: 400 + 100 = 500
      // Future: day 5 = 100 (no categories)
      expect(score(unscheduledCat1), greaterThan(score(futureCat1)));
    });
  });

  group('Sorting Tests', () {
    test('tasks sort in correct priority order', () {
      final tasks = [
        Task(
          id: 'future_important',
          title: 'Future Important',
          isImportant: true,
          scheduledDate: today.add(const Duration(days: 10)),
          createdAt: now,
        ),
        Task(
          id: 'today_regular',
          title: 'Today Regular',
          scheduledDate: today,
          createdAt: now,
        ),
        Task(
          id: 'today_important',
          title: 'Today Important',
          isImportant: true,
          scheduledDate: today,
          createdAt: now,
        ),
      ];

      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      expect(prioritized[0].id, equals('today_important'));
      expect(prioritized[1].id, equals('today_regular'));
      expect(prioritized[2].id, equals('future_important'));
    });
  });
}
