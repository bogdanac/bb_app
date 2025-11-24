import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'task_service.dart';
import 'task_list_widget_filter_service.dart';
import '../shared/error_logger.dart';

class TaskListWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.bb.bb_app/task_list_widget');

  /// Update the task list widget to reflect latest task data
  static Future<void> updateWidget() async {
    try {
      // Update the filtered task list for widget
      await TaskListWidgetFilterService.updateWidgetTasks();

      // Trigger widget UI update
      await _channel.invokeMethod('updateTaskListWidget');

      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Step 6: Method channel triggered',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskListWidget',
        error: 'Step 6 FAILED: ${e.toString()}',
        stackTrace: stackTrace.toString(),
      );
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
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskListWidgetService.refreshTasks',
        error: 'Error refreshing tasks from widget: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }
}
