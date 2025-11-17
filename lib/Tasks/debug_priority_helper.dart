import 'package:flutter/foundation.dart';
import 'tasks_data_models.dart';
import 'services/task_priority_service.dart';

/// Helper class to debug task prioritization issues
class DebugPriorityHelper {
  static void printTaskPriorities(
    List<Task> tasks,
    List<TaskCategory> categories,
  ) {
    if (!kDebugMode) return;

    final service = TaskPriorityService();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    print('\n========== TASK PRIORITY DEBUG ==========');
    print('Current time: $now');
    print('Today: $today');
    print('Total tasks: ${tasks.length}\n');

    // Calculate scores for all tasks
    final taskScores = <Task, int>{};
    for (final task in tasks) {
      taskScores[task] = service.calculateTaskPriorityScore(
        task,
        now,
        today,
        categories,
      );
    }

    // Sort by score (descending)
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) {
      final aScore = taskScores[a] ?? 0;
      final bScore = taskScores[b] ?? 0;
      return bScore.compareTo(aScore);
    });

    // Print each task with its score and details
    for (int i = 0; i < sortedTasks.length; i++) {
      final task = sortedTasks[i];
      final score = taskScores[task] ?? 0;

      print('[$i] Score: $score - ${task.title}');
      print('    ID: ${task.id}');
      print('    Completed: ${task.isCompleted}');
      print('    Postponed: ${task.isPostponed}');
      print('    Important: ${task.isImportant}');

      if (task.scheduledDate != null) {
        final daysFromToday = task.scheduledDate!.difference(today).inDays;
        final overdueStatus = daysFromToday < 0
            ? 'OVERDUE by ${-daysFromToday} days'
            : daysFromToday == 0
                ? 'TODAY'
                : 'in $daysFromToday days';
        print('    Scheduled: ${_formatDate(task.scheduledDate!)} ($overdueStatus)');
      } else {
        print('    Scheduled: NONE');
      }

      if (task.deadline != null) {
        final daysFromToday = task.deadline!.difference(today).inDays;
        print('    Deadline: ${_formatDate(task.deadline!)} (in $daysFromToday days)');
      }

      if (task.reminderTime != null) {
        final minutesFromNow = task.reminderTime!.difference(now).inMinutes;
        final reminderStatus = minutesFromNow < 0
            ? 'PAST by ${-minutesFromNow} min'
            : minutesFromNow == 0
                ? 'NOW'
                : 'in $minutesFromNow min';
        print('    Reminder: ${_formatDateTime(task.reminderTime!)} ($reminderStatus)');
      }

      if (task.recurrence != null) {
        print('    Recurrence: ${task.recurrence!.type}');
        if (task.recurrence!.reminderTime != null) {
          print('    Recurrence reminder: ${task.recurrence!.reminderTime!.hour}:${task.recurrence!.reminderTime!.minute.toString().padLeft(2, '0')}');
        }
      }

      print('');
    }

    print('========== END DEBUG ==========\n');
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
