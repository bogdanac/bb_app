import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'energy_settings_model.dart';
import 'flow_calculator.dart';
import 'battery_flow_widget_channel.dart';

/// Service for persisting and retrieving Body Battery & Flow data
class EnergyService {
  static const String _settingsKey = 'energy_settings';
  static const String _todayKey = 'energy_today';

  // ========================
  // SETTINGS MANAGEMENT
  // ========================

  /// Load energy settings from storage
  static Future<EnergySettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_settingsKey);
    if (json != null) {
      return EnergySettings.fromJson(jsonDecode(json));
    }
    return const EnergySettings();
  }

  /// Save energy settings to storage
  static Future<void> saveSettings(EnergySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // ========================
  // TODAY'S ENERGY TRACKING
  // ========================

  /// Get today's energy record
  static Future<DailyEnergyRecord?> getTodayRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getTodayKey();
    final json = prefs.getString(dateKey);
    if (json != null) {
      return DailyEnergyRecord.fromJson(jsonDecode(json));
    }
    return null;
  }

  /// Save today's energy record
  static Future<void> saveTodayRecord(DailyEnergyRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getTodayKey();
    await prefs.setString(dateKey, jsonEncode(record.toJson()));

    // Also add to history
    await _addToHistory(record);

    // Update widget
    await BatteryFlowWidgetChannel.updateWidget();
  }

  /// Add energy consumption for completed task
  /// Now updates both battery and flow points
  static Future<void> addTaskEnergyConsumption({
    required String taskId,
    required String taskTitle,
    required int energyLevel,
  }) async {
    final entry = EnergyConsumptionEntry(
      id: taskId,
      title: taskTitle,
      energyLevel: energyLevel,
      completedAt: DateTime.now(),
      sourceType: EnergySourceType.task,
    );
    await _addEnergyEntry(entry);
  }

  /// Add energy consumption for completed routine step
  /// Now updates both battery and flow points
  static Future<void> addRoutineStepEnergyConsumption({
    required String stepId,
    required String stepTitle,
    required int energyLevel,
    String? routineTitle,
  }) async {
    final displayTitle = routineTitle != null ? '$routineTitle: $stepTitle' : stepTitle;
    final entry = EnergyConsumptionEntry(
      id: stepId,
      title: displayTitle,
      energyLevel: energyLevel,
      completedAt: DateTime.now(),
      sourceType: EnergySourceType.routineStep,
    );
    await _addEnergyEntry(entry);
  }

  /// Manually adjust battery (for quick buttons)
  static Future<void> adjustBattery(int batteryChange) async {
    final today = await getTodayRecord();
    if (today == null) return;

    final newBattery = today.currentBattery + batteryChange;
    final updated = today.copyWith(currentBattery: newBattery);
    await saveTodayRecord(updated);
  }

  /// Manually add flow points (for quick buttons)
  static Future<void> addFlowPoints(int points) async {
    final today = await getTodayRecord();
    if (today == null) return;

    final settings = await loadSettings();
    final newFlowPoints = today.flowPoints + points;
    final isGoalMet = FlowCalculator.isFlowGoalMet(newFlowPoints, today.flowGoal);
    final isPR = FlowCalculator.isPersonalRecord(newFlowPoints, settings.personalRecord);

    // Update streak if goal just met
    int newStreak = settings.currentStreak;
    if (isGoalMet && !today.isGoalMet) {
      // Goal was just achieved
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayRecord = await getRecordForDate(yesterday);
      newStreak = FlowCalculator.updateStreak(
        goalMetToday: true,
        goalMetYesterday: yesterdayRecord?.isGoalMet ?? false,
        currentStreak: settings.currentStreak,
      );
    }

    // Update personal record if needed
    int newPR = settings.personalRecord;
    if (isPR) {
      newPR = newFlowPoints;
    }

    // Save updated settings
    if (newStreak != settings.currentStreak || newPR != settings.personalRecord) {
      await saveSettings(settings.copyWith(
        currentStreak: newStreak,
        personalRecord: newPR,
      ));
    }

    final updated = today.copyWith(
      flowPoints: newFlowPoints,
      isGoalMet: isGoalMet,
      isPR: isPR,
    );
    await saveTodayRecord(updated);
  }

  /// Get summary of today's energy (for UI display)
  static Future<Map<String, dynamic>> getTodaySummary() async {
    final record = await getTodayRecord();
    if (record == null) {
      return {
        'goal': 0,
        'consumed': 0,
        'remaining': 0,
        'percentage': 0.0,
      };
    }
    return {
      'goal': record.energyGoal,
      'consumed': record.energyConsumed,
      'remaining': (record.energyGoal - record.energyConsumed).clamp(0, record.energyGoal),
      'percentage': record.completionPercentage,
    };
  }

  /// Remove energy consumption (when task is uncompleted)
  /// Reverses battery and flow changes
  static Future<void> removeEnergyConsumption(String id) async {
    final today = await getTodayRecord();
    if (today == null) return;

    // Find the entry to remove
    final entryToRemove = today.entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Entry not found'),
    );

    final updatedEntries = today.entries.where((e) => e.id != id).toList();

    // Reverse the battery and flow changes
    final batteryChange = FlowCalculator.calculateBatteryChange(entryToRemove.energyLevel);
    final flowPointsEarned = FlowCalculator.calculateFlowPoints(entryToRemove.energyLevel);

    final newBattery = today.currentBattery - batteryChange;
    final newFlowPoints = (today.flowPoints - flowPointsEarned).clamp(0, 999999);

    // Check if goal is still met
    final settings = await loadSettings();
    final isGoalMet = FlowCalculator.isFlowGoalMet(newFlowPoints, today.flowGoal);

    // If goal was previously met but now broken, reset streak
    int newStreak = settings.currentStreak;
    if (!isGoalMet && today.isGoalMet) {
      newStreak = 0;
      await saveSettings(settings.copyWith(currentStreak: 0));
    }

    final updatedRecord = today.copyWith(
      currentBattery: newBattery,
      flowPoints: newFlowPoints,
      isGoalMet: isGoalMet,
      isPR: false, // No longer a PR if we're removing entries
      entries: updatedEntries,
    );

    await saveTodayRecord(updatedRecord);
  }

  /// Get total energy consumed today
  static Future<int> getTodayConsumedEnergy() async {
    final record = await getTodayRecord();
    return record?.energyConsumed ?? 0;
  }

  /// Initialize today's record with battery, flow goal, and phase info
  static Future<DailyEnergyRecord> initializeTodayRecord({
    int? startingBattery,
    required int flowGoal,
    required String menstrualPhase,
    required int cycleDayNumber,
  }) async {
    final existing = await getTodayRecord();
    if (existing != null) {
      // Update goal and phase info but keep entries and battery
      final updated = existing.copyWith(
        flowGoal: flowGoal,
        menstrualPhase: menstrualPhase,
        cycleDayNumber: cycleDayNumber,
      );
      await saveTodayRecord(updated);
      return updated;
    }

    final newRecord = DailyEnergyRecord(
      date: DateTime.now(),
      startingBattery: startingBattery ?? 100,
      currentBattery: startingBattery ?? 100,
      flowGoal: flowGoal,
      menstrualPhase: menstrualPhase,
      cycleDayNumber: cycleDayNumber,
      entries: [],
    );
    await saveTodayRecord(newRecord);
    return newRecord;
  }

  // ========================
  // HISTORY MANAGEMENT
  // ========================

  /// Get energy history for a date range
  static Future<List<DailyEnergyRecord>> getHistory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = <DailyEnergyRecord>[];

    for (var date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final key = _getDateKey(date);
      final json = prefs.getString(key);
      if (json != null) {
        records.add(DailyEnergyRecord.fromJson(jsonDecode(json)));
      }
    }

    return records;
  }

  /// Get energy record for a specific date
  static Future<DailyEnergyRecord?> getRecordForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDateKey(date);
    final json = prefs.getString(key);
    if (json != null) {
      return DailyEnergyRecord.fromJson(jsonDecode(json));
    }
    return null;
  }

  // ========================
  // PRIVATE HELPERS
  // ========================

  static Future<void> _addEnergyEntry(EnergyConsumptionEntry entry) async {
    final today = await getTodayRecord();
    if (today == null) return;

    // Check if entry already exists (prevent duplicates)
    if (today.entries.any((e) => e.id == entry.id)) {
      return;
    }

    final updatedEntries = [...today.entries, entry];

    // Calculate new battery and flow
    final batteryChange = FlowCalculator.calculateBatteryChange(entry.energyLevel);
    final flowPointsEarned = FlowCalculator.calculateFlowPoints(entry.energyLevel);

    final newBattery = today.currentBattery + batteryChange;
    final newFlowPoints = today.flowPoints + flowPointsEarned;

    // Check if goal met or PR achieved
    final settings = await loadSettings();
    final isGoalMet = FlowCalculator.isFlowGoalMet(newFlowPoints, today.flowGoal);
    final isPR = FlowCalculator.isPersonalRecord(newFlowPoints, settings.personalRecord);

    // Update streak if goal just met
    int newStreak = settings.currentStreak;
    if (isGoalMet && !today.isGoalMet) {
      // Goal was just achieved
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayRecord = await getRecordForDate(yesterday);
      newStreak = FlowCalculator.updateStreak(
        goalMetToday: true,
        goalMetYesterday: yesterdayRecord?.isGoalMet ?? false,
        currentStreak: settings.currentStreak,
      );
    } else if (!isGoalMet && today.isGoalMet) {
      // Goal was previously met but now broken (shouldn't happen, but handle it)
      newStreak = 0;
    }

    // Update personal record if needed
    int newPR = settings.personalRecord;
    if (isPR) {
      newPR = newFlowPoints;
    }

    // Save updated settings
    if (newStreak != settings.currentStreak || newPR != settings.personalRecord) {
      await saveSettings(settings.copyWith(
        currentStreak: newStreak,
        personalRecord: newPR,
      ));
    }

    final updatedRecord = today.copyWith(
      currentBattery: newBattery,
      flowPoints: newFlowPoints,
      isGoalMet: isGoalMet,
      isPR: isPR,
      entries: updatedEntries,
    );

    await saveTodayRecord(updatedRecord);
  }

  static Future<void> _addToHistory(DailyEnergyRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDateKey(record.date);
    await prefs.setString(key, jsonEncode(record.toJson()));
  }

  static String _getTodayKey() {
    final now = DateTime.now();
    return _getDateKey(now);
  }

  static String _getDateKey(DateTime date) {
    return '${_todayKey}_${date.year}_${date.month}_${date.day}';
  }
}
