import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'tasks_data_models.dart';
import '../Notifications/notification_service.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final NotificationService _notificationService = NotificationService();
  
  // Global task change notifier
  final List<VoidCallback> _taskChangeListeners = [];
  
  // Add listener for task changes
  void addTaskChangeListener(VoidCallback listener) {
    if (!_taskChangeListeners.contains(listener)) {
      _taskChangeListeners.add(listener);
    }
  }
  
  // Remove listener for task changes
  void removeTaskChangeListener(VoidCallback listener) {
    _taskChangeListeners.remove(listener);
  }
  
  // Notify all listeners that tasks have changed
  void _notifyTasksChanged() {
    for (final listener in _taskChangeListeners) {
      listener();
    }
  }

  Future<List<Task>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> tasksJson;
      try {
        tasksJson = prefs.getStringList('tasks') ?? [];
      } catch (e) {
        if (kDebugMode) {
          print('ERROR: Tasks data type mismatch, clearing corrupted data');
        }
        await prefs.remove('tasks');
        tasksJson = [];
      }

      final tasks = tasksJson
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();

      // Check for menstrual tasks that should be prioritized today due to phaseDay
      await _updateMenstrualTaskPriorities(tasks, prefs);

      return tasks;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading tasks: $e');
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
      
      // Notify all listeners that tasks have changed
      _notifyTasksChanged();
    } catch (e) {
      if (kDebugMode) {
        print('ERROR saving tasks: $e');
      }
    }
  }

  Future<List<TaskCategory>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> categoriesJson;
      try {
        categoriesJson = prefs.getStringList('task_categories') ?? [];
      } catch (e) {
        if (kDebugMode) {
          print('ERROR: Task categories data type mismatch, clearing corrupted data');
        }
        await prefs.remove('task_categories');
        categoriesJson = [];
      }

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
        print('ERROR loading categories: $e');
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
        print('ERROR saving categories: $e');
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
        print('ERROR loading task settings: $e');
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
        print('ERROR saving task settings: $e');
      }
    }
  }

  // Category filter persistence methods
  Future<List<String>> loadSelectedCategoryFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        return prefs.getStringList('selected_category_filters') ?? [];
      } catch (e) {
        if (kDebugMode) {
          print('ERROR: Category filters data type mismatch, clearing corrupted data');
        }
        await prefs.remove('selected_category_filters');
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading category filters: $e');
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
        print('ERROR saving category filters: $e');
      }
    }
  }

  // Postpone a task to tomorrow
  Future<void> postponeTaskToTomorrow(Task task) async {
    try {
      final now = DateTime.now();
      
      // Calculate the new postpone date - add 1 day to existing scheduled date or use tomorrow if no scheduled date
      DateTime postponeDate;
      if (task.scheduledDate != null) {
        // If task already has a scheduled date, add 1 day to that date
        postponeDate = task.scheduledDate!.add(const Duration(days: 1));
      } else {
        // If no scheduled date, set to tomorrow
        postponeDate = DateTime(now.year, now.month, now.day + 1);
      }
      
      DateTime? newReminderTime = task.reminderTime;
      
      // If task has a reminder time, keep the same time but move date to postpone date
      if (task.reminderTime != null) {
        newReminderTime = DateTime(postponeDate.year, postponeDate.month, postponeDate.day,
                                 task.reminderTime!.hour, task.reminderTime!.minute);
      }
      
      // Create updated task with scheduled date moved to postpone date
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        categoryIds: List.from(task.categoryIds),
        deadline: task.deadline, // Keep original deadline
        scheduledDate: postponeDate, // Move scheduled date to postpone date
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

      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR postponing task: $e');
      }
      rethrow;
    }
  }

  // Check if a task should show postpone button (due today, overdue, recurring today, or reminder today)
  static bool shouldShowPostponeButton(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. Tasks with deadlines today or overdue
    if (task.deadline != null) {
      final taskDeadline = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
      if (taskDeadline.isAtSameMomentAs(today) || taskDeadline.isBefore(today)) {
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
      final aPriorityScore = _calculateTaskPriorityScore(a, now, today, categories);
      final bPriorityScore = _calculateTaskPriorityScore(b, now, today, categories);
      
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
  int _calculateTaskPriorityScore(Task task, DateTime now, DateTime today, List<TaskCategory> categories) {
    int score = 0;

    // SPECIAL CASE: Postponed recurring tasks get absolute lowest priority
    if (task.recurrence != null && task.scheduledDate != null) {
      final tomorrow = today.add(const Duration(days: 1));
      if (task.scheduledDate!.isAfter(today) || _isSameDay(task.scheduledDate!, tomorrow)) {
        // This is a postponed recurring task - give it minimal priority
        // It will only get points from categories, nothing else
        return 1; // Return immediately with minimal score
      }
    }

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
        // Special handling for postponed recurring tasks - absolute lowest priority
        final tomorrow = today.add(const Duration(days: 1));
        if (task.recurrence != null && task.scheduledDate != null && 
            (task.scheduledDate!.isAfter(today) || _isSameDay(task.scheduledDate!, tomorrow))) {
          score += 0; // No priority for postponed recurring tasks - they should appear last
        } else {
          score += 30; // Reduced priority for future reminders - they're not urgent yet
        }
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

    // 4. CONTEXT-AWARE PRIORITY: Tomorrow's deadlines
    else if (task.deadline != null) {
      final tomorrow = today.add(const Duration(days: 1));
      if (_isSameDay(task.deadline!, tomorrow)) {
        // Non-recurring deadlines get time-based priority
        score += _getContextualTomorrowPriority(now);
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

    // 4b. RECURRING TASKS: Handle scheduled dates for tomorrow (lowest priority)
    else if (task.recurrence != null && task.scheduledDate != null) {
      final tomorrow = today.add(const Duration(days: 1));
      if (_isSameDay(task.scheduledDate!, tomorrow)) {
        // Postponed recurring tasks should have the absolute lowest priority
        // Don't add any score - they'll only get minimal points from categories if any
        score += 0; // No priority boost for postponed recurring tasks
      }
    }

    // AUTO-FIX: Update scheduledDate for recurring tasks if outdated OR missing
    if (task.recurrence != null) {
      // Check if task would be due today according to its recurrence pattern
      if (task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt)) {
        // Update if scheduledDate is missing OR outdated
        if (task.scheduledDate == null || task.scheduledDate!.isBefore(today)) {
          // Note: This async call is fire-and-forget during prioritization
          // The task list will be refreshed and show the updated scheduledDate
          _updateTaskScheduledDate(task, today);
        }
      }
    }

    // 5. MEDIUM-HIGH PRIORITY: Recurring tasks due today
    if (task.recurrence != null && task.isDueToday()) {
      
      // If task was postponed (has scheduledDate for future), reduce recurring priority
      if (task.scheduledDate != null && task.scheduledDate!.isAfter(today)) {
        score += 5; // Much lower priority for postponed recurring tasks
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

    // 5b. SCHEDULED TODAY: Tasks scheduled for today (should appear before unscheduled important tasks)
    if (task.scheduledDate != null && _isSameDay(task.scheduledDate!, today)) {
      score += 600; // High priority for tasks scheduled today, higher than important tasks
    }

    // 6. LOW-MEDIUM PRIORITY: Important tasks (less than reminder priority)
    if (task.isImportant) {
      score += 50; // Reduced from 100 to ensure reminders take precedence
    }

    // 7. CATEGORY PRIORITY: Based on category order (higher than basic tasks, lower than important)
    if (task.categoryIds.isNotEmpty) {
      final categoryImportance = _getCategoryImportance(task.categoryIds, categories);
      // Lower category order = higher priority
      // Category order 1 = +40 points, order 2 = +35 points, order 5 = +20 points, etc.
      if (categoryImportance < 999) {
        int baseScore = math.max(10, 45 - (categoryImportance * 5));
        
        // Bonus for multiple categories: +2 points per additional category (max +10)
        // This makes tasks with multiple high-priority categories rank higher
        int categoryBonus = math.min(10, (task.categoryIds.length - 1) * 2);
        score += baseScore + categoryBonus;
      }
    }

    // Note: Removed bonus for reminder tasks since they already get priority above

    return score;
  }

  // Helper method to calculate contextual priority for tomorrow's tasks based on time of day
  int _getContextualTomorrowPriority(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 50;   // Morning: focus today
    if (hour < 18) return 150;  // Afternoon: light planning
    return 300; // Evening: prep for tomorrow
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
      for (final task in tasks) {
        if (!task.isCompleted && task.reminderTime != null) {
          await scheduleTaskNotification(task);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling task notifications: $e');
      }
    }
  }

  Future<void> scheduleTaskNotification(Task task) async {
    try {
      if (task.reminderTime == null) return;

      final now = DateTime.now();
      DateTime scheduledDate = task.reminderTime!;

      // For recurring tasks, only use _getNextReminderTime if the current reminderTime is in the past
      if (task.recurrence != null && scheduledDate.isBefore(now)) {
        final nextReminderTime = _getNextReminderTime(task, now);
        if (nextReminderTime != null) {
          scheduledDate = nextReminderTime;
        } else {
          return;
        }
      }

      // Don't schedule if the time has already passed and it's not recurring
      if (scheduledDate.isBefore(now) && task.recurrence == null) {
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

    } catch (e) {
      if (kDebugMode) {
        print('ERROR scheduling task notification for ${task.title}: $e');
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
      final isDue = task.recurrence!.isDueOn(currentCheck, taskCreatedAt: task.createdAt);

      if (isDue) {
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
    } catch (e) {
      if (kDebugMode) {
        print('ERROR canceling task notifications: $e');
      }
    }
  }

  Future<void> cancelTaskNotification(Task task) async {
    try {
      await _notificationService.cancelTaskNotification(task.id);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR canceling task notification: $e');
      }
    }
  }

  // Force reschedule all task notifications (useful for debugging)
  Future<void> forceRescheduleAllNotifications() async {
    try {
      final tasks = await loadTasks();
      await _scheduleAllTaskNotifications(tasks);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR force rescheduling notifications: $e');
      }
    }
  }

  // Update a task's scheduled date and save to storage
  Future<void> _updateTaskScheduledDate(Task task, DateTime newScheduledDate) async {
    task.scheduledDate = newScheduledDate;

    // Load all tasks, update this one, and save back
    final allTasks = await loadTasks();
    final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
    if (taskIndex != -1) {
      allTasks[taskIndex] = task;
      await saveTasks(allTasks);
    }

    // Reschedule notification if task has reminder time
    if (task.reminderTime != null) {
      await scheduleTaskNotification(task);
    }

  }

  // Check menstrual tasks and set scheduledDate for those on their target phaseDay
  Future<void> _updateMenstrualTaskPriorities(List<Task> tasks, SharedPreferences prefs) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Get menstrual cycle data
    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    if (lastStartStr == null) return; // No cycle data available

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final lastPeriodEnd = lastEndStr != null ? DateTime.parse(lastEndStr) : null;

    // Get current menstrual phase
    final currentPhase = MenstrualCycleUtils.getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);

    bool tasksUpdated = false;

    for (final task in tasks) {
      // Skip non-menstrual tasks or tasks without phaseDay
      if (task.recurrence == null || task.recurrence!.phaseDay == null || !_isMenstrualCycleTask(task.recurrence!)) {
        continue;
      }

      // Skip postponed tasks (they already have a scheduled date for the future)
      if (task.scheduledDate != null && task.scheduledDate!.isAfter(todayDate)) {
        continue;
      }

      // Check if task's menstrual phase matches current phase
      final taskMatchesCurrentPhase = _taskMatchesPhase(task.recurrence!, currentPhase);
      if (!taskMatchesCurrentPhase) continue;

      // Get target phase for this task
      final targetPhase = _getTaskTargetPhase(task.recurrence!);
      if (targetPhase == null) continue;

      // Check if today is the target phaseDay
      final currentDayInPhase = MenstrualCycleUtils.getCurrentDayInPhase(
        lastPeriodStart,
        averageCycleLength,
        targetPhase
      );

      if (currentDayInPhase == task.recurrence!.phaseDay) {
        // Today is the target day! Set scheduledDate to today for high priority
        if (task.scheduledDate == null || !_isSameDay(task.scheduledDate!, todayDate)) {
          task.scheduledDate = todayDate;
          tasksUpdated = true;
        }
      }
    }

    // Save tasks if any were updated
    if (tasksUpdated) {
      await saveTasks(tasks);
    }
  }

  // Helper method to check if task matches current phase
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

  // Helper method to get the target phase name for a task
  String? _getTaskTargetPhase(TaskRecurrence recurrence) {
    for (final type in recurrence.types) {
      switch (type) {
        case RecurrenceType.menstrualPhase:
          return MenstrualCycleConstants.menstrualPhase;
        case RecurrenceType.follicularPhase:
          return MenstrualCycleConstants.follicularPhase;
        case RecurrenceType.ovulationPhase:
          return MenstrualCycleConstants.ovulationPhase;
        case RecurrenceType.earlyLutealPhase:
          return MenstrualCycleConstants.earlyLutealPhase;
        case RecurrenceType.lateLutealPhase:
          return MenstrualCycleConstants.lateLutealPhase;
        default:
          continue;
      }
    }
    return null;
  }
}