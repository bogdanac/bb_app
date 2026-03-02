import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'chore_data_models.dart';
import '../Services/firebase_backup_service.dart';
import '../Services/realtime_sync_service.dart';
import '../shared/error_logger.dart';
import '../Settings/app_customization_service.dart';
import '../Energy/energy_service.dart';
import '../Energy/energy_calculator.dart';

class ChoreService {
  static const String _choresKey = 'chores';
  static const String _categoriesKey = 'chores_categories';
  static const String _settingsKey = 'chores_settings';

  // ==================== Chores CRUD ====================

  static final _realtimeSync = RealtimeSyncService();

  /// Load all chores from SharedPreferences (or Firestore on web)
  static Future<List<Chore>> loadChores() async {
    List<String> choresJson = [];

    // On web, try Firestore first since SharedPreferences doesn't persist reliably
    if (kIsWeb) {
      final firestoreChores = await _realtimeSync.fetchChoresFromFirestore();
      if (firestoreChores != null && firestoreChores.isNotEmpty) {
        debugPrint('ChoreService.loadChores: WEB - got ${firestoreChores.length} chores from Firestore');
        choresJson = firestoreChores;
        // Cache to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_choresKey, firestoreChores);
      }
    }

    // Fallback to SharedPreferences
    if (choresJson.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      choresJson = prefs.getStringList(_choresKey) ?? [];
    }

    if (choresJson.isEmpty) return [];

    try {
      final chores =
          choresJson.map((json) => Chore.fromJson(jsonDecode(json))).toList();

      // On mobile, sync to Firestore for web access
      if (!kIsWeb && chores.isNotEmpty) {
        _realtimeSync.syncChores(jsonEncode(choresJson)).catchError((e, stackTrace) {
          ErrorLogger.logError(
            source: 'ChoreService.loadChores',
            error: 'Background chore sync failed: $e',
            stackTrace: stackTrace.toString(),
          );
        });
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

  /// Save chores to SharedPreferences and sync to Firestore
  static Future<void> saveChores(List<Chore> chores) async {
    final prefs = await SharedPreferences.getInstance();

    final choresJson =
        chores.map((chore) => jsonEncode(chore.toJson())).toList();
    await prefs.setStringList(_choresKey, choresJson);

    // Sync to Firestore — await on web to ensure data persists before refresh
    if (kIsWeb) {
      try {
        await _realtimeSync.syncChores(jsonEncode(choresJson));
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'ChoreService.saveChores',
          error: 'Firestore sync failed: $e',
          stackTrace: stackTrace.toString(),
        );
      }
    } else {
      _realtimeSync.syncChores(jsonEncode(choresJson)).catchError((e, stackTrace) {
        ErrorLogger.logError(
          source: 'ChoreService.saveChores',
          error: 'Background sync failed: $e',
          stackTrace: stackTrace.toString(),
        );
      });
    }

    // Also backup via legacy service
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
    final categories = await loadCategories();
    final categoryOrder = categories.map((c) => c.name).toList();

    // Filter: today is preferred day OR chore is overdue
    // For yearly chores with activeMonth: only show if in active month or overdue
    final todayChores = chores.where((chore) {
      if (!chore.isInActiveMonth && !chore.isOverdue) return false;
      return settings.preferredCleaningDays.contains(today) || chore.isOverdue;
    }).toList();

    // Sort by priority (highest priority first)
    todayChores.sort((a, b) {
      final aPriority = calculatePriority(a, categoryOrder: categoryOrder);
      final bPriority = calculatePriority(b, categoryOrder: categoryOrder);
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

    // Track energy if module is enabled and chore has energy level
    if (chore.energyLevel != 0) {
      try {
        final states = await AppCustomizationService.loadAllModuleStates();
        if (states[AppCustomizationService.moduleEnergy] == true) {
          await EnergyCalculator.initializeToday();
          await EnergyService.addTaskEnergyConsumption(
            taskId: 'chore_${chore.id}',
            taskTitle: chore.name,
            energyLevel: chore.energyLevel,
          );
        }
      } catch (e) {
        debugPrint('Error tracking chore energy: $e');
      }
    }
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
  /// Factors: category rank, condition level, days overdue, critical status
  static double calculatePriority(Chore chore, {List<String>? categoryOrder}) {
    final overdueDays = chore.isOverdue
        ? DateTime.now().difference(chore.nextDueDate).inDays
        : 0;
    final conditionFactor =
        (1.0 - chore.currentCondition) * 100; // 0-100 (lower condition = higher priority)
    final overdueFactor = overdueDays * 10; // 10 points per overdue day
    final criticalBonus = chore.isCritical ? 50 : 0; // Critical = urgent
    // Yearly chores get a boost during their active month
    final activeMonthBonus = (chore.intervalUnit == 'years' &&
        chore.activeMonth != null &&
        chore.isInActiveMonth) ? 30 : 0;
    // Category priority: top category (#0) gets max bonus, lower ones get less
    double categoryBonus = 0;
    if (categoryOrder != null && categoryOrder.isNotEmpty) {
      final idx = categoryOrder.indexOf(chore.category);
      if (idx >= 0) {
        categoryBonus = (categoryOrder.length - idx) * 20.0; // 20 pts per rank
      }
    }

    // Shorter interval = more frequent = small priority boost (max ~3.6 pts for daily)
    final intervalBonus = 365.0 / chore.intervalDays.clamp(1, 365);

    return conditionFactor + overdueFactor + criticalBonus + activeMonthBonus + categoryBonus + intervalBonus;
  }

  // ==================== Categories Management ====================

  /// Load categories from SharedPreferences (or Firestore on web)
  static Future<List<ChoreCategory>> loadCategories() async {
    List<String>? categoriesJson;

    // On web, try Firestore first
    if (kIsWeb) {
      final firestoreCategories = await _realtimeSync.fetchChoreCategoriesFromFirestore();
      if (firestoreCategories != null && firestoreCategories.isNotEmpty) {
        debugPrint('ChoreService.loadCategories: WEB - got ${firestoreCategories.length} categories from Firestore');
        categoriesJson = firestoreCategories;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_categoriesKey, firestoreCategories);
      }
    }

    // Fallback to SharedPreferences
    if (categoriesJson == null || categoriesJson.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      categoriesJson = prefs.getStringList(_categoriesKey);
    }

    if (categoriesJson == null || categoriesJson.isEmpty) {
      // Return defaults if none saved
      final defaults = ChoreCategory.getDefaults();
      await saveCategories(defaults);
      return defaults;
    }

    try {
      final categories = categoriesJson
          .map((json) => ChoreCategory.fromJson(jsonDecode(json)))
          .toList();

      // On mobile, sync to Firestore for web access
      if (!kIsWeb && categories.isNotEmpty) {
        _realtimeSync.syncChoreCategories(jsonEncode(categoriesJson)).catchError((e, stackTrace) {
          ErrorLogger.logError(
            source: 'ChoreService.loadCategories',
            error: 'Background category sync failed: $e',
            stackTrace: stackTrace.toString(),
          );
        });
      }

      return categories;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'ChoreService.loadCategories',
        error: 'Error loading categories: $e',
        stackTrace: stackTrace.toString(),
      );
      return ChoreCategory.getDefaults();
    }
  }

  /// Save categories to SharedPreferences and sync to Firestore
  static Future<void> saveCategories(List<ChoreCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson =
        categories.map((cat) => jsonEncode(cat.toJson())).toList();
    await prefs.setStringList(_categoriesKey, categoriesJson);

    if (kIsWeb) {
      try {
        await _realtimeSync.syncChoreCategories(jsonEncode(categoriesJson));
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'ChoreService.saveCategories',
          error: 'Firestore sync failed: $e',
          stackTrace: stackTrace.toString(),
        );
      }
    } else {
      _realtimeSync.syncChoreCategories(jsonEncode(categoriesJson)).catchError((e, stackTrace) {
        ErrorLogger.logError(
          source: 'ChoreService.saveCategories',
          error: 'Background sync failed: $e',
          stackTrace: stackTrace.toString(),
        );
      });
    }

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

  /// Load settings (from Firestore on web, SharedPreferences otherwise)
  static Future<ChoreSettings> loadSettings() async {
    String? settingsJson;

    // On web, try Firestore first
    if (kIsWeb) {
      final firestoreSettings = await _realtimeSync.fetchChoreSettingsFromFirestore();
      if (firestoreSettings != null) {
        debugPrint('ChoreService.loadSettings: WEB - got settings from Firestore');
        settingsJson = firestoreSettings;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_settingsKey, firestoreSettings);
      }
    }

    // Fallback to SharedPreferences
    if (settingsJson == null) {
      final prefs = await SharedPreferences.getInstance();
      settingsJson = prefs.getString(_settingsKey);
    }

    if (settingsJson == null) {
      return ChoreSettings(); // Return default
    }
    try {
      final settings = ChoreSettings.fromJson(jsonDecode(settingsJson));

      // On mobile, sync to Firestore for web access
      if (!kIsWeb) {
        _realtimeSync.syncChoreSettings(settingsJson).catchError((e, stackTrace) {
          ErrorLogger.logError(
            source: 'ChoreService.loadSettings',
            error: 'Background settings sync failed: $e',
            stackTrace: stackTrace.toString(),
          );
        });
      }

      return settings;
    } catch (e) {
      return ChoreSettings(); // Return default on error
    }
  }

  /// Save settings and sync to Firestore
  static Future<void> saveSettings(ChoreSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, json);

    if (kIsWeb) {
      try {
        await _realtimeSync.syncChoreSettings(json);
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'ChoreService.saveSettings',
          error: 'Firestore sync failed: $e',
          stackTrace: stackTrace.toString(),
        );
      }
    } else {
      _realtimeSync.syncChoreSettings(json).catchError((e, stackTrace) {
        ErrorLogger.logError(
          source: 'ChoreService.saveSettings',
          error: 'Background sync failed: $e',
          stackTrace: stackTrace.toString(),
        );
      });
    }

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
