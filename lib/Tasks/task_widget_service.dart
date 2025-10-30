import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'task_edit_screen.dart';
import 'task_service.dart';

class TaskWidgetService {
  static const MethodChannel _channel = MethodChannel('com.bb.bb_app/task_widget');

  static Future<bool> checkForWidgetIntent() async {
    try {
      final bool hasWidgetIntent = await _channel.invokeMethod('checkWidgetIntent');
      return hasWidgetIntent;
    } catch (e) {
      debugPrint('Error checking widget intent: $e');
      return false;
    }
  }

  static Future<bool> checkForTaskListIntent() async {
    try {
      final bool hasTaskListIntent = await _channel.invokeMethod('checkTaskListIntent');
      return hasTaskListIntent;
    } catch (e) {
      debugPrint('Error checking task list intent: $e');
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
          onSave: (task) async {
            try {
              // Save the task properly (handle both new and existing tasks)
              final allTasks = await taskService.loadTasks();
              final existingIndex = allTasks.indexWhere((t) => t.id == task.id);
              
              if (existingIndex != -1) {
                allTasks[existingIndex] = task;
              } else {
                allTasks.add(task);
              }
              
              await taskService.saveTasks(allTasks);

              // Close the screen
              if (context.mounted) {
                Navigator.of(context).pop();
              }

              // No snackbar needed - user will see the task in the list
            } catch (e) {
              debugPrint('Error saving task from widget: $e');
              // Don't show snackbar due to context issues after navigation
            }
          },
        ),
      ),
    );
  }
}