import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tasks_data_models.dart';

/// Service responsible for calculating task priority scores and sorting tasks.
/// Pure logic - NO side effects, NO async operations (except for menstrual utils).
class TaskPriorityService {
  /// Get prioritized list of tasks
  List<Task> getPrioritizedTasks(
    List<Task> tasks,
    List<TaskCategory> categories,
    int maxTasks, {
    bool includeCompleted = false,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter tasks based on completion status
    final availableTasks = includeCompleted
        ? tasks
        : tasks.where((task) => !task.isCompleted).toList();

    // Pre-calculate priority scores for all tasks
    final taskScores = <Task, int>{};
    for (final task in availableTasks) {
      taskScores[task] = calculateTaskPriorityScore(task, now, today, categories);
    }

    // Sort by priority with enhanced logic
    availableTasks.sort((a, b) {
      // Use pre-calculated scores
      final aPriorityScore = taskScores[a] ?? 0;
      final bPriorityScore = taskScores[b] ?? 0;

      if (aPriorityScore != bPriorityScore) {
        return bPriorityScore.compareTo(aPriorityScore); // Higher score = higher priority
      }

      // If same priority score, use secondary sorting criteria

      // 1. For reminders within 30 minutes, earlier times get higher priority
      final aReminder = a.reminderTime;
      final bReminder = b.reminderTime;
      final aScheduledToday = a.scheduledDate != null && _isSameDay(a.scheduledDate!, today);
      final bScheduledToday = b.scheduledDate != null && _isSameDay(b.scheduledDate!, today);

      if (aReminder != null && bReminder != null) {
        final aDiff = aReminder.difference(now).inMinutes;
        final bDiff = bReminder.difference(now).inMinutes;
        final aWithin30 = aScheduledToday && aDiff >= 0 && aDiff <= 30;
        final bWithin30 = bScheduledToday && bDiff >= 0 && bDiff <= 30;

        // Both reminders within 30 min - earlier time wins
        if (aWithin30 && bWithin30) {
          return aReminder.compareTo(bReminder);
        }

        // Only one reminder within 30 min - that one wins
        if (aWithin30 && !bWithin30) return -1;
        if (!aWithin30 && bWithin30) return 1;
      }

      // 2. Important flag
      if (a.isImportant && !b.isImportant) return -1;
      if (!a.isImportant && b.isImportant) return 1;

      // 3. Category importance (based on order)
      final aCategoryOrder = _getCategoryImportance(a.categoryIds, categories);
      final bCategoryOrder = _getCategoryImportance(b.categoryIds, categories);
      if (aCategoryOrder != bCategoryOrder) {
        return aCategoryOrder.compareTo(bCategoryOrder);
      }

      // 4. Creation date (newer first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return availableTasks.take(maxTasks).toList();
  }

  /// Calculate priority score for a task
  /// This is a PURE function - no side effects, no async operations
  int calculateTaskPriorityScore(
    Task task,
    DateTime now,
    DateTime today,
    List<TaskCategory> categories,
  ) {
    int score = 0;

    // SPECIAL CASE: Skipped/postponed tasks without scheduledDate
    if (task.isPostponed && task.scheduledDate == null) {
      return 2; // Very low priority - visible but at bottom
    }

    // Determine the effective reminder time
    DateTime? effectiveReminderTime = task.reminderTime;

    // For recurring tasks SCHEDULED today, ensure we use today's reminder time
    if (task.recurrence?.reminderTime != null &&
        task.scheduledDate != null &&
        _isSameDay(task.scheduledDate!, today)) {
      final correctReminderForToday = DateTime(
        today.year,
        today.month,
        today.day,
        task.recurrence!.reminderTime!.hour,
        task.recurrence!.reminderTime!.minute,
      );

      if (effectiveReminderTime == null ||
          !_isSameDay(effectiveReminderTime, today)) {
        effectiveReminderTime = correctReminderForToday;
      }
    }

    // 1. HIGHEST PRIORITY: Tasks with reminder times
    if (effectiveReminderTime != null) {
      final reminderDiff = effectiveReminderTime.difference(now).inMinutes;
      final isReminderToday = _isReminderToday(effectiveReminderTime, now);
      final isScheduledToday = task.scheduledDate != null && _isSameDay(task.scheduledDate!, today);

      // Prioritize reminders if:
      // 1. Task is scheduled for today, OR
      // 2. Task has no scheduled date but reminder is today
      final shouldPrioritizeReminder = isScheduledToday ||
                                       (task.scheduledDate == null && isReminderToday);

      // Upcoming reminders
      if (shouldPrioritizeReminder && reminderDiff >= 0) {
        if (reminderDiff < 30) {
          // Less than 30 minutes - HIGH PRIORITY
          score += 1100;
        } else if (reminderDiff <= 120) {
          // 30 min to 2 hours - symbolic priority
          score += 15;
        }
        // Beyond 2 hours: score stays at 0
      }
      // Past reminders (overdue) - still show if missed
      else if (reminderDiff < 0) {
        // Overdue reminder (in the past) - always show these
        if (shouldPrioritizeReminder || task.scheduledDate == null) {
          final hoursPast = (-reminderDiff) / 60;
          if (hoursPast <= 1) {
            score += 1200;
          } else if (hoursPast <= 24) {
            score += 1000;
          } else {
            score += 800;
          }
        }
      }
    }

    // 2. HIGHEST PRIORITY: Overdue deadlines
    if (task.deadline != null && task.deadline!.isBefore(today)) {
      final daysPast = today.difference(
        DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)
      ).inDays;
      score += 900 - (daysPast * 10);
    }

    // 3. HIGH PRIORITY: Deadlines today
    else if (task.deadline != null && _isSameDay(task.deadline!, today)) {
      score += 800;
    }

    // 4. CONTEXT-AWARE PRIORITY: Tomorrow's deadlines
    else if (task.deadline != null) {
      final tomorrow = today.add(const Duration(days: 1));
      if (_isSameDay(task.deadline!, tomorrow)) {
        score += _getContextualTomorrowPriority(now);
      } else {
        final daysUntil = task.deadline!.difference(today).inDays;
        if (daysUntil <= 2 && daysUntil > 0) {
          score += 200 - (daysUntil * 50);
        }
      }
    }

    // 4b. RECURRING TASKS: Handle scheduled dates in the future
    else if (task.recurrence != null &&
             task.scheduledDate != null &&
             task.scheduledDate!.isAfter(today)) {
      final daysUntil = task.scheduledDate!.difference(today).inDays;

      if (daysUntil > 2) {
        return 1;
      } else if (daysUntil == 1) {
        score += 5;
      } else {
        score += 3;
      }
    }

    // 5. MEDIUM-HIGH PRIORITY: Recurring tasks due today
    if (task.recurrence != null && task.isDueToday()) {
      if (task.scheduledDate != null && task.scheduledDate!.isAfter(today)) {
        score += 5;
      } else {
        if (_isMenstrualCycleTask(task.recurrence!)) {
          final daysUntilTarget = _getDaysUntilMenstrualTarget(task.recurrence!);
          if (daysUntilTarget != null) {
            if (daysUntilTarget <= 1) {
              score += 700;
            } else if (daysUntilTarget <= 3) {
              score += 400;
            } else if (daysUntilTarget <= 7) {
              score += 100;
            }
          } else {
            score += 200;
          }
        } else {
          score += 700;
        }
      }
    }

    // 5b. OVERDUE SCHEDULED TASKS
    if (task.scheduledDate != null &&
        task.scheduledDate!.isBefore(today) &&
        task.recurrence == null) {
      final daysOverdue = today.difference(
        DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
      ).inDays;
      score += math.max(550, 595 - (daysOverdue * 5));
    }

    // 5c. SCHEDULED TODAY
    final isScheduledToday = task.scheduledDate != null &&
        _isSameDay(task.scheduledDate!, today);
    if (isScheduledToday) {
      int reminderMinutesAway = 0;
      if (effectiveReminderTime != null) {
        reminderMinutesAway = effectiveReminderTime.difference(now).inMinutes;
      }

      if (task.isPostponed && reminderMinutesAway > 60) {
        score += 10;
      } else if (reminderMinutesAway > 120) {
        score += 20;
      } else if (reminderMinutesAway > 60) {
        score += 50;
      } else {
        score += 600;
      }
    }

    // 6. LOW-MEDIUM PRIORITY: Important tasks
    // Don't boost priority for tasks explicitly scheduled for future dates
    final isExplicitlyScheduledFuture = task.scheduledDate != null &&
                                         task.scheduledDate!.isAfter(today) &&
                                         !task.isDueToday(); // Allow recurring tasks due today

    // Don't boost for tasks with reminders more than 30 minutes away
    bool hasDistantReminder = false;
    if (effectiveReminderTime != null) {
      final reminderDiff = effectiveReminderTime.difference(now).inMinutes;
      hasDistantReminder = reminderDiff >= 30;
    }

    if (task.isImportant && !isExplicitlyScheduledFuture && !hasDistantReminder) {
      if (isScheduledToday) {
        score += 100;
      } else {
        score += 50;
      }
    }

    // 7. CATEGORY PRIORITY
    // Don't boost priority for tasks explicitly scheduled for future dates or with distant reminders
    if (task.categoryIds.isNotEmpty && !isExplicitlyScheduledFuture && !hasDistantReminder) {
      final categoryImportance = _getCategoryImportance(task.categoryIds, categories);
      if (categoryImportance < 999) {
        int baseScore = math.max(10, 45 - (categoryImportance * 5));
        int categoryBonus = math.min(10, (task.categoryIds.length - 1) * 2);

        if (isScheduledToday) {
          baseScore = (baseScore * 1.5).round();
        }

        score += baseScore + categoryBonus;
      }
    }

    return score;
  }

  // Helper methods

  bool _isReminderToday(DateTime reminderTime, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(
      reminderTime.year,
      reminderTime.month,
      reminderTime.day
    );
    return reminderDate.isAtSameMomentAs(today);
  }

  int _getContextualTomorrowPriority(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 50;
    if (hour < 18) return 150;
    return 300;
  }

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

  int? _getDaysUntilMenstrualTarget(TaskRecurrence recurrence) {
    try {
      final now = DateTime.now();
      final nextDueDate = recurrence.getNextDueDate(now);

      if (nextDueDate != null) {
        final daysUntil = nextDueDate.difference(now).inDays;
        return daysUntil >= 0 ? daysUntil : 0;
      }

      return _estimateDaysToMenstrualTarget(recurrence.type);
    } catch (e) {
      return null;
    }
  }

  int? _estimateDaysToMenstrualTarget(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.menstrualStartDay:
        return 14;
      case RecurrenceType.menstrualPhase:
        return 12;
      case RecurrenceType.follicularPhase:
        return 8;
      case RecurrenceType.ovulationPhase:
      case RecurrenceType.ovulationPeakDay:
        return 21;
      case RecurrenceType.earlyLutealPhase:
        return 7;
      case RecurrenceType.lateLutealPhase:
        return 3;
      default:
        return null;
    }
  }

  int _getCategoryImportance(List<String> categoryIds, List<TaskCategory> categories) {
    if (categoryIds.isEmpty) return 999;

    int minOrder = 999;
    for (final categoryId in categoryIds) {
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => TaskCategory(
          id: '',
          name: '',
          color: const Color(0xFF666666),
          order: 999
        ),
      );
      if (category.order < minOrder) {
        minOrder = category.order;
      }
    }
    return minOrder;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
