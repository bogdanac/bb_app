import '../models/task_recurrence_model.dart';
import '../../MenstrualCycle/menstrual_cycle_constants.dart';

/// Presentation logic for formatting task recurrence patterns into human-readable text.
/// Contains only display/formatting methods, no business logic.
class RecurrenceFormatter {
  RecurrenceFormatter._(); // Private constructor to prevent instantiation

  /// Converts a recurrence pattern to human-readable display text
  static String getDisplayText(TaskRecurrenceModel recurrence) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
        return _formatDaily(recurrence);

      case RecurrenceType.weekly:
        return _formatWeekly(recurrence);

      case RecurrenceType.monthly:
        return _formatMonthly(recurrence);

      case RecurrenceType.yearly:
        return _formatYearly(recurrence);

      case RecurrenceType.menstrualPhase:
        return _formatPhase(
          MenstrualCycleConstants.menstrualPhaseTask,
          recurrence.phaseDay,
        );
      case RecurrenceType.follicularPhase:
        return _formatPhase(
          MenstrualCycleConstants.follicularPhaseTask,
          recurrence.phaseDay,
        );
      case RecurrenceType.ovulationPhase:
        return _formatPhase(
          MenstrualCycleConstants.ovulationPhaseTask,
          recurrence.phaseDay,
        );
      case RecurrenceType.earlyLutealPhase:
        return _formatPhase(
          MenstrualCycleConstants.earlyLutealPhaseTask,
          recurrence.phaseDay,
        );
      case RecurrenceType.lateLutealPhase:
        return _formatPhase(
          MenstrualCycleConstants.lateLutealPhaseTask,
          recurrence.phaseDay,
        );

      case RecurrenceType.menstrualStartDay:
        return MenstrualCycleConstants.menstrualStartDayTask;
      case RecurrenceType.ovulationPeakDay:
        return MenstrualCycleConstants.ovulationPeakDayTask;

      case RecurrenceType.custom:
        return _formatCustom(recurrence);
    }
  }

  static String _formatDaily(TaskRecurrenceModel recurrence) {
    return recurrence.interval == 1
        ? 'Daily'
        : 'Every ${recurrence.interval} days';
  }

  static String _formatWeekly(TaskRecurrenceModel recurrence) {
    if (recurrence.weekDays.isEmpty) {
      return recurrence.interval == 1
          ? 'Weekly'
          : 'Every ${recurrence.interval} weeks';
    }
    if (recurrence.weekDays.length == 7) return 'Daily';

    final dayNames = recurrence.weekDays.map((day) => _getDayName(day)).join(', ');
    return recurrence.interval == 1
        ? 'Weekly on $dayNames'
        : 'Every ${recurrence.interval} weeks on $dayNames';
  }

  static String _formatMonthly(TaskRecurrenceModel recurrence) {
    if (recurrence.isLastDayOfMonth) {
      return recurrence.interval == 1
          ? 'Monthly on last day'
          : 'Every ${recurrence.interval} months on last day';
    }
    return recurrence.interval == 1
        ? 'Monthly on day ${recurrence.dayOfMonth}'
        : 'Every ${recurrence.interval} months on day ${recurrence.dayOfMonth}';
  }

  static String _formatYearly(TaskRecurrenceModel recurrence) {
    if (recurrence.dayOfMonth != null) {
      const monthNames = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return 'Yearly on ${monthNames[recurrence.interval]} ${recurrence.dayOfMonth}';
    }
    return 'Yearly';
  }

  static String _formatPhase(String phaseLabel, int? phaseDay) {
    if (phaseDay != null) {
      return '$phaseLabel (Day $phaseDay)';
    }
    return phaseLabel;
  }

  static String _formatCustom(TaskRecurrenceModel recurrence) {
    if (recurrence.daysAfterPeriod != null) {
      return '${recurrence.daysAfterPeriod} days after period ends';
    }
    return 'Custom';
  }

  static String _getDayName(int weekday) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayNames[weekday - 1];
  }
}
