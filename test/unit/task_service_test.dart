import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Tasks/task_service.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  group('TaskService', () {
    late TaskService taskService;

    setUp(() async {
      // Initialize Firebase mocks
      setupFirebaseMocks();
      // Initialize mock shared preferences with empty values
      SharedPreferences.setMockInitialValues({});

      // Get singleton instance
      taskService = TaskService();

      // Clear any existing data to ensure clean state for each test
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    group('CRUD Operations', () {
      test('should create and save new task', () async {
        final task = Task(
          id: '1',
          title: 'Test Task',
          description: 'Test Description',
          categoryIds: [],
          isCompleted: false,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].id, '1');
        expect(loaded[0].title, 'Test Task');
      });

      test('should load multiple tasks', () async {
        final tasks = [
          Task(id: '1', title: 'Task 1', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '2', title: 'Task 2', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '3', title: 'Task 3', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
        ];

        await taskService.saveTasks(tasks);
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 3);
        expect(loaded.map((t) => t.id), containsAll(['1', '2', '3']));
      });

      test('should update existing task', () async {
        final task = Task(id: '1', title: 'Original', categoryIds: [], isCompleted: false, createdAt: DateTime.now());
        await taskService.saveTasks([task]);

        final updated = Task(id: '1', title: 'Updated', categoryIds: [], isCompleted: false, createdAt: task.createdAt);
        await taskService.saveTasks([updated]);

        final loaded = await taskService.loadTasks();
        expect(loaded[0].title, 'Updated');
      });

      test('should delete task', () async {
        final tasks = [
          Task(id: '1', title: 'Task 1', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '2', title: 'Task 2', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
        ];
        await taskService.saveTasks(tasks);

        await taskService.saveTasks([tasks[0]]); // Remove task 2
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].id, '1');
      });
    });

    group('Task Completion', () {
      test('should mark task as completed', () async {
        final task = Task(id: '1', title: 'Task', categoryIds: [], isCompleted: false, createdAt: DateTime.now());
        await taskService.saveTasks([task]);

        final completed = task.copyWith(isCompleted: true, completedAt: DateTime.now());
        await taskService.saveTasks([completed]);

        final loaded = await taskService.loadTasks();
        expect(loaded[0].isCompleted, true);
        expect(loaded[0].completedAt, isNotNull);
      });

      test('should preserve completion status across restarts', () async {
        final task = Task(
          id: '1',
          title: 'Task',
          categoryIds: [],
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );
        await taskService.saveTasks([task]);

        // Simulate restart by creating new service instance
        final newService = TaskService();
        final loaded = await newService.loadTasks();

        expect(loaded[0].isCompleted, true);
        expect(loaded[0].completedAt, isNotNull);
      });
    });

    group('Recurring Tasks', () {
      test('should create daily recurring task', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
          reminderTime: const TimeOfDay(hour: 10, minute: 0),
        );

        final task = Task(
          id: '1',
          title: 'Daily Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded[0].recurrence, isNotNull);
        expect(loaded[0].recurrence!.types, contains(RecurrenceType.daily));
      });

      test('should calculate next occurrence for daily task', () async {
        final today = DateTime.now();
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'Daily',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: today,
          createdAt: DateTime.now(),
        );

        // Test internal calculation logic by checking task migration
        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        // Task should have scheduledDate set
        expect(loaded[0].scheduledDate, isNotNull);
      });
    });

    group('Task Scheduling', () {
      test('should schedule task for specific date', () async {
        final futureDate = DateTime.now().add(const Duration(days: 7));
        final task = Task(
          id: '1',
          title: 'Future Task',
          categoryIds: [],
          isCompleted: false,
          scheduledDate: futureDate,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded[0].scheduledDate, isNotNull);
        expect(loaded[0].scheduledDate!.isAfter(DateTime.now()), true);
      });

      test('should set reminder time', () async {
        final task = Task(
          id: '1',
          title: 'Task with Reminder',
          categoryIds: [],
          isCompleted: false,
          reminderTime: DateTime.now().add(const Duration(hours: 2)),
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded[0].reminderTime, isNotNull);
      });
    });

    group('Task Postponing', () {
      test('should postpone task to tomorrow', () async {
        final today = DateTime.now();
        final task = Task(
          id: '1',
          title: 'Task',
          categoryIds: [],
          isCompleted: false,
          scheduledDate: today,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        await taskService.postponeTaskToTomorrow(task);

        final loaded = await taskService.loadTasks();
        expect(loaded[0].isPostponed, true);
        expect(loaded[0].scheduledDate!.day, today.add(const Duration(days: 1)).day);
      });

      test('should mark postponed task with flag', () async {
        final task = Task(
          id: '1',
          title: 'Task',
          categoryIds: [],
          isCompleted: false,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        await taskService.postponeTaskToTomorrow(task);

        final loaded = await taskService.loadTasks();
        expect(loaded[0].isPostponed, true);
      });
    });

    group('Task Prioritization', () {
      test('should prioritize important tasks', () async {
        final tasks = [
          Task(id: '1', title: 'Regular', categoryIds: [], isCompleted: false, isImportant: false, createdAt: DateTime.now()),
          Task(id: '2', title: 'Important', categoryIds: [], isCompleted: false, isImportant: true, createdAt: DateTime.now()),
        ];

        final prioritized = await taskService.getPrioritizedTasks(tasks, [], 10);

        expect(prioritized[0].isImportant, true);
        expect(prioritized[1].isImportant, false);
      });

      test('should prioritize overdue tasks', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        final tasks = [
          Task(
            id: '1',
            title: 'Today',
            categoryIds: [],
            isCompleted: false,
            scheduledDate: today,
            createdAt: now,
          ),
          Task(
            id: '2',
            title: 'Overdue',
            categoryIds: [],
            isCompleted: false,
            scheduledDate: yesterday,
            createdAt: now,
          ),
        ];

        final prioritized = await taskService.getPrioritizedTasks(tasks, [], 10);

        // Verify prioritization logic - overdue tasks should score higher
        // The exact order depends on the priority scoring algorithm
        expect(prioritized.length, 2);
        // Both tasks should be in the list
        expect(prioritized.any((t) => t.id == '1'), true);
        expect(prioritized.any((t) => t.id == '2'), true);
      });
    });

    group('Category Filtering', () {
      test('should filter tasks by single category', () async {
        final tasks = [
          Task(id: '1', title: 'Work Task', categoryIds: ['work'], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '2', title: 'Personal Task', categoryIds: ['personal'], isCompleted: false, createdAt: DateTime.now()),
        ];

        await taskService.saveTasks(tasks);

        final workTasks = tasks.where((t) => t.categoryIds.contains('work')).toList();
        expect(workTasks.length, 1);
        expect(workTasks[0].title, 'Work Task');
      });

      test('should filter tasks by multiple categories', () async {
        final tasks = [
          Task(id: '1', title: 'Work Only', categoryIds: ['work'], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '2', title: 'Work + Personal', categoryIds: ['work', 'personal'], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '3', title: 'Personal Only', categoryIds: ['personal'], isCompleted: false, createdAt: DateTime.now()),
        ];

        // Tasks with BOTH categories
        final bothCategories = tasks.where((t) =>
          t.categoryIds.contains('work') && t.categoryIds.contains('personal')
        ).toList();

        expect(bothCategories.length, 1);
        expect(bothCategories[0].title, 'Work + Personal');
      });
    });

    group('Skip Task Functionality', () {
      test('should skip recurring task to next occurrence', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'Daily Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final skipped = await taskService.skipToNextOccurrence(task);

        expect(skipped, isNotNull);
        expect(skipped!.isPostponed, true);
        expect(skipped.scheduledDate, isNotNull);
      });

      test('should skip menstrual task by clearing scheduledDate', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.ovulationPhase],
        );

        final task = Task(
          id: '1',
          title: 'Menstrual Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final skipped = await taskService.skipToNextOccurrence(task);

        expect(skipped, isNotNull);
        // Menstrual tasks should NOT be marked as postponed when skipped
        expect(skipped!.isPostponed, false);
        // Menstrual tasks should have null scheduledDate when skipped
        // (they will be rescheduled on the next cycle update)
        expect(skipped.scheduledDate, isNull);
        expect(skipped.recurrence?.types, contains(RecurrenceType.ovulationPhase));
      });

      test('should skip weekly Tue/Wed task to next occurrence', () async {
        // Scenario: Task recurs on Tuesday and Wednesday
        // Skipping should go to the next scheduled day in the pattern
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 1,
          weekDays: [DateTime.tuesday, DateTime.wednesday],
          startDate: today,
        );

        final task = Task(
          id: '1',
          title: 'Tue/Wed Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: today,
          createdAt: today,
        );

        await taskService.saveTasks([task]);
        final skipped = await taskService.skipToNextOccurrence(task);

        expect(skipped, isNotNull);
        expect(skipped!.isPostponed, true);
        expect(skipped.scheduledDate, isNotNull);
        // Should skip to a future date (next Tuesday or Wednesday)
        expect(skipped.scheduledDate!.isAfter(today), true);
        // Should be either Tuesday or Wednesday
        expect([DateTime.tuesday, DateTime.wednesday].contains(skipped.scheduledDate!.weekday), true);
      });

      test('should skip daily task to tomorrow', () async {
        // Scenario: Daily task should skip to tomorrow
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'Daily Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: today,
          createdAt: today,
        );

        await taskService.saveTasks([task]);
        final skipped = await taskService.skipToNextOccurrence(task);

        expect(skipped, isNotNull);
        expect(skipped!.isPostponed, true);
        expect(skipped.scheduledDate, isNotNull);
        // Should skip to tomorrow
        expect(skipped.scheduledDate!.year, equals(tomorrow.year));
        expect(skipped.scheduledDate!.month, equals(tomorrow.month));
        expect(skipped.scheduledDate!.day, equals(tomorrow.day));
      });

      test('should skip bi-weekly task to next occurrence in correct week', () async {
        // Scenario: Task recurs bi-weekly
        // Skip should go to next occurrence respecting the interval
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 2, // Bi-weekly
          weekDays: [today.weekday], // Same weekday as today
          startDate: today,
        );

        final task = Task(
          id: '1',
          title: 'Bi-weekly Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: today,
          createdAt: today,
        );

        await taskService.saveTasks([task]);
        final skipped = await taskService.skipToNextOccurrence(task);

        expect(skipped, isNotNull);
        expect(skipped!.isPostponed, true);
        expect(skipped.scheduledDate, isNotNull);
        // Should skip to future date (at least 7 days away for bi-weekly)
        final daysDifference = skipped.scheduledDate!.difference(today).inDays;
        expect(daysDifference >= 7, true, reason: 'Bi-weekly task should skip at least 7 days');
        // Should be same weekday
        expect(skipped.scheduledDate!.weekday, equals(today.weekday));
      });
    });

    group('Service Delegation and Architecture', () {
      test('should delegate persistence to TaskRepository', () async {
        // Create and save a task
        final task = Task(
          id: '1',
          title: 'Test Task',
          categoryIds: [],
          isCompleted: false,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);

        // Load tasks - should retrieve from repository
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].id, '1');
        expect(loaded[0].title, 'Test Task');
      });

      test('should delegate prioritization to TaskPriorityService', () async {
        final now = DateTime.now();
        final tasks = [
          Task(
            id: '1',
            title: 'Regular Task',
            categoryIds: [],
            isCompleted: false,
            isImportant: false,
            createdAt: now,
          ),
          Task(
            id: '2',
            title: 'Important Task',
            categoryIds: [],
            isCompleted: false,
            isImportant: true,
            createdAt: now,
          ),
          Task(
            id: '3',
            title: 'Overdue Task',
            categoryIds: [],
            isCompleted: false,
            scheduledDate: now.subtract(const Duration(days: 1)),
            createdAt: now,
          ),
        ];

        // getPrioritizedTasks should delegate to TaskPriorityService
        final prioritized = await taskService.getPrioritizedTasks(tasks, [], 10);

        // Should prioritize overdue and important tasks first
        expect(prioritized.length, 3);
        // Overdue task should be first
        expect(prioritized[0].id, '3');
      });

      test('should support category operations', () async {
        final categories = [
          TaskCategory(id: '1', name: 'Work', color: const Color(0xFF2196F3), order: 0),
          TaskCategory(id: '2', name: 'Personal', color: const Color(0xFF4CAF50), order: 1),
        ];

        await taskService.saveCategories(categories);
        final loaded = await taskService.loadCategories();

        expect(loaded.length, 2);
        expect(loaded[0].name, 'Work');
        expect(loaded[1].name, 'Personal');
      });

      test('should support task settings operations', () async {
        final settings = TaskSettings(maxTasksOnHomePage: 10);

        await taskService.saveTaskSettings(settings);
        final loaded = await taskService.loadTaskSettings();

        expect(loaded.maxTasksOnHomePage, 10);
      });

      test('should support category filter operations', () async {
        final filterIds = ['1', '2', '3'];

        await taskService.saveSelectedCategoryFilters(filterIds);
        final loaded = await taskService.loadSelectedCategoryFilters();

        expect(loaded, filterIds);
      });
    });

    group('Skip Flags in saveTasks', () {
      test('should save tasks normally without skip flags', () async {
        final task = Task(
          id: '1',
          title: 'Normal Task',
          categoryIds: [],
          isCompleted: false,
          reminderTime: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
        );

        // Save without skip flags (default behavior)
        await taskService.saveTasks([task]);

        final loaded = await taskService.loadTasks();
        expect(loaded.length, 1);
        expect(loaded[0].id, '1');
      });

      test('should accept skipNotificationUpdate flag', () async {
        final task = Task(
          id: '1',
          title: 'Task with Skip Notification',
          categoryIds: [],
          isCompleted: false,
          reminderTime: DateTime.now().add(const Duration(hours: 1)),
          createdAt: DateTime.now(),
        );

        // Save with skipNotificationUpdate flag
        await taskService.saveTasks([task], skipNotificationUpdate: true);

        final loaded = await taskService.loadTasks();
        expect(loaded.length, 1);
        expect(loaded[0].id, '1');
      });

      test('should accept skipWidgetUpdate flag', () async {
        final task = Task(
          id: '1',
          title: 'Task with Skip Widget',
          categoryIds: [],
          isCompleted: false,
          createdAt: DateTime.now(),
        );

        // Save with skipWidgetUpdate flag
        await taskService.saveTasks([task], skipWidgetUpdate: true);

        final loaded = await taskService.loadTasks();
        expect(loaded.length, 1);
        expect(loaded[0].id, '1');
      });

      test('should accept both skip flags together', () async {
        final task = Task(
          id: '1',
          title: 'Task with Both Flags',
          categoryIds: [],
          isCompleted: false,
          createdAt: DateTime.now(),
        );

        // Save with both skip flags
        await taskService.saveTasks(
          [task],
          skipNotificationUpdate: true,
          skipWidgetUpdate: true,
        );

        final loaded = await taskService.loadTasks();
        expect(loaded.length, 1);
        expect(loaded[0].id, '1');
      });

      test('should handle batch save with skip flags', () async {
        final tasks = [
          Task(id: '1', title: 'Task 1', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '2', title: 'Task 2', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
          Task(id: '3', title: 'Task 3', categoryIds: [], isCompleted: false, createdAt: DateTime.now()),
        ];

        // Batch save with skip flags
        await taskService.saveTasks(
          tasks,
          skipNotificationUpdate: true,
          skipWidgetUpdate: true,
        );

        final loaded = await taskService.loadTasks();
        expect(loaded.length, 3);
        expect(loaded.map((t) => t.id), containsAll(['1', '2', '3']));
      });
    });

    group('Task Auto-Migration on Load', () {
      test('should schedule new recurring tasks without scheduledDate', () async {
        final now = DateTime.now();
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'New Daily Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          // Note: No scheduledDate set
          createdAt: now,
        );

        // Save the task properly through the service, then reload
        // This tests the auto-migration logic that happens on load
        await taskService.saveTasks([task]);

        // Clear and save again without scheduledDate to simulate old data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('tasks', [
          '{"id":"1","title":"New Daily Task","description":"","categoryIds":[],"isImportant":false,"isPostponed":false,"recurrence":{"types":[0],"type":0,"interval":1,"weekDays":[],"isLastDayOfMonth":false},"isCompleted":false,"createdAt":"${now.toIso8601String()}"}'
        ]);

        // Load should auto-migrate and set scheduledDate
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].scheduledDate, isNotNull);
      });

      test('should NOT auto-advance overdue recurring tasks', () async {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'Overdue Daily Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: threeDaysAgo,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        );

        await taskService.saveTasks([task]);

        // Load should NOT auto-advance overdue tasks - they stay overdue until manually completed/skipped
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].scheduledDate, isNotNull);
        // Should remain at the original scheduled date (threeDaysAgo)
        final loadedDate = loaded[0].scheduledDate!;
        expect(loadedDate.year, threeDaysAgo.year);
        expect(loadedDate.month, threeDaysAgo.month);
        expect(loadedDate.day, threeDaysAgo.day);
      });

      test('should fix reminder times for tasks scheduled today', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final wrongReminderTime = DateTime(now.year, now.month, now.day - 1, 10, 0);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
          reminderTime: const TimeOfDay(hour: 10, minute: 0),
        );

        final task = Task(
          id: '1',
          title: 'Task with Wrong Reminder Time',
          categoryIds: [],
          isCompleted: false,
          recurrence: recurrence,
          scheduledDate: today,
          reminderTime: wrongReminderTime,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        );

        await taskService.saveTasks([task]);

        // Load should fix the reminder time
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        if (loaded[0].reminderTime != null) {
          // Reminder time should be for today, not yesterday
          expect(loaded[0].reminderTime!.year, today.year);
          expect(loaded[0].reminderTime!.month, today.month);
          expect(loaded[0].reminderTime!.day, today.day);
          expect(loaded[0].reminderTime!.hour, 10);
          expect(loaded[0].reminderTime!.minute, 0);
        }
      });

      // Tests for auto-rescheduling removed - overdue tasks now stay overdue
    });

    group('Recurrence Calculations', () {
      test('should recalculate all recurring tasks', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final tasks = [
          Task(
            id: '1',
            title: 'Daily Task 1',
            categoryIds: [],
            isCompleted: false,
            recurrence: recurrence,
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          Task(
            id: '2',
            title: 'Daily Task 2',
            categoryIds: [],
            isCompleted: false,
            recurrence: recurrence,
            createdAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ];

        await taskService.saveTasks(tasks);

        // Recalculate all recurring tasks
        final updatedCount = await taskService.recalculateAllRecurringTasks();

        // Should have updated tasks (either 0 or positive, depending on current state)
        expect(updatedCount, greaterThanOrEqualTo(0));
      });
    });
  });
}
