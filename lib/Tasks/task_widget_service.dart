import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'task_edit_screen.dart';
import 'task_service.dart';
import '../shared/error_logger.dart';

class TaskWidgetService {
  static const MethodChannel _channel = MethodChannel('com.bb.bb_app/task_widget');

  static Future<bool> checkForWidgetIntent() async {
    try {
      final bool hasWidgetIntent = await _channel.invokeMethod('checkWidgetIntent');
      return hasWidgetIntent;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskWidgetService.checkForWidgetIntent',
        error: 'Error checking widget intent: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }

  static Future<bool> checkForTaskListIntent() async {
    try {
      final bool hasTaskListIntent = await _channel.invokeMethod('checkTaskListIntent');
      return hasTaskListIntent;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskWidgetService.checkForTaskListIntent',
        error: 'Error checking task list intent: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }

  static Future<void> showQuickTaskDialog(BuildContext context) async {
    if (!context.mounted) return;

    // Load categories for the task edit dialog
    final taskService = TaskService();
    final categories = await taskService.loadCategories();

    if (!context.mounted) return;

    // Show the task edit screen in full screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          categories: categories,
          onSave: (task, {bool isAutoSave = false}) async {
            try {
              // Save the task properly (handle both new and existing tasks)
              final allTasks = await taskService.loadTasks();
              final existingIndex = allTasks.indexWhere((t) => t.id == task.id);

              if (existingIndex != -1) {
                allTasks[existingIndex] = task;
              } else {
                allTasks.add(task);
              }

              // Skip expensive operations during auto-save
              await taskService.saveTasks(allTasks,
                skipNotificationUpdate: isAutoSave,
                skipWidgetUpdate: isAutoSave);

              // Note: TaskEditScreen handles its own navigation via PopScope
              // We don't pop here to avoid double-pop issues

              // No snackbar needed - user will see the task in the list
            } catch (e, stackTrace) {
              await ErrorLogger.logError(
                source: 'TaskWidgetService.showQuickTaskDialog.onSave',
                error: 'Error saving task from widget: $e',
                stackTrace: stackTrace.toString(),
                context: {'taskId': task.id, 'taskTitle': task.title},
              );
              // Don't show snackbar due to context issues after navigation
            }
          },
        ),
      ),
    );
  }
}