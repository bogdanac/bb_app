import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chore_data_models.dart';
import '../Services/firebase_backup_service.dart';
import '../shared/error_logger.dart';

class ChoreService {
  static const String _choresKey = 'chores';
  static const String _categoriesKey = 'chores_categories';
  static const String _settingsKey = 'chores_settings';

  // ==================== Chores CRUD ====================

  /// Load all chores from SharedPreferences
  static Future<List<Chore>> loadChores() async {
    final prefs = await SharedPreferences.getInstance();
    final choresJson = prefs.getStringList(_choresKey) ?? [];

    if (choresJson.isEmpty) return [];

    try {
      final chores =
          choresJson.map((json) => Chore.fromJson(jsonDecode(json))).toList();

      // Refresh condition values based on decay
      for (var chore in chores) {
        chore.refreshCondition();
      }

      return chores;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'ChoreService.loadChores',
        error: 'Error loading chores: $e',
        stackTrace: stackTrace.toString(),
      );
      return [];
    }
  }

  /// Save chores to SharedPreferences
  static Future<void> saveChores(List<Chore> chores) async {
    final prefs = await SharedPreferences.getInstance();

    // Refresh condition before saving
    for (var chore in chores) {
      chore.refreshCondition();
    }

    final choresJson =
        chores.map((chore) => jsonEncode(chore.toJson())).toList();
    await prefs.setStringList(_choresKey, choresJson);

    // Backup to Firebase
    FirebaseBackupService.triggerBackup();
  }

  /// Get active chores only (condition >= 0%)
  static Future<List<Chore>> getActiveChores() async {
    final chores = await loadChores();
    return chores; // All chores are active since they can decay
  }

  /// Get chores for today (matching preferred days OR overdue)
  /// Sorted by priority algorithm
  static Future<List<Chore>> getTodayChores() async {
    final settings = await loadSettings();
    final today = DateTime.now().weekday; // 1=Monday, 7=Sunday
    final chores = await getActiveChores();

    // Filter: today is preferred day OR chore is overdue
    final todayChores = chores.where((chore) {
      return settings.preferredCleaningDays.contains(today) || chore.isOverdue;
    }).toList();

    // Sort by priority (highest priority first)
    todayChores.sort((a, b) {
      final aPriority = calculatePriority(a);
      final bPriority = calculatePriority(b);
      return bPriority.compareTo(aPriority); // Higher priority first
    });

    return todayChores;
  }

  /// Get overdue chores (past due date)
  static Future<List<Chore>> getOverdueChores() async {
    final chores = await getActiveChores();
    return chores.where((c) => c.isOverdue).toList();
  }

  /// Get critical chores (condition < 40%)
  static Future<List<Chore>> getCriticalChores() async {
    final chores = await getActiveChores();
    return chores.where((c) => c.isCritical).toList();
  }

  /// Add new chore
  static Future<void> addChore(Chore chore) async {
    final chores = await loadChores();
    chores.add(chore);
    await saveChores(chores);
  }

  /// Update existing chore
  static Future<void> updateChore(Chore updatedChore) async {
    final chores = await loadChores();
    final index = chores.indexWhere((c) => c.id == updatedChore.id);
    if (index != -1) {
      chores[index] = updatedChore;
      await saveChores(chores);
    }
  }

  /// Delete chore
  static Future<void> deleteChore(String choreId) async {
    final chores = await loadChores();
    chores.removeWhere((c) => c.id == choreId);
    await saveChores(chores);
  }

  /// Complete a chore (restore to 100% condition)
  static Future<void> completeChore(String choreId,
      {String? notes}) async {
    final chores = await loadChores();
    final chore = chores.firstWhere((c) => c.id == choreId);
    chore.complete(completionNotes: notes);
    await saveChores(chores);
  }

  /// Update chore condition manually
  static Future<void> updateChoreCondition(
      String choreId, double newCondition) async {
    final chores = await loadChores();
    final chore = chores.firstWhere((c) => c.id == choreId);
    chore.setCondition(newCondition);
    await saveChores(chores);
  }

  /// Move chore to different category
  static Future<void> moveChoreToCategory(
      String choreId, String newCategory) async {
    final chores = await loadChores();
    final chore = chores.firstWhere((c) => c.id == choreId);
    chore.category = newCategory;
    await saveChores(chores);
  }

  // ==================== Priority Calculation ====================

  /// Calculate priority for sorting today's list
  /// Higher number = higher priority
  /// Factors: condition level, days overdue, critical status
  static double calculatePriority(Chore chore) {
    final overdueDays = chore.isOverdue
        ? DateTime.now().difference(chore.nextDueDate).inDays
        : 0;
    final conditionFactor =
        (1.0 - chore.currentCondition) * 100; // 0-100 (lower condition = higher priority)
    final overdueFactor = overdueDays * 10; // 10 points per overdue day
    final criticalBonus = chore.isCritical ? 50 : 0; // Critical = urgent

    return conditionFactor + overdueFactor + criticalBonus;
  }

  // ==================== Categories Management ====================

  /// Load categories from SharedPreferences
  static Future<List<ChoreCategory>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList(_categoriesKey);

    if (categoriesJson == null || categoriesJson.isEmpty) {
      // Return defaults if none saved
      final defaults = ChoreCategory.getDefaults();
      await saveCategories(defaults); // Save defaults
      return defaults;
    }

    try {
      return categoriesJson
          .map((json) => ChoreCategory.fromJson(jsonDecode(json)))
          .toList();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'ChoreService.loadCategories',
        error: 'Error loading categories: $e',
        stackTrace: stackTrace.toString(),
      );
      return ChoreCategory.getDefaults();
    }
  }

  /// Save categories to SharedPreferences
  static Future<void> saveCategories(List<ChoreCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson =
        categories.map((cat) => jsonEncode(cat.toJson())).toList();
    await prefs.setStringList(_categoriesKey, categoriesJson);
    FirebaseBackupService.triggerBackup();
  }

  /// Add new category
  static Future<void> addCategory(ChoreCategory category) async {
    final categories = await loadCategories();
    categories.add(category);
    await saveCategories(categories);
  }

  /// Update existing category
  static Future<void> updateCategory(ChoreCategory updatedCategory) async {
    final categories = await loadCategories();
    final index = categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index != -1) {
      categories[index] = updatedCategory;
      await saveCategories(categories);
    }
  }

  /// Delete category
  static Future<void> deleteCategory(String categoryId) async {
    final categories = await loadCategories();
    categories.removeWhere((c) => c.id == categoryId);
    await saveCategories(categories);
  }

  // ==================== Settings Management ====================

  /// Load settings
  static Future<ChoreSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson == null) {
      return ChoreSettings(); // Return default
    }
    try {
      return ChoreSettings.fromJson(jsonDecode(settingsJson));
    } catch (e) {
      return ChoreSettings(); // Return default on error
    }
  }

  /// Save settings
  static Future<void> saveSettings(ChoreSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    FirebaseBackupService.triggerBackup();
  }

  // ==================== Statistics ====================

  /// Get statistics for all chores
  static Future<Map<String, dynamic>> getStats() async {
    final chores = await getActiveChores();

    if (chores.isEmpty) {
      return {
        'totalChores': 0,
        'avgCondition': 0.0,
        'totalCompletions': 0,
        'overdueCount': 0,
        'criticalCount': 0,
      };
    }

    final totalCompletions =
        chores.fold<int>(0, (sum, chore) => sum + chore.totalCompletions);

    final avgCondition = chores.fold<double>(
          0.0,
          (sum, chore) => sum + chore.currentCondition,
        ) /
        chores.length;

    final overdueCount = chores.where((c) => c.isOverdue).length;
    final criticalCount = chores.where((c) => c.isCritical).length;

    return {
      'totalChores': chores.length,
      'avgCondition': avgCondition,
      'totalCompletions': totalCompletions,
      'overdueCount': overdueCount,
      'criticalCount': criticalCount,
    };
  }
}
