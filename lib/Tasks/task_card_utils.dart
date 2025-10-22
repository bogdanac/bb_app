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
        return recurrence.interval == 1 ? 'Weekly' : '${recurrence.interval}w';
      case RecurrenceType.monthly:
        return recurrence.interval == 1 ? 'Monthly' : '${recurrence.interval}m';
      case RecurrenceType.yearly:
        return recurrence.interval == 1 ? 'Yearly' : '${recurrence.interval}y';
      case RecurrenceType.custom:
        return 'Custom';
      // Menstrual cycle phases
      case RecurrenceType.menstrualPhase:
        return 'Menstrual';
      case RecurrenceType.follicularPhase:
        return 'Follicular';
      case RecurrenceType.ovulationPhase:
        return 'Ovulation';
      case RecurrenceType.earlyLutealPhase:
        return 'Early Luteal';
      case RecurrenceType.lateLutealPhase:
        return 'Late Luteal';
      case RecurrenceType.menstrualStartDay:
        return 'Menstrual Day 1';
      case RecurrenceType.ovulationPeakDay:
        return 'Ovulation Day 14';
    }
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

    // Check reminder time - highest priority display
    if (task.reminderTime != null) {
      final reminderDiff = task.reminderTime!.difference(now).inMinutes;
      if (reminderDiff <= 15 && reminderDiff >= -15) {
        if (reminderDiff <= 0) {
          return 'Reminder now';
        } else {
          return 'Reminder in ${reminderDiff}m';
        }
      } else if (reminderDiff <= 60 && reminderDiff >= -30) {
        if (reminderDiff <= 0) {
          return 'Reminder ${(-reminderDiff)}m ago';
        } else {
          return 'Reminder in ${reminderDiff}m';
        }
      } else if (reminderDiff <= 120 && reminderDiff >= -60) {
        if (reminderDiff <= 0) {
          return 'Reminder past';
        } else {
          return 'Reminder in ${(reminderDiff / 60).round()}h';
        }
      }
    }

    // Check deadline today
    if (task.deadline != null &&
        DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)
            .isAtSameMomentAs(today)) {
      return dueToday;
    }

    // Check overdue deadlines
    if (task.deadline != null && 
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

    // Check if task is scheduled for today (for recurring tasks)
    if (task.scheduledDate != null &&
        DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
            .isAtSameMomentAs(today)) {
      return 'Scheduled today';
    }

    // Check scheduled date tomorrow (for recurring tasks)
    if (task.scheduledDate != null && task.recurrence != null &&
        DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
            .isAtSameMomentAs(tomorrow)) {
      return dueTomorrow;
    }
    return '';
  }

  // Get priority color based on the priority reason
  static Color getPriorityColor(String reason) {
    if (reason.contains('Reminder now') || reason.contains('Reminder in') && reason.endsWith('m')) {
      final minutes = int.tryParse(reason.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      if (minutes <= 15) {
        return scheduledTodayColor; // Urgent - very close reminder
      } else if (minutes <= 60) {
        return AppColors.coral; // High priority - close reminder
      }
      return reminderColor; // Medium priority reminder
    }
    
    switch (reason) {
      case dueToday:
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
    if (priorityReason == dueToday && scheduledDay.isAtSameMomentAs(today)) {
      return null; // Priority already says "today"
    }
    if (priorityReason == dueTomorrow && scheduledDay.isAtSameMomentAs(tomorrow)) {
      return null; // Priority already says "tomorrow"
    }
    if (priorityReason.contains('today') && scheduledDay.isAtSameMomentAs(today)) {
      return null; // Priority already mentions today
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