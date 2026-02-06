import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tasks_data_models.dart';
import '../../MenstrualCycle/menstrual_cycle_constants.dart';

/// Service responsible for calculating task priority scores and sorting tasks.
/// Pure logic - NO side effects, NO async operations (except for menstrual utils).
class TaskPriorityService {
  /// Get prioritized list of tasks
  List<Task> getPrioritizedTasks(
    List<Task> tasks,
    List<TaskCategory> categories,
    int maxTasks, {
    bool includeCompleted = false,
    String? currentMenstrualPhase,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter tasks based on completion status
    final availableTasks = includeCompleted
        ? tasks
        : tasks.where((task) => !task.isCompleted).toList();

    // If showing only completed tasks, sort by completion date (newest first)
    // Don't use priority scoring for completed tasks view
    if (includeCompleted && availableTasks.every((t) => t.isCompleted)) {
      availableTasks.sort((a, b) {
        if (a.completedAt == null && b.completedAt == null) return 0;
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!); // Newest first
      });
      return availableTasks.take(maxTasks).toList();
    }

    // Pre-calculate priority scores for all tasks
    final taskScores = <Task, int>{};
    for (final task in availableTasks) {
      taskScores[task] = calculateTaskPriorityScore(
        task,
        now,
        today,
        categories,
        currentMenstrualPhase: currentMenstrualPhase,
      );
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

      // Check if both tasks are scheduled in the future
      final aScheduledFuture = a.scheduledDate != null && a.scheduledDate!.isAfter(today);
      final bScheduledFuture = b.scheduledDate != null && b.scheduledDate!.isAfter(today);

      // For future-scheduled tasks: sort by date FIRST to prevent intercalation
      // This ensures tasks in 2026, 2027, etc. are always in chronological order
      if (aScheduledFuture && bScheduledFuture) {
        final dateComparison = a.scheduledDate!.compareTo(b.scheduledDate!);
        if (dateComparison != 0) {
          return dateComparison;
        }
        // If same date, fall through to other criteria
      } else if (aScheduledFuture && !bScheduledFuture) {
        return 1; // Future tasks come after non-future tasks with same score
      } else if (!aScheduledFuture && bScheduledFuture) {
        return -1; // Non-future tasks come before future tasks with same score
      }

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

      // 4. Energy level (draining tasks first - negative energy = higher priority)
      // In the new system: -5 (most draining) should come before +5 (most charging)
      if (a.energyLevel != b.energyLevel) {
        return a.energyLevel.compareTo(b.energyLevel);
      }

      // 5. Scheduled date (earlier dates first) - for non-future tasks
      // This ensures tasks with same priority are ordered chronologically
      if (a.scheduledDate != null && b.scheduledDate != null) {
        final dateComparison = a.scheduledDate!.compareTo(b.scheduledDate!);
        if (dateComparison != 0) {
          return dateComparison;
        }
      } else if (a.scheduledDate != null) {
        return -1; // Tasks with scheduled dates come before unscheduled
      } else if (b.scheduledDate != null) {
        return 1; // Tasks with scheduled dates come before unscheduled
      }

      // 6. Creation date (newer first)
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
    List<TaskCategory> categories, {
    String? currentMenstrualPhase,
  }) {
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

    // Calculate hasDistantReminder early
    // hasDistantReminder = reminder exists AND is > 30 minutes away
    bool hasDistantReminder = false;
    int reminderMinutesAway = 0;
    if (effectiveReminderTime != null) {
      reminderMinutesAway = effectiveReminderTime.difference(now).inMinutes;
      hasDistantReminder = reminderMinutesAway > 30;
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
    // IMPORTANT: Use same scoring as non-recurring tasks to prevent intercalation
    else if (task.recurrence != null &&
             task.scheduledDate != null &&
             task.scheduledDate!.isAfter(today)) {
      final daysUntil = task.scheduledDate!.difference(today).inDays;

      // Use SAME scoring as non-recurring future tasks (lines 341-369)
      // to ensure tasks on the same day have similar scores
      if (daysUntil == 1) {
        score += 120;
      } else if (daysUntil == 2) {
        score += 115;
      } else if (daysUntil == 3) {
        score += 110;
      } else if (daysUntil == 4) {
        score += 105;
      } else if (daysUntil == 5) {
        score += 100;
      } else if (daysUntil == 6) {
        score += 95;
      } else if (daysUntil == 7) {
        score += 90;
      } else if (daysUntil <= 20) {
        score += math.max(10, 90 - ((daysUntil - 7) * 5));
      } else {
        score += math.max(1, 10 - (daysUntil - 20));
      }
    }

    // 5. MEDIUM-HIGH PRIORITY: Recurring tasks due today (not overdue)
    // IMPORTANT: Skip tasks explicitly scheduled in the future - they were handled in section 4b
    if (task.recurrence != null &&
        task.isDueToday() &&
        (task.scheduledDate == null || !task.scheduledDate!.isAfter(today))) {
      // Check if task is scheduled today (not overdue, not future)
      final isScheduledToday = task.scheduledDate == null ||
                                _isSameDay(task.scheduledDate!, today);

      if (isScheduledToday) {
        if (_isMenstrualCycleTask(task.recurrence!)) {
          // For menstrual tasks, check if current phase matches
          final phaseMatches = currentMenstrualPhase != null &&
              _taskMatchesPhase(task.recurrence!, currentMenstrualPhase);

          if (phaseMatches) {
            // Phase matches - high priority, but respect distant reminders
            if (hasDistantReminder) {
              score += 125;
            } else {
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
            }
          } else {
            // Phase doesn't match - low priority
            score += 125;
          }
        } else {
          // Non-menstrual recurring task
          if (hasDistantReminder) {
            score += 125;
          } else {
            score += 700;
          }
        }

        // For tasks without distant reminders, add bonuses
        if (!hasDistantReminder) {
          // BODY BATTERY BOOST: Energy-based priority for today's recurring tasks
          // Formula: 200 - (energyLevel + 5) × 18
          // Range: -5 gets +200, +5 gets +20
          score += 200 - ((task.energyLevel + 5) * 18);

          // Add category priority for recurring tasks due today
          score += _calculateCategoryScore(task.categoryIds, categories);

          // Add important bonus for recurring tasks due today
          if (task.isImportant) {
            score += 100;
          }
        }
      }
    }

    // 5a. MENSTRUAL TASKS: Phase matches but not "due today" (e.g., phase+weekly, phase not matching weekly day)
    // These tasks should still be visible when their phase matches, even if the weekly day doesn't
    if (task.recurrence != null &&
        _isMenstrualCycleTask(task.recurrence!) &&
        !task.isDueToday() && // Not caught by section 5
        !task.isPostponed &&
        currentMenstrualPhase != null &&
        _taskMatchesPhase(task.recurrence!, currentMenstrualPhase)) {
      // Phase matches but task is not "due" (e.g., weekly day doesn't match)
      // Give medium priority so it's visible but below tasks that are fully due
      if (hasDistantReminder) {
        score += 120;
      } else {
        score += 300; // Below fully-due tasks (700) but above unscheduled (400 minus bonuses)
      }
    }

    // 5b. OVERDUE RECURRING TASKS (within grace period)
    // High priority to ensure you don't forget about them
    // IMPORTANT: Include postponed tasks - they're still overdue!
    // SKIP for daily interval=1 tasks (they recur every single day)
    // SKIP for tasks with distant reminders (> 30 min away)
    final isDailyInterval1 = task.recurrence?.type == RecurrenceType.daily && task.recurrence?.interval == 1;

    if (task.recurrence != null &&
        task.scheduledDate != null &&
        task.scheduledDate!.isBefore(today) &&
        !isDailyInterval1 &&
        !hasDistantReminder) {
      final daysOverdue = today.difference(
        DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
      ).inDays;

      // CRITICAL FIX: Overdue tasks should be HIGH priority
      // Scoring: 1000+ range to ensure they're above most other tasks
      if (daysOverdue == 1) {
        score += 950;
      } else if (daysOverdue == 2) {
        score += 940;
      } else if (daysOverdue == 3) {
        score += 930;
      } else if (daysOverdue == 4) {
        score += 920;
      } else if (daysOverdue == 5) {
        score += 910;
      } else if (daysOverdue == 6) {
        score += 905;
      } else if (daysOverdue == 7) {
        score += 900;
      } else {
        // Grace period exceeded (> 7 days), still very visible
        score += 895;
      }
    }

    // 5c. OVERDUE NON-RECURRING SCHEDULED TASKS
    else if (task.scheduledDate != null &&
        task.scheduledDate!.isBefore(today) &&
        task.recurrence == null) {
      final daysOverdue = today.difference(
        DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day)
      ).inDays;
      // CRITICAL FIX: Non-recurring overdue tasks also need high priority
      // Slightly lower than recurring to differentiate, but still HIGH
      score += math.max(850, 880 - (daysOverdue * 5));
    }

    final isScheduledToday = task.scheduledDate != null &&
        _isSameDay(task.scheduledDate!, today);

    // Check if task is due today (for recurring tasks)
    final isRecurringDueToday = task.recurrence != null &&
                                 task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt);

    final isExplicitlyScheduledFuture = task.scheduledDate != null &&
                                         task.scheduledDate!.isAfter(today) &&
                                         !isRecurringDueToday; // Allow recurring tasks due today

    // 5d. SCHEDULED TODAY (non-recurring only)
    // Recurring tasks are handled in section 5
    if (isScheduledToday && task.recurrence == null) {
      if (hasDistantReminder) {
        // Task scheduled today but reminder > 30 min away
        score += 125;
      } else {
        // Task scheduled today with no reminder OR reminder within 30 min
        score += 600;

        // Add category priority for scheduled today tasks
        score += _calculateCategoryScore(task.categoryIds, categories);

        // Add important bonus for scheduled today tasks
        if (task.isImportant) {
          score += 100;
        }

        // BODY BATTERY BOOST: Energy-based priority for today's tasks
        // Formula: 200 - (energyLevel + 5) × 18
        // Range: -5 gets +200, +5 gets +20
        score += 200 - ((task.energyLevel + 5) * 18);
      }
    }
    // 5e. UNSCHEDULED TASKS (no scheduled date)
    else if (task.scheduledDate == null) {
      // If task has distant reminder (> 30 min away), give it lower priority
      // But still above far-future scheduled tasks
      if (hasDistantReminder) {
        score += 120; // Same as tomorrow scheduled tasks
      } else {
        score += 400;

        // Add category priority for unscheduled tasks
        score += _calculateCategoryScore(task.categoryIds, categories);

        // Add important bonus for unscheduled tasks
        if (task.isImportant) {
          score += 100;
        }

        // Note: Energy boost only applies to tasks scheduled for TODAY
      }
    }
    // 5f. FUTURE SCHEDULED TASKS (non-recurring only, recurring handled in 4b)
    // Note: hasDistantReminder is irrelevant for future tasks - they should always be visible
    else if (isExplicitlyScheduledFuture && task.recurrence == null) {
      final daysUntil = task.scheduledDate!.difference(today).inDays;

      // Tomorrow starts at +120, decreases by 5 each day
      if (daysUntil == 1) {
        score += 120;
      } else if (daysUntil == 2) {
        score += 115;
      } else if (daysUntil == 3) {
        score += 110;
      } else if (daysUntil == 4) {
        score += 105;
      } else if (daysUntil == 5) {
        score += 100;
      } else if (daysUntil == 6) {
        score += 95;
      } else if (daysUntil == 7) {
        score += 90;
      } else if (daysUntil <= 20) {
        // Days 8-20: decrease by 5 each day
        score += math.max(10, 90 - ((daysUntil - 7) * 5));
      } else {
        // Days 21+: decrease by 1 each day until minimum of 1
        score += math.max(1, 10 - (daysUntil - 20));
      }

      // NO categories for future scheduled tasks
      // NO important bonus for future scheduled tasks
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

  /// Calculate category score by summing points for all categories
  /// Uses the HIGHEST priority category (lowest order) as the primary factor
  /// This ensures tasks are grouped by category within the same priority tier
  int _calculateCategoryScore(List<String> categoryIds, List<TaskCategory> categories) {
    if (categoryIds.isEmpty) return 0;

    // Find the highest priority category (lowest order number)
    int bestOrder = 999;
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
      if (category.order < bestOrder) {
        bestOrder = category.order;
      }
    }

    // Skip if no valid categories
    if (bestOrder == 999) return 0;

    // Calculate points: Priority 1 = 300, Priority 2 = 270, Priority 3 = 240, etc.
    // This ensures category grouping overrides energy bonuses (max 200) and importance (100)
    // Formula: (10 - order) * 30, minimum of 30 points
    return math.max(30, (10 - bestOrder) * 30);
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

  bool _taskMatchesPhase(TaskRecurrence recurrence, String currentPhase) {
    return recurrence.types.any((type) {
      switch (type) {
        case RecurrenceType.menstrualPhase:
          return currentPhase == MenstrualCycleConstants.menstrualPhase;
        case RecurrenceType.follicularPhase:
          return currentPhase == MenstrualCycleConstants.follicularPhase;
        case RecurrenceType.ovulationPhase:
          return currentPhase == MenstrualCycleConstants.ovulationPhase;
        case RecurrenceType.earlyLutealPhase:
          return currentPhase == MenstrualCycleConstants.earlyLutealPhase;
        case RecurrenceType.lateLutealPhase:
          return currentPhase == MenstrualCycleConstants.lateLutealPhase;
        default:
          return false;
      }
    });
  }
}
