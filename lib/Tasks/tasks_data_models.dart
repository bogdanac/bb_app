// ENHANCED DATA MODELS
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';

class Task {
  final String id;
  String title;
  String description;
  List<String> categoryIds;
  DateTime? deadline;
  DateTime? scheduledDate; // For recurring tasks, this is when the task is scheduled for
  DateTime? reminderTime;
  bool isImportant;
  bool isPostponed; // True if user manually postponed/rescheduled this task
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
    this.scheduledDate,
    this.reminderTime,
    this.isImportant = false,
    this.isPostponed = false,
    this.recurrence,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Check if task is due today based on deadline, scheduledDate, recurrence, or reminder
  bool isDueToday() {
    final today = DateTime.now();

    // Priority 1: For recurring tasks, check both recurrence pattern AND scheduled date
    if (recurrence != null) {
      // First check if specifically scheduled for today (from postponing)
      if (scheduledDate != null && _isSameDay(scheduledDate!, today)) {
        return true;
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
  };

  static Task fromJson(Map<String, dynamic> json) => Task(
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

class TaskRecurrence {
  final List<RecurrenceType> types; // Support multiple recurrence types
  final int interval;
  final List<int> weekDays; // 1-7 for weekly (Monday = 1)
  final int? dayOfMonth; // 1-31 for monthly
  final bool isLastDayOfMonth;
  final DateTime? startDate; // When recurrence pattern should begin
  final DateTime? endDate;
  final int? phaseDay; // Optional specific day within a menstrual phase (1-N)
  final int? daysAfterPeriod; // Days after period ends for custom recurrence
  final TimeOfDay? reminderTime; // Optional reminder time for recurring tasks

  TaskRecurrence({
    List<RecurrenceType>? types,
    RecurrenceType? type, // Backward compatibility
    this.interval = 1,
    this.weekDays = const [],
    this.dayOfMonth,
    this.isLastDayOfMonth = false,
    this.startDate,
    this.endDate,
    this.phaseDay,
    this.daysAfterPeriod,
    this.reminderTime,
  }) : types = types ?? (type != null ? [type] : []);

  // Backward compatibility getter
  RecurrenceType get type => types.isNotEmpty ? types.first : RecurrenceType.daily;

  bool isDueOn(DateTime date, {DateTime? taskCreatedAt}) {
    // Check if date is before start date
    if (startDate != null && date.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) {
      return false;
    }
    
    if (endDate != null && date.isAfter(endDate!)) {
      return false;
    }

    if (types.isEmpty) return false;

    // Separate menstrual/cycle types from basic schedule types
    final menstrualTypes = [
      RecurrenceType.menstrualPhase, RecurrenceType.follicularPhase, RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase, RecurrenceType.lateLutealPhase
    ];
    
    final cycleTypes = types.where((type) => menstrualTypes.contains(type)).toList();
    final scheduleTypes = types.where((type) => !menstrualTypes.contains(type)).toList();

    // If both cycle and schedule types exist, task is due when BOTH conditions are met (AND logic)
    if (cycleTypes.isNotEmpty && scheduleTypes.isNotEmpty) {
      final cycleMatches = cycleTypes.any((type) => _isTypeDueOn(type, date, taskCreatedAt: taskCreatedAt));
      final scheduleMatches = scheduleTypes.any((type) => _isTypeDueOn(type, date, taskCreatedAt: taskCreatedAt));
      return cycleMatches && scheduleMatches;
    }
    
    // If only cycle types: task is due during ANY of the selected phases (OR logic for phases)
    // If only schedule types: task is due on ANY of the selected schedules (OR logic for schedules)
    return types.any((type) => _isTypeDueOn(type, date, taskCreatedAt: taskCreatedAt));
  }

  bool _isTypeDueOn(RecurrenceType type, DateTime date, {DateTime? taskCreatedAt}) {
    switch (type) {
      case RecurrenceType.daily:
        // For daily with interval > 1, check if it's actually due today
        if (interval > 1) {
          // Use startDate as primary reference, fallback to task creation date
          final referenceDate = startDate ?? taskCreatedAt ?? DateTime(2024, 1, 1);
          final daysSinceReference = date.difference(DateTime(referenceDate.year, referenceDate.month, referenceDate.day)).inDays;
          return daysSinceReference >= 0 && daysSinceReference % interval == 0;
        }
        return true; // Daily (every day)

      case RecurrenceType.weekly:
        if (!weekDays.contains(date.weekday)) {
          return false;
        }
        if (interval > 1) {
          final referenceDate = startDate ?? taskCreatedAt ?? DateTime(2024, 1, 1);
          final daysSinceReference = date.difference(DateTime(referenceDate.year, referenceDate.month, referenceDate.day)).inDays;
          final weeksSinceReference = daysSinceReference ~/ 7;
          return weeksSinceReference >= 0 && weeksSinceReference % interval == 0;
        }
        return true;

      case RecurrenceType.monthly:
        if (isLastDayOfMonth) {
          final nextMonth = DateTime(date.year, date.month + 1, 1);
          final lastDay = nextMonth.subtract(const Duration(days: 1));
          return date.day == lastDay.day;
        }
        return dayOfMonth != null && date.day == dayOfMonth;

      case RecurrenceType.yearly:
        return dayOfMonth != null && date.day == dayOfMonth && date.month == interval;

      // Simplified menstrual cycle phases - ONLY occurs during that specific phase
      case RecurrenceType.menstrualPhase:
        return _isMenstrualPhase(date, MenstrualCycleConstants.menstrualPhase);
      case RecurrenceType.follicularPhase:
        return _isMenstrualPhase(date, MenstrualCycleConstants.follicularPhase);
      case RecurrenceType.ovulationPhase:
        return _isMenstrualPhase(date, MenstrualCycleConstants.ovulationPhase);
      case RecurrenceType.earlyLutealPhase:
        return _isMenstrualPhase(date, MenstrualCycleConstants.earlyLutealPhase);
      case RecurrenceType.lateLutealPhase:
        return _isMenstrualPhase(date, MenstrualCycleConstants.lateLutealPhase);
      
      // Special specific day options
      case RecurrenceType.menstrualStartDay:
        return _isSpecificCycleDay(date, MenstrualCycleConstants.menstrualStartDayNumber);
      case RecurrenceType.ovulationPeakDay:
        return _isSpecificCycleDay(date, MenstrualCycleConstants.ovulationPeakDayNumber);
      
      case RecurrenceType.custom:
        // Custom recurrence logic (period-based intervals)
        if (daysAfterPeriod != null) {
          // Logic for tasks that should occur a specific number of days after period ends
          return _isDaysAfterPeriodEnd(date, daysAfterPeriod!);
        }
        return false;
    }
  }


  bool _isMenstrualPhase(DateTime date, String expectedPhase) {
    // For now, return true to allow menstrual phase recurrences to work
    // This is a simplified implementation - in practice, you'd want to check
    // actual cycle data from SharedPreferences
    try {
      // Get cycle data synchronously (this is a limitation - ideally async)
      // For MVP, we'll return true so the feature works
      // Note: phaseDay specific checking is handled in the async UI layer
      return _checkMenstrualPhaseSync(date, expectedPhase);
    } catch (e) {
      // If there's any error, default to false
      if (kDebugMode) {
        print('Error checking menstrual phase: $e');
      } // Add debug info
      return false;
    }
  }

  bool _checkMenstrualPhaseSync(DateTime date, String expectedPhase) {
    // Since we now handle menstrual phase checking properly in todo_screen.dart,
    // this sync version can just return true to avoid blocking regular task recurrence
    // The proper async phase checking happens in the UI layer
    return true;
  }

  bool _isSpecificCycleDay(DateTime date, int targetDay) {
    // For specific day recurrence (like day 1 or day 14)
    final referenceDate = DateTime(2024, 1, 1); // Assume period started here
    final daysSinceReference = date.difference(referenceDate).inDays;
    final cycleDay = (daysSinceReference % 30) + 1;
    return cycleDay == targetDay;
  }

  bool _isDaysAfterPeriodEnd(DateTime date, int daysAfter) {
    // For tasks that should occur X days after period ends (end of menstrual phase)
    final referenceDate = DateTime(2024, 1, 1); // Assume period started here
    final daysSinceReference = date.difference(referenceDate).inDays;
    final cycleDay = (daysSinceReference % 30) + 1;
    // Assuming menstrual phase ends on day 5, so days after period would be 6, 7, 8...
    final periodEndDay = 5;
    return cycleDay == periodEndDay + daysAfter;
  }

  DateTime? getNextDueDate(DateTime from) {
    if (endDate != null && from.isAfter(endDate!)) {
      return null;
    }

    switch (type) {
      case RecurrenceType.daily:
        return from.add(Duration(days: interval));

      case RecurrenceType.weekly:
        if (weekDays.isEmpty) {
          return from.add(Duration(days: 7 * interval));
        }
        
        // Find the next weekday from the list
        DateTime next = from.add(const Duration(days: 1));
        for (int i = 0; i < 7; i++) {
          if (weekDays.contains(next.weekday)) {
            return next;
          }
          next = next.add(const Duration(days: 1));
        }
        return null;

      case RecurrenceType.monthly:
        if (isLastDayOfMonth) {
          // Next month's last day
          final nextMonth = DateTime(from.year, from.month + interval, 1);
          final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 1).subtract(const Duration(days: 1));
          return lastDay;
        } else if (dayOfMonth != null) {
          // Next month, same day
          DateTime nextMonth = DateTime(from.year, from.month + interval, dayOfMonth!);
          
          // If the day doesn't exist in the target month (e.g., Feb 30), adjust to last day of month
          if (nextMonth.month != from.month + interval) {
            nextMonth = DateTime(from.year, from.month + interval + 1, 1).subtract(const Duration(days: 1));
          }
          
          return nextMonth;
        }
        return null;

      case RecurrenceType.yearly:
        if (dayOfMonth != null) {
          // For yearly recurrence, interval represents the month (1-12)
          // and we want next year with same month and day
          try {
            DateTime nextYear = DateTime(from.year + 1, interval, dayOfMonth!);
            return nextYear;
          } catch (e) {
            // Handle invalid dates (like Feb 29 on non-leap years)
            try {
              // Try last day of the month instead
              DateTime lastDayOfMonth = DateTime(from.year + 1, interval + 1, 1).subtract(const Duration(days: 1));
              return lastDayOfMonth;
            } catch (e2) {
              return null;
            }
          }
        }
        return null;

      // Simplified menstrual cycle phases - search for next occurrence of the phase/day
      case RecurrenceType.menstrualPhase:
      case RecurrenceType.follicularPhase:
      case RecurrenceType.ovulationPhase:
      case RecurrenceType.earlyLutealPhase:
      case RecurrenceType.lateLutealPhase:
      case RecurrenceType.menstrualStartDay:
      case RecurrenceType.ovulationPeakDay:
      case RecurrenceType.custom:
        // Search for the next occurrence of this custom pattern (up to 60 days ahead)
        DateTime next = from.add(const Duration(days: 1));
        for (int i = 0; i < 60; i++) {
          if (isDueOn(next)) {
            return next;
          }
          next = next.add(const Duration(days: 1));
        }
        return null;
    }
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

      case RecurrenceType.yearly:
        if (dayOfMonth != null) {
          final monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return 'Yearly on ${monthNames[interval]} $dayOfMonth';
        }
        return 'Yearly';

      // Simplified menstrual cycle phases
      case RecurrenceType.menstrualPhase:
        if (phaseDay != null) {
          return '${MenstrualCycleConstants.menstrualPhaseTask} (Day $phaseDay)';
        }
        return MenstrualCycleConstants.menstrualPhaseTask;
      case RecurrenceType.follicularPhase:
        if (phaseDay != null) {
          return '${MenstrualCycleConstants.follicularPhaseTask} (Day $phaseDay)';
        }
        return MenstrualCycleConstants.follicularPhaseTask;
      case RecurrenceType.ovulationPhase:
        if (phaseDay != null) {
          return '${MenstrualCycleConstants.ovulationPhaseTask} (Day $phaseDay)';
        }
        return MenstrualCycleConstants.ovulationPhaseTask;
      case RecurrenceType.earlyLutealPhase:
        if (phaseDay != null) {
          return '${MenstrualCycleConstants.earlyLutealPhaseTask} (Day $phaseDay)';
        }
        return MenstrualCycleConstants.earlyLutealPhaseTask;
      case RecurrenceType.lateLutealPhase:
        if (phaseDay != null) {
          return '${MenstrualCycleConstants.lateLutealPhaseTask} (Day $phaseDay)';
        }
        return MenstrualCycleConstants.lateLutealPhaseTask;
      
      // Special specific day options
      case RecurrenceType.menstrualStartDay:
        return MenstrualCycleConstants.menstrualStartDayTask;
      case RecurrenceType.ovulationPeakDay:
        return MenstrualCycleConstants.ovulationPeakDayTask;
      
      case RecurrenceType.custom:
        if (daysAfterPeriod != null) {
          return '$daysAfterPeriod days after period ends';
        }
        return 'Custom';
    }
  }

  String _getDayName(int weekday) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayNames[weekday - 1];
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

  static TaskRecurrence fromJson(Map<String, dynamic> json) {
    // Handle both new types array and legacy single type
    List<RecurrenceType> types;
    if (json['types'] != null) {
      types = (json['types'] as List).map((index) {
        // Migration: Handle old enum values that no longer exist
        // old menstrualStartDay = 10, ovulationPeakDay = 11 (assuming these were the indices)
        if (index == 10) { // old menstrualStartDay -> menstrual phase day 1
          return RecurrenceType.menstrualPhase;
        } else if (index == 11) { // old ovulationPeakDay -> ovulation phase day 3 (middle of phase)
          return RecurrenceType.ovulationPhase;
        } else if (index >= RecurrenceType.values.length) {
          return null; // Skip invalid indices
        }
        return RecurrenceType.values[index];
      }).where((type) => type != null).cast<RecurrenceType>().toList();
    } else if (json['type'] != null) {
      // Backward compatibility with single type
      final typeIndex = json['type'];
      if (typeIndex == 10) { // old menstrualStartDay
        types = [RecurrenceType.menstrualPhase];
      } else if (typeIndex == 11) { // old ovulationPeakDay
        types = [RecurrenceType.ovulationPhase];
      } else if (typeIndex >= RecurrenceType.values.length) {
        types = [RecurrenceType.menstrualPhase]; // Default fallback
      } else {
        types = [RecurrenceType.values[typeIndex]];
      }
    } else {
      types = [];
    }

    // Migration: Set phaseDay for migrated tasks
    int? phaseDay = json['phaseDay'];
    if (phaseDay == null) {
      if (json['type'] == 10) { // old menstrualStartDay
        phaseDay = 1; // Day 1 of menstrual phase
      } else if (json['type'] == 11) { // old ovulationPeakDay
        phaseDay = 3; // Day 3 of ovulation phase (middle)
      } else if (json['daysAfterPeriod'] != null) {
        // Convert old daysAfterPeriod to phaseDay in menstrual phase
        phaseDay = json['daysAfterPeriod'] + 5; // After period ends (day 5) + X days
      }
    }

    return TaskRecurrence(
      types: types,
      interval: json['interval'] ?? 1,
      weekDays: List<int>.from(json['weekDays'] ?? []),
      dayOfMonth: json['dayOfMonth'],
      isLastDayOfMonth: json['isLastDayOfMonth'] ?? false,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      phaseDay: phaseDay,
      daysAfterPeriod: json['daysAfterPeriod'], // Keep for backward compatibility during transition
      reminderTime: json['reminderTime'] != null 
          ? TimeOfDay(
              hour: json['reminderTime']['hour'], 
              minute: json['reminderTime']['minute']
            ) 
          : null,
    );
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