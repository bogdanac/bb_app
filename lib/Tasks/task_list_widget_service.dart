import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class TaskListWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.bb.bb_app/task_list_widget');

  /// Update the task list widget to reflect latest task data
  static Future<void> updateWidget() async {
    try {
      await _channel.invokeMethod('updateTaskListWidget');
      if (kDebugMode) {
        print('Task list widget updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating task list widget: $e');
      }
    }
  }
}
