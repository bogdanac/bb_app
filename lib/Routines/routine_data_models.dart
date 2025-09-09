// ROUTINE DATA MODELS
class Routine {
  final String id;
  String title;
  List<RoutineItem> items;
  bool reminderEnabled;
  int reminderHour;
  int reminderMinute;
  Set<int> activeDays; // 1=Monday, 2=Tuesday, ..., 7=Sunday

  Routine({
    required this.id,
    required this.title,
    required this.items,
    this.reminderEnabled = false,
    this.reminderHour = 8,
    this.reminderMinute = 0,
    Set<int>? activeDays,
  }) : activeDays = activeDays ?? {1, 2, 3, 4, 5, 6, 7}; // Default to all days

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'items': items.map((item) => item.toJson()).toList(),
    'reminderEnabled': reminderEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'activeDays': activeDays.toList(),
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
    activeDays: json['activeDays'] != null 
        ? Set<int>.from(json['activeDays']) 
        : {1, 2, 3, 4, 5, 6, 7},
  );

  String getActiveDaysText() {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sortedDays = activeDays.toList()..sort();
    
    if (sortedDays.length == 7) {
      return 'Every day';
    } else if (sortedDays.length == 5 && 
               [1, 2, 3, 4, 5].every((day) => sortedDays.contains(day))) {
      return 'Weekdays';
    } else if (sortedDays.length == 2 && 
               [6, 7].every((day) => sortedDays.contains(day))) {
      return 'Weekends';
    } else {
      return sortedDays.map((day) => dayNames[day - 1]).join(', ');
    }
  }

  bool isActiveToday() {
    final now = DateTime.now();
    final today = now.weekday; // 1=Monday, 7=Sunday
    return activeDays.contains(today);
  }
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