import 'tasks_data_models.dart';

/// Utility class for building Task objects with consistent logic
/// Eliminates code duplication between auto-save and manual save
class TaskBuilder {
  /// Build a task from edit screen state
  static Task buildFromEditScreen({
    required String? currentTaskId,
    required String title,
    required List<String> categoryIds,
    required DateTime? deadline,
    required DateTime? scheduledDate,
    required DateTime? reminderTime,
    required bool isImportant,
    required bool isPostponed,
    required TaskRecurrence? recurrence,
    required bool hasUserModifiedScheduledDate,
    required Task? currentTask,
    bool preserveCompletionStatus = false,
    int energyLevel = 1,
  }) {
    // Calculate effective scheduled date
    final DateTime? effectiveScheduledDate = hasUserModifiedScheduledDate
        ? scheduledDate
        : (scheduledDate ?? (currentTask?.scheduledDate));

    return Task(
      id: currentTaskId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: '',
      categoryIds: categoryIds,
      deadline: deadline,
      scheduledDate: effectiveScheduledDate,
      reminderTime: reminderTime,
      isImportant: isImportant,
      isPostponed: isPostponed || (scheduledDate != null),
      recurrence: recurrence,
      isCompleted: preserveCompletionStatus ? (currentTask?.isCompleted ?? false) : false,
      completedAt: preserveCompletionStatus ? currentTask?.completedAt : null,
      createdAt: currentTask?.createdAt ?? DateTime.now(),
      energyLevel: energyLevel,
    );
  }

  /// Update task with new scheduled date (for recurring tasks)
  static Task updateScheduledDate(
    Task task,
    DateTime newScheduledDate, {
    bool resetCompletion = true,
  }) {
    // Calculate new reminder time if task has one
    DateTime? newReminderTime;
    if (task.reminderTime != null) {
      newReminderTime = DateTime(
        newScheduledDate.year,
        newScheduledDate.month,
        newScheduledDate.day,
        task.reminderTime!.hour,
        task.reminderTime!.minute,
      );
    } else if (task.recurrence?.reminderTime != null) {
      newReminderTime = DateTime(
        newScheduledDate.year,
        newScheduledDate.month,
        newScheduledDate.day,
        task.recurrence!.reminderTime!.hour,
        task.recurrence!.reminderTime!.minute,
      );
    }

    return task.copyWith(
      scheduledDate: newScheduledDate,
      reminderTime: newReminderTime,
      isCompleted: resetCompletion ? false : null,
      clearCompletedAt: resetCompletion,
      isPostponed: false, // Clear postponed flag when auto-scheduling
    );
  }

  /// Mark task as postponed to a specific date
  static Task postponeToDate(
    Task task,
    DateTime postponeDate,
  ) {
    DateTime? newReminderTime;
    if (task.reminderTime != null) {
      newReminderTime = DateTime(
        postponeDate.year,
        postponeDate.month,
        postponeDate.day,
        task.reminderTime!.hour,
        task.reminderTime!.minute,
      );
    } else if (task.recurrence?.reminderTime != null) {
      newReminderTime = DateTime(
        postponeDate.year,
        postponeDate.month,
        postponeDate.day,
        task.recurrence!.reminderTime!.hour,
        task.recurrence!.reminderTime!.minute,
      );
    }

    return task.copyWith(
      scheduledDate: postponeDate,
      reminderTime: newReminderTime,
      isPostponed: true,
    );
  }

  /// Complete a task
  static Task complete(Task task) {
    return task.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
  }

  /// Uncomplete a task
  static Task uncomplete(Task task) {
    return task.copyWith(
      isCompleted: false,
      clearCompletedAt: true,
    );
  }
}
