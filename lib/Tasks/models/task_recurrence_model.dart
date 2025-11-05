import 'package:flutter/material.dart';

/// Pure data model for task recurrence patterns.
/// Contains only data fields, serialization, and immutability logic.
/// No business logic or presentation logic.
class TaskRecurrenceModel {
  final List<RecurrenceType> types;
  final int interval;
  final List<int> weekDays; // 1-7 for weekly (Monday = 1)
  final int? dayOfMonth; // 1-31 for monthly
  final bool isLastDayOfMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? phaseDay; // Optional specific day within a menstrual phase (1-N)
  final int? daysAfterPeriod; // Days after period ends for custom recurrence
  final TimeOfDay? reminderTime;

  const TaskRecurrenceModel({
    required this.types,
    this.interval = 1,
    this.weekDays = const [],
    this.dayOfMonth,
    this.isLastDayOfMonth = false,
    this.startDate,
    this.endDate,
    this.phaseDay,
    this.daysAfterPeriod,
    this.reminderTime,
  });

  /// Backward compatibility getter
  RecurrenceType get type => types.isNotEmpty ? types.first : RecurrenceType.daily;

  /// Create a copy with modified fields
  TaskRecurrenceModel copyWith({
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
    return TaskRecurrenceModel(
      types: types ?? this.types,
      interval: interval ?? this.interval,
      weekDays: weekDays ?? this.weekDays,
      dayOfMonth: clearDayOfMonth ? null : (dayOfMonth ?? this.dayOfMonth),
      isLastDayOfMonth: isLastDayOfMonth ?? this.isLastDayOfMonth,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      phaseDay: clearPhaseDay ? null : (phaseDay ?? this.phaseDay),
      daysAfterPeriod: clearDaysAfterPeriod ? null : (daysAfterPeriod ?? this.daysAfterPeriod),
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
    );
  }

  Map<String, dynamic> toJson() => {
    'types': types.map((type) => type.index).toList(),
    // Keep 'type' for backward compatibility
    'type': types.isNotEmpty ? types.first.index : 0,
    'interval': interval,
    'weekDays': weekDays,
    'dayOfMonth': dayOfMonth,
    'isLastDayOfMonth': isLastDayOfMonth,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'phaseDay': phaseDay,
    'daysAfterPeriod': daysAfterPeriod,
    'reminderTime': reminderTime != null
        ? {'hour': reminderTime!.hour, 'minute': reminderTime!.minute}
        : null,
  };

  static TaskRecurrenceModel fromJson(Map<String, dynamic> json) {
    // Handle both new types array and legacy single type
    List<RecurrenceType> types = _parseTypes(json);

    // Simplified migration: Set phaseDay for specific old enum values
    int? phaseDay = json['phaseDay'];
    if (phaseDay == null && json['type'] != null) {
      final typeIndex = json['type'] as int;
      if (typeIndex == 10) {
        // old menstrualStartDay -> Day 1 of menstrual phase
        phaseDay = 1;
      } else if (typeIndex == 11) {
        // old ovulationPeakDay -> Day 3 of ovulation phase
        phaseDay = 3;
      }
    }

    return TaskRecurrenceModel(
      types: types,
      interval: json['interval'] ?? 1,
      weekDays: List<int>.from(json['weekDays'] ?? []),
      dayOfMonth: json['dayOfMonth'],
      isLastDayOfMonth: json['isLastDayOfMonth'] ?? false,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      phaseDay: phaseDay,
      daysAfterPeriod: json['daysAfterPeriod'],
      reminderTime: json['reminderTime'] != null
          ? TimeOfDay(
              hour: json['reminderTime']['hour'],
              minute: json['reminderTime']['minute']
            )
          : null,
    );
  }

  static List<RecurrenceType> _parseTypes(Map<String, dynamic> json) {
    if (json['types'] != null) {
      return (json['types'] as List)
          .map((index) => _migrateTypeIndex(index))
          .where((type) => type != null)
          .cast<RecurrenceType>()
          .toList();
    } else if (json['type'] != null) {
      // Backward compatibility with single type
      final type = _migrateTypeIndex(json['type']);
      return type != null ? [type] : [];
    }
    return [];
  }

  static RecurrenceType? _migrateTypeIndex(int index) {
    // Handle migration from old enum values
    if (index == 10) {
      // old menstrualStartDay -> menstrualPhase
      return RecurrenceType.menstrualPhase;
    } else if (index == 11) {
      // old ovulationPeakDay -> ovulationPhase
      return RecurrenceType.ovulationPhase;
    } else if (index >= RecurrenceType.values.length) {
      return null; // Skip invalid indices
    }
    return RecurrenceType.values[index];
  }
}

enum RecurrenceType {
  daily,
  weekly,
  monthly,
  yearly,
  // Simplified menstrual cycle phases (5 phases)
  menstrualPhase,
  follicularPhase,
  ovulationPhase,
  earlyLutealPhase,
  lateLutealPhase,
  // Special specific day options
  menstrualStartDay,
  ovulationPeakDay,
  // Custom option for period-based intervals
  custom,
}
