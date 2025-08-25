// ROUTINE DATA MODELS
class Routine {
  final String id;
  String title;
  List<RoutineItem> items;
  bool reminderEnabled;
  int reminderHour;
  int reminderMinute;

  Routine({
    required this.id,
    required this.title,
    required this.items,
    this.reminderEnabled = false,
    this.reminderHour = 8,
    this.reminderMinute = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'items': items.map((item) => item.toJson()).toList(),
    'reminderEnabled': reminderEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
  };

  static Routine fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'],
    title: json['title'],
    items: (json['items'] as List)
        .map((item) => RoutineItem.fromJson(item))
        .toList(),
    reminderEnabled: json['reminderEnabled'] ?? false,
    reminderHour: json['reminderHour'] ?? 8,
    reminderMinute: json['reminderMinute'] ?? 0,
  );
}

class RoutineItem {
  final String id;
  String text;
  bool isCompleted;
  bool isSkipped;

  RoutineItem({
    required this.id,
    required this.text,
    required this.isCompleted,
    this.isSkipped = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isCompleted': isCompleted,
    'isSkipped': isSkipped,
  };

  static RoutineItem fromJson(Map<String, dynamic> json) => RoutineItem(
    id: json['id'],
    text: json['text'],
    isCompleted: json['isCompleted'],
    isSkipped: json['isSkipped'] ?? false,
  );
}