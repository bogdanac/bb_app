import 'package:shared_preferences/shared_preferences.dart';
import '../tasks_data_models.dart';

/// Service responsible for calculating recurrence dates.
/// Contains ONLY pure calculation functions - NO side effects.
class RecurrenceCalculator {
  /// Calculates just the DATE for the next occurrence of a recurring task.
  /// Pure calculation - does NOT create a Task object.
  /// Returns null if no valid next date can be calculated.
  Future<DateTime?> calculateNextOccurrenceDate(
    Task task,
    SharedPreferences prefs,
  ) async {
    if (task.recurrence == null) return null;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Handle menstrual cycle tasks
    if (_isMenstrualCycleTask(task.recurrence!)) {
      return await calculateMenstrualTaskScheduledDate(task, prefs);
    } else {
      // Handle regular recurring tasks (daily, weekly, monthly, yearly)
      return calculateRegularRecurringTaskDate(task, todayDate);
    }
  }

  /// Creates a Task with updated scheduledDate for the next occurrence.
  ///
  /// IMPORTANT: This function ALWAYS resets completion status because:
  /// - New tasks being scheduled for the first time are not completed anyway
  /// - Overdue tasks being moved to next occurrence should be reset
  Future<Task?> calculateNextScheduledDate(
    Task task,
    SharedPreferences prefs,
  ) async {
    if (task.recurrence == null) return null;

    // Calculate the next occurrence date
    final newScheduledDate = await calculateNextOccurrenceDate(task, prefs);

    if (newScheduledDate == null) return null;

    // Update reminderTime to match new scheduled date
    DateTime? updatedReminderTime;
    if (task.reminderTime != null) {
      updatedReminderTime = DateTime(
        newScheduledDate.year,
        newScheduledDate.month,
        newScheduledDate.day,
        task.reminderTime!.hour,
        task.reminderTime!.minute,
      );
    } else if (task.recurrence?.reminderTime != null) {
      updatedReminderTime = DateTime(
        newScheduledDate.year,
        newScheduledDate.month,
        newScheduledDate.day,
        task.recurrence!.reminderTime!.hour,
        task.recurrence!.reminderTime!.minute,
      );
    }

    return task.copyWith(
      scheduledDate: newScheduledDate,
      reminderTime: updatedReminderTime,
      isPostponed: false, // Auto-calculated, not user-postponed
      isCompleted: false, // ALWAYS reset completion for next occurrence
      clearCompletedAt: true, // ALWAYS clear completion timestamp
    );
  }

  /// Calculate scheduled date for menstrual cycle tasks
  /// IMPORTANT: Respects startDate and endDate constraints
  Future<DateTime?> calculateMenstrualTaskScheduledDate(
    Task task,
    SharedPreferences prefs,
  ) async {
    final recurrence = task.recurrence!;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if recurrence has ended - if endDate is in the past, return null
    if (recurrence.endDate != null) {
      final endDateOnly = DateTime(
        recurrence.endDate!.year,
        recurrence.endDate!.month,
        recurrence.endDate!.day,
      );
      if (endDateOnly.isBefore(todayDate)) {
        return null;
      }
    }

    // Check if recurrence has a future startDate
    if (recurrence.startDate != null) {
      final startDateOnly = DateTime(
        recurrence.startDate!.year,
        recurrence.startDate!.month,
        recurrence.startDate!.day,
      );
      if (startDateOnly.isAfter(todayDate)) {
        // Start date is in the future - check it doesn't exceed endDate
        if (recurrence.endDate != null && startDateOnly.isAfter(recurrence.endDate!)) {
          return null;
        }
        return startDateOnly;
      }
    }

    final lastStartStr = prefs.getString('last_period_start');
    if (lastStartStr == null) return null;

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;

    // Calculate phase start dates for current cycle
    final phaseStartDates = calculatePhaseStartDates(
      lastPeriodStart,
      averageCycleLength
    );

    for (final recurrenceType in recurrence.types) {
      DateTime? phaseStart;

      switch (recurrenceType) {
        case RecurrenceType.menstrualPhase:
          phaseStart = phaseStartDates['menstrual'];
          break;
        case RecurrenceType.follicularPhase:
          phaseStart = phaseStartDates['follicular'];
          break;
        case RecurrenceType.ovulationPhase:
          phaseStart = phaseStartDates['ovulation'];
          break;
        case RecurrenceType.earlyLutealPhase:
          phaseStart = phaseStartDates['earlyLuteal'];
          break;
        case RecurrenceType.lateLutealPhase:
          phaseStart = phaseStartDates['lateLuteal'];
          break;
        default:
          continue;
      }

      if (phaseStart != null && recurrence.phaseDay != null) {
        final dayInPhase = recurrence.phaseDay!;
        final result = phaseStart.add(Duration(days: dayInPhase - 1));

        // Check if result exceeds endDate
        if (recurrence.endDate != null && result.isAfter(recurrence.endDate!)) {
          return null;
        }
        return result;
      }
    }

    return null;
  }

  /// Calculate scheduled date for regular recurring tasks - OPTIMIZED
  /// IMPORTANT: For daily tasks with reminder time after current time, can return today
  /// IMPORTANT: Respects startDate - won't schedule before it
  DateTime? calculateRegularRecurringTaskDate(Task task, DateTime todayDate) {
    final recurrence = task.recurrence!;

    // Check if recurrence has ended - if endDate is in the past, return null
    if (recurrence.endDate != null) {
      final endDateOnly = DateTime(
        recurrence.endDate!.year,
        recurrence.endDate!.month,
        recurrence.endDate!.day,
      );
      if (endDateOnly.isBefore(todayDate)) {
        // End date has passed, no more occurrences
        return null;
      }
    }

    // Check if recurrence has a future startDate - if so, return startDate
    if (recurrence.startDate != null) {
      final startDateOnly = DateTime(
        recurrence.startDate!.year,
        recurrence.startDate!.month,
        recurrence.startDate!.day,
      );
      if (startDateOnly.isAfter(todayDate)) {
        // Start date is in the future, schedule for start date
        // But also check it doesn't exceed endDate
        if (recurrence.endDate != null && startDateOnly.isAfter(recurrence.endDate!)) {
          return null;
        }
        return startDateOnly;
      }
    }

    // Determine the base date to calculate from
    // If task has scheduledDate in the past, use that as base; otherwise use today
    final baseDate = (task.scheduledDate != null && task.scheduledDate!.isBefore(todayDate))
        ? DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
        : todayDate;

    // Helper to check if result exceeds endDate
    DateTime? checkEndDate(DateTime? result) {
      if (result == null) return null;
      if (recurrence.endDate != null && result.isAfter(recurrence.endDate!)) {
        return null; // Result exceeds end date
      }
      return result;
    }

    // For daily tasks, check if reminder time is later today
    if (recurrence.types.contains(RecurrenceType.daily)) {
      final interval = recurrence.interval;
      final now = DateTime.now();

      // Check if task has a reminder time set for later today
      if ((task.reminderTime != null || recurrence.reminderTime != null) &&
          (task.scheduledDate == null || !task.scheduledDate!.isBefore(todayDate))) {

        int reminderHour;
        int reminderMinute;

        if (task.reminderTime != null) {
          // task.reminderTime is a DateTime
          reminderHour = task.reminderTime!.hour;
          reminderMinute = task.reminderTime!.minute;
        } else {
          // recurrence.reminderTime is a TimeOfDay
          reminderHour = recurrence.reminderTime!.hour;
          reminderMinute = recurrence.reminderTime!.minute;
        }

        // Create a datetime for the reminder time today
        final reminderTimeToday = DateTime(
          todayDate.year,
          todayDate.month,
          todayDate.day,
          reminderHour,
          reminderMinute,
        );

        // If reminder time hasn't passed yet today, schedule for today
        if (reminderTimeToday.isAfter(now)) {
          return checkEndDate(todayDate);
        }
      }

      if (task.scheduledDate == null) {
        // Task has no scheduled date yet - schedule for today so it shows "Scheduled today" chip
        return checkEndDate(todayDate);
      }
      if (!task.scheduledDate!.isBefore(todayDate)) {
        // Task is not overdue (scheduled today or future), return next interval from today
        return checkEndDate(todayDate.add(Duration(days: interval)));
      }
      // Task is overdue - calculate how many intervals have passed and add one more
      final daysSinceScheduled = todayDate.difference(baseDate).inDays;
      final intervalsToSkip = (daysSinceScheduled / interval).ceil() + 1;
      return checkEndDate(baseDate.add(Duration(days: intervalsToSkip * interval)));
    } else if (recurrence.types.contains(RecurrenceType.weekly)) {
      final daysToCheck = 7 * recurrence.interval;
      // Start from i=0 to check today first - a task created on its target day
      // (e.g., Sunday task created on Sunday) should appear today, not next week
      for (int i = 0; i <= daysToCheck; i++) {
        final checkDate = todayDate.add(Duration(days: i));
        if (recurrence.isDueOn(checkDate, taskCreatedAt: task.createdAt)) {
          return checkEndDate(checkDate);
        }
      }
    } else if (recurrence.types.contains(RecurrenceType.monthly)) {
      // Handle last day of month recurrence
      if (recurrence.isLastDayOfMonth) {
        var nextMonth = todayDate.month + recurrence.interval;
        var nextYear = todayDate.year;

        while (nextMonth > 12) {
          nextMonth -= 12;
          nextYear++;
        }

        // Get the last day of the next month
        final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        return checkEndDate(DateTime(nextYear, nextMonth, lastDayOfNextMonth));
      }

      // Handle specific day of month
      final targetDay = recurrence.dayOfMonth ?? task.createdAt.day;
      var nextMonth = todayDate.month;
      var nextYear = todayDate.year;

      // Use > instead of >= so that if today IS the target day, we return today
      // (e.g., monthly task on the 15th created on the 15th should appear today)
      if (todayDate.day > targetDay) {
        nextMonth += recurrence.interval; // Use interval for number of months
        while (nextMonth > 12) {
          nextMonth -= 12;
          nextYear++;
        }
      }

      final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;
      return checkEndDate(DateTime(nextYear, nextMonth, actualDay));
    } else if (recurrence.types.contains(RecurrenceType.yearly)) {
      final targetMonth = recurrence.interval;
      final targetDay = recurrence.dayOfMonth ?? task.createdAt.day;
      var nextYear = todayDate.year;

      final targetDate = DateTime(nextYear, targetMonth, targetDay);
      // Only skip to next year if today is AFTER the target date
      // If today IS the target date, return today (e.g., yearly March 15 task created on March 15)
      if (todayDate.isAfter(targetDate)) {
        nextYear++;
      }

      return checkEndDate(DateTime(nextYear, targetMonth, targetDay));
    } else {
      // For custom recurrence, limit to 30 days
      for (int i = 1; i <= 30; i++) {
        final checkDate = todayDate.add(Duration(days: i));
        if (recurrence.isDueOn(checkDate, taskCreatedAt: task.createdAt)) {
          return checkEndDate(checkDate);
        }
      }
    }

    return null;
  }

  /// Calculate phase start dates (reused from cycle_tracking_screen.dart logic)
  Map<String, DateTime> calculatePhaseStartDates(
    DateTime lastPeriodStart,
    int averageCycleLength,
  ) {
    final menstrualStart = lastPeriodStart;
    final follicularStart = menstrualStart.add(const Duration(days: 5));
    final ovulationStart = menstrualStart.add(
      Duration(days: averageCycleLength ~/ 2 - 1)
    );
    final earlyLutealStart = ovulationStart.add(const Duration(days: 3));
    final lateLutealStart = menstrualStart.add(
      Duration(days: (averageCycleLength * 0.75).round())
    );

    return {
      'menstrual': menstrualStart,
      'follicular': follicularStart,
      'ovulation': ovulationStart,
      'earlyLuteal': earlyLutealStart,
      'lateLuteal': lateLutealStart,
    };
  }

  /// Calculate menstrual task date from cached phase data
  DateTime? calculateMenstrualDateFromCache(
    Task task,
    Map<String, DateTime> phaseStartDates,
  ) {
    final recurrence = task.recurrence!;

    for (final recurrenceType in recurrence.types) {
      DateTime? phaseStart;

      switch (recurrenceType) {
        case RecurrenceType.menstrualPhase:
          phaseStart = phaseStartDates['menstrual'];
          break;
        case RecurrenceType.follicularPhase:
          phaseStart = phaseStartDates['follicular'];
          break;
        case RecurrenceType.ovulationPhase:
          phaseStart = phaseStartDates['ovulation'];
          break;
        case RecurrenceType.earlyLutealPhase:
          phaseStart = phaseStartDates['earlyLuteal'];
          break;
        case RecurrenceType.lateLutealPhase:
          phaseStart = phaseStartDates['lateLuteal'];
          break;
        default:
          continue;
      }

      if (phaseStart != null && recurrence.phaseDay != null) {
        final dayInPhase = recurrence.phaseDay!;
        return phaseStart.add(Duration(days: dayInPhase - 1));
      }
    }

    return null;
  }

  // Helper methods

  bool _isMenstrualCycleTask(TaskRecurrence recurrence) {
    return [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase,
      RecurrenceType.menstrualStartDay,
      RecurrenceType.ovulationPeakDay,
    ].contains(recurrence.type) ||
    (recurrence.type == RecurrenceType.custom &&
     (recurrence.interval <= -100 || recurrence.interval == -1));
  }
}
