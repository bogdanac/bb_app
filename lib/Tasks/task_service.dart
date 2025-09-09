import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tasks_data_models.dart';
import '../Notifications/notification_service.dart';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final NotificationService _notificationService = NotificationService();

  Future<List<Task>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getStringList('tasks') ?? [];

      return tasksJson
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading tasks: $e');
      }
      return [];
    }
  }

  Future<void> saveTasks(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = tasks
          .map((task) => jsonEncode(task.toJson()))
          .toList();
      await prefs.setStringList('tasks', tasksJson);

      // Update task notifications when saving
      await _scheduleAllTaskNotifications(tasks);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving tasks: $e');
      }
    }
  }

  Future<List<TaskCategory>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getStringList('task_categories') ?? [];

      if (categoriesJson.isEmpty) {
        // Default categories
        final defaultCategories = [
          TaskCategory(id: '1', name: 'Cleaning', color: const Color(0xFF2196F3), order: 0), // Blue
          TaskCategory(id: '2', name: 'At Home', color: const Color(0xFF4CAF50), order: 1), // Green
          TaskCategory(id: '3', name: 'Research', color: const Color(0xFF9C27B0), order: 2), // Purple
          TaskCategory(id: '4', name: 'Travel', color: const Color(0xFFFF9800), order: 3), // Orange
        ];
        await saveCategories(defaultCategories);
        return defaultCategories;
      }

      return categoriesJson
          .map((json) => TaskCategory.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading categories: $e');
      }
      return [];
    }
  }

  Future<void> saveCategories(List<TaskCategory> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = categories
          .map((category) => jsonEncode(category.toJson()))
          .toList();
      await prefs.setStringList('task_categories', categoriesJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving categories: $e');
      }
    }
  }

  Future<TaskSettings> loadTaskSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('task_settings');

      if (settingsJson == null) {
        return TaskSettings();
      }

      return TaskSettings.fromJson(jsonDecode(settingsJson));
    } catch (e) {
      if (kDebugMode) {
        print('Error loading task settings: $e');
      }
      return TaskSettings();
    }
  }

  Future<void> saveTaskSettings(TaskSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('task_settings', jsonEncode(settings.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving task settings: $e');
      }
    }
  }

  // Category filter persistence methods
  Future<List<String>> loadSelectedCategoryFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('selected_category_filters') ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading category filters: $e');
      }
      return [];
    }
  }

  Future<void> saveSelectedCategoryFilters(List<String> categoryIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selected_category_filters', categoryIds);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving category filters: $e');
      }
    }
  }

  // Postpone a task to tomorrow
  Future<void> postponeTaskToTomorrow(Task task) async {
    try {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      
      // Determine what to postpone based on task type
      DateTime? newDeadline = task.deadline;
      DateTime? newReminderTime = task.reminderTime;
      
      // 1. If task has a deadline today, move it to tomorrow
      if (task.deadline != null) {
        final taskDeadline = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
        final today = DateTime(now.year, now.month, now.day);
        if (taskDeadline.isAtSameMomentAs(today)) {
          newDeadline = tomorrow;
        }
      }
      
      // 2. If task has a reminder today, move it to tomorrow
      if (task.reminderTime != null) {
        final reminderDate = DateTime(task.reminderTime!.year, task.reminderTime!.month, task.reminderTime!.day);
        final today = DateTime(now.year, now.month, now.day);
        if (reminderDate.isAtSameMomentAs(today)) {
          newReminderTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
                                   task.reminderTime!.hour, task.reminderTime!.minute);
        }
      }
      
      // 3. For recurring tasks, we add a deadline for tomorrow to "skip" today's occurrence
      if (task.recurrence != null && task.recurrence!.isDueOn(now, taskCreatedAt: task.createdAt)) {
        // If it doesn't already have a deadline or the deadline is not tomorrow, set it to tomorrow
        if (newDeadline == null || !DateTime(newDeadline.year, newDeadline.month, newDeadline.day).isAtSameMomentAs(tomorrow)) {
          newDeadline = tomorrow;
        }
      }
      
      // Create updated task
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        categoryIds: List.from(task.categoryIds),
        deadline: newDeadline,
        reminderTime: newReminderTime,
        isImportant: task.isImportant,
        recurrence: task.recurrence,
        isCompleted: task.isCompleted,
        completedAt: task.completedAt,
        createdAt: task.createdAt,
      );

      // Load fresh task list and update it
      final allTasks = await loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
      
      if (taskIndex != -1) {
        allTasks[taskIndex] = updatedTask;
        await saveTasks(allTasks);
        
        if (kDebugMode) {
          print('Task postponed to tomorrow: ${task.title}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error postponing task: $e');
      }
      rethrow;
    }
  }

  // Check if a task should show postpone button (due today, recurring today, or reminder today)
  static bool shouldShowPostponeButton(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. Tasks with deadlines today
    if (task.deadline != null) {
      final taskDeadline = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
      if (taskDeadline.isAtSameMomentAs(today)) {
        return true;
      }
    }
    
    // 2. Recurring tasks that are due today
    if (task.recurrence != null && task.recurrence!.isDueOn(now)) {
      return true;
    }
    
    // 3. Tasks with reminders today
    if (task.reminderTime != null) {
      final reminderDate = DateTime(task.reminderTime!.year, task.reminderTime!.month, task.reminderTime!.day);
      if (reminderDate.isAtSameMomentAs(today)) {
        return true;
      }
    }
    
    return false;
  }

  // Keep the old method for backward compatibility
  static bool isTaskDueToday(Task task) {
    return shouldShowPostponeButton(task);
  }

  // Get prioritized tasks for home page
  List<Task> getPrioritizedTasks(List<Task> tasks, List<TaskCategory> categories, int maxTasks, {bool includeCompleted = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter tasks based on completion status
    final availableTasks = includeCompleted ? tasks : tasks.where((task) => !task.isCompleted).toList();

    // Sort by priority with enhanced logic
    availableTasks.sort((a, b) {
      // Calculate priority scores for better comparison
      final aPriorityScore = _calculateTaskPriorityScore(a, now, today);
      final bPriorityScore = _calculateTaskPriorityScore(b, now, today);
      
      if (aPriorityScore != bPriorityScore) {
        return bPriorityScore.compareTo(aPriorityScore); // Higher score = higher priority
      }

      // If same priority score, use secondary sorting criteria
      
      // 1. For reminders TODAY, earlier times get higher priority
      if (a.reminderTime != null && b.reminderTime != null) {
        final aIsToday = _isReminderToday(a.reminderTime!, now);
        final bIsToday = _isReminderToday(b.reminderTime!, now);
        
        // Both reminders today - earlier time wins
        if (aIsToday && bIsToday) {
          return a.reminderTime!.compareTo(b.reminderTime!);
        }
        
        // Only one reminder today - that one wins
        if (aIsToday && !bIsToday) return -1;
        if (!aIsToday && bIsToday) return 1;
        
        // Neither today - closer time wins
        final aDiff = (a.reminderTime!.difference(now).inMinutes).abs();
        final bDiff = (b.reminderTime!.difference(now).inMinutes).abs();
        if (aDiff != bDiff) return aDiff.compareTo(bDiff);
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

  // Helper method to check if reminder is today
  bool _isReminderToday(DateTime reminderTime, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(reminderTime.year, reminderTime.month, reminderTime.day);
    return reminderDate.isAtSameMomentAs(today);
  }

  // Calculate priority score for enhanced task ordering
  int _calculateTaskPriorityScore(Task task, DateTime now, DateTime today) {
    int score = 0;

    // 1. HIGHEST PRIORITY: Tasks with reminder times (past or future)
    if (task.reminderTime != null) {
      final reminderDiff = task.reminderTime!.difference(now).inMinutes;
      final isReminderToday = _isReminderToday(task.reminderTime!, now);
      
      // Past reminders (overdue) get highest priority
      if (reminderDiff < 0) {
        final hoursPast = (-reminderDiff) / 60;
        if (hoursPast <= 1) {
          score += 1200; // Recently overdue reminders get highest priority
        } else if (hoursPast <= 24) {
          score += 1000; // Overdue reminders within 24 hours
        } else {
          score += 800; // Older overdue reminders
        }
      }
      // Future reminders within 15 minutes
      else if (reminderDiff <= 15) {
        score += 1100; // Very high priority for imminent reminders
      }
      // Future reminders within 1 hour
      else if (reminderDiff <= 60) {
        score += 900; // High priority for upcoming reminders
      }
      // Future reminders within 2 hours
      else if (reminderDiff <= 120) {
        score += 700; // Medium-high priority for near-term reminders
      }
      // For reminders today beyond 2 hours
      else if (isReminderToday) {
        // Reminders more than 90 minutes away get very low priority
        if (reminderDiff > 90) {
          score += 10; // Very low priority - lower than important tasks and deadlines
        } else {
          // Within 90 minutes - give normal priority based on time of day
          final hourOfDay = task.reminderTime!.hour;
          // Earlier hours get higher scores (morning tasks prioritized over evening)
          score += 650 - (hourOfDay * 5); // 6 AM = 620, 9 AM = 605, 6 PM = 560, 9 PM = 545
        }
      }
      // Future reminders beyond today
      else {
        score += 300; // Lower but still significant priority for future reminders
      }
    }

    // 2. HIGHEST PRIORITY: Overdue deadlines (past due)
    if (task.deadline != null && task.deadline!.isBefore(today)) {
      final daysPast = today.difference(DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)).inDays;
      score += 900 - (daysPast * 10); // Decreasing priority as time passes, but still very high
    }

    // 3. HIGH PRIORITY: Deadlines today
    else if (task.deadline != null && _isSameDay(task.deadline!, today)) {
      score += 800;
    }

    // 4. MEDIUM-HIGH PRIORITY: Deadlines tomorrow
    else if (task.deadline != null) {
      final tomorrow = today.add(const Duration(days: 1));
      if (_isSameDay(task.deadline!, tomorrow)) {
        score += 400;
      }
      // Only prioritize deadlines that are very close - ignore distant ones
      else {
        final daysUntil = task.deadline!.difference(today).inDays;
        // Don't add priority score for deadlines more than 2 days away
        if (daysUntil <= 2 && daysUntil > 0) {
          score += 200 - (daysUntil * 50); // Small boost for 2-day window
        }
        // Deadlines beyond 2 days get no priority boost from deadline alone
      }
    }

    // 5. MEDIUM-HIGH PRIORITY: Recurring tasks due today
    if (task.recurrence != null && task.isDueToday()) {
      // If task was postponed (has deadline for today/future), reduce recurring priority
      if (task.deadline != null && !task.deadline!.isBefore(today)) {
        score += 200; // Lower priority for postponed recurring tasks
      } else {
        // For menstrual cycle tasks, consider distance to target day
        if (_isMenstrualCycleTask(task.recurrence!)) {
          final daysUntilTarget = _getDaysUntilMenstrualTarget(task.recurrence!);
          if (daysUntilTarget != null) {
            if (daysUntilTarget <= 1) {
              score += 700; // Full priority if very close (today or tomorrow)
            } else if (daysUntilTarget <= 3) {
              score += 400; // Medium priority if within 3 days
            } else if (daysUntilTarget <= 7) {
              score += 100; // Low priority if within a week
          }
          // Beyond 7 days: no priority boost for menstrual cycle tasks
          } else {
            score += 200; // Default for menstrual tasks without clear timing
          }
        } else {
          score += 700; // Full priority for non-menstrual recurring tasks
        }
      }
    }

    // 6. LOW-MEDIUM PRIORITY: Important tasks (less than reminder priority)
    if (task.isImportant) {
      score += 50; // Reduced from 100 to ensure reminders take precedence
    }

    // Note: Removed bonus for reminder tasks since they already get priority above

    return score;
  }

  // Check if a task is a menstrual cycle-based task
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
    (recurrence.type == RecurrenceType.custom && (recurrence.interval <= -100 || recurrence.interval == -1));
  }

  // Calculate days until the next occurrence of a menstrual cycle target
  int? _getDaysUntilMenstrualTarget(TaskRecurrence recurrence) {
    try {
      final now = DateTime.now();
      final nextDueDate = recurrence.getNextDueDate(now);
      
      if (nextDueDate != null) {
        final daysUntil = nextDueDate.difference(now).inDays;
        return daysUntil >= 0 ? daysUntil : 0;
      }
      
      // Fallback: estimate based on cycle phase
      return _estimateDaysToMenstrualTarget(recurrence.type);
    } catch (e) {
      return null; // Return null if we can't calculate
    }
  }

  // Rough estimation of days until menstrual cycle target (fallback)
  int? _estimateDaysToMenstrualTarget(RecurrenceType type) {
    // This is a rough estimate assuming a 28-day cycle
    // In reality, this should use actual user cycle data
    switch (type) {
      case RecurrenceType.menstrualStartDay:
        return 14; // Assume mid-cycle, so ~2 weeks to next period
      case RecurrenceType.menstrualPhase:
        return 12; // Similar to above
      case RecurrenceType.follicularPhase:
        return 8; // Assume we're in luteal, so ~1 week+ to follicular
      case RecurrenceType.ovulationPhase:
      case RecurrenceType.ovulationPeakDay:
        return 21; // Assume we're in luteal, so ~3 weeks to next ovulation
      case RecurrenceType.earlyLutealPhase:
        return 7; // Assume we're in late luteal, so ~1 week
      case RecurrenceType.lateLutealPhase:
        return 3; // Assume we're in early luteal, so ~3 days
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
        orElse: () => TaskCategory(id: '', name: '', color: const Color(0xFF666666), order: 999),
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

  // Notification methods
  Future<void> _scheduleAllTaskNotifications(List<Task> tasks) async {
    try {
      // Cancel all existing task notifications
      await _cancelAllTaskNotifications();

      // Schedule notifications for all tasks with reminder times
      int scheduledCount = 0;
      for (final task in tasks) {
        if (!task.isCompleted && task.reminderTime != null) {
          await _scheduleTaskNotification(task);
          scheduledCount++;
        }
      }

      if (kDebugMode) {
        print('Scheduled $scheduledCount task notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling task notifications: $e');
      }
    }
  }

  Future<void> _scheduleTaskNotification(Task task) async {
    try {
      if (task.reminderTime == null) return;

      final now = DateTime.now();
      DateTime? scheduledDate;

      if (task.recurrence != null) {
        // For recurring tasks, find the next occurrence and schedule reminder accordingly
        scheduledDate = _getNextReminderTime(task, now);
      } else {
        // For non-recurring tasks, use the original reminder time
        scheduledDate = task.reminderTime!;
      }

      // Don't schedule if no valid date found
      if (scheduledDate == null) {
        if (kDebugMode) {
          print('No valid reminder date found for task: ${task.title}');
        }
        return;
      }

      // Don't schedule if the time has already passed and it's not recurring
      if (scheduledDate.isBefore(now) && task.recurrence == null) {
        if (kDebugMode) {
          print('Skipping past reminder for task: ${task.title}');
        }
        return;
      }

      // Cancel existing notification first to avoid duplicates
      await _notificationService.cancelTaskNotification(task.id);
      
      // Use NotificationService to schedule the notification
      await _notificationService.scheduleTaskNotification(
        task.id,
        task.title,
        scheduledDate,
        isRecurring: task.recurrence != null,
      );

      if (kDebugMode) {
        print('Scheduled task notification: ${task.title} at $scheduledDate (recurring: ${task.recurrence != null})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling task notification for ${task.title}: $e');
      }
    }
  }

  /// Get the next reminder time for a recurring task
  DateTime? _getNextReminderTime(Task task, DateTime now) {
    if (task.reminderTime == null || task.recurrence == null) return null;

    final originalTime = task.reminderTime!;
    final timeOfDay = TimeOfDay(hour: originalTime.hour, minute: originalTime.minute);
    
    // Start checking from today
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    
    // Look ahead for up to 90 days to find the next occurrence
    for (int i = 0; i < 90; i++) {
      final currentCheck = checkDate.add(Duration(days: i));
      
      // Check if task is due on this date according to its recurrence pattern
      if (task.recurrence!.isDueOn(currentCheck, taskCreatedAt: task.createdAt)) {
        final reminderDateTime = DateTime(
          currentCheck.year,
          currentCheck.month,
          currentCheck.day,
          timeOfDay.hour,
          timeOfDay.minute,
        );
        
        // Only schedule if the reminder time is in the future
        if (reminderDateTime.isAfter(now)) {
          return reminderDateTime;
        }
      }
    }
    
    // If no occurrence found in the next 90 days, return null
    return null;
  }

  Future<void> _cancelAllTaskNotifications() async {
    try {
      await _notificationService.cancelAllTaskNotifications();
      if (kDebugMode) {
        print('Cancelled all task notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error canceling task notifications: $e');
      }
    }
  }

  Future<void> cancelTaskNotification(Task task) async {
    try {
      await _notificationService.cancelTaskNotification(task.id);

      if (kDebugMode) {
        print('Cancelled notification for task: ${task.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error canceling task notification: $e');
      }
    }
  }

  // Force reschedule all task notifications (useful for debugging)
  Future<void> forceRescheduleAllNotifications() async {
    try {
      final tasks = await loadTasks();
      await _scheduleAllTaskNotifications(tasks);
      
      if (kDebugMode) {
        print('Force rescheduled all task notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error force rescheduling notifications: $e');
      }
    }
  }
}