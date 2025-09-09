import 'package:flutter/material.dart';
import 'tasks_data_models.dart';

class TaskCardUtils {
  // Common method to get deadline color based on days remaining
  static Color getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    final difference = deadlineDay.difference(today).inDays;

    if (difference < 0) return Colors.red;
    if (difference == 0) return Colors.orange;
    if (difference == 1) return Colors.amber;
    return Colors.blue;
  }

  // Common method to get reminder color based on time remaining
  static Color getReminderColor(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now).inMinutes;

    if (difference < -30) return Colors.grey; // Past
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}