import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Represents a single chore completion event
class ChoreCompletion {
  final DateTime completedAt;
  final String? notes;

  ChoreCompletion({
    required this.completedAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'completedAt': completedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
      };

  factory ChoreCompletion.fromJson(Map<String, dynamic> json) {
    return ChoreCompletion(
      completedAt: DateTime.parse(json['completedAt']),
      notes: json['notes'],
    );
  }
}

/// Represents a chore category
class ChoreCategory {
  final String id;
  String name;
  IconData icon;

  ChoreCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  /// Default categories
  static List<ChoreCategory> getDefaults() => [
        ChoreCategory(
          id: 'kitchen',
          name: 'Kitchen',
          icon: Icons.kitchen_rounded,
        ),
        ChoreCategory(
          id: 'bathroom',
          name: 'Bathroom',
          icon: Icons.bathroom_rounded,
        ),
        ChoreCategory(
          id: 'bedroom',
          name: 'Bedroom',
          icon: Icons.bed_rounded,
        ),
        ChoreCategory(
          id: 'laundry',
          name: 'Laundry',
          icon: Icons.local_laundry_service_rounded,
        ),
        ChoreCategory(
          id: 'plants',
          name: 'Plants & Garden',
          icon: Icons.local_florist_rounded,
        ),
        ChoreCategory(
          id: 'personal',
          name: 'Personal Care',
          icon: Icons.face_rounded,
        ),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
      };

  factory ChoreCategory.fromJson(Map<String, dynamic> json) {
    return ChoreCategory(
      id: json['id'],
      name: json['name'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
    );
  }

  ChoreCategory copyWith({
    String? id,
    String? name,
    IconData? icon,
  }) {
    return ChoreCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
    );
  }
}

/// Represents a household chore with adaptive condition decay
class Chore {
  final String id;
  String name;
  String category; // Category name (editable)
  int intervalDays; // Recurs X days after completion
  double condition; // 0.0-1.0 (stored value)
  DateTime lastCompleted;
  DateTime createdAt;
  List<ChoreCompletion> completionHistory;
  String? notes;

  Chore({
    String? id,
    required this.name,
    required this.category,
    required this.intervalDays,
    this.condition = 1.0,
    DateTime? lastCompleted,
    DateTime? createdAt,
    List<ChoreCompletion>? completionHistory,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        lastCompleted = lastCompleted ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        completionHistory = completionHistory ?? [];

  /// Calculate current condition based on ADAPTIVE decay
  /// Decay rate = 100% / intervalDays per day
  double get currentCondition {
    final now = DateTime.now();
    final daysSince = now.difference(lastCompleted).inDays;
    final decayRate = 1.0 / intervalDays; // Adaptive to interval
    final decayed = condition - (daysSince * decayRate);
    return decayed.clamp(0.0, 1.0);
  }

  /// Get condition percentage as integer (0-100)
  int get conditionPercentage => (currentCondition * 100).round();

  /// Chore is "active" when condition drops below 10%
  bool get isActive => currentCondition < 0.1;

  /// Get color based on condition level
  Color get conditionColor {
    if (currentCondition >= 0.7) return Colors.green;
    if (currentCondition >= 0.4) return Colors.orange;
    return Colors.red;
  }

  /// Get next due date
  DateTime get nextDueDate {
    return lastCompleted.add(Duration(days: intervalDays));
  }

  /// Check if chore is overdue (past due date)
  bool get isOverdue {
    final now = DateTime.now();
    return now.isAfter(nextDueDate);
  }

  /// Get days until next due (negative if overdue)
  int get daysUntilDue {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final dueDate =
        DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return dueDate.difference(nowDate).inDays;
  }

  /// Check if chore is critical (condition < 40%)
  bool get isCritical => currentCondition < 0.4;

  /// Complete this chore (restore condition to 100%)
  void complete({String? completionNotes}) {
    condition = 1.0;
    lastCompleted = DateTime.now();
    completionHistory.add(ChoreCompletion(
      completedAt: lastCompleted,
      notes: completionNotes,
    ));
  }

  /// Manual condition adjustment
  void setCondition(double newCondition) {
    condition = newCondition.clamp(0.0, 1.0);
  }

  /// Refresh condition to current calculated value (for persistence)
  void refreshCondition() {
    condition = currentCondition;
  }

  /// Get total completion count
  int get totalCompletions => completionHistory.length;

  /// Get streak (consecutive completions without missing due date)
  int getStreak() {
    if (completionHistory.isEmpty) return 0;

    int streak = 0;
    DateTime? previousCompletion;

    // Sort completions by date (newest first)
    final sorted = List<ChoreCompletion>.from(completionHistory)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    for (final completion in sorted) {
      if (previousCompletion == null) {
        // First completion - always counts
        streak++;
        previousCompletion = completion.completedAt;
        continue;
      }

      // Calculate expected completion window
      final expectedDueDate =
          previousCompletion.add(Duration(days: intervalDays));
      final gracePeriod =
          expectedDueDate.add(const Duration(days: 2)); // 2-day grace period

      // Check if completion was within acceptable range
      if (completion.completedAt.isBefore(gracePeriod)) {
        streak++;
        previousCompletion = completion.completedAt;
      } else {
        // Streak broken
        break;
      }
    }

    return streak;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'intervalDays': intervalDays,
        'condition': condition,
        'lastCompleted': lastCompleted.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'completionHistory':
            completionHistory.map((c) => c.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };

  factory Chore.fromJson(Map<String, dynamic> json) {
    return Chore(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      intervalDays: json['intervalDays'],
      condition: (json['condition'] as num).toDouble(),
      lastCompleted: DateTime.parse(json['lastCompleted']),
      createdAt: DateTime.parse(json['createdAt']),
      completionHistory: (json['completionHistory'] as List<dynamic>?)
              ?.map((c) => ChoreCompletion.fromJson(c))
              .toList() ??
          [],
      notes: json['notes'],
    );
  }

  Chore copyWith({
    String? id,
    String? name,
    String? category,
    int? intervalDays,
    double? condition,
    DateTime? lastCompleted,
    DateTime? createdAt,
    List<ChoreCompletion>? completionHistory,
    String? notes,
  }) {
    return Chore(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      intervalDays: intervalDays ?? this.intervalDays,
      condition: condition ?? this.condition,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      createdAt: createdAt ?? this.createdAt,
      completionHistory: completionHistory ?? this.completionHistory,
      notes: notes ?? this.notes,
    );
  }
}

/// Settings for chores module
class ChoreSettings {
  Set<int> preferredCleaningDays; // 1=Monday, 7=Sunday
  bool notificationsEnabled;
  int notificationHour; // 0-23
  int notificationMinute; // 0-59

  ChoreSettings({
    Set<int>? preferredCleaningDays,
    this.notificationsEnabled = true,
    this.notificationHour = 9,
    this.notificationMinute = 0,
  }) : preferredCleaningDays =
            preferredCleaningDays ?? {1, 2, 3, 4, 5, 6, 7};

  Map<String, dynamic> toJson() => {
        'preferredCleaningDays': preferredCleaningDays.toList(),
        'notificationsEnabled': notificationsEnabled,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
      };

  factory ChoreSettings.fromJson(Map<String, dynamic> json) {
    return ChoreSettings(
      preferredCleaningDays: (json['preferredCleaningDays'] as List<dynamic>?)
              ?.map((d) => d as int)
              .toSet() ??
          {1, 2, 3, 4, 5, 6, 7},
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      notificationHour: json['notificationHour'] ?? 9,
      notificationMinute: json['notificationMinute'] ?? 0,
    );
  }

  ChoreSettings copyWith({
    Set<int>? preferredCleaningDays,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
  }) {
    return ChoreSettings(
      preferredCleaningDays:
          preferredCleaningDays ?? this.preferredCleaningDays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
    );
  }
}
