import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Tasks/task_service.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Tasks/task_list_widget_filter_service.dart';
import 'package:bb_app/MenstrualCycle/menstrual_cycle_utils.dart';
import 'dart:convert';

void main() {
  group('Widget Synchronization Tests', () {
    late TaskService taskService;

    setUp(() async {
      // Initialize shared preferences with empty values
      SharedPreferences.setMockInitialValues({});
      taskService = TaskService();
    });

    test('Widget filtered tasks should update when task is completed', () async {
      // Create a test task
      final task = Task(
        id: 'test-task-1',
        title: 'Test Task',
        description: 'A test task',
        categoryIds: ['1'],
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      // Save the task
      await taskService.saveTasks([task]);

      // Update the widget tasks (this simulates the initial widget setup)
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Load widget tasks to verify it was saved
      final prefs = await SharedPreferences.getInstance();
      final widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson, isNotNull);
      expect(widgetTasksJson!.length, 1);

      // Parse the widget task
      final widgetTask = Task.fromJson(jsonDecode(widgetTasksJson[0]));
      expect(widgetTask.id, 'test-task-1');
      expect(widgetTask.isCompleted, false);

      // Complete the task
      final completedTask = task.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      await taskService.saveTasks([completedTask]);

      // Update widget tasks after completion
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify widget tasks list no longer contains the completed task
      final updatedWidgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(updatedWidgetTasksJson, isNotNull);
      expect(updatedWidgetTasksJson!.length, 0,
        reason: 'Completed task should be removed from widget filtered tasks');
    });

    test('Widget filtered tasks should only show incomplete tasks', () async {
      // Create multiple tasks with different completion statuses
      final tasks = [
        Task(
          id: 'task-1',
          title: 'Incomplete Task 1',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
        Task(
          id: 'task-2',
          title: 'Completed Task',
          categoryIds: ['1'],
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        Task(
          id: 'task-3',
          title: 'Incomplete Task 2',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
      ];

      await taskService.saveTasks(tasks);
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify only incomplete tasks are in widget list
      final prefs = await SharedPreferences.getInstance();
      final widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson, isNotNull);
      expect(widgetTasksJson!.length, 2,
        reason: 'Only incomplete tasks should be in widget filtered list');

      // Verify the incomplete tasks are the ones we expect
      final widgetTasks = widgetTasksJson
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();
      expect(widgetTasks.any((t) => t.id == 'task-1'), true);
      expect(widgetTasks.any((t) => t.id == 'task-3'), true);
      expect(widgetTasks.any((t) => t.id == 'task-2'), false,
        reason: 'Completed task should not be in widget list');
    });

    test('Widget tasks should be limited to maximum count', () async {
      // Create more tasks than the widget can display
      final tasks = List.generate(
        10,
        (index) => Task(
          id: 'task-$index',
          title: 'Task $index',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: DateTime.now().subtract(Duration(days: index)),
        ),
      );

      await taskService.saveTasks(tasks);
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify widget tasks are limited to max count (5)
      final prefs = await SharedPreferences.getInstance();
      final widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson, isNotNull);
      expect(widgetTasksJson!.length, lessThanOrEqualTo(5),
        reason: 'Widget should only show maximum of 5 tasks');
    });

    test('Widget tasks should update when new task is added', () async {
      // Start with one task
      final task1 = Task(
        id: 'task-1',
        title: 'First Task',
        categoryIds: ['1'],
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      await taskService.saveTasks([task1]);
      await TaskListWidgetFilterService.updateWidgetTasks();

      final prefs = await SharedPreferences.getInstance();
      var widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson?.length, 1);

      // Add a second task
      final task2 = Task(
        id: 'task-2',
        title: 'Second Task',
        categoryIds: ['1'],
        isCompleted: false,
        isImportant: true, // Make it important so it's prioritized
        createdAt: DateTime.now(),
      );

      await taskService.saveTasks([task1, task2]);
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify widget tasks list is updated
      widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson?.length, 2);

      final widgetTasks = widgetTasksJson!
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();
      expect(widgetTasks.any((t) => t.id == 'task-2'), true,
        reason: 'Newly added task should appear in widget list');
    });

    test('Widget tasks should respect priority ordering', () async {
      // Create tasks with different priorities
      final normalTask = Task(
        id: 'normal-task',
        title: 'Normal Task',
        categoryIds: ['1'],
        isCompleted: false,
        isImportant: false,
        createdAt: DateTime.now(),
      );

      final importantTask = Task(
        id: 'important-task',
        title: 'Important Task',
        categoryIds: ['1'],
        isCompleted: false,
        isImportant: true,
        createdAt: DateTime.now(),
      );

      final overdueTask = Task(
        id: 'overdue-task',
        title: 'Overdue Task',
        categoryIds: ['1'],
        isCompleted: false,
        isImportant: false,
        deadline: DateTime.now().subtract(const Duration(days: 1)), // Past deadline
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      );

      // Save tasks in non-priority order
      await taskService.saveTasks([normalTask, importantTask, overdueTask]);
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify priority ordering in widget tasks
      final prefs = await SharedPreferences.getInstance();
      final widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson, isNotNull);

      final widgetTasks = widgetTasksJson!
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();

      // Overdue tasks should come first, followed by important tasks
      final overdueIndex = widgetTasks.indexWhere((t) => t.id == 'overdue-task');
      final importantIndex = widgetTasks.indexWhere((t) => t.id == 'important-task');
      final normalIndex = widgetTasks.indexWhere((t) => t.id == 'normal-task');

      expect(overdueIndex, lessThan(normalIndex),
        reason: 'Overdue task should be prioritized over normal task');
      expect(importantIndex, lessThan(normalIndex),
        reason: 'Important task should be prioritized over normal task');
    });

    test('Widget tasks should handle empty task list', () async {
      // Save empty task list
      await taskService.saveTasks([]);
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify widget tasks list is empty
      final prefs = await SharedPreferences.getInstance();
      final widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson, isNotNull);
      expect(widgetTasksJson!.length, 0,
        reason: 'Widget should handle empty task list gracefully');
    });

    test('Widget tasks clear should remove all filtered tasks', () async {
      // Create and save tasks
      final tasks = [
        Task(
          id: 'task-1',
          title: 'Task 1',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
        Task(
          id: 'task-2',
          title: 'Task 2',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
      ];

      await taskService.saveTasks(tasks);
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify tasks exist
      final prefs = await SharedPreferences.getInstance();
      var widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson?.length, 2);

      // Clear widget tasks
      await TaskListWidgetFilterService.clearWidgetTasks();

      // Verify widget tasks are cleared
      widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson, isNull,
        reason: 'Widget tasks should be completely removed after clear');
    });

    test('Widget MUST ONLY show tasks from current menstrual phase (flower icon ON)', () async {
      // Set up menstrual cycle data - simulate being in the Follicular phase
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastPeriodStart = now.subtract(const Duration(days: 10)); // 10 days ago
      await prefs.setString('last_period_start', lastPeriodStart.toIso8601String());
      await prefs.setInt('average_cycle_length', 31);

      // Verify we're in the expected phase
      final currentPhase = MenstrualCycleUtils.getCyclePhase(lastPeriodStart, null, 31);
      expect(currentPhase, 'Follicular Phase',
        reason: 'Test setup should place us in Follicular Phase');

      // Create tasks with different menstrual phase settings
      final tasks = [
        // Task 1: Menstrual phase task (should NOT show - wrong phase)
        Task(
          id: 'menstrual-task',
          title: 'Menstrual Phase Task',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.menstrualPhase],
            startDate: lastPeriodStart,
          ),
        ),
        // Task 2: Follicular phase task (SHOULD show - matches current phase)
        Task(
          id: 'follicular-task',
          title: 'Follicular Phase Task',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.follicularPhase],
            startDate: lastPeriodStart,
          ),
        ),
        // Task 3: Ovulation phase task (should NOT show - wrong phase)
        Task(
          id: 'ovulation-task',
          title: 'Ovulation Phase Task',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.ovulationPhase],
            startDate: lastPeriodStart,
          ),
        ),
        // Task 4: No menstrual settings (SHOULD show - always included)
        Task(
          id: 'no-phase-task',
          title: 'Task Without Phase',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
        ),
        // Task 5: Follicular + Daily, scheduled for today (SHOULD show - correct phase AND due today)
        Task(
          id: 'follicular-daily-today',
          title: 'Follicular Daily Task Due Today',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
          scheduledDate: today,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.follicularPhase, RecurrenceType.daily],
            startDate: now,
          ),
        ),
        // Task 6: Follicular + Daily, scheduled for tomorrow (should NOT show - correct phase but NOT due today)
        Task(
          id: 'follicular-daily-tomorrow',
          title: 'Follicular Daily Task Due Tomorrow',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
          scheduledDate: today.add(const Duration(days: 1)),
          recurrence: TaskRecurrence(
            types: [RecurrenceType.follicularPhase, RecurrenceType.daily],
            startDate: now,
          ),
        ),
        // Task 7: Follicular phase with phaseDay = 6 (SHOULD show - 10 days after period = day 11 of cycle = day 6 of follicular)
        // 10 days after period start = cycle day 11, follicular starts day 6, so day 11 = follicular day 6
        Task(
          id: 'follicular-phaseday-6',
          title: 'Follicular Phase Day 6 Task',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.follicularPhase],
            startDate: lastPeriodStart,
            phaseDay: 6,
          ),
        ),
        // Task 8: Follicular phase with phaseDay = 1 (should NOT show - wrong day)
        Task(
          id: 'follicular-phaseday-1',
          title: 'Follicular Phase Day 1 Task',
          categoryIds: ['1'],
          isCompleted: false,
          createdAt: now,
          recurrence: TaskRecurrence(
            types: [RecurrenceType.follicularPhase],
            startDate: lastPeriodStart,
            phaseDay: 1,
          ),
        ),
      ];

      await taskService.saveTasks(tasks);
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Verify ONLY tasks from current phase or without phase settings are shown
      final widgetTasksJson = prefs.getStringList('flutter.widget_filtered_tasks');
      expect(widgetTasksJson, isNotNull);

      final widgetTasks = widgetTasksJson!
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();

      // Should include follicular phase task (ONLY menstrual phase, no regular recurrence)
      expect(widgetTasks.any((t) => t.id == 'follicular-task'), true,
        reason: 'Widget MUST show tasks from current menstrual phase (Follicular)');

      // Should include tasks without menstrual phase settings
      expect(widgetTasks.any((t) => t.id == 'no-phase-task'), true,
        reason: 'Widget MUST show tasks without menstrual phase settings');

      // Should include follicular + daily task that is due today
      expect(widgetTasks.any((t) => t.id == 'follicular-daily-today'), true,
        reason: 'Widget MUST show tasks with correct phase AND due today');

      // Should include follicular phaseDay task matching current day
      expect(widgetTasks.any((t) => t.id == 'follicular-phaseday-6'), true,
        reason: 'Widget MUST show tasks with correct phase AND matching phaseDay');

      // CRITICAL: Should NOT include tasks from other phases
      expect(widgetTasks.any((t) => t.id == 'menstrual-task'), false,
        reason: 'Widget MUST NOT show tasks from other menstrual phases (Menstrual)');
      expect(widgetTasks.any((t) => t.id == 'ovulation-task'), false,
        reason: 'Widget MUST NOT show tasks from other menstrual phases (Ovulation)');

      // CRITICAL: Should NOT include follicular + daily task scheduled for tomorrow (not due today)
      expect(widgetTasks.any((t) => t.id == 'follicular-daily-tomorrow'), false,
        reason: 'Widget MUST NOT show tasks with correct phase but NOT due today');

      // CRITICAL: Should NOT include follicular phaseDay task with wrong day
      expect(widgetTasks.any((t) => t.id == 'follicular-phaseday-1'), false,
        reason: 'Widget MUST NOT show tasks with correct phase but wrong phaseDay');

      // Verify correct count (4 tasks should be shown)
      expect(widgetTasks.length, 4,
        reason: 'Widget should show exactly 4 tasks matching current phase filter');
    });
  });
}
