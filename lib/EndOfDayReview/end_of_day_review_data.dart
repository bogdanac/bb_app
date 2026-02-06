import 'package:flutter/material.dart';

/// Complete end of day review data containing summaries from all active modules
class EndOfDayReviewData {
  final DateTime date;
  final List<ModuleSummary> moduleSummaries;
  final DateTime generatedAt;

  const EndOfDayReviewData({
    required this.date,
    required this.moduleSummaries,
    required this.generatedAt,
  });

  bool get isEmpty => moduleSummaries.isEmpty;

  /// Get summary for a specific module key
  ModuleSummary? getSummary(String moduleKey) {
    try {
      return moduleSummaries.firstWhere((s) => s.moduleKey == moduleKey);
    } catch (_) {
      return null;
    }
  }
}

/// Summary data for a single module
class ModuleSummary {
  final String moduleKey;
  final String moduleName;
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;

  const ModuleSummary({
    required this.moduleKey,
    required this.moduleName,
    required this.icon,
    required this.color,
    required this.data,
  });

  /// Helper to safely get a value from data
  T? getValue<T>(String key) {
    final value = data[key];
    if (value is T) return value;
    return null;
  }

  /// Helper to get int value with default
  int getInt(String key, [int defaultValue = 0]) {
    final value = data[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  /// Helper to get bool value with default
  bool getBool(String key, [bool defaultValue = false]) {
    final value = data[key];
    if (value is bool) return value;
    return defaultValue;
  }

  /// Helper to get string value with default
  String getString(String key, [String defaultValue = '']) {
    final value = data[key];
    if (value is String) return value;
    return defaultValue;
  }

  /// Helper to get list value
  List<T> getList<T>(String key) {
    final value = data[key];
    if (value is List) {
      return value.whereType<T>().toList();
    }
    return [];
  }
}

// ============= Module-specific summary helpers =============

/// Helper class for Tasks summary data
class TasksSummaryHelper {
  final ModuleSummary summary;

  TasksSummaryHelper(this.summary);

  int get completedCount => summary.getInt('completedCount');
  int get pendingCount => summary.getInt('pendingCount');
  List<String> get completedTitles => summary.getList<String>('completedTitles');

  bool get hasActivity => completedCount > 0;
}

/// Helper class for Habits summary data
class HabitsSummaryHelper {
  final ModuleSummary summary;

  HabitsSummaryHelper(this.summary);

  int get completedCount => summary.getInt('completedCount');
  int get totalCount => summary.getInt('totalCount');
  int get percentage => summary.getInt('percentage');

  bool get hasActivity => totalCount > 0;
  bool get allCompleted => totalCount > 0 && completedCount >= totalCount;
}

/// Helper class for Energy summary data
class EnergySummaryHelper {
  final ModuleSummary summary;

  EnergySummaryHelper(this.summary);

  int get flowPoints => summary.getInt('flowPoints');
  int get flowGoal => summary.getInt('goal');
  bool get isGoalMet => summary.getBool('isGoalMet');
  int get currentBattery => summary.getInt('battery');
  int get percentage => summary.getInt('percentage');

  bool get hasActivity => flowPoints > 0;
}

/// Helper class for Timers/Activities summary data
class TimersSummaryHelper {
  final ModuleSummary summary;

  TimersSummaryHelper(this.summary);

  int get totalMinutes => summary.getInt('totalMinutes');
  int get activityCount => summary.getInt('activityCount');
  Map<String, int> get activityBreakdown {
    final value = summary.data['activityBreakdown'];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v is int ? v : 0));
    }
    return {};
  }

  bool get hasActivity => totalMinutes > 0;

  String get formattedTime {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Helper class for Fasting summary data
class FastingSummaryHelper {
  final ModuleSummary summary;

  FastingSummaryHelper(this.summary);

  bool get isCurrentlyFasting => summary.getBool('isCurrentlyFasting');
  String get currentFastType => summary.getString('currentFastType');
  int get elapsedMinutes => summary.getInt('elapsedMinutes');
  bool get completedFastToday => summary.getBool('completedFastToday');
  String get fastingStatus => summary.getString('status');

  bool get hasActivity => isCurrentlyFasting || completedFastToday;
}

/// Helper class for Menstrual Cycle summary data
class MenstrualSummaryHelper {
  final ModuleSummary summary;

  MenstrualSummaryHelper(this.summary);

  String get currentPhase => summary.getString('currentPhase');
  int get cycleDay => summary.getInt('cycleDay');
  int get daysUntilPeriod => summary.getInt('daysUntilPeriod');
  bool get isPeriodDay => summary.getBool('isPeriodDay');

  bool get hasData => currentPhase.isNotEmpty;
}

/// Helper class for Water summary data
class WaterSummaryHelper {
  final ModuleSummary summary;

  WaterSummaryHelper(this.summary);

  int get intake => summary.getInt('intake');
  int get goal => summary.getInt('goal');
  bool get goalMet => summary.getBool('goalMet');
  int get percentage => summary.getInt('percentage');

  bool get hasActivity => intake > 0;

  String get formattedIntake {
    if (intake >= 1000) {
      return '${(intake / 1000).toStringAsFixed(1)}L';
    }
    return '${intake}ml';
  }
}

/// Helper class for Food summary data
class FoodSummaryHelper {
  final ModuleSummary summary;

  FoodSummaryHelper(this.summary);

  int get healthyCount => summary.getInt('healthyCount');
  int get processedCount => summary.getInt('processedCount');
  int get totalCount => healthyCount + processedCount;
  int get healthyPercentage => summary.getInt('healthyPercentage');
  int get targetPercentage => summary.getInt('targetPercentage');
  bool get goalMet => summary.getBool('goalMet');

  bool get hasActivity => totalCount > 0;
}

/// Helper class for Routines summary data
class RoutinesSummaryHelper {
  final ModuleSummary summary;

  RoutinesSummaryHelper(this.summary);

  int get completedCount => summary.getInt('completedCount');
  int get totalCount => summary.getInt('totalCount');
  List<String> get completedNames => summary.getList<String>('completedNames');

  bool get hasActivity => completedCount > 0;
}

class ChoresSummaryHelper {
  final ModuleSummary summary;

  ChoresSummaryHelper(this.summary);

  int get totalChores => summary.getInt('totalChores');
  double get avgCondition => summary.data['avgCondition'] ?? 0.0;
  int get completedToday => summary.getInt('completedToday');
  int get overdueCount => summary.getInt('overdueCount');
  int get criticalCount => summary.getInt('criticalCount');

  bool get hasActivity => completedToday > 0;
}
