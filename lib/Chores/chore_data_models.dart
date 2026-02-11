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
  Color color;

  ChoreCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.color = const Color(0xFF64B5F6), // Default waterBlue
  });

  /// Default categories
  static List<ChoreCategory> getDefaults() => [
        ChoreCategory(
          id: 'kitchen',
          name: 'Kitchen',
          icon: Icons.kitchen_rounded,
          color: const Color(0xFFFF7043), // coral
        ),
        ChoreCategory(
          id: 'bathroom',
          name: 'Bathroom',
          icon: Icons.bathroom_rounded,
          color: const Color(0xFF64B5F6), // waterBlue
        ),
        ChoreCategory(
          id: 'bedroom',
          name: 'Bedroom',
          icon: Icons.bed_rounded,
          color: const Color(0xFF9575CD), // purple
        ),
        ChoreCategory(
          id: 'laundry',
          name: 'Laundry',
          icon: Icons.local_laundry_service_rounded,
          color: const Color(0xFF4DD0E1), // cyan
        ),
        ChoreCategory(
          id: 'plants',
          name: 'Plants & Garden',
          icon: Icons.local_florist_rounded,
          color: const Color(0xFF81C784), // green
        ),
        ChoreCategory(
          id: 'personal',
          name: 'Personal Care',
          icon: Icons.face_rounded,
          color: const Color(0xFFFFB74D), // orange
        ),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
        'color': color.toARGB32(),
      };

  factory ChoreCategory.fromJson(Map<String, dynamic> json) {
    return ChoreCategory(
      id: json['id'],
      name: json['name'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      color: json['color'] != null
          ? Color(json['color'] as int)
          : const Color(0xFF64B5F6),
    );
  }

  ChoreCategory copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
  }) {
    return ChoreCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

/// Represents a household chore with adaptive condition decay
class Chore {
  final String id;
  String name;
  String category; // Category name (editable)
  int intervalValue; // The number (e.g., 3)
  String intervalUnit; // 'days', 'weeks', 'months', 'years'
  double condition; // 0.0-1.0 (stored value)
  DateTime lastCompleted;
  DateTime createdAt;
  List<ChoreCompletion> completionHistory;
  String? notes;
  int energyLevel; // Energy impact (-5 to +5), 0 = neutral
  int? activeMonth; // 1-12, only for yearly chores: which month this chore is relevant

  Chore({
    String? id,
    required this.name,
    required this.category,
    int? intervalDays, // Legacy support
    int? intervalValue,
    this.intervalUnit = 'days',
    this.condition = 1.0,
    DateTime? lastCompleted,
    DateTime? createdAt,
    List<ChoreCompletion>? completionHistory,
    this.notes,
    this.energyLevel = 0,
    this.activeMonth,
  })  : id = id ?? const Uuid().v4(),
        intervalValue = intervalValue ?? intervalDays ?? 7,
        lastCompleted = lastCompleted ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        completionHistory = completionHistory ?? [];

  /// Calculate total interval in days (for decay calculation)
  int get intervalDays {
    switch (intervalUnit) {
      case 'weeks': return intervalValue * 7;
      case 'months': return intervalValue * 30;
      case 'years': return intervalValue * 365;
      default: return intervalValue;
    }
  }

  /// Human-readable interval text
  String get intervalDisplayText {
    final unit = intervalValue == 1
        ? intervalUnit.substring(0, intervalUnit.length - 1) // Remove 's'
        : intervalUnit;
    final base = 'Every $intervalValue $unit';
    if (intervalUnit == 'years' && activeMonth != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$base (in ${months[activeMonth! - 1]})';
    }
    return base;
  }

  /// Check if this chore is in its active month (for yearly chores)
  bool get isInActiveMonth {
    if (intervalUnit != 'years' || activeMonth == null) return true;
    return DateTime.now().month == activeMonth;
  }

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
        'intervalValue': intervalValue,
        'intervalUnit': intervalUnit,
        'intervalDays': intervalDays, // Keep for backward compat
        'condition': condition,
        'lastCompleted': lastCompleted.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'completionHistory':
            completionHistory.map((c) => c.toJson()).toList(),
        if (notes != null) 'notes': notes,
        'energyLevel': energyLevel,
        if (activeMonth != null) 'activeMonth': activeMonth,
      };

  factory Chore.fromJson(Map<String, dynamic> json) {
    return Chore(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      intervalValue: json['intervalValue'],
      intervalUnit: json['intervalUnit'] ?? 'days',
      // Fallback: if no intervalValue, use legacy intervalDays
      intervalDays: json['intervalValue'] == null ? json['intervalDays'] : null,
      condition: (json['condition'] as num).toDouble(),
      lastCompleted: DateTime.parse(json['lastCompleted']),
      createdAt: DateTime.parse(json['createdAt']),
      completionHistory: (json['completionHistory'] as List<dynamic>?)
              ?.map((c) => ChoreCompletion.fromJson(c))
              .toList() ??
          [],
      notes: json['notes'],
      energyLevel: json['energyLevel'] ?? 0,
      activeMonth: json['activeMonth'],
    );
  }

  Chore copyWith({
    String? id,
    String? name,
    String? category,
    int? intervalValue,
    String? intervalUnit,
    double? condition,
    DateTime? lastCompleted,
    DateTime? createdAt,
    List<ChoreCompletion>? completionHistory,
    String? notes,
    int? energyLevel,
    int? activeMonth,
    bool clearActiveMonth = false,
  }) {
    return Chore(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      condition: condition ?? this.condition,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      createdAt: createdAt ?? this.createdAt,
      completionHistory: completionHistory ?? this.completionHistory,
      notes: notes ?? this.notes,
      energyLevel: energyLevel ?? this.energyLevel,
      activeMonth: clearActiveMonth ? null : (activeMonth ?? this.activeMonth),
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
