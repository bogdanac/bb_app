// DATA MODELS
import 'dart:ui';

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
  final int? dayOfWeek; // 1-7 for weekly
  final int? dayOfMonth; // 1-31 for monthly
  final bool isLastDayOfMonth;

  TaskRecurrence({
    required this.type,
    this.interval = 1,
    this.dayOfWeek,
    this.dayOfMonth,
    this.isLastDayOfMonth = false,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'interval': interval,
    'dayOfWeek': dayOfWeek,
    'dayOfMonth': dayOfMonth,
    'isLastDayOfMonth': isLastDayOfMonth,
  };

  static TaskRecurrence fromJson(Map<String, dynamic> json) => TaskRecurrence(
    type: RecurrenceType.values[json['type']],
    interval: json['interval'] ?? 1,
    dayOfWeek: json['dayOfWeek'],
    dayOfMonth: json['dayOfMonth'],
    isLastDayOfMonth: json['isLastDayOfMonth'] ?? false,
  );
}

enum RecurrenceType { daily, weekly, monthly }