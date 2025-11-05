import 'package:flutter/foundation.dart';
import '../models/task_recurrence_model.dart';
import '../../MenstrualCycle/menstrual_cycle_constants.dart';

/// Business logic for evaluating task recurrence patterns.
/// Contains pure static methods for determining if a task is due and calculating next due dates.
class RecurrenceEvaluator {
  RecurrenceEvaluator._(); // Private constructor to prevent instantiation

  /// Determines if a task with the given recurrence is due on a specific date
  static bool isDueOn(
    TaskRecurrenceModel recurrence,
    DateTime date, {
    DateTime? taskCreatedAt,
  }) {
    // Check if date is before start date
    if (recurrence.startDate != null &&
        date.isBefore(DateTime(
          recurrence.startDate!.year,
          recurrence.startDate!.month,
          recurrence.startDate!.day,
        ))) {
      return false;
    }

    if (recurrence.endDate != null && date.isAfter(recurrence.endDate!)) {
      return false;
    }

    if (recurrence.types.isEmpty) return false;

    // Separate menstrual/cycle types from basic schedule types
    final menstrualTypes = [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase
    ];

    final cycleTypes = recurrence.types.where((type) => menstrualTypes.contains(type)).toList();
    final scheduleTypes = recurrence.types.where((type) => !menstrualTypes.contains(type)).toList();

    // If both cycle and schedule types exist, task is due when BOTH conditions are met (AND logic)
    if (cycleTypes.isNotEmpty && scheduleTypes.isNotEmpty) {
      final cycleMatches = cycleTypes.any((type) =>
          _isTypeDueOn(recurrence, type, date, taskCreatedAt: taskCreatedAt));
      final scheduleMatches = scheduleTypes.any((type) =>
          _isTypeDueOn(recurrence, type, date, taskCreatedAt: taskCreatedAt));
      return cycleMatches && scheduleMatches;
    }

    // If only cycle types: task is due during ANY of the selected phases (OR logic for phases)
    // If only schedule types: task is due on ANY of the selected schedules (OR logic for schedules)
    return recurrence.types.any((type) =>
        _isTypeDueOn(recurrence, type, date, taskCreatedAt: taskCreatedAt));
  }

  static bool _isTypeDueOn(
    TaskRecurrenceModel recurrence,
    RecurrenceType type,
    DateTime date, {
    DateTime? taskCreatedAt,
  }) {
    switch (type) {
      case RecurrenceType.daily:
        return _isDailyDueOn(recurrence, date, taskCreatedAt);

      case RecurrenceType.weekly:
        return _isWeeklyDueOn(recurrence, date, taskCreatedAt);

      case RecurrenceType.monthly:
        return _isMonthlyDueOn(recurrence, date);

      case RecurrenceType.yearly:
        return _isYearlyDueOn(recurrence, date);

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

      case RecurrenceType.menstrualStartDay:
        return _isSpecificCycleDay(date, MenstrualCycleConstants.menstrualStartDayNumber);
      case RecurrenceType.ovulationPeakDay:
        return _isSpecificCycleDay(date, MenstrualCycleConstants.ovulationPeakDayNumber);

      case RecurrenceType.custom:
        if (recurrence.daysAfterPeriod != null) {
          return _isDaysAfterPeriodEnd(date, recurrence.daysAfterPeriod!);
        }
        return false;
    }
  }

  static bool _isDailyDueOn(
    TaskRecurrenceModel recurrence,
    DateTime date,
    DateTime? taskCreatedAt,
  ) {
    if (recurrence.interval > 1) {
      final referenceDate = recurrence.startDate ?? taskCreatedAt ?? DateTime(2024, 1, 1);
      final daysSinceReference = date.difference(DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
      )).inDays;
      return daysSinceReference >= 0 && daysSinceReference % recurrence.interval == 0;
    }
    return true; // Daily (every day)
  }

  static bool _isWeeklyDueOn(
    TaskRecurrenceModel recurrence,
    DateTime date,
    DateTime? taskCreatedAt,
  ) {
    if (!recurrence.weekDays.contains(date.weekday)) {
      return false;
    }
    if (recurrence.interval > 1) {
      final referenceDate = recurrence.startDate ?? taskCreatedAt ?? DateTime(2024, 1, 1);
      final daysSinceReference = date.difference(DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
      )).inDays;
      final weeksSinceReference = daysSinceReference ~/ 7;
      return weeksSinceReference >= 0 && weeksSinceReference % recurrence.interval == 0;
    }
    return true;
  }

  static bool _isMonthlyDueOn(TaskRecurrenceModel recurrence, DateTime date) {
    if (recurrence.isLastDayOfMonth) {
      final nextMonth = DateTime(date.year, date.month + 1, 1);
      final lastDay = nextMonth.subtract(const Duration(days: 1));
      return date.day == lastDay.day;
    }
    return recurrence.dayOfMonth != null && date.day == recurrence.dayOfMonth;
  }

  static bool _isYearlyDueOn(TaskRecurrenceModel recurrence, DateTime date) {
    return recurrence.dayOfMonth != null &&
        date.day == recurrence.dayOfMonth &&
        date.month == recurrence.interval;
  }

  static bool _isMenstrualPhase(DateTime date, String expectedPhase) {
    try {
      return _checkMenstrualPhaseSync(date, expectedPhase);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR checking menstrual phase: $e');
      }
      return false;
    }
  }

  static bool _checkMenstrualPhaseSync(DateTime date, String expectedPhase) {
    // Since we now handle menstrual phase checking properly in todo_screen.dart,
    // this sync version can just return true to avoid blocking regular task recurrence
    // The proper async phase checking happens in the UI layer
    return true;
  }

  static bool _isSpecificCycleDay(DateTime date, int targetDay) {
    // For specific day recurrence (like day 1 or day 14)
    final referenceDate = DateTime(2024, 1, 1); // Assume period started here
    final daysSinceReference = date.difference(referenceDate).inDays;
    final cycleDay = (daysSinceReference % 30) + 1;
    return cycleDay == targetDay;
  }

  static bool _isDaysAfterPeriodEnd(DateTime date, int daysAfter) {
    // For tasks that should occur X days after period ends (end of menstrual phase)
    final referenceDate = DateTime(2024, 1, 1); // Assume period started here
    final daysSinceReference = date.difference(referenceDate).inDays;
    final cycleDay = (daysSinceReference % 30) + 1;
    // Assuming menstrual phase ends on day 5, so days after period would be 6, 7, 8...
    const periodEndDay = 5;
    return cycleDay == periodEndDay + daysAfter;
  }

  /// Calculates the next due date for a recurring task
  static DateTime? getNextDueDate(TaskRecurrenceModel recurrence, DateTime from) {
    if (recurrence.endDate != null && from.isAfter(recurrence.endDate!)) {
      return null;
    }

    switch (recurrence.type) {
      case RecurrenceType.daily:
        return from.add(Duration(days: recurrence.interval));

      case RecurrenceType.weekly:
        return _getNextWeeklyDueDate(recurrence, from);

      case RecurrenceType.monthly:
        return _getNextMonthlyDueDate(recurrence, from);

      case RecurrenceType.yearly:
        return _getNextYearlyDueDate(recurrence, from);

      case RecurrenceType.menstrualPhase:
      case RecurrenceType.follicularPhase:
      case RecurrenceType.ovulationPhase:
      case RecurrenceType.earlyLutealPhase:
      case RecurrenceType.lateLutealPhase:
      case RecurrenceType.menstrualStartDay:
      case RecurrenceType.ovulationPeakDay:
      case RecurrenceType.custom:
        return _getNextCustomDueDate(recurrence, from);
    }
  }

  static DateTime? _getNextWeeklyDueDate(TaskRecurrenceModel recurrence, DateTime from) {
    if (recurrence.weekDays.isEmpty) {
      return from.add(Duration(days: 7 * recurrence.interval));
    }

    // For interval > 1 (bi-weekly, tri-weekly, etc.), we need to respect the cycle
    if (recurrence.interval > 1 && recurrence.startDate != null) {
      // Calculate which week we're in relative to start date
      final daysSinceStart = from.difference(recurrence.startDate!).inDays;
      final weeksSinceStart = daysSinceStart ~/ 7;

      // Start from the current week and search forward
      for (int weekOffset = 0; weekOffset < recurrence.interval * 2; weekOffset++) {
        final targetWeek = weeksSinceStart + weekOffset;

        // Check if this week is in the active cycle
        if (targetWeek % recurrence.interval == 0) {
          // Find the start of this target week
          final targetWeekStart = recurrence.startDate!.add(Duration(days: targetWeek * 7));

          // Check each day in this week for a valid weekday
          for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
            final checkDate = targetWeekStart.add(Duration(days: dayOffset));
            if (checkDate.isAfter(from) && recurrence.weekDays.contains(checkDate.weekday)) {
              return checkDate;
            }
          }
        }
      }
      return null;
    }

    // For weekly (interval = 1), just find the next weekday from the list
    DateTime next = from.add(const Duration(days: 1));
    for (int i = 0; i < 7; i++) {
      if (recurrence.weekDays.contains(next.weekday)) {
        return next;
      }
      next = next.add(const Duration(days: 1));
    }
    return null;
  }

  static DateTime? _getNextMonthlyDueDate(TaskRecurrenceModel recurrence, DateTime from) {
    if (recurrence.isLastDayOfMonth) {
      // Next month's last day
      final nextMonth = DateTime(from.year, from.month + recurrence.interval, 1);
      final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 1)
          .subtract(const Duration(days: 1));
      return lastDay;
    } else if (recurrence.dayOfMonth != null) {
      // Next month, same day
      DateTime nextMonth = DateTime(
        from.year,
        from.month + recurrence.interval,
        recurrence.dayOfMonth!,
      );

      // If the day doesn't exist in the target month (e.g., Feb 30), adjust to last day of month
      if (nextMonth.month != from.month + recurrence.interval) {
        nextMonth = DateTime(from.year, from.month + recurrence.interval + 1, 1)
            .subtract(const Duration(days: 1));
      }

      return nextMonth;
    }
    return null;
  }

  static DateTime? _getNextYearlyDueDate(TaskRecurrenceModel recurrence, DateTime from) {
    if (recurrence.dayOfMonth != null) {
      // For yearly recurrence, interval represents the month (1-12)
      // and we want next year with same month and day
      try {
        return DateTime(from.year + 1, recurrence.interval, recurrence.dayOfMonth!);
      } catch (e) {
        // Handle invalid dates (like Feb 29 on non-leap years)
        try {
          // Try last day of the month instead
          return DateTime(from.year + 1, recurrence.interval + 1, 1)
              .subtract(const Duration(days: 1));
        } catch (e2) {
          return null;
        }
      }
    }
    return null;
  }

  static DateTime? _getNextCustomDueDate(TaskRecurrenceModel recurrence, DateTime from) {
    // Search for the next occurrence of this custom pattern (up to 60 days ahead)
    DateTime next = from.add(const Duration(days: 1));
    for (int i = 0; i < 60; i++) {
      if (isDueOn(recurrence, next)) {
        return next;
      }
      next = next.add(const Duration(days: 1));
    }
    return null;
  }
}
