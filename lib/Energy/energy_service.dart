import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'energy_settings_model.dart';
import 'flow_calculator.dart';
import 'battery_flow_widget_service.dart';
import '../Services/realtime_sync_service.dart';
import '../shared/error_logger.dart';

/// Service for persisting and retrieving Body Battery & Flow data
class EnergyService {
  static const String _settingsKey = 'energy_settings';
  static const String _todayKey = 'energy_today';

  static final _realtimeSync = RealtimeSyncService();

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

    // Sync energy data to Firestore real-time collection (non-blocking)
    _syncEnergyData(prefs).catchError((e, stackTrace) async {
      await ErrorLogger.logError(
        source: 'EnergyService.saveSettings',
        error: 'Real-time sync failed: $e',
        stackTrace: stackTrace.toString(),
      );
    });
  }

  // ========================
  // TODAY'S ENERGY TRACKING
  // ========================

  /// Get today's energy record
  /// Set [forceReload] to true when syncing with Android widget
  static Future<DailyEnergyRecord?> getTodayRecord({bool forceReload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (forceReload) {
      // Reload to pick up changes made by Android widget
      await prefs.reload();
    }
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

    // Sync energy data to Firestore real-time collection (non-blocking)
    _syncEnergyData(prefs).catchError((e, stackTrace) async {
      await ErrorLogger.logError(
        source: 'EnergyService.saveTodayRecord',
        error: 'Real-time sync failed: $e',
        stackTrace: stackTrace.toString(),
      );
    });

    // Update widget
    await BatteryFlowWidgetService.updateWidget();
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

  /// Add energy consumption for completed timer session
  /// Uses duration-based formula: 1 point per 25 min, ±5% battery per 25 min
  /// batteryPer25Min: -5 (draining), 0 (neutral), or +5 (recharging)
  /// Respects the trackTimerEnergy setting - if disabled, does nothing
  static Future<void> addTimerSessionEnergyConsumption({
    required String sessionId,
    required String activityName,
    required int batteryPer25Min,
    required int durationMinutes,
  }) async {
    // Check if timer energy tracking is enabled
    final settings = await loadSettings();
    if (!settings.trackTimerEnergy) {
      return; // Timer energy tracking is disabled
    }

    final entry = EnergyConsumptionEntry(
      id: sessionId,
      title: activityName,
      energyLevel: batteryPer25Min, // Used for display, actual calculation uses duration
      completedAt: DateTime.now(),
      sourceType: EnergySourceType.timerSession,
      durationMinutes: durationMinutes,
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

  /// Apply time-based battery decay
  /// Decay rate: ~3% per hour, but ONLY during waking hours
  /// Call this when loading today's record to apply any pending decay
  /// Set [forceReload] to true when syncing with Android widget
  static Future<DailyEnergyRecord?> getTodayRecordWithDecay({bool forceReload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (forceReload) {
      // Reload to pick up changes made by Android widget
      await prefs.reload();
    }
    final dateKey = _getTodayKey();
    final json = prefs.getString(dateKey);
    if (json == null) return null;

    final record = DailyEnergyRecord.fromJson(jsonDecode(json));
    final settings = await loadSettings();

    // Check last decay time
    final lastDecayKey = '${dateKey}_last_decay';
    final lastDecayStr = prefs.getString(lastDecayKey);
    final now = DateTime.now();

    // Calculate wake and sleep times for today
    final wakeTime = DateTime(now.year, now.month, now.day, settings.wakeHour, settings.wakeMinute);
    final sleepTime = DateTime(now.year, now.month, now.day, settings.sleepHour, settings.sleepMinute);

    // If current time is before wake time, no decay (sleeping)
    if (now.isBefore(wakeTime)) {
      return record;
    }

    DateTime lastDecay;
    if (lastDecayStr != null) {
      lastDecay = DateTime.parse(lastDecayStr);
    } else {
      // First time - use wake time from settings
      lastDecay = wakeTime;
    }

    // Ensure lastDecay is not before wake time (no decay during sleep)
    if (lastDecay.isBefore(wakeTime)) {
      lastDecay = wakeTime;
    }

    // Calculate effective end time for decay (cap at sleep time)
    final effectiveEndTime = now.isAfter(sleepTime) ? sleepTime : now;

    // If lastDecay is after effectiveEndTime, no decay needed
    if (lastDecay.isAfter(effectiveEndTime) || lastDecay.isAtSameMomentAs(effectiveEndTime)) {
      return record;
    }

    // Calculate waking hours between lastDecay and effectiveEndTime
    final wakingHoursSinceLastDecay = effectiveEndTime.difference(lastDecay).inMinutes / 60.0;

    // Only apply decay if at least 15 minutes have passed
    if (wakingHoursSinceLastDecay < 0.25) {
      return record;
    }

    // Calculate decay: ~3% per hour of waking time, max 15% per check
    final decayAmount = (wakingHoursSinceLastDecay * 3.0).round().clamp(0, 15);

    if (decayAmount > 0) {
      final newBattery = record.currentBattery - decayAmount;
      final updated = record.copyWith(currentBattery: newBattery);

      // Save updated record and last decay time
      await prefs.setString(dateKey, jsonEncode(updated.toJson()));
      await prefs.setString(lastDecayKey, now.toIso8601String());

      // Update widget with new battery value
      await BatteryFlowWidgetService.updateWidget();

      return updated;
    }

    return record;
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
    int newLongestStreak = settings.longestStreak;
    if (isGoalMet && !today.isGoalMet) {
      // Goal was just achieved
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayRecord = await getRecordForDate(yesterday);
      newStreak = FlowCalculator.updateStreak(
        goalMetToday: true,
        goalMetYesterday: yesterdayRecord?.isGoalMet ?? false,
        currentStreak: settings.currentStreak,
      );
      // Update longest streak if current beats it
      if (newStreak > newLongestStreak) {
        newLongestStreak = newStreak;
      }
    }

    // Update personal record if needed
    int newPR = settings.personalRecord;
    if (isPR) {
      newPR = newFlowPoints;
    }

    // Save updated settings
    if (newStreak != settings.currentStreak || newPR != settings.personalRecord || newLongestStreak != settings.longestStreak) {
      await saveSettings(settings.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongestStreak,
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
  /// Uses flowPoints and flowGoal for the new Body Battery & Flow system
  static Future<Map<String, dynamic>> getTodaySummary() async {
    final record = await getTodayRecord();
    if (record == null) {
      return {
        'goal': 0,
        'flowPoints': 0,
        'remaining': 0,
        'percentage': 0.0,
        'battery': 100,
        'isGoalMet': false,
      };
    }
    return {
      'goal': record.flowGoal,
      'flowPoints': record.flowPoints,
      'remaining': (record.flowGoal - record.flowPoints).clamp(0, record.flowGoal),
      'percentage': record.flowPercentage,
      'battery': record.currentBattery,
      'isGoalMet': record.isGoalMet,
    };
  }

  /// Remove energy consumption (when task is uncompleted)
  /// Reverses battery and flow changes
  /// Only removes from today's record - entries from other days are not affected
  static Future<void> removeEnergyConsumption(String id) async {
    final today = await getTodayRecord();
    if (today == null) return;

    // Find the entry to remove - only in today's record
    // If the task was completed on a different day, the entry won't be here
    final entryIndex = today.entries.indexWhere((e) => e.id == id);
    if (entryIndex == -1) {
      // Entry not in today's record (task may have been completed on a different day)
      // Nothing to reverse for today
      return;
    }

    final entryToRemove = today.entries[entryIndex];
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
    if (!isGoalMet && today.isGoalMet) {
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

  /// Get total flow points earned today
  static Future<int> getTodayFlowPoints() async {
    final record = await getTodayRecord();
    return record?.flowPoints ?? 0;
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

  /// Set the decay start time for today
  /// Called when user confirms morning prompt to start decay from that moment
  static Future<void> setDecayStartTime(DateTime startTime) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getTodayKey();
    final lastDecayKey = '${dateKey}_last_decay';
    await prefs.setString(lastDecayKey, startTime.toIso8601String());
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
    // If no record exists for today, initialize one
    // This ensures energy is always tracked to today's record,
    // even when completing tasks scheduled for other dates
    final today = await getTodayRecord() ?? await _initializeDefaultTodayRecord();

    // Check if entry already exists (prevent duplicates)
    if (today.entries.any((e) => e.id == entry.id)) {
      return;
    }

    final updatedEntries = [...today.entries, entry];

    // Calculate new battery and flow based on source type
    int batteryChange;
    int flowPointsEarned;

    if (entry.sourceType == EnergySourceType.timerSession && entry.durationMinutes != null) {
      // Timer sessions: duration-based formula
      // 1 point per 25 min, ±5% battery per 25 min
      batteryChange = FlowCalculator.calculateTimerSessionBatteryChange(
        entry.energyLevel, // This is batteryPer25Min: -5, 0, or +5
        entry.durationMinutes!,
      );
      flowPointsEarned = FlowCalculator.calculateTimerSessionFlowPoints(entry.durationMinutes!);
    } else {
      // Tasks and routine steps: standard formula
      batteryChange = FlowCalculator.calculateBatteryChange(entry.energyLevel);
      flowPointsEarned = FlowCalculator.calculateFlowPoints(entry.energyLevel);
    }

    final newBattery = today.currentBattery + batteryChange;
    final newFlowPoints = today.flowPoints + flowPointsEarned;

    // Check if goal met or PR achieved
    final settings = await loadSettings();
    final isGoalMet = FlowCalculator.isFlowGoalMet(newFlowPoints, today.flowGoal);
    final isPR = FlowCalculator.isPersonalRecord(newFlowPoints, settings.personalRecord);

    // Update streak if goal just met
    int newStreak = settings.currentStreak;
    int newLongestStreak = settings.longestStreak;
    if (isGoalMet && !today.isGoalMet) {
      // Goal was just achieved
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayRecord = await getRecordForDate(yesterday);
      newStreak = FlowCalculator.updateStreak(
        goalMetToday: true,
        goalMetYesterday: yesterdayRecord?.isGoalMet ?? false,
        currentStreak: settings.currentStreak,
      );
      // Update longest streak if current beats it
      if (newStreak > newLongestStreak) {
        newLongestStreak = newStreak;
      }
    }
    // Note: Don't break streak here if goal drops below - that's handled at day end

    // Update personal record if needed
    int newPR = settings.personalRecord;
    if (isPR) {
      newPR = newFlowPoints;
    }

    // Save updated settings
    if (newStreak != settings.currentStreak || newPR != settings.personalRecord || newLongestStreak != settings.longestStreak) {
      await saveSettings(settings.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongestStreak,
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

  /// Check and update streak at end of day (called when day changes)
  /// This is where streak can break or skip is used
  /// Returns true if a skip was auto-used
  static Future<bool> checkStreakAtDayEnd(DateTime previousDay) async {
    final settings = await loadSettings();

    // Normalize date to midnight
    final checkDate = DateTime(previousDay.year, previousDay.month, previousDay.day);

    // Skip if we've already checked this date
    if (settings.lastStreakCheckDate != null) {
      final lastCheck = DateTime(
        settings.lastStreakCheckDate!.year,
        settings.lastStreakCheckDate!.month,
        settings.lastStreakCheckDate!.day,
      );
      if (!checkDate.isAfter(lastCheck)) {
        return false; // Already checked this date or earlier
      }
    }

    final previousRecord = await getRecordForDate(checkDate);

    // If no record for this day, treat as goal not met
    final goalMetOnDate = previousRecord?.isGoalMet ?? false;

    if (goalMetOnDate) {
      // Goal was met, streak continues normally - update last check date
      await saveSettings(settings.copyWith(
        lastStreakCheckDate: checkDate,
      ));
      return false;
    }

    // Goal was NOT met - check if we can use a skip
    final result = FlowCalculator.calculateStreakAtDayEnd(
      goalMetToday: goalMetOnDate,
      currentStreak: settings.currentStreak,
      lastSkipDate: settings.lastSkipDate,
      today: checkDate,
      skipDayMode: settings.skipDayMode,
      autoUseSkip: settings.autoUseSkip,
    );

    if (result.skipUsed) {
      // Save that we used a skip and mark for notification
      await saveSettings(settings.copyWith(
        lastSkipDate: checkDate,
        pendingSkipNotification: checkDate,
        lastStreakCheckDate: checkDate,
      ));
      return true;
    } else if (result.streakBroken) {
      // Streak is broken - save the lost streak count for notification
      final lostStreakCount = settings.currentStreak;
      await saveSettings(settings.copyWith(
        currentStreak: 0,
        pendingStreakLostNotification: lostStreakCount > 0 ? checkDate : null,
        lastStreakCheckDate: checkDate,
      ));
    } else {
      // No streak to break, just update last check date
      await saveSettings(settings.copyWith(
        lastStreakCheckDate: checkDate,
      ));
    }
    return false;
  }

  /// Check if there's a pending skip notification and clear it
  /// Returns the date the skip was used if there's a pending notification
  static Future<DateTime?> checkAndClearSkipNotification() async {
    final settings = await loadSettings();
    if (settings.pendingSkipNotification != null) {
      final skipDate = settings.pendingSkipNotification;
      await saveSettings(settings.copyWith(clearPendingSkipNotification: true));
      return skipDate;
    }
    return null;
  }

  /// Check if there's a pending streak lost notification and clear it
  /// Returns the date the streak was lost if there's a pending notification
  static Future<DateTime?> checkAndClearStreakLostNotification() async {
    final settings = await loadSettings();
    if (settings.pendingStreakLostNotification != null) {
      final lostDate = settings.pendingStreakLostNotification;
      await saveSettings(settings.copyWith(clearPendingStreakLostNotification: true));
      return lostDate;
    }
    return null;
  }

  /// Manually use a skip day to preserve streak (user-triggered)
  static Future<bool> useStreakSkip() async {
    final settings = await loadSettings();
    final today = DateTime.now();

    if (!FlowCalculator.canUseStreakSkip(
      lastSkipDate: settings.lastSkipDate,
      lastStreakDate: settings.lastStreakDate,
      today: today,
    )) {
      return false; // Can't use skip
    }

    await saveSettings(settings.copyWith(
      lastSkipDate: today,
    ));
    return true;
  }

  /// Check if a streak skip is available
  static Future<bool> canUseSkip() async {
    final settings = await loadSettings();
    return FlowCalculator.canUseStreakSkip(
      lastSkipDate: settings.lastSkipDate,
      lastStreakDate: settings.lastStreakDate,
      today: DateTime.now(),
      skipDayMode: settings.skipDayMode,
    );
  }

  static String _getTodayKey() {
    final now = DateTime.now();
    return _getDateKey(now);
  }

  static String _getDateKey(DateTime date) {
    return '${_todayKey}_${date.year}_${date.month}_${date.day}';
  }

  /// Initialize a default today record when none exists
  /// Used when completing tasks from other dates before today's record is created
  static Future<DailyEnergyRecord> _initializeDefaultTodayRecord() async {
    final newRecord = DailyEnergyRecord(
      date: DateTime.now(),
      startingBattery: 100,
      currentBattery: 100,
      flowGoal: 10, // Default goal
      menstrualPhase: 'Unknown',
      cycleDayNumber: 0,
      entries: [],
    );
    await saveTodayRecord(newRecord);
    return newRecord;
  }

  /// Sync all energy-related data to Firestore
  static Future<void> _syncEnergyData(SharedPreferences prefs) async {
    final energyData = <String, String>{};

    // Collect all energy-related keys
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith(_settingsKey) || key.startsWith(_todayKey)) {
        final value = prefs.getString(key);
        if (value != null) {
          energyData[key] = value;
        }
      }
    }

    // Sync to Firestore
    await _realtimeSync.syncEnergy(energyData);
  }
}
