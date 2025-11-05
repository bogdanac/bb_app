import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'task_service.dart';

class TaskListWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.bb.bb_app/task_list_widget');

  /// Update the task list widget to reflect latest task data
  static Future<void> updateWidget() async {
    try {
      await _channel.invokeMethod('updateTaskListWidget');
    } catch (e) {
      if (kDebugMode) {
        print('ERROR updating task list widget: $e');
      }
    }
  }

  /// Force reload and re-sort tasks (called when widget refresh is triggered)
  static Future<void> refreshTasks() async {
    try {
      if (kDebugMode) {
        print('Widget refresh triggered - reloading and re-sorting tasks');
      }
      final taskService = TaskService();
      final tasks = await taskService.loadTasks();
      await taskService.saveTasks(tasks); // This will re-sort and save
      if (kDebugMode) {
        print('Tasks reloaded and re-sorted successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR refreshing tasks from widget: $e');
      }
    }
  }
}
