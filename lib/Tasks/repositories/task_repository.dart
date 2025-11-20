import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../tasks_data_models.dart';
import '../../shared/error_logger.dart';

/// Repository responsible for ONLY data persistence operations.
/// NO business logic, NO notifications, NO widget updates.
class TaskRepository {
  static final TaskRepository _instance = TaskRepository._internal();
  factory TaskRepository() => _instance;
  TaskRepository._internal();

  /// Load tasks from SharedPreferences
  Future<List<Task>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> tasksJson;
      try {
        tasksJson = prefs.getStringList('tasks') ?? [];
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'TaskRepository.loadTasks',
          error: 'Tasks data type mismatch, clearing corrupted data: $e',
          stackTrace: stackTrace.toString(),
        );
        await prefs.remove('tasks');
        tasksJson = [];
      }

      final tasks = tasksJson
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();

      return tasks;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.loadTasks',
        error: 'Error loading tasks: $e',
        stackTrace: stackTrace.toString(),
      );
      return [];
    }
  }

  /// Save tasks to SharedPreferences
  Future<void> saveTasks(List<Task> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = tasks
          .map((task) => jsonEncode(task.toJson()))
          .toList();
      await prefs.setStringList('tasks', tasksJson);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.saveTasks',
        error: 'Error saving tasks: $e',
        stackTrace: stackTrace.toString(),
        context: {'taskCount': tasks.length},
      );
      rethrow;
    }
  }

  /// Load categories from SharedPreferences
  Future<List<TaskCategory>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> categoriesJson;
      try {
        categoriesJson = prefs.getStringList('task_categories') ?? [];
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'TaskRepository.loadCategories',
          error: 'Task categories data type mismatch, clearing corrupted data: $e',
          stackTrace: stackTrace.toString(),
        );
        await prefs.remove('task_categories');
        categoriesJson = [];
      }

      if (categoriesJson.isEmpty) {
        return [];
      }

      return categoriesJson
          .map((json) => TaskCategory.fromJson(jsonDecode(json)))
          .toList();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.loadCategories',
        error: 'Error loading categories: $e',
        stackTrace: stackTrace.toString(),
      );
      return [];
    }
  }

  /// Save categories to SharedPreferences
  Future<void> saveCategories(List<TaskCategory> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = categories
          .map((category) => jsonEncode(category.toJson()))
          .toList();
      await prefs.setStringList('task_categories', categoriesJson);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.saveCategories',
        error: 'Error saving categories: $e',
        stackTrace: stackTrace.toString(),
        context: {'categoryCount': categories.length},
      );
      rethrow;
    }
  }

  /// Load task settings from SharedPreferences
  Future<TaskSettings> loadTaskSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('task_settings');

      if (settingsJson == null) {
        return TaskSettings();
      }

      return TaskSettings.fromJson(jsonDecode(settingsJson));
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.loadTaskSettings',
        error: 'Error loading task settings: $e',
        stackTrace: stackTrace.toString(),
      );
      return TaskSettings();
    }
  }

  /// Save task settings to SharedPreferences
  Future<void> saveTaskSettings(TaskSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('task_settings', jsonEncode(settings.toJson()));
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.saveTaskSettings',
        error: 'Error saving task settings: $e',
        stackTrace: stackTrace.toString(),
      );
      rethrow;
    }
  }

  /// Load selected category filters from SharedPreferences
  Future<List<String>> loadSelectedCategoryFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        return prefs.getStringList('selected_category_filters') ?? [];
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'TaskRepository.loadSelectedCategoryFilters',
          error: 'Category filters data type mismatch, clearing corrupted data: $e',
          stackTrace: stackTrace.toString(),
        );
        await prefs.remove('selected_category_filters');
        return [];
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.loadSelectedCategoryFilters',
        error: 'Error loading category filters: $e',
        stackTrace: stackTrace.toString(),
      );
      return [];
    }
  }

  /// Save selected category filters to SharedPreferences
  Future<void> saveSelectedCategoryFilters(List<String> categoryIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selected_category_filters', categoryIds);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskRepository.saveSelectedCategoryFilters',
        error: 'Error saving category filters: $e',
        stackTrace: stackTrace.toString(),
        context: {'filterCount': categoryIds.length},
      );
      rethrow;
    }
  }
}
