import 'package:flutter/material.dart';
import 'tasks_data_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_format_utils.dart';

class TaskCardUtils {
  // Text constants for task status labels
  static const String dueToday = 'today';
  static const String dueTomorrow = 'tomorrow';
  static const String important = 'important';
  static const String overdue = 'overdue';
  static const String overdueOneDay = 'overdue (1 day)';
  static const String overdueDays = 'overdue (%d days)';

  // Color constants for task chips
  static const Color dueTomorrowColor = AppColors.yellow;
  static const Color importantColor = AppColors.coral;
  static const Color overdueColor = AppColors.red;
  static const Color scheduledTodayColor = AppColors.successGreen;
  static const Color reminderColor = AppColors.waterBlue;
  static const Color recurringColor = AppColors.lightYellow;
  static const Color defaultColor = AppColors.greyText;

  // Common method to get deadline color based on days remaining
  static Color getDeadlineColor(DateTime deadline) {
    // All deadline chips should be red for visibility and urgency
    return AppColors.red;
  }

  // Common method to get reminder color based on time remaining
  static Color getReminderColor(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now).inMinutes;

    if (difference < -30) return AppColors.greyText; // Past
    if (difference <= 0) return Colors.red; // Now or just passed
    if (difference <= 60) return Colors.orange; // Within an hour
    return Colors.blue; // Future
  }

  // Common method to get short recurrence text
  static String getShortRecurrenceText(TaskRecurrence recurrence) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
        return recurrence.interval == 1 ? 'Daily' : '${recurrence.interval}d';
      case RecurrenceType.weekly:
        String baseText = recurrence.interval == 1 ? 'Weekly' : '${recurrence.interval}w';
        if (recurrence.weekDays.isNotEmpty) {
          final days = recurrence.weekDays.map((day) {
            switch (day) {
              case 1: return 'M';
              case 2: return 'T';
              case 3: return 'W';
              case 4: return 'Th';
              case 5: return 'F';
              case 6: return 'Sa';
              case 7: return 'Su';
              default: return '';
            }
          }).join('/');
          return '$baseText $days';
        }
        return baseText;
      case RecurrenceType.monthly:
        String baseText = recurrence.interval == 1 ? 'Monthly' : '${recurrence.interval}m';
        if (recurrence.dayOfMonth != null) {
          return '$baseText ${recurrence.dayOfMonth}${_getOrdinalSuffix(recurrence.dayOfMonth!)}';
        }
        return baseText;
      case RecurrenceType.yearly:
        return 'Yearly';
      case RecurrenceType.custom:
        return 'Custom';
      // Menstrual cycle phases
      case RecurrenceType.menstrualPhase:
        return recurrence.phaseDay != null ? 'Menstrual D${recurrence.phaseDay}' : 'Menstrual';
      case RecurrenceType.follicularPhase:
        return recurrence.phaseDay != null ? 'Follicular D${recurrence.phaseDay}' : 'Follicular';
      case RecurrenceType.ovulationPhase:
        return recurrence.phaseDay != null ? 'Ovulation D${recurrence.phaseDay}' : 'Ovulation';
      case RecurrenceType.earlyLutealPhase:
        return recurrence.phaseDay != null ? 'Early Luteal D${recurrence.phaseDay}' : 'Early Luteal';
      case RecurrenceType.lateLutealPhase:
        return recurrence.phaseDay != null ? 'Late Luteal D${recurrence.phaseDay}' : 'Late Luteal';
      case RecurrenceType.menstrualStartDay:
        return 'Menstrual D1';
      case RecurrenceType.ovulationPeakDay:
        return 'Ovulation D14';
    }
  }

  static String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // Check if a recurrence type is menstrual-related
  static bool isMenstrualType(RecurrenceType type) {
    return type == RecurrenceType.menstrualPhase ||
        type == RecurrenceType.follicularPhase ||
        type == RecurrenceType.ovulationPhase ||
        type == RecurrenceType.earlyLutealPhase ||
        type == RecurrenceType.lateLutealPhase ||
        type == RecurrenceType.menstrualStartDay ||
        type == RecurrenceType.ovulationPeakDay;
  }

  // Get non-menstrual types from a recurrence
  static List<RecurrenceType> getNonMenstrualTypes(TaskRecurrence recurrence) {
    return recurrence.types.where((type) => !isMenstrualType(type)).toList();
  }

  // Get menstrual types from a recurrence
  static List<RecurrenceType> getMenstrualTypes(TaskRecurrence recurrence) {
    return recurrence.types.where((type) => isMenstrualType(type)).toList();
  }

  // Common method to build info chip with icon
  static Widget buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Common method to build category chip without icon
  static Widget buildCategoryChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }


  // Get task priority reason based on urgency and context
  static String getTaskPriorityReason(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if task is daily recurring with interval 1 (every single day)
    final bool isDailyInterval1 = task.recurrence?.type == RecurrenceType.daily && task.recurrence?.interval == 1;

    // Check deadline today
    if (task.deadline != null &&
        DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)
            .isAtSameMomentAs(today)) {
      return dueToday;
    }

    // Check overdue deadlines (skip for daily interval=1 tasks)
    if (!isDailyInterval1 && task.deadline != null &&
        task.deadline!.isBefore(today)) {
      final daysPast = today.difference(DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)).inDays;
      if (daysPast == 1) {
        return overdueOneDay;
      } else if (daysPast <= 7) {
        return overdueDays.replaceAll('%d', daysPast.toString());
      } else {
        return overdue;
      }
    }

    // Check deadline tomorrow (for non-recurring tasks)
    final tomorrow = today.add(const Duration(days: 1));
    if (task.deadline != null && task.recurrence == null &&
        DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)
            .isAtSameMomentAs(tomorrow)) {
      return dueTomorrow;
    }

    // Check if task is scheduled for today
    final bool isScheduledToday = task.scheduledDate != null &&
        DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
            .isAtSameMomentAs(today);

    if (isScheduledToday) {
      // Check for upcoming reminder (within 30 minutes only) - only for tasks scheduled today
      DateTime? reminderDateTime = task.reminderTime;
      if (reminderDateTime == null && task.recurrence?.reminderTime != null) {
        // Convert TimeOfDay to DateTime for today
        final now = DateTime.now();
        final timeOfDay = task.recurrence!.reminderTime!;
        reminderDateTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
      }

      if (reminderDateTime != null) {
        final now = DateTime.now();
        final diff = reminderDateTime.difference(now);

        // Only show reminder priority if within 30 minutes
        if (diff.inMinutes >= 0 && diff.inMinutes <= 30) {
          if (diff.inMinutes == 0) {
            return 'Reminder now';
          }
          return 'Reminder in ${diff.inMinutes}m';
        }
      }

      return 'Scheduled today';
    }

    // Check scheduled date tomorrow
    // Only show this for recurring tasks or postponed tasks - simple scheduled tasks show chip instead
    if (task.scheduledDate != null &&
        (task.recurrence != null || task.isPostponed) &&
        DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
            .isAtSameMomentAs(tomorrow)) {
      return dueTomorrow;
    }
    return '';
  }

  // Get priority color based on the priority reason
  static Color getPriorityColor(String reason) {
    if (reason.contains('Reminder now') || (reason.contains('Reminder in') && reason.endsWith('m'))) {
      if (reason == 'Reminder now') {
        return overdueColor; // Red - immediate
      }
      final minutes = int.tryParse(reason.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      if (minutes <= 15) {
        return AppColors.coral; // Orange - very close
      }
      return AppColors.yellow; // Yellow - upcoming
    }
    
    switch (reason) {
      case dueToday:
        return overdueColor; // Red for deadline today (urgent)
      case 'Reminder now':
        return scheduledTodayColor;
      case 'Scheduled today':
        return scheduledTodayColor; // Green for scheduled today
      case 'Recurring today':
        return recurringColor;
      case dueTomorrow:
        return dueTomorrowColor;
      case important:
        return importantColor;
      default:
        if (reason.contains('overdue')) {
          return overdueColor;
        }
        if (reason.contains('Reminder')) {
          return reminderColor;
        }
        return defaultColor;
    }
  }

  // Get scheduled date text for display
  static String? getScheduledDateText(Task task, String priorityReason) {
    if (task.scheduledDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final scheduledDay = DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day);

    // Don't show scheduled date if priority reason already covers it
    // This prevents duplicate chips (e.g., priority says "Scheduled today" AND scheduled chip says "Scheduled Today")
    if (priorityReason.contains('Scheduled today') && scheduledDay.isAtSameMomentAs(today)) {
      return null; // Priority already says "Scheduled today"
    }
    if (priorityReason == dueToday && scheduledDay.isAtSameMomentAs(today)) {
      return null; // Priority already says "today"
    }
    if (priorityReason == dueTomorrow && scheduledDay.isAtSameMomentAs(tomorrow)) {
      return null; // Priority already says "tomorrow"
    }
    if (priorityReason.contains('tomorrow') && scheduledDay.isAtSameMomentAs(tomorrow)) {
      return null; // Priority already mentions tomorrow
    }
    
    // For recurring tasks, don't show past scheduled dates
    if (task.recurrence != null && scheduledDay.isBefore(today)) {
      return null; // Don't show past dates for recurring tasks
    }
    
    // Format the scheduled date
    if (scheduledDay.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (scheduledDay.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow';
    } else {
      // Use format like "Nov 10" for other dates
      return DateFormatUtils.formatShort(task.scheduledDate!);
    }
  }
}