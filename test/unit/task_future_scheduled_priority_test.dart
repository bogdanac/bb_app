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

  group('Reminder Priority Rules', () {
    test('reminder less than 30 minutes away gets high priority', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);

      final task = Task(
        id: '1',
        title: 'Soon Reminder',
        reminderTime: DateTime(2025, 11, 5, 14, 20), // 20 min away
        createdAt: DateTime.now(),
      );

      final score = service.calculateTaskPriorityScore(task, now, today, categories);
      expect(score, equals(1100)); // High priority
    });

    test('reminder 30 min to 2 hours away gets symbolic priority', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);

      final task = Task(
        id: '1',
        title: 'Hour Away Reminder',
        reminderTime: DateTime(2025, 11, 5, 15, 0), // 60 min away
        createdAt: DateTime.now(),
      );

      final score = service.calculateTaskPriorityScore(task, now, today, categories);
      expect(score, equals(15)); // Symbolic priority
    });

    test('reminder more than 2 hours away gets no priority', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);

      final task = Task(
        id: '1',
        title: 'Distant Reminder',
        reminderTime: DateTime(2025, 11, 5, 18, 0), // 4 hours away
        createdAt: DateTime.now(),
      );

      final score = service.calculateTaskPriorityScore(task, now, today, categories);
      expect(score, equals(0)); // No priority
    });

    test('overdue reminder still gets high priority', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);

      final task = Task(
        id: '1',
        title: 'Overdue Reminder',
        reminderTime: DateTime(2025, 11, 5, 13, 0), // 1 hour ago
        createdAt: DateTime.now(),
      );

      final score = service.calculateTaskPriorityScore(task, now, today, categories);
      expect(score, equals(1200)); // High priority for overdue
    });
  });

  group('Future Scheduled Tasks Priority', () {
    test('important task scheduled for future date should NOT get high priority', () {
      final now = DateTime(2025, 11, 5, 14, 0); // Nov 5, 2:00 PM
      final today = DateTime(now.year, now.month, now.day);
      final futureDate = DateTime(2025, 11, 10); // Nov 10

      // Important task scheduled for Nov 10 (5 days in future)
      final futureTask = Task(
        id: '1',
        title: 'Future Important Task',
        isImportant: true,
        scheduledDate: futureDate,
        createdAt: DateTime.now(),
      );

      // Regular task due today
      final todayTask = Task(
        id: '2',
        title: 'Today Task',
        isImportant: false,
        scheduledDate: today,
        createdAt: DateTime.now(),
      );

      final futureScore = service.calculateTaskPriorityScore(futureTask, now, today, categories);
      final todayScore = service.calculateTaskPriorityScore(todayTask, now, today, categories);

      // Future task should have very low priority even though it's important
      expect(futureScore, lessThan(10)); // Should be 1-5 range
      // Today task should have higher priority
      expect(todayScore, greaterThan(futureScore));
    });

    test('important task scheduled for today SHOULD get high priority', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);

      final todayImportantTask = Task(
        id: '1',
        title: 'Today Important Task',
        isImportant: true,
        scheduledDate: today,
        createdAt: DateTime.now(),
      );

      final regularTask = Task(
        id: '2',
        title: 'Regular Task',
        isImportant: false,
        createdAt: DateTime.now(),
      );

      final importantScore = service.calculateTaskPriorityScore(todayImportantTask, now, today, categories);
      final regularScore = service.calculateTaskPriorityScore(regularTask, now, today, categories);

      // Important task scheduled today should get priority boost
      expect(importantScore, greaterThan(600)); // Gets scheduled today + important bonus
      expect(importantScore, greaterThan(regularScore));
    });

    test('recurring task due today but scheduled for future should NOT get inflated priority', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);
      final futureDate = DateTime(2025, 11, 10);

      final recurringFutureTask = Task(
        id: '1',
        title: 'Recurring Future Task',
        isImportant: true,
        scheduledDate: futureDate,
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        createdAt: DateTime.now(),
      );

      final score = service.calculateTaskPriorityScore(recurringFutureTask, now, today, categories);

      // Should have low priority since it's scheduled for future
      // Even though recurring tasks due today normally get priority
      expect(score, lessThan(20));
    });

    test('task with category scheduled for future should NOT get category boost', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);
      final futureDate = DateTime(2025, 11, 10);

      final futureCategoryTask = Task(
        id: '1',
        title: 'Future Category Task',
        categoryIds: ['1'], // Work category (order=0, high priority)
        scheduledDate: futureDate,
        createdAt: DateTime.now(),
      );

      final todayCategoryTask = Task(
        id: '2',
        title: 'Today Category Task',
        categoryIds: ['1'],
        scheduledDate: today,
        createdAt: DateTime.now(),
      );

      final futureScore = service.calculateTaskPriorityScore(futureCategoryTask, now, today, categories);
      final todayScore = service.calculateTaskPriorityScore(todayCategoryTask, now, today, categories);

      // Future task should NOT get category boost
      expect(futureScore, lessThan(10));
      // Today task SHOULD get category boost
      expect(todayScore, greaterThan(futureScore));
      expect(todayScore, greaterThan(600)); // Scheduled today + category bonus
    });

    test('sorting - future important tasks should appear below today tasks', () {
      final now = DateTime(2025, 11, 5, 14, 0);
      final today = DateTime(now.year, now.month, now.day);
      final futureDate = DateTime(2025, 11, 10);

      final tasks = [
        Task(
          id: '1',
          title: 'Future Important',
          isImportant: true,
          scheduledDate: futureDate,
          createdAt: DateTime.now(),
        ),
        Task(
          id: '2',
          title: 'Today Regular',
          scheduledDate: today,
          createdAt: DateTime.now(),
        ),
        Task(
          id: '3',
          title: 'Today Important',
          isImportant: true,
          scheduledDate: today,
          createdAt: DateTime.now(),
        ),
      ];

      final prioritized = service.getPrioritizedTasks(tasks, categories, 10);

      // Order should be: Today Important, Today Regular, Future Important
      expect(prioritized[0].id, equals('3')); // Today Important first
      expect(prioritized[1].id, equals('2')); // Today Regular second
      expect(prioritized[2].id, equals('1')); // Future Important last
    });
  });
}
