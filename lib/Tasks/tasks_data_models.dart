// ENHANCED DATA MODELS
import 'package:flutter/material.dart';

class Task {
  final String id;
  String title;
  String description;
  List<String> categoryIds;
  DateTime? deadline;
  DateTime? reminderTime;
  bool isImportant;
  TaskRecurrence? recurrence;
  bool isCompleted;
  DateTime? completedAt;
  DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.categoryIds = const [],
    this.deadline,
    this.reminderTime,
    this.isImportant = false,
    this.recurrence,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Check if task is due today based on recurrence
  bool isDueToday() {
    final today = DateTime.now();

    if (recurrence == null) {
      return deadline != null &&
          _isSameDay(deadline!, today);
    }

    return recurrence!.isDueOn(today);
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
    'reminderTime': reminderTime?.toIso8601String(),
    'isImportant': isImportant,
    'recurrence': recurrence?.toJson(),
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  static Task fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    description: json['description'] ?? '',
    categoryIds: List<String>.from(json['categoryIds'] ?? []),
    deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    reminderTime: json['reminderTime'] != null ? DateTime.parse(json['reminderTime']) : null,
    isImportant: json['isImportant'] ?? false,
    recurrence: json['recurrence'] != null ? TaskRecurrence.fromJson(json['recurrence']) : null,
    isCompleted: json['isCompleted'] ?? false,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    createdAt: DateTime.parse(json['createdAt']),
  );
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
    'color': color.value,
    'order': order,
  };

  static TaskCategory fromJson(Map<String, dynamic> json) => TaskCategory(
    id: json['id'],
    name: json['name'],
    color: Color(json['color']),
    order: json['order'],
  );
}

class TaskRecurrence {
  final RecurrenceType type;
  final int interval;
  final List<int> weekDays; // 1-7 for weekly (Monday = 1)
  final int? dayOfMonth; // 1-31 for monthly
  final bool isLastDayOfMonth;
  final DateTime? endDate;

  TaskRecurrence({
    required this.type,
    this.interval = 1,
    this.weekDays = const [],
    this.dayOfMonth,
    this.isLastDayOfMonth = false,
    this.endDate,
  });

  bool isDueOn(DateTime date) {
    if (endDate != null && date.isAfter(endDate!)) {
      return false;
    }

    switch (type) {
      case RecurrenceType.daily:
        return true;

      case RecurrenceType.weekly:
        return weekDays.contains(date.weekday);

      case RecurrenceType.monthly:
        if (isLastDayOfMonth) {
          final nextMonth = DateTime(date.year, date.month + 1, 1);
          final lastDay = nextMonth.subtract(const Duration(days: 1));
          return date.day == lastDay.day;
        }
        return dayOfMonth != null && date.day == dayOfMonth;

      case RecurrenceType.custom:
      // For custom intervals, check if the date matches the pattern
        return _checkCustomInterval(date);
    }
  }

  bool _checkCustomInterval(DateTime date) {
    // Implementation for custom intervals would go here
    // For now, return false
    return false;
  }

  DateTime? getNextDueDate(DateTime from) {
    DateTime next = from.add(const Duration(days: 1));

    // Look ahead up to 365 days to find the next due date
    for (int i = 0; i < 365; i++) {
      if (isDueOn(next)) {
        return next;
      }
      next = next.add(const Duration(days: 1));
    }

    return null;
  }

  String getDisplayText() {
    switch (type) {
      case RecurrenceType.daily:
        return interval == 1 ? 'Daily' : 'Every $interval days';

      case RecurrenceType.weekly:
        if (weekDays.isEmpty) return 'Weekly';
        if (weekDays.length == 7) return 'Daily';

        final dayNames = weekDays.map((day) => _getDayName(day)).join(', ');
        return 'Weekly on $dayNames';

      case RecurrenceType.monthly:
        if (isLastDayOfMonth) {
          return 'Monthly on last day';
        }
        return 'Monthly on day $dayOfMonth';

      case RecurrenceType.custom:
        return 'Custom';
    }
  }

  String _getDayName(int weekday) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayNames[weekday - 1];
  }

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'interval': interval,
    'weekDays': weekDays,
    'dayOfMonth': dayOfMonth,
    'isLastDayOfMonth': isLastDayOfMonth,
    'endDate': endDate?.toIso8601String(),
  };

  static TaskRecurrence fromJson(Map<String, dynamic> json) => TaskRecurrence(
    type: RecurrenceType.values[json['type']],
    interval: json['interval'] ?? 1,
    weekDays: List<int>.from(json['weekDays'] ?? []),
    dayOfMonth: json['dayOfMonth'],
    isLastDayOfMonth: json['isLastDayOfMonth'] ?? false,
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
  );
}

enum RecurrenceType { daily, weekly, monthly, custom }

// Task Settings for home page display
class TaskSettings {
  int maxTasksOnHomePage;
  bool showCompletedTasks;

  TaskSettings({
    this.maxTasksOnHomePage = 5,
    this.showCompletedTasks = false,
  });

  Map<String, dynamic> toJson() => {
    'maxTasksOnHomePage': maxTasksOnHomePage,
    'showCompletedTasks': showCompletedTasks,
  };

  static TaskSettings fromJson(Map<String, dynamic> json) => TaskSettings(
    maxTasksOnHomePage: json['maxTasksOnHomePage'] ?? 5,
    showCompletedTasks: json['showCompletedTasks'] ?? false,
  );
}