// ENHANCED DATA MODELS
import 'package:flutter/material.dart';
import 'models/task_recurrence_model.dart';
import 'services/recurrence_evaluator.dart';
import 'utils/recurrence_formatter.dart';

// Re-export for backward compatibility
export 'models/task_recurrence_model.dart' show RecurrenceType;

class Task {
  final String id;
  final String title;
  final String description;
  final List<String> categoryIds;
  final DateTime? deadline;
  final DateTime? scheduledDate; // For recurring tasks, this is when the task is scheduled for
  final DateTime? reminderTime;
  final bool isImportant;
  final bool isPostponed; // True if user manually postponed/rescheduled this task
  final TaskRecurrence? recurrence;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final int energyLevel; // Body Battery impact (-5 to +5: negative=draining, positive=charging, default=-1)

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.categoryIds = const [],
    this.deadline,
    this.scheduledDate,
    this.reminderTime,
    this.isImportant = false,
    this.isPostponed = false,
    this.recurrence,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
    this.energyLevel = -1, // Default to -1 (drains 10%, earns 11 flow points)
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy of this task with modified fields
  Task copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? categoryIds,
    DateTime? deadline,
    DateTime? scheduledDate,
    DateTime? reminderTime,
    bool? isImportant,
    bool? isPostponed,
    TaskRecurrence? recurrence,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    int? energyLevel,
    bool clearDeadline = false,
    bool clearScheduledDate = false,
    bool clearReminderTime = false,
    bool clearRecurrence = false,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryIds: categoryIds ?? this.categoryIds,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      scheduledDate: clearScheduledDate ? null : (scheduledDate ?? this.scheduledDate),
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      isImportant: isImportant ?? this.isImportant,
      isPostponed: isPostponed ?? this.isPostponed,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      energyLevel: energyLevel ?? this.energyLevel,
    );
  }

  // Check if task is due today based on deadline, scheduledDate, recurrence, or reminder
  bool isDueToday() {
    final today = DateTime.now();

    // Priority 1: For recurring tasks, check both recurrence pattern AND scheduled date
    if (recurrence != null) {
      // First check if specifically scheduled for today (from postponing)
      if (scheduledDate != null && _isSameDay(scheduledDate!, today)) {
        return true;
      }

      // If scheduled for a future date, ignore recurrence pattern
      if (scheduledDate != null && scheduledDate!.isAfter(today)) {
        return false;
      }

      // Then check recurrence pattern
      // Special exception: Show Ovulation Peak Day and Menstrual Start Day tasks for 2 days
      if (recurrence!.type == RecurrenceType.ovulationPeakDay ||
          recurrence!.type == RecurrenceType.menstrualStartDay) {
        final yesterday = today.subtract(const Duration(days: 1));
        return recurrence!.isDueOn(today, taskCreatedAt: createdAt) ||
               recurrence!.isDueOn(yesterday, taskCreatedAt: createdAt);
      }

      if (recurrence!.isDueOn(today, taskCreatedAt: createdAt)) {
        return true;
      }
    }

    // Priority 2: For non-recurring tasks, check deadline (today or overdue)
    if (recurrence == null && deadline != null && (_isSameDay(deadline!, today) || deadline!.isBefore(today))) {
      return true;
    }

    // Priority 3: For non-recurring tasks, check scheduled date
    if (recurrence == null && scheduledDate != null) {
      final result = _isSameDay(scheduledDate!, today);
      return result;
    }

    // Priority 4: For non-recurring tasks, check if reminder is set for today
    if (recurrence == null && reminderTime != null && _isSameDay(reminderTime!, today)) {
      return true;
    }

    return false;
  }

  // Get next due date for recurring tasks
  DateTime? getNextDueDate() {
    if (recurrence == null) return deadline;

    final today = DateTime.now();
    return recurrence!.getNextDueDate(today);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'categoryIds': categoryIds,
    'deadline': deadline?.toIso8601String(),
    'scheduledDate': scheduledDate?.toIso8601String(),
    'reminderTime': reminderTime?.toIso8601String(),
    'isImportant': isImportant,
    'isPostponed': isPostponed,
    'recurrence': recurrence?.toJson(),
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'energyLevel': energyLevel,
  };

  static Task fromJson(Map<String, dynamic> json) {
    // Handle migration from old energy system (1-5) to new system (-5 to +5)
    int energyLevel = json['energyLevel'] ?? -1;

    // If energy level is in old range (1-5), convert to new system
    if (energyLevel >= 1 && energyLevel <= 5) {
      // Convert: 1→-1, 2→-2, 3→-3, 4→-4, 5→-5
      energyLevel = -energyLevel;
    }

    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      categoryIds: List<String>.from(json['categoryIds'] ?? []),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      scheduledDate: json['scheduledDate'] != null ? DateTime.parse(json['scheduledDate']) : null,
      reminderTime: json['reminderTime'] != null ? DateTime.parse(json['reminderTime']) : null,
      isImportant: json['isImportant'] ?? false,
      isPostponed: json['isPostponed'] ?? false,
      recurrence: json['recurrence'] != null ? TaskRecurrence.fromJson(json['recurrence']) : null,
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      energyLevel: energyLevel,
    );
  }
}

class TaskCategory {
  final String id;
  String name;
  Color color;
  int order;

  TaskCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'order': order,
  };

  static TaskCategory fromJson(Map<String, dynamic> json) => TaskCategory(
    id: json['id'],
    name: json['name'],
    color: Color(json['color']),
    order: json['order'],
  );
}

/// Facade class for backward compatibility.
/// Delegates to TaskRecurrenceModel for data, RecurrenceEvaluator for business logic,
/// and RecurrenceFormatter for presentation.
class TaskRecurrence {
  final TaskRecurrenceModel _model;

  TaskRecurrence({
    List<RecurrenceType>? types,
    RecurrenceType? type, // Backward compatibility
    int interval = 1,
    List<int> weekDays = const [],
    int? dayOfMonth,
    bool isLastDayOfMonth = false,
    DateTime? startDate,
    DateTime? endDate,
    int? phaseDay,
    int? daysAfterPeriod,
    TimeOfDay? reminderTime,
  }) : _model = TaskRecurrenceModel(
          types: types ?? (type != null ? [type] : []),
          interval: interval,
          weekDays: weekDays,
          dayOfMonth: dayOfMonth,
          isLastDayOfMonth: isLastDayOfMonth,
          startDate: startDate,
          endDate: endDate,
          phaseDay: phaseDay,
          daysAfterPeriod: daysAfterPeriod,
          reminderTime: reminderTime,
        );

  // Constructor from model (for internal use)
  TaskRecurrence._fromModel(this._model);

  // Expose all fields from the model
  List<RecurrenceType> get types => _model.types;
  int get interval => _model.interval;
  List<int> get weekDays => _model.weekDays;
  int? get dayOfMonth => _model.dayOfMonth;
  bool get isLastDayOfMonth => _model.isLastDayOfMonth;
  DateTime? get startDate => _model.startDate;
  DateTime? get endDate => _model.endDate;
  int? get phaseDay => _model.phaseDay;
  int? get daysAfterPeriod => _model.daysAfterPeriod;
  TimeOfDay? get reminderTime => _model.reminderTime;

  // Backward compatibility getter
  RecurrenceType get type => _model.type;

  // Copy with modified fields
  TaskRecurrence copyWith({
    List<RecurrenceType>? types,
    int? interval,
    List<int>? weekDays,
    int? dayOfMonth,
    bool? isLastDayOfMonth,
    DateTime? startDate,
    DateTime? endDate,
    int? phaseDay,
    int? daysAfterPeriod,
    TimeOfDay? reminderTime,
    bool clearDayOfMonth = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearPhaseDay = false,
    bool clearDaysAfterPeriod = false,
    bool clearReminderTime = false,
  }) {
    return TaskRecurrence._fromModel(_model.copyWith(
      types: types,
      interval: interval,
      weekDays: weekDays,
      dayOfMonth: dayOfMonth,
      isLastDayOfMonth: isLastDayOfMonth,
      startDate: startDate,
      endDate: endDate,
      phaseDay: phaseDay,
      daysAfterPeriod: daysAfterPeriod,
      reminderTime: reminderTime,
      clearDayOfMonth: clearDayOfMonth,
      clearStartDate: clearStartDate,
      clearEndDate: clearEndDate,
      clearPhaseDay: clearPhaseDay,
      clearDaysAfterPeriod: clearDaysAfterPeriod,
      clearReminderTime: clearReminderTime,
    ));
  }

  // Delegate business logic to RecurrenceEvaluator
  bool isDueOn(DateTime date, {DateTime? taskCreatedAt}) {
    return RecurrenceEvaluator.isDueOn(_model, date, taskCreatedAt: taskCreatedAt);
  }

  DateTime? getNextDueDate(DateTime from) {
    return RecurrenceEvaluator.getNextDueDate(_model, from);
  }

  // Delegate presentation logic to RecurrenceFormatter
  String getDisplayText() {
    return RecurrenceFormatter.getDisplayText(_model);
  }

  // Serialization
  Map<String, dynamic> toJson() => _model.toJson();

  static TaskRecurrence fromJson(Map<String, dynamic> json) {
    return TaskRecurrence._fromModel(TaskRecurrenceModel.fromJson(json));
  }
}

// Task Settings for home page display
class TaskSettings {
  int maxTasksOnHomePage;

  TaskSettings({
    this.maxTasksOnHomePage = 5,
  });

  Map<String, dynamic> toJson() => {
    'maxTasksOnHomePage': maxTasksOnHomePage,
  };

  static TaskSettings fromJson(Map<String, dynamic> json) => TaskSettings(
    maxTasksOnHomePage: json['maxTasksOnHomePage'] ?? 5,
  );
}