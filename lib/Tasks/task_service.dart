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

  // Get prioritized tasks for home page
  List<Task> getPrioritizedTasks(List<Task> tasks, List<TaskCategory> categories, int maxTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Filter out completed tasks and get only relevant tasks
    final availableTasks = tasks.where((task) => !task.isCompleted).toList();

    // Sort by priority with enhanced logic
    availableTasks.sort((a, b) {
      // Calculate priority scores for better comparison
      final aPriorityScore = _calculateTaskPriorityScore(a, now, today);
      final bPriorityScore = _calculateTaskPriorityScore(b, now, today);
      
      if (aPriorityScore != bPriorityScore) {
        return bPriorityScore.compareTo(aPriorityScore); // Higher score = higher priority
      }

      // If same priority score, use secondary sorting criteria
      
      // 1. For reminders, closer time gets higher priority
      if (a.reminderTime != null && b.reminderTime != null) {
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

  // Calculate priority score for enhanced task ordering
  int _calculateTaskPriorityScore(Task task, DateTime now, DateTime today) {
    int score = 0;

    // 1. HIGHEST PRIORITY: Reminders that are very close (within 15 minutes)
    if (task.reminderTime != null) {
      final reminderDiff = task.reminderTime!.difference(now).inMinutes;
      if (reminderDiff <= 15 && reminderDiff >= -15) {
        score += 1000; // Highest priority
      } else if (reminderDiff <= 60 && reminderDiff >= -30) {
        score += 900; // Very high priority for reminders within hour
      } else if (reminderDiff <= 120 && reminderDiff >= -60) {
        score += 300; // High priority for reminders within 2 hours
      }
    }

    // 2. HIGH PRIORITY: Deadlines today
    if (task.deadline != null && _isSameDay(task.deadline!, today)) {
      score += 800;
    }

    // 3. MEDIUM-HIGH PRIORITY: Recurring tasks due today
    if (task.recurrence != null && task.isDueToday()) {
      score += 700;
    }

    // 4. MEDIUM PRIORITY: Deadlines tomorrow
    final tomorrow = today.add(const Duration(days: 1));
    if (task.deadline != null && _isSameDay(task.deadline!, tomorrow)) {
      score += 400;
    }

    // 5. MEDIUM PRIORITY: Overdue deadlines (past due)
    if (task.deadline != null && task.deadline!.isBefore(today)) {
      final daysPast = today.difference(DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)).inDays;
      score += 600 - (daysPast * 10); // Decreasing priority as time passes
    }

    // 6. LOW-MEDIUM PRIORITY: Important tasks
    if (task.isImportant) {
      score += 200;
    }

    // 7. BONUS: Tasks with reminders get slight boost even if not close
    if (task.reminderTime != null && score < 300) {
      score += 50;
    }

    return score;
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
      var scheduledDate = task.reminderTime!;

      // If the reminder time has passed today, schedule for tomorrow (for recurring tasks)
      if (scheduledDate.isBefore(now) && task.recurrence != null) {
        final nextDue = task.getNextDueDate();
        if (nextDue != null) {
          scheduledDate = DateTime(
            nextDue.year,
            nextDue.month,
            nextDue.day,
            task.reminderTime!.hour,
            task.reminderTime!.minute,
          );
        }
      }

      // Don't schedule if the time has already passed and it's not recurring
      if (scheduledDate.isBefore(now) && task.recurrence == null) {
        if (kDebugMode) {
          print('Skipping past reminder for task: ${task.title}');
        }
        return;
      }

      // Use NotificationService to schedule the notification
      await _notificationService.scheduleTaskNotification(
        task.id,
        task.title,
        scheduledDate,
        isRecurring: task.recurrence != null,
      );

      if (kDebugMode) {
        print('Scheduled task notification: ${task.title} at $scheduledDate');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling task notification for ${task.title}: $e');
      }
    }
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
}