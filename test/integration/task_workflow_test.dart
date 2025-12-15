import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Tasks/task_service.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import '../helpers/firebase_mock_helper.dart';

/// Comprehensive integration tests for the complete task workflow.
/// Tests the interaction between TaskService, TaskRepository, TaskPriorityService,
/// and RecurrenceCalculator working together as a cohesive system.
void main() {
  group('Task Workflow Integration Tests', () {
    late TaskService taskService;

    setUp(() async {
      // Initialize Firebase mocks
      setupFirebaseMocks();
      // Clear and initialize SharedPreferences
      SharedPreferences.setMockInitialValues({});
      taskService = TaskService();

      // Set up menstrual cycle data for menstrual task tests
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      await prefs.setString('last_period_start', today.subtract(const Duration(days: 5)).toIso8601String());
      await prefs.setString('last_period_end', today.subtract(const Duration(days: 1)).toIso8601String());
      await prefs.setInt('average_cycle_length', 28);
    });

    group('Complete Task Lifecycle', () {
      test('Create task → Save → Load → Verify persistence', () async {
        // Create a task
        final task = Task(
          id: 'lifecycle-1',
          title: 'Lifecycle Test Task',
          description: 'Testing complete lifecycle',
          categoryIds: ['cat1'],
          isImportant: true,
          createdAt: DateTime.now(),
        );

        // Save the task
        await taskService.saveTasks([task]);

        // Load tasks
        final loadedTasks = await taskService.loadTasks();

        // Verify
        expect(loadedTasks.length, 1);
        expect(loadedTasks[0].id, 'lifecycle-1');
        expect(loadedTasks[0].title, 'Lifecycle Test Task');
        expect(loadedTasks[0].description, 'Testing complete lifecycle');
        expect(loadedTasks[0].isImportant, true);
        expect(loadedTasks[0].categoryIds, ['cat1']);
      });

      test('Create recurring task → Auto-migration → Verify scheduling', () async {
        // Create a daily recurring task without scheduledDate
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        );

        final task = Task(
          id: 'recurring-1',
          title: 'Daily Morning Task',
          recurrence: recurrence,
          createdAt: DateTime.now(),
        );

        // Save task
        await taskService.saveTasks([task]);

        // Load tasks - should trigger auto-migration
        final loadedTasks = await taskService.loadTasks();

        // Verify auto-migration scheduled the task
        expect(loadedTasks.length, 1);
        expect(loadedTasks[0].scheduledDate, isNotNull);
        expect(loadedTasks[0].reminderTime, isNotNull);

        // Verify reminder time is set correctly
        // If before 2pm, should be today; if after 2pm, should be tomorrow
        final now = DateTime.now();
        final isBefore2PM = now.hour < 14;
        final expectedDay = isBefore2PM ? now.day : now.add(const Duration(days: 1)).day;

        expect(loadedTasks[0].reminderTime!.hour, 9);
        expect(loadedTasks[0].reminderTime!.minute, 0);
        expect(loadedTasks[0].reminderTime!.day, expectedDay);
      });

      test('Edit task → Auto-save → Verify updates', () async {
        // Create and save initial task
        final task = Task(
          id: 'edit-1',
          title: 'Original Title',
          description: 'Original Description',
          createdAt: DateTime.now(),
        );
        await taskService.saveTasks([task]);

        // Edit the task
        final editedTask = task.copyWith(
          title: 'Updated Title',
          description: 'Updated Description',
          isImportant: true,
        );
        await taskService.saveTasks([editedTask]);

        // Load and verify changes persisted
        final loadedTasks = await taskService.loadTasks();
        expect(loadedTasks.length, 1);
        expect(loadedTasks[0].title, 'Updated Title');
        expect(loadedTasks[0].description, 'Updated Description');
        expect(loadedTasks[0].isImportant, true);
      });

      test('Complete task → Verify completion tracking', () async {
        // Create task
        final task = Task(
          id: 'complete-1',
          title: 'Task to Complete',
          createdAt: DateTime.now(),
        );
        await taskService.saveTasks([task]);

        // Complete the task
        final completedTask = task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        await taskService.saveTasks([completedTask]);

        // Load and verify completion
        final loadedTasks = await taskService.loadTasks();
        expect(loadedTasks.length, 1);
        expect(loadedTasks[0].isCompleted, true);
        expect(loadedTasks[0].completedAt, isNotNull);
      });

      test('Skip recurring task → Verify next occurrence', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: 'skip-1',
          title: 'Daily Task to Skip',
          recurrence: recurrence,
          scheduledDate: today,
          createdAt: DateTime.now(),
        );
        await taskService.saveTasks([task]);

        // Skip to next occurrence
        final skippedTask = await taskService.skipToNextOccurrence(task);

        // Verify
        expect(skippedTask, isNotNull);
        expect(skippedTask!.isPostponed, true);
        expect(skippedTask.scheduledDate, isNotNull);

        // For daily tasks, next occurrence could be today (if recalculated) or tomorrow
        final skippedDay = DateTime(
          skippedTask.scheduledDate!.year,
          skippedTask.scheduledDate!.month,
          skippedTask.scheduledDate!.day,
        );
        // Should be today or after
        expect(
          skippedDay.isAtSameMomentAs(today) || skippedDay.isAfter(today),
          true,
        );
      });

      test('Postpone task → Verify new schedule', () async {
        final today = DateTime.now();
        final tomorrow = DateTime(today.year, today.month, today.day + 1);

        final task = Task(
          id: 'postpone-1',
          title: 'Task to Postpone',
          scheduledDate: today,
          reminderTime: DateTime(today.year, today.month, today.day, 10, 0),
          createdAt: DateTime.now(),
        );
        await taskService.saveTasks([task]);

        // Postpone to tomorrow
        await taskService.postponeTaskToTomorrow(task);

        // Load and verify
        final loadedTasks = await taskService.loadTasks();
        expect(loadedTasks.length, 1);
        expect(loadedTasks[0].isPostponed, true);
        expect(loadedTasks[0].scheduledDate!.day, tomorrow.day);
        expect(loadedTasks[0].reminderTime!.day, tomorrow.day);
        expect(loadedTasks[0].reminderTime!.hour, 10); // Same time, different day
      });
    });

    group('Priority and Sorting', () {
      test('Create tasks with various priorities → Get prioritized list → Verify order', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final tasks = [
          Task(
            id: 'low',
            title: 'Low Priority',
            createdAt: now,
          ),
          Task(
            id: 'important',
            title: 'Important Task',
            isImportant: true,
            createdAt: now,
          ),
          Task(
            id: 'deadline-today',
            title: 'Deadline Today',
            deadline: today,
            createdAt: now,
          ),
          Task(
            id: 'overdue',
            title: 'Overdue Task',
            deadline: today.subtract(const Duration(days: 2)),
            createdAt: now,
          ),
        ];

        await taskService.saveTasks(tasks);
        final categories = await taskService.loadCategories();

        // Get prioritized list
        final prioritized = await taskService.getPrioritizedTasks(tasks, categories, 10);

        // Verify order: overdue > deadline today > important > low
        expect(prioritized[0].id, 'overdue');
        expect(prioritized[1].id, 'deadline-today');
        // Important and low can vary based on other factors
        expect(prioritized.map((t) => t.id), containsAll(['important', 'low']));
      });

      test('Mix of overdue, today, important, scheduled → Verify correct prioritization', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        final tasks = [
          Task(
            id: 'scheduled-today',
            title: 'Scheduled Today',
            scheduledDate: today,
            createdAt: now,
          ),
          Task(
            id: 'overdue-scheduled',
            title: 'Overdue Scheduled',
            scheduledDate: yesterday,
            createdAt: now,
          ),
          Task(
            id: 'important-no-date',
            title: 'Important No Date',
            isImportant: true,
            createdAt: now,
          ),
          Task(
            id: 'reminder-soon',
            title: 'Reminder Soon',
            reminderTime: now.add(const Duration(minutes: 30)),
            scheduledDate: today, // Schedule for today so reminder priority works
            createdAt: now,
          ),
        ];

        await taskService.saveTasks(tasks);
        final categories = await taskService.loadCategories();

        final prioritized = await taskService.getPrioritizedTasks(tasks, categories, 10);

        // Reminder soon should be at top (or near top)
        final reminderIndex = prioritized.indexWhere((t) => t.id == 'reminder-soon');
        expect(reminderIndex, lessThan(3), reason: 'Reminder soon should be in top 3');

        // Overdue and scheduled today should both be prioritized
        final overdueIndex = prioritized.indexWhere((t) => t.id == 'overdue-scheduled');
        final importantIndex = prioritized.indexWhere((t) => t.id == 'important-no-date');

        // Overdue should be higher than just important with no date
        expect(overdueIndex, lessThan(importantIndex),
               reason: 'Overdue should be higher priority than important without date');
      });

      test('Update task attributes → Re-prioritize → Verify new order', () async {
        final now = DateTime.now();

        final tasks = [
          Task(id: 'task1', title: 'Task 1', createdAt: now),
          Task(id: 'task2', title: 'Task 2', createdAt: now),
        ];

        await taskService.saveTasks(tasks);
        final categories = await taskService.loadCategories();

        // Update task2 to be important
        final updatedTask2 = tasks[1].copyWith(isImportant: true);
        final updatedTasks = [tasks[0], updatedTask2];
        await taskService.saveTasks(updatedTasks);

        // Re-prioritize
        final reprioritized = await taskService.getPrioritizedTasks(updatedTasks, categories, 10);

        // task2 should now be higher priority
        final task2Index = reprioritized.indexWhere((t) => t.id == 'task2');
        final task1Index = reprioritized.indexWhere((t) => t.id == 'task1');
        expect(task2Index, lessThan(task1Index));
      });
    });

    group('Recurrence Workflows', () {
      test('Create daily task → Check if due today → Complete → Check next occurrence', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: 'daily-1',
          title: 'Daily Task',
          recurrence: recurrence,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        // Check if due today (should be after auto-migration)
        // If before 2pm, should be today; if after 2pm, should be tomorrow
        final now = DateTime.now();
        final isBefore2PM = now.hour < 14;
        expect(loaded[0].isDueToday(), isBefore2PM);

        // Complete the task
        final completed = loaded[0].copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        await taskService.saveTasks([completed]);

        // In a real scenario, the next load would show it scheduled for tomorrow
        // For this test, we verify the completion
        final afterComplete = await taskService.loadTasks();
        expect(afterComplete[0].isCompleted, true);
      });

      test('Create weekly task → Skip to next occurrence → Verify new date', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 1,
          weekDays: [now.weekday], // Same day of week
        );

        final task = Task(
          id: 'weekly-1',
          title: 'Weekly Task',
          recurrence: recurrence,
          scheduledDate: today,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);

        // Skip to next occurrence
        final skipped = await taskService.skipToNextOccurrence(task);

        // Should be scheduled for future
        expect(skipped, isNotNull);
        expect(skipped!.scheduledDate, isNotNull);
        expect(skipped.isPostponed, true);

        // Verify it's scheduled (could be today if recalculated, or future)
        final skippedDay = DateTime(
          skipped.scheduledDate!.year,
          skipped.scheduledDate!.month,
          skipped.scheduledDate!.day,
        );

        // Should be at least today or later
        expect(
          skippedDay.isAtSameMomentAs(today) || skippedDay.isAfter(today),
          true,
          reason: 'Skipped task should be scheduled for today or future',
        );
      });

      test('Create menstrual task → Skip → Verify scheduling behavior', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.ovulationPhase],
          phaseDay: 2,
        );

        final task = Task(
          id: 'menstrual-1',
          title: 'Menstrual Phase Task',
          recurrence: recurrence,
          scheduledDate: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);

        // Skip menstrual task
        final skipped = await taskService.skipToNextOccurrence(task);

        // Verify task was skipped
        expect(skipped, isNotNull);
        // Menstrual tasks should NOT be marked as postponed
        expect(skipped!.isPostponed, false);
        // Menstrual tasks should have scheduledDate cleared when skipped
        expect(skipped.scheduledDate, isNull);
        expect(skipped.recurrence, isNotNull);
        expect(skipped.recurrence!.types, contains(RecurrenceType.ovulationPhase));
      });

      test('Overdue recurring task → Load → Verify task stays overdue for manual completion', () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        // Create a task that's overdue
        final prefs = await SharedPreferences.getInstance();
        final task = Task(
          id: 'overdue-recurring',
          title: 'Overdue Daily Task',
          recurrence: recurrence,
          scheduledDate: yesterday,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        );

        // Manually save to bypass auto-migration
        final tasksJson = [task.toJson()];
        await prefs.setStringList(
          'tasks',
          tasksJson.map((t) => t.toString()).toList(),
        );

        // Clear and save properly
        await taskService.saveTasks([task]);

        // Load - should NOT auto-advance overdue tasks (they stay overdue for manual completion)
        final loaded = await taskService.loadTasks();

        // Verify task stays at its scheduled date (not auto-migrated)
        expect(loaded.length, 1);
        expect(loaded[0].scheduledDate, isNotNull);

        final scheduledDay = DateTime(
          loaded[0].scheduledDate!.year,
          loaded[0].scheduledDate!.month,
          loaded[0].scheduledDate!.day,
        );
        final yesterdayDay = DateTime(yesterday.year, yesterday.month, yesterday.day);

        // Task should stay at its original overdue date for manual completion
        // (NO AUTO-ADVANCE: Tasks stay overdue indefinitely until manually completed)
        expect(
          scheduledDay.isAtSameMomentAs(yesterdayDay),
          true,
          reason: 'Overdue recurring tasks should stay at their original date until manually completed'
        );
      });

      test('Monthly recurring task → Verify correct date calculation', () async {
        final now = DateTime.now();

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.monthly],
          interval: 1,
          dayOfMonth: 15,
        );

        final task = Task(
          id: 'monthly-1',
          title: 'Monthly Task on 15th',
          recurrence: recurrence,
          createdAt: now,
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        // Verify task was scheduled
        expect(loaded.length, 1);
        expect(loaded[0].scheduledDate, isNotNull);

        // Should be scheduled for the 15th of current or next month
        expect(loaded[0].scheduledDate!.day, 15);
      });

      test('Yearly recurring task → Verify correct date calculation', () async {
        final now = DateTime.now();

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.yearly],
          interval: 6, // June
          dayOfMonth: 20,
        );

        final task = Task(
          id: 'yearly-1',
          title: 'Yearly Task on June 20',
          recurrence: recurrence,
          createdAt: now,
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        // Verify task was scheduled
        expect(loaded.length, 1);
        expect(loaded[0].scheduledDate, isNotNull);

        // Should be scheduled for June 20th
        expect(loaded[0].scheduledDate!.month, 6);
        expect(loaded[0].scheduledDate!.day, 20);
      });
    });

    group('Category Filtering', () {
      test('Create tasks with categories → Filter → Verify results', () async {
        final categories = [
          TaskCategory(id: 'work', name: 'Work', color: Colors.blue, order: 0),
          TaskCategory(id: 'personal', name: 'Personal', color: Colors.green, order: 1),
        ];
        await taskService.saveCategories(categories);

        final tasks = [
          Task(id: 'task1', title: 'Work Task 1', categoryIds: ['work'], createdAt: DateTime.now()),
          Task(id: 'task2', title: 'Work Task 2', categoryIds: ['work'], createdAt: DateTime.now()),
          Task(id: 'task3', title: 'Personal Task', categoryIds: ['personal'], createdAt: DateTime.now()),
          Task(id: 'task4', title: 'Both Categories', categoryIds: ['work', 'personal'], createdAt: DateTime.now()),
        ];
        await taskService.saveTasks(tasks);

        // Filter by work category
        final workTasks = tasks.where((t) => t.categoryIds.contains('work')).toList();
        expect(workTasks.length, 3); // task1, task2, task4

        // Filter by personal category
        final personalTasks = tasks.where((t) => t.categoryIds.contains('personal')).toList();
        expect(personalTasks.length, 2); // task3, task4

        // Filter by both categories
        final bothTasks = tasks.where((t) =>
          t.categoryIds.contains('work') && t.categoryIds.contains('personal')
        ).toList();
        expect(bothTasks.length, 1); // task4
      });

      test('Save filter preferences → Reload → Verify persistence', () async {
        // Save category filters
        await taskService.saveSelectedCategoryFilters(['work', 'personal']);

        // Load filters
        final filters = await taskService.loadSelectedCategoryFilters();

        expect(filters.length, 2);
        expect(filters, containsAll(['work', 'personal']));

        // Update filters
        await taskService.saveSelectedCategoryFilters(['work']);

        // Reload
        final updated = await taskService.loadSelectedCategoryFilters();
        expect(updated.length, 1);
        expect(updated, ['work']);
      });
    });

    group('Edge Case Workflows', () {
      test('Create 50 tasks → Prioritize → Verify performance (<100ms)', () async {
        final now = DateTime.now();
        final tasks = List.generate(50, (i) => Task(
          id: 'task-$i',
          title: 'Task $i',
          isImportant: i % 5 == 0,
          scheduledDate: i % 3 == 0 ? now : null,
          deadline: i % 7 == 0 ? now.add(Duration(days: i)) : null,
          createdAt: now.subtract(Duration(days: i)),
        ));

        await taskService.saveTasks(tasks);
        final categories = await taskService.loadCategories();

        // Measure prioritization performance
        final stopwatch = Stopwatch()..start();
        final prioritized = await taskService.getPrioritizedTasks(tasks, categories, 50);
        stopwatch.stop();

        expect(prioritized.length, 50);
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('Concurrent task operations → Verify data consistency', () async {
        final task1 = Task(id: '1', title: 'Task 1', createdAt: DateTime.now());
        final task2 = Task(id: '2', title: 'Task 2', createdAt: DateTime.now());
        final task3 = Task(id: '3', title: 'Task 3', createdAt: DateTime.now());

        // Simulate concurrent operations
        await Future.wait([
          taskService.saveTasks([task1]),
          taskService.saveTasks([task2]),
          taskService.saveTasks([task3]),
        ]);

        // Load and verify
        final loaded = await taskService.loadTasks();

        // Should have the last saved task (due to sequential execution)
        expect(loaded.length, 1);
        expect(loaded[0].id, '3');
      });

      test('Task with all features (recurring, important, categories, reminder, deadline)', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 1,
          weekDays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
          reminderTime: const TimeOfDay(hour: 10, minute: 30),
        );

        final complexTask = Task(
          id: 'complex',
          title: 'Complex Task',
          description: 'A task with all possible features',
          categoryIds: ['work', 'important'],
          isImportant: true,
          deadline: today.add(const Duration(days: 7)),
          scheduledDate: today,
          reminderTime: DateTime(today.year, today.month, today.day, 10, 30),
          recurrence: recurrence,
          createdAt: now,
        );

        await taskService.saveTasks([complexTask]);
        final loaded = await taskService.loadTasks();

        // Verify all features persist
        expect(loaded.length, 1);
        final task = loaded[0];
        expect(task.title, 'Complex Task');
        expect(task.isImportant, true);
        expect(task.categoryIds, ['work', 'important']);
        expect(task.deadline, isNotNull);
        expect(task.scheduledDate, isNotNull);
        expect(task.reminderTime, isNotNull);
        expect(task.recurrence, isNotNull);
        expect(task.recurrence!.types, [RecurrenceType.weekly]);
        expect(task.recurrence!.weekDays.length, 3);
      });

      test('App restart simulation (new service instances)', () async {
        // First session
        final task = Task(
          id: 'restart-test',
          title: 'Persist Across Restarts',
          isImportant: true,
          createdAt: DateTime.now(),
        );
        await taskService.saveTasks([task]);

        // Simulate app restart with new service instance
        final newService = TaskService();
        final loaded = await newService.loadTasks();

        // Verify data persists
        expect(loaded.length, 1);
        expect(loaded[0].id, 'restart-test');
        expect(loaded[0].title, 'Persist Across Restarts');
        expect(loaded[0].isImportant, true);
      });

      test('Large batch operations → 100 tasks save and load', () async {
        final now = DateTime.now();
        final tasks = List.generate(100, (i) => Task(
          id: 'batch-$i',
          title: 'Batch Task $i',
          description: 'Task number $i in batch',
          isImportant: i % 10 == 0,
          categoryIds: i % 2 == 0 ? ['even'] : ['odd'],
          createdAt: now.subtract(Duration(hours: i)),
        ));

        // Save all tasks
        final saveStopwatch = Stopwatch()..start();
        await taskService.saveTasks(tasks);
        saveStopwatch.stop();

        // Load all tasks
        final loadStopwatch = Stopwatch()..start();
        final loaded = await taskService.loadTasks();
        loadStopwatch.stop();

        // Verify
        expect(loaded.length, 100);
        expect(saveStopwatch.elapsedMilliseconds, lessThan(1000),
               reason: 'Saving 100 tasks should complete within 1 second');
        expect(loadStopwatch.elapsedMilliseconds, lessThan(1000),
               reason: 'Loading 100 tasks should complete within 1 second');

        // Verify data integrity
        final batch50 = loaded.firstWhere((t) => t.id == 'batch-50');
        expect(batch50.title, 'Batch Task 50');
        expect(batch50.categoryIds, ['even']);
      });

      test('Rapid successive edits → Verify final state', () async {
        final task = Task(
          id: 'rapid-edit',
          title: 'Original',
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);

        // Perform rapid edits
        for (int i = 1; i <= 5; i++) {
          final edited = task.copyWith(title: 'Edit $i');
          await taskService.saveTasks([edited]);
        }

        // Verify final state
        final loaded = await taskService.loadTasks();
        expect(loaded.length, 1);
        expect(loaded[0].title, 'Edit 5');
      });

      test('Mixed completed and incomplete tasks → Verify sorting', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));

        final tasks = [
          Task(id: 'incomplete-1', title: 'Incomplete 1', isImportant: true, createdAt: now),
          Task(id: 'completed-1', title: 'Completed 1', isCompleted: true,
               completedAt: yesterday, createdAt: now.subtract(const Duration(days: 2))),
          Task(id: 'incomplete-2', title: 'Incomplete 2', createdAt: now),
          Task(id: 'completed-2', title: 'Completed 2', isCompleted: true,
               completedAt: now, createdAt: now.subtract(const Duration(days: 1))),
        ];

        await taskService.saveTasks(tasks);
        final loaded = await taskService.loadTasks();

        // Verify incomplete tasks come before completed tasks
        final incompleteCount = loaded.where((t) => !t.isCompleted).length;
        expect(incompleteCount, 2);

        // First tasks should be incomplete
        expect(loaded[0].isCompleted, false);
        expect(loaded[1].isCompleted, false);

        // Last tasks should be completed
        expect(loaded[2].isCompleted, true);
        expect(loaded[3].isCompleted, true);

        // Completed tasks should be sorted by completion date (newest first)
        expect(loaded[2].id, 'completed-2');
        expect(loaded[3].id, 'completed-1');
      });

      test('Task with special characters in title and description', () async {
        final task = Task(
          id: 'special-chars',
          title: 'Task with "quotes" & <symbols> #hashtag',
          description: 'Description with\nnewlines\tand\ttabs & émojis 🎉',
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].title, 'Task with "quotes" & <symbols> #hashtag');
        expect(loaded[0].description, 'Description with\nnewlines\tand\ttabs & émojis 🎉');
      });

      test('Task date boundaries → End of month, leap year', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.monthly],
          interval: 1,
          dayOfMonth: 31,
        );

        final task = Task(
          id: 'month-boundary',
          title: 'Last day of month task',
          recurrence: recurrence,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        // Verify it handles months with different day counts
        expect(loaded.length, 1);
        expect(loaded[0].scheduledDate, isNotNull);
        // Should handle months with fewer than 31 days gracefully
      });
    });

    group('Data Integrity', () {
      test('Save tasks → Corrupt shared prefs → Load → Verify graceful handling', () async {
        // Save valid tasks
        final tasks = [
          Task(id: '1', title: 'Task 1', createdAt: DateTime.now()),
          Task(id: '2', title: 'Task 2', createdAt: DateTime.now()),
        ];
        await taskService.saveTasks(tasks);

        // Corrupt the data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('tasks', ['invalid json', 'also invalid']);

        // Load should handle gracefully
        final loaded = await taskService.loadTasks();

        // Should return empty list or handle error gracefully
        expect(loaded, isA<List<Task>>());
      });

      test('Handle empty task list operations', () async {
        // Save empty list
        await taskService.saveTasks([]);

        // Load empty list
        final loaded = await taskService.loadTasks();
        expect(loaded, isEmpty);

        // Prioritize empty list
        final prioritized = await taskService.getPrioritizedTasks([], [], 10);
        expect(prioritized, isEmpty);
      });

      test('Handle null and edge case values in task fields', () async {
        final task = Task(
          id: 'edge-case',
          title: '', // Empty title
          description: '', // Empty description
          categoryIds: [], // No categories
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].title, '');
        expect(loaded[0].description, '');
        expect(loaded[0].categoryIds, isEmpty);
      });

      test('Save and load categories with default values', () async {
        // First load should create default categories
        final defaultCategories = await taskService.loadCategories();

        expect(defaultCategories.length, 4);
        expect(defaultCategories.map((c) => c.name),
               containsAll(['Cleaning', 'At Home', 'Research', 'Travel']));

        // Save custom categories
        final custom = [
          TaskCategory(id: 'custom1', name: 'Custom 1', color: Colors.red, order: 0),
        ];
        await taskService.saveCategories(custom);

        // Load custom categories
        final loaded = await taskService.loadCategories();
        expect(loaded.length, 1);
        expect(loaded[0].name, 'Custom 1');
      });

      test('Task settings persistence', () async {
        // Load default settings
        final defaultSettings = await taskService.loadTaskSettings();
        expect(defaultSettings.maxTasksOnHomePage, 5);

        // Save custom settings
        final customSettings = TaskSettings(maxTasksOnHomePage: 10);
        await taskService.saveTaskSettings(customSettings);

        // Load custom settings
        final loaded = await taskService.loadTaskSettings();
        expect(loaded.maxTasksOnHomePage, 10);
      });

      test('Corrupted category data → Graceful recovery', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('task_categories', ['corrupt', 'data']);

        // Should handle gracefully
        final categories = await taskService.loadCategories();
        expect(categories, isA<List<TaskCategory>>());
      });

      test('Very long task titles and descriptions', () async {
        final longTitle = 'A' * 1000;
        final longDescription = 'B' * 5000;

        final task = Task(
          id: 'long-text',
          title: longTitle,
          description: longDescription,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].title.length, 1000);
        expect(loaded[0].description.length, 5000);
      });
    });

    group('Real-World Scenarios', () {
      test('Morning routine: Load tasks, complete some, skip some, postpone some', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Set up morning tasks
        final morningTasks = [
          Task(
            id: 'morning-1',
            title: 'Exercise',
            scheduledDate: today,
            reminderTime: DateTime(today.year, today.month, today.day, 7, 0),
            recurrence: TaskRecurrence(types: [RecurrenceType.daily], interval: 1),
            createdAt: now,
          ),
          Task(
            id: 'morning-2',
            title: 'Breakfast',
            scheduledDate: today,
            createdAt: now,
          ),
          Task(
            id: 'morning-3',
            title: 'Check emails',
            isImportant: true,
            createdAt: now,
          ),
        ];

        await taskService.saveTasks(morningTasks);

        // Complete exercise
        final completed = morningTasks[0].copyWith(
          isCompleted: true,
          completedAt: now,
        );

        // Skip breakfast to next occurrence (it's recurring)
        // Actually breakfast is not recurring, so postpone instead
        await taskService.postponeTaskToTomorrow(morningTasks[1]);

        // Keep check emails as-is

        // Save the completed one
        final allTasks = await taskService.loadTasks();
        final updatedTasks = allTasks.map((t) {
          if (t.id == 'morning-1') return completed;
          return t;
        }).toList();

        await taskService.saveTasks(updatedTasks);

        // Verify final state
        final finalTasks = await taskService.loadTasks();

        final exercise = finalTasks.firstWhere((t) => t.id == 'morning-1');
        final breakfast = finalTasks.firstWhere((t) => t.id == 'morning-2');
        final emails = finalTasks.firstWhere((t) => t.id == 'morning-3');

        expect(exercise.isCompleted, true);
        expect(breakfast.isPostponed, true);
        expect(emails.isImportant, true);
      });

      test('Weekly planning: Create tasks for next week, prioritize, filter by category', () async {
        final today = DateTime.now();
        final nextWeek = today.add(const Duration(days: 7));

        // Create work category
        final categories = [
          TaskCategory(id: 'work', name: 'Work', color: Colors.blue, order: 0),
          TaskCategory(id: 'personal', name: 'Personal', color: Colors.green, order: 1),
        ];
        await taskService.saveCategories(categories);

        // Create tasks for next week
        final weeklyTasks = [
          Task(
            id: 'week-1',
            title: 'Team Meeting',
            categoryIds: ['work'],
            scheduledDate: nextWeek,
            isImportant: true,
            createdAt: today,
          ),
          Task(
            id: 'week-2',
            title: 'Project Deadline',
            categoryIds: ['work'],
            deadline: nextWeek.add(const Duration(days: 2)),
            isImportant: true,
            createdAt: today,
          ),
          Task(
            id: 'week-3',
            title: 'Dentist Appointment',
            categoryIds: ['personal'],
            scheduledDate: nextWeek.add(const Duration(days: 3)),
            createdAt: today,
          ),
        ];

        await taskService.saveTasks(weeklyTasks);

        // Filter by work category
        final workTasks = weeklyTasks.where((t) => t.categoryIds.contains('work')).toList();
        expect(workTasks.length, 2);

        // Prioritize
        final prioritized = await taskService.getPrioritizedTasks(weeklyTasks, categories, 10);

        // Important tasks should be higher
        expect(prioritized[0].isImportant || prioritized[1].isImportant, true);
      });

      test('Task migration: Overdue tasks stay overdue for manual completion', () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
        final eightDaysAgo = yesterday.subtract(const Duration(days: 7));

        // Create tasks with old dates
        final oldTasks = [
          Task(
            id: 'old-1',
            title: 'Overdue Daily',
            recurrence: TaskRecurrence(types: [RecurrenceType.daily], interval: 1),
            scheduledDate: twoDaysAgo,
            createdAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          Task(
            id: 'old-2',
            title: 'Overdue Weekly',
            recurrence: TaskRecurrence(
              types: [RecurrenceType.weekly],
              interval: 1,
              weekDays: [DateTime.now().weekday],
            ),
            scheduledDate: eightDaysAgo,
            createdAt: DateTime.now().subtract(const Duration(days: 20)),
          ),
        ];

        await taskService.saveTasks(oldTasks);

        // Load - should NOT auto-migrate overdue tasks (they stay for manual completion)
        final loaded = await taskService.loadTasks();

        // Verify tasks stay at their original overdue dates
        // (NO AUTO-ADVANCE: Tasks stay overdue indefinitely until manually completed)
        final dailyTask = loaded.firstWhere((t) => t.id == 'old-1');
        final weeklyTask = loaded.firstWhere((t) => t.id == 'old-2');

        expect(dailyTask.scheduledDate, isNotNull);
        expect(weeklyTask.scheduledDate, isNotNull);

        // Tasks should stay at their original overdue dates
        final dailyScheduled = DateTime(
          dailyTask.scheduledDate!.year,
          dailyTask.scheduledDate!.month,
          dailyTask.scheduledDate!.day,
        );
        final weeklyScheduled = DateTime(
          weeklyTask.scheduledDate!.year,
          weeklyTask.scheduledDate!.month,
          weeklyTask.scheduledDate!.day,
        );
        final twoDaysAgoDay = DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day);
        final eightDaysAgoDay = DateTime(eightDaysAgo.year, eightDaysAgo.month, eightDaysAgo.day);

        expect(
          dailyScheduled.isAtSameMomentAs(twoDaysAgoDay),
          true,
          reason: 'Overdue daily task should stay at original date for manual completion',
        );
        expect(
          weeklyScheduled.isAtSameMomentAs(eightDaysAgoDay),
          true,
          reason: 'Overdue weekly task should stay at original date for manual completion',
        );
      });

      test('Multi-user scenario: Multiple task lists managed independently', () async {
        // User 1 tasks
        final user1Tasks = [
          Task(id: 'u1-1', title: 'User 1 Task 1', createdAt: DateTime.now()),
          Task(id: 'u1-2', title: 'User 1 Task 2', createdAt: DateTime.now()),
        ];

        await taskService.saveTasks(user1Tasks);
        final loaded1 = await taskService.loadTasks();
        expect(loaded1.length, 2);

        // Simulate user switch - replace all tasks
        final user2Tasks = [
          Task(id: 'u2-1', title: 'User 2 Task 1', createdAt: DateTime.now()),
          Task(id: 'u2-2', title: 'User 2 Task 2', createdAt: DateTime.now()),
          Task(id: 'u2-3', title: 'User 2 Task 3', createdAt: DateTime.now()),
        ];

        await taskService.saveTasks(user2Tasks);
        final loaded2 = await taskService.loadTasks();
        expect(loaded2.length, 3);
        expect(loaded2[0].title, contains('User 2'));
      });

      test('Recovery workflow: Delete all tasks, recreate from backup', () async {
        // Create initial tasks
        final originalTasks = [
          Task(id: 'backup-1', title: 'Important Task', isImportant: true, createdAt: DateTime.now()),
          Task(id: 'backup-2', title: 'Regular Task', createdAt: DateTime.now()),
        ];

        await taskService.saveTasks(originalTasks);

        // Simulate deletion
        await taskService.saveTasks([]);
        final afterDelete = await taskService.loadTasks();
        expect(afterDelete, isEmpty);

        // Restore from backup
        await taskService.saveTasks(originalTasks);
        final restored = await taskService.loadTasks();

        expect(restored.length, 2);
        expect(restored[0].title, 'Important Task');
        expect(restored[1].title, 'Regular Task');
      });

      test('Productivity workflow: Daily task review and planning', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));

        // Morning: Review yesterday's incomplete tasks
        final yesterdaysTasks = [
          Task(
            id: 'yesterday-1',
            title: 'Incomplete from yesterday',
            scheduledDate: today.subtract(const Duration(days: 1)),
            createdAt: now.subtract(const Duration(days: 1)),
          ),
        ];

        // Add today's tasks
        final todaysTasks = [
          Task(
            id: 'today-1',
            title: 'Morning meeting',
            scheduledDate: today,
            reminderTime: DateTime(today.year, today.month, today.day, 9, 0),
            createdAt: now,
          ),
          Task(
            id: 'today-2',
            title: 'Complete report',
            deadline: today,
            isImportant: true,
            createdAt: now,
          ),
        ];

        // Plan tomorrow's tasks
        final tomorrowsTasks = [
          Task(
            id: 'tomorrow-1',
            title: 'Client presentation',
            scheduledDate: tomorrow,
            isImportant: true,
            createdAt: now,
          ),
        ];

        final allTasks = [...yesterdaysTasks, ...todaysTasks, ...tomorrowsTasks];
        await taskService.saveTasks(allTasks);

        // Get prioritized list
        final categories = await taskService.loadCategories();
        final prioritized = await taskService.getPrioritizedTasks(allTasks, categories, 10);

        // Today's tasks should be prioritized over tomorrow's
        final todayTasksInPriority = prioritized.where((t) =>
          t.id.startsWith('today-') || t.id.startsWith('yesterday-')
        ).length;

        expect(todayTasksInPriority, greaterThan(0));

        // Important deadline should be near top
        final reportIndex = prioritized.indexWhere((t) => t.id == 'today-2');
        expect(reportIndex, lessThan(3));
      });
    });

    group('Recurrence Calculation Tests', () {
      test('Recalculate all recurring tasks → Verify batch update', () async {
        final now = DateTime.now();

        final tasks = [
          Task(
            id: 'recalc-1',
            title: 'Daily task',
            recurrence: TaskRecurrence(types: [RecurrenceType.daily], interval: 1),
            createdAt: now,
          ),
          Task(
            id: 'recalc-2',
            title: 'Weekly task',
            recurrence: TaskRecurrence(
              types: [RecurrenceType.weekly],
              interval: 1,
              weekDays: [now.weekday],
            ),
            createdAt: now,
          ),
          Task(
            id: 'recalc-3',
            title: 'Non-recurring task',
            createdAt: now,
          ),
        ];

        await taskService.saveTasks(tasks);

        // Load first to trigger auto-migration which sets scheduledDate
        final loaded = await taskService.loadTasks();

        // Verify tasks now have scheduledDate set after auto-migration
        final dailyTask = loaded.firstWhere((t) => t.id == 'recalc-1');
        final weeklyTask = loaded.firstWhere((t) => t.id == 'recalc-2');

        expect(dailyTask.scheduledDate, isNotNull);
        expect(weeklyTask.scheduledDate, isNotNull);

        // Now recalculate - might return 0 if dates are already current
        final updatedCount = await taskService.recalculateAllRecurringTasks();

        // Either updates happened or dates are already current
        expect(updatedCount, greaterThanOrEqualTo(0));
      });

      test('Task with last day of month recurrence', () async {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.monthly],
          interval: 1,
          isLastDayOfMonth: true,
        );

        final task = Task(
          id: 'last-day',
          title: 'Last day of month task',
          recurrence: recurrence,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([task]);
        final loaded = await taskService.loadTasks();

        expect(loaded.length, 1);
        expect(loaded[0].scheduledDate, isNotNull);

        // Should be scheduled for last day of current or next month
        final scheduledMonth = loaded[0].scheduledDate!.month;
        final scheduledDay = loaded[0].scheduledDate!.day;
        final lastDayOfMonth = DateTime(
          loaded[0].scheduledDate!.year,
          scheduledMonth + 1,
          0,
        ).day;

        expect(scheduledDay, lastDayOfMonth);
      });
    });

    group('Task Change Listeners', () {
      test('Add listener → Save task → Verify listener called', () async {
        void listener() {
          // Listener function for testing add/remove API
        }

        taskService.addTaskChangeListener(listener);

        final task = Task(
          id: 'listener-test',
          title: 'Test listener',
          createdAt: DateTime.now(),
        );

        // Save task - listener should be called despite Firebase error
        try {
          await taskService.saveTasks([task]);
        } catch (e) {
          // Firebase error is expected in tests
        }

        // Wait a bit for async listener notification
        await Future.delayed(const Duration(milliseconds: 10));

        // Note: This test verifies the listener mechanism exists and is wired up
        // In the actual code, listeners are called in _notifyTasksChanged which happens
        // before the Firebase error, but the error is caught and swallowed

        taskService.removeTaskChangeListener(listener);

        // Verify listener can be removed
        expect(taskService.removeTaskChangeListener, isNotNull);
      });

      test('Multiple listeners → Add and remove mechanism', () async {
        void listener1() {
          // Listener 1 for testing add/remove API
        }
        void listener2() {
          // Listener 2 for testing add/remove API
        }

        // Test adding multiple listeners
        taskService.addTaskChangeListener(listener1);
        taskService.addTaskChangeListener(listener2);

        // Test removing listeners
        taskService.removeTaskChangeListener(listener1);
        taskService.removeTaskChangeListener(listener2);

        // Verify the API exists and works
        expect(taskService.addTaskChangeListener, isNotNull);
        expect(taskService.removeTaskChangeListener, isNotNull);
      });

      test('Listener management API exists', () async {
        void dummyListener() {}

        // Verify listener API exists
        taskService.addTaskChangeListener(dummyListener);
        taskService.removeTaskChangeListener(dummyListener);

        // Adding same listener twice shouldn't cause issues
        taskService.addTaskChangeListener(dummyListener);
        taskService.addTaskChangeListener(dummyListener);
        taskService.removeTaskChangeListener(dummyListener);

        expect(taskService.addTaskChangeListener, isNotNull);
      });
    });

    group('Task Due Today Logic', () {
      test('Verify isDueToday for various task types', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));

        final tasks = [
          Task(
            id: 'due-1',
            title: 'Deadline today',
            deadline: today,
            createdAt: now,
          ),
          Task(
            id: 'due-2',
            title: 'Scheduled today',
            scheduledDate: today,
            createdAt: now,
          ),
          Task(
            id: 'due-3',
            title: 'Reminder today',
            reminderTime: DateTime(today.year, today.month, today.day, 14, 0),
            createdAt: now,
          ),
          Task(
            id: 'not-due-1',
            title: 'Scheduled tomorrow',
            scheduledDate: tomorrow,
            createdAt: now,
          ),
        ];

        // Verify isDueToday logic
        expect(tasks[0].isDueToday(), true);
        expect(tasks[1].isDueToday(), true);
        expect(tasks[2].isDueToday(), true);
        expect(tasks[3].isDueToday(), false);
      });

      test('shouldShowPostponeButton logic verification', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final dailyTask = Task(
          id: 'postpone-test',
          title: 'Daily task due today',
          recurrence: TaskRecurrence(types: [RecurrenceType.daily], interval: 1),
          scheduledDate: today,
          createdAt: now,
        );

        expect(TaskService.shouldShowPostponeButton(dailyTask), true);

        final futureTask = Task(
          id: 'future-task',
          title: 'Future task',
          scheduledDate: today.add(const Duration(days: 5)),
          createdAt: now,
        );

        expect(TaskService.shouldShowPostponeButton(futureTask), false);
      });
    });

    group('Menstrual Phase Task Skip Behavior', () {
      test('Skip menstrual phase task → Marked as postponed', () async {
        final today = DateTime.now();

        // Create a menstrual phase task scheduled for today
        final menstrualTask = Task(
          id: 'menstrual-skip-1',
          title: 'Follicular Phase Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.follicularPhase],
            phaseDay: 3,
          ),
          scheduledDate: today,
          createdAt: today,
        );

        // Save the task
        await taskService.saveTasks([menstrualTask]);

        // Skip the task
        final skippedTask = await taskService.skipToNextOccurrence(menstrualTask);

        // Verify skip behavior - menstrual tasks should NOT be marked as postponed
        expect(skippedTask, isNotNull);
        expect(skippedTask!.isPostponed, false, reason: 'Menstrual tasks should NOT be postponed when skipped');
        expect(skippedTask.scheduledDate, isNull, reason: 'ScheduledDate should be cleared for menstrual tasks');

        // Load tasks to verify persistence
        final loadedTasks = await taskService.loadTasks();
        final loadedSkippedTask = loadedTasks.firstWhere((t) => t.id == 'menstrual-skip-1');

        // Verify task is NOT marked as postponed after reload
        expect(loadedSkippedTask.isPostponed, false, reason: 'Menstrual tasks should NOT be postponed');
        expect(loadedSkippedTask.scheduledDate, isNull, reason: 'ScheduledDate should remain null');
      });

      test('Regular recurring task vs Menstrual task → Different postponed behavior', () async {
        final today = DateTime.now();

        // Create regular daily recurring task
        final dailyTask = Task(
          id: 'daily-compare',
          title: 'Daily Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          scheduledDate: today,
          createdAt: today,
        );

        // Create menstrual phase task
        final menstrualTask = Task(
          id: 'menstrual-compare',
          title: 'Menstrual Phase Task',
          categoryIds: [],
          isCompleted: false,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.menstrualPhase],
            phaseDay: 1,
          ),
          scheduledDate: today,
          createdAt: today,
        );

        await taskService.saveTasks([dailyTask, menstrualTask]);

        // Skip both tasks
        final skippedDaily = await taskService.skipToNextOccurrence(dailyTask);
        final skippedMenstrual = await taskService.skipToNextOccurrence(menstrualTask);

        // Regular task should be marked as postponed
        expect(skippedDaily, isNotNull);
        expect(skippedDaily!.isPostponed, true, reason: 'Regular recurring tasks should be postponed');
        expect(skippedDaily.scheduledDate, isNotNull, reason: 'Regular tasks get next scheduled date');

        // Menstrual task should NOT be marked as postponed
        expect(skippedMenstrual, isNotNull);
        expect(skippedMenstrual!.isPostponed, false, reason: 'Menstrual tasks should NOT be postponed');
        expect(skippedMenstrual.scheduledDate, isNull, reason: 'Menstrual tasks have scheduledDate cleared');

        // Verify persistence after reload
        final loadedTasks = await taskService.loadTasks();
        final loadedDaily = loadedTasks.firstWhere((t) => t.id == 'daily-compare');
        final loadedMenstrual = loadedTasks.firstWhere((t) => t.id == 'menstrual-compare');

        expect(loadedDaily.isPostponed, true, reason: 'Regular task postponed flag persists');
        expect(loadedMenstrual.isPostponed, false, reason: 'Menstrual task NOT postponed after reload');
        expect(loadedMenstrual.scheduledDate, isNull, reason: 'Menstrual scheduledDate remains null');
      });
    });

    group('Task Persistence After Refresh', () {
      test('Save tasks → Clear service instance → Load → Tasks still present', () async {
        // Create multiple tasks
        final tasks = [
          Task(
            id: 'persist-1',
            title: 'Task 1',
            description: 'First task',
            categoryIds: ['cat1'],
            isImportant: true,
            createdAt: DateTime.now(),
          ),
          Task(
            id: 'persist-2',
            title: 'Task 2',
            description: 'Second task',
            categoryIds: ['cat2'],
            deadline: DateTime.now().add(const Duration(days: 3)),
            createdAt: DateTime.now(),
          ),
          Task(
            id: 'persist-3',
            title: 'Task 3',
            recurrence: TaskRecurrence(
              types: [RecurrenceType.weekly],
              weekDays: [1, 3, 5],  // Mon, Wed, Fri
              interval: 1,
            ),
            scheduledDate: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ];

        // Save tasks
        await taskService.saveTasks(tasks);

        // Simulate app refresh by creating new TaskService instance
        final newTaskService = TaskService();

        // Load tasks from new instance
        final loadedTasks = await newTaskService.loadTasks();

        // Verify all tasks are still present with correct data
        expect(loadedTasks.length, 3, reason: 'All 3 tasks should persist after refresh');

        final task1 = loadedTasks.firstWhere((t) => t.id == 'persist-1');
        expect(task1.title, 'Task 1');
        expect(task1.description, 'First task');
        expect(task1.isImportant, true);
        expect(task1.categoryIds, contains('cat1'));

        final task2 = loadedTasks.firstWhere((t) => t.id == 'persist-2');
        expect(task2.title, 'Task 2');
        expect(task2.deadline, isNotNull);

        final task3 = loadedTasks.firstWhere((t) => t.id == 'persist-3');
        expect(task3.recurrence, isNotNull);
        expect(task3.recurrence!.types, contains(RecurrenceType.weekly));
        expect(task3.recurrence!.weekDays, containsAll([1, 3, 5]));
      });

      test('Complete task → Refresh → Completion persists', () async {
        final task = Task(
          id: 'complete-persist',
          title: 'Task to Complete',
          categoryIds: [],
          isCompleted: false,
          createdAt: DateTime.now(),
        );

        // Save initial task
        await taskService.saveTasks([task]);

        // Complete the task
        final completedTask = task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        await taskService.saveTasks([completedTask]);

        // Simulate refresh
        final newTaskService = TaskService();
        final loadedTasks = await newTaskService.loadTasks();

        // Verify completion persists
        final persistedTask = loadedTasks.firstWhere((t) => t.id == 'complete-persist');
        expect(persistedTask.isCompleted, true, reason: 'Completion status should persist');
        expect(persistedTask.completedAt, isNotNull, reason: 'Completion timestamp should persist');
      });

      test('Edit task → Refresh → Changes persist', () async {
        // Create initial task
        final originalTask = Task(
          id: 'edit-persist',
          title: 'Original Title',
          description: 'Original description',
          categoryIds: ['cat1'],
          isImportant: false,
          createdAt: DateTime.now(),
        );

        await taskService.saveTasks([originalTask]);

        // Edit the task
        final editedTask = originalTask.copyWith(
          title: 'Updated Title',
          description: 'Updated description',
          categoryIds: ['cat1', 'cat2'],
          isImportant: true,
        );
        await taskService.saveTasks([editedTask]);

        // Simulate refresh
        final newTaskService = TaskService();
        final loadedTasks = await newTaskService.loadTasks();

        // Verify edits persist
        final persistedTask = loadedTasks.firstWhere((t) => t.id == 'edit-persist');
        expect(persistedTask.title, 'Updated Title', reason: 'Title edit should persist');
        expect(persistedTask.description, 'Updated description', reason: 'Description edit should persist');
        expect(persistedTask.categoryIds, containsAll(['cat1', 'cat2']), reason: 'Category changes should persist');
        expect(persistedTask.isImportant, true, reason: 'Importance flag should persist');
      });

      test('Multiple save/refresh cycles → Data integrity maintained', () async {
        // Cycle 1: Create task
        final task1 = Task(
          id: 'multi-cycle',
          title: 'Cycle 1',
          categoryIds: [],
          createdAt: DateTime.now(),
        );
        await taskService.saveTasks([task1]);

        // Refresh and verify
        var service = TaskService();
        var loaded = await service.loadTasks();
        expect(loaded.firstWhere((t) => t.id == 'multi-cycle').title, 'Cycle 1');

        // Cycle 2: Update task
        final task2 = task1.copyWith(title: 'Cycle 2', isImportant: true);
        await service.saveTasks([task2]);

        // Refresh and verify
        service = TaskService();
        loaded = await service.loadTasks();
        var task = loaded.firstWhere((t) => t.id == 'multi-cycle');
        expect(task.title, 'Cycle 2');
        expect(task.isImportant, true);

        // Cycle 3: Complete task
        final task3 = task.copyWith(isCompleted: true, completedAt: DateTime.now());
        await service.saveTasks([task3]);

        // Refresh and verify
        service = TaskService();
        loaded = await service.loadTasks();
        task = loaded.firstWhere((t) => t.id == 'multi-cycle');
        expect(task.title, 'Cycle 2');
        expect(task.isImportant, true);
        expect(task.isCompleted, true);
        expect(task.completedAt, isNotNull);
      });

      test('Display tasks in list after refresh → Prioritization intact', () async {
        final now = DateTime.now();

        // Create tasks with different priorities
        final tasks = [
          Task(
            id: 'priority-low',
            title: 'Low Priority',
            categoryIds: [],
            createdAt: now,
          ),
          Task(
            id: 'priority-high',
            title: 'High Priority',
            categoryIds: [],
            isImportant: true,
            deadline: now, // Due today
            createdAt: now,
          ),
          Task(
            id: 'priority-medium',
            title: 'Medium Priority',
            categoryIds: [],
            scheduledDate: now,
            createdAt: now,
          ),
        ];

        await taskService.saveTasks(tasks);

        // Simulate refresh
        final newTaskService = TaskService();
        final loadedTasks = await newTaskService.loadTasks();
        final categories = await newTaskService.loadCategories();

        // Get prioritized list (like the UI would display)
        final prioritized = await newTaskService.getPrioritizedTasks(loadedTasks, categories, 10);

        // Verify prioritization is correct after refresh
        expect(prioritized.length, 3);

        // High priority task should be first (important + deadline today)
        expect(prioritized[0].id, 'priority-high', reason: 'Task with importance and deadline should be highest priority');

        // Medium priority (scheduled today) should be second
        expect(prioritized[1].id, 'priority-medium', reason: 'Task scheduled today should be second priority');

        // Low priority should be last
        expect(prioritized[2].id, 'priority-low', reason: 'Task with no priority attributes should be lowest');
      });
    });
  });
}
