import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tasks_data_models.dart';

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

      return tasks;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading tasks: $e');
      }
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
    } catch (e) {
      if (kDebugMode) {
        print('ERROR saving tasks: $e');
      }
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
      } catch (e) {
        if (kDebugMode) {
          print('ERROR: Task categories data type mismatch, clearing corrupted data');
        }
        await prefs.remove('task_categories');
        categoriesJson = [];
      }

      if (categoriesJson.isEmpty) {
        return [];
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

  /// Save categories to SharedPreferences
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
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading task settings: $e');
      }
      return TaskSettings();
    }
  }

  /// Save task settings to SharedPreferences
  Future<void> saveTaskSettings(TaskSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('task_settings', jsonEncode(settings.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print('ERROR saving task settings: $e');
      }
      rethrow;
    }
  }

  /// Load selected category filters from SharedPreferences
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

  /// Save selected category filters to SharedPreferences
  Future<void> saveSelectedCategoryFilters(List<String> categoryIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selected_category_filters', categoryIds);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR saving category filters: $e');
      }
      rethrow;
    }
  }
}
