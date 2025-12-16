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

  static Routine fromJson(Map<String, dynamic> json) {
    // Parse scheduledTime if present (format: "HH:MM")
    int reminderHour = json['reminderHour'] ?? 8;
    int reminderMinute = json['reminderMinute'] ?? 0;
    if (json['scheduledTime'] != null) {
      final parts = (json['scheduledTime'] as String).split(':');
      if (parts.length == 2) {
        reminderHour = int.tryParse(parts[0]) ?? 8;
        reminderMinute = int.tryParse(parts[1]) ?? 0;
      }
    }

    return Routine(
      id: json['id'],
      title: json['title'],
      items: (json['items'] as List)
          .map((item) => RoutineItem.fromJson(item))
          .toList(),
      // Support both 'reminderEnabled' and 'notificationEnabled' for backwards compatibility
      reminderEnabled: json['reminderEnabled'] ?? json['notificationEnabled'] ?? false,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      activeDays: json['activeDays'] != null
          ? Set<int>.from(json['activeDays'])
          : {1, 2, 3, 4, 5, 6, 7},
    );
  }

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
  bool isSkipped;      // Permanently skipped - won't come back
  bool isPostponed;    // Temporarily postponed - will come back later
  int? energyLevel;    // Optional Body Battery impact (-5 to +5, null means neutral/0)

  RoutineItem({
    required this.id,
    required this.text,
    required this.isCompleted,
    this.isSkipped = false,
    this.isPostponed = false,
    this.energyLevel,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isCompleted': isCompleted,
    'isSkipped': isSkipped,
    'isPostponed': isPostponed,
    if (energyLevel != null) 'energyLevel': energyLevel,
  };

  static RoutineItem fromJson(Map<String, dynamic> json) {
    return RoutineItem(
      id: json['id'],
      // Support both 'text' and 'title' for backwards compatibility with backup data
      text: json['text'] ?? json['title'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      isSkipped: json['isSkipped'] ?? false,
      isPostponed: json['isPostponed'] ?? false,
      energyLevel: json['energyLevel'],
    );
  }
}