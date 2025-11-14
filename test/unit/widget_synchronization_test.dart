import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Tasks/task_service.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Tasks/task_list_widget_filter_service.dart';
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
  });
}
