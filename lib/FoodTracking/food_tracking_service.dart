import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'food_tracking_data_models.dart';
import '../Services/firebase_backup_service.dart';
import '../shared/error_logger.dart';

enum FoodTrackingResetFrequency { weekly, monthly }

class FoodTrackingService {
  static const String _entriesKey = 'food_entries';
  static const String _resetFrequencyKey = 'food_tracking_reset_frequency';
  static const String _lastResetKey = 'food_tracking_last_reset';
  static const String _periodHistoryKey = 'food_tracking_period_history';
  static const String _targetGoalKey = 'food_tracking_target_goal';

  static Future<List<FoodEntry>> getAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> entriesJson;
    try {
      entriesJson = prefs.getStringList(_entriesKey) ?? [];
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FoodTrackingService.getAllEntries',
        error: 'Food tracking data type mismatch, clearing corrupted data: $e',
        stackTrace: stackTrace.toString(),
      );
      await prefs.remove(_entriesKey);
      entriesJson = [];
    }

    return entriesJson
        .map((json) => FoodEntry.fromJsonString(json))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> addEntry(FoodEntry entry) async {
    // Check for period reset before adding new entry
    await _checkAndPerformReset();

    final entries = await getAllEntries();

    // Generate a new ID if the entry doesn't have one
    if (entry.id.isEmpty) {
      entry = FoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: entry.type,
        timestamp: entry.timestamp,
        note: entry.note,
      );
    }

    entries.insert(0, entry);
    await _saveEntries(entries);
  }

  static Future<void> deleteEntry(String id) async {
    final entries = await getAllEntries();
    entries.removeWhere((entry) => entry.id == id);
    await _saveEntries(entries);
  }

  static Future<void> _saveEntries(List<FoodEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = entries.map((entry) => entry.toJsonString()).toList();
    await prefs.setStringList(_entriesKey, entriesJson);

    // Backup to Firebase
    FirebaseBackupService.triggerBackup();
  }

  static Future<List<FoodEntry>> getEntriesForWeek(DateTime weekStart) async {
    final entries = await getAllEntries();
    final weekEnd = weekStart.add(const Duration(days: 7));

    return entries.where((entry) =>
        entry.timestamp.isAtSameMomentAs(weekStart) ||
        (entry.timestamp.isAfter(weekStart) && entry.timestamp.isBefore(weekEnd))).toList();
  }

  static Future<List<FoodEntry>> getEntriesForMonth(DateTime monthStart) async {
    final entries = await getAllEntries();
    final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);

    return entries.where((entry) =>
        (entry.timestamp.isAtSameMomentAs(monthStart) ||
         entry.timestamp.isAfter(monthStart)) &&
        entry.timestamp.isBefore(nextMonth)).toList();
  }

  static Future<List<FoodEntry>> getEntriesForDay(DateTime day) async {
    final entries = await getAllEntries();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    return entries.where((entry) =>
        entry.timestamp.isAfter(dayStart) &&
        entry.timestamp.isBefore(dayEnd)).toList();
  }

  // Reset frequency settings
  static Future<FoodTrackingResetFrequency> getResetFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_resetFrequencyKey) ?? FoodTrackingResetFrequency.monthly.index;
    return FoodTrackingResetFrequency.values[index];
  }

  static Future<void> setResetFrequency(FoodTrackingResetFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_resetFrequencyKey, frequency.index);

    // Check if we need to reset data when frequency changes
    await _checkAndPerformReset();
  }

  // Public method to check and perform reset - call this on app startup
  static Future<void> checkAndPerformResetIfNeeded() async {
    await _checkAndPerformReset();
  }

  // Check if reset is needed and perform it
  static Future<void> _checkAndPerformReset() async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = await getResetFrequency();
    final lastResetStr = prefs.getString(_lastResetKey);

    DateTime? lastReset;
    if (lastResetStr != null) {
      lastReset = DateTime.parse(lastResetStr);
    }

    final now = DateTime.now();
    bool shouldReset = false;

    if (lastReset == null) {
      // First time using the app, set current period start as last reset
      shouldReset = false;
      await _setLastReset(_getCurrentPeriodStart(frequency, now));
      return;
    }

    if (frequency == FoodTrackingResetFrequency.monthly) {
      // Reset if we're in a new month
      final currentMonthStart = getCurrentMonthStart();
      shouldReset = lastReset.isBefore(currentMonthStart);
    } else {
      // Reset if we're in a new week
      final currentWeekStart = getCurrentWeekStart();
      shouldReset = lastReset.isBefore(currentWeekStart);
    }

    if (shouldReset) {
      await _performReset();
      await _setLastReset(_getCurrentPeriodStart(frequency, now));
    }
  }

  static DateTime _getCurrentPeriodStart(FoodTrackingResetFrequency frequency, DateTime now) {
    if (frequency == FoodTrackingResetFrequency.monthly) {
      return DateTime(now.year, now.month, 1);
    } else {
      final daysFromMonday = (now.weekday - 1) % 7;
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
    }
  }

  static Future<void> _setLastReset(DateTime resetDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastResetKey, resetDate.toIso8601String());
  }

  static Future<void> _performReset() async {
    final frequency = await getResetFrequency();
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_lastResetKey);

    // Determine the previous period to save
    // We need to save data from the PREVIOUS period, not the current one
    DateTime previousPeriodStart;
    DateTime previousPeriodEnd;

    if (lastResetStr != null) {
      previousPeriodStart = DateTime.parse(lastResetStr);
    } else {
      // Fallback: calculate previous period start
      final now = DateTime.now();
      if (frequency == FoodTrackingResetFrequency.monthly) {
        previousPeriodStart = DateTime(now.year, now.month - 1, 1);
      } else {
        previousPeriodStart = getCurrentWeekStart().subtract(const Duration(days: 7));
      }
    }

    // Calculate previous period end (day before current period start)
    if (frequency == FoodTrackingResetFrequency.monthly) {
      previousPeriodEnd = DateTime(previousPeriodStart.year, previousPeriodStart.month + 1, 0); // Last day of that month
    } else {
      previousPeriodEnd = previousPeriodStart.add(const Duration(days: 6)); // Sunday of that week
    }

    // Get entries specifically from the PREVIOUS period
    final previousPeriodCounts = frequency == FoodTrackingResetFrequency.monthly
        ? await getMonthlyCount(previousPeriodStart)
        : await getWeeklyCounts(previousPeriodStart);

    await _savePeriodToHistory(frequency, previousPeriodCounts, previousPeriodStart, previousPeriodEnd);

    // Now delete entries from the previous period only
    // Keep any entries from the current period (Dec 1-15 in your case)
    await _deleteEntriesBeforeDate(_getCurrentPeriodStart(frequency, DateTime.now()));

    final healthy = previousPeriodCounts['healthy'] ?? 0;
    final processed = previousPeriodCounts['processed'] ?? 0;
    final total = healthy + processed;
    final percentage = total > 0 ? (healthy / total * 100).round() : 0;
    await ErrorLogger.logError(
      source: 'FoodTrackingService.resetCounts',
      error: 'Food tracking reset: $percentage% healthy saved to history for ${_getMonthLabel(previousPeriodStart)}',
      stackTrace: '',
    );
  }

  // Delete entries before a specific date
  static Future<void> _deleteEntriesBeforeDate(DateTime date) async {
    final entries = await getAllEntries();
    final filteredEntries = entries.where((entry) =>
        entry.timestamp.isAfter(date) || entry.timestamp.isAtSameMomentAs(date)).toList();

    final prefs = await SharedPreferences.getInstance();
    final entriesJson = filteredEntries.map((entry) => entry.toJsonString()).toList();
    await prefs.setStringList(_entriesKey, entriesJson);
  }

  static Future<void> _savePeriodToHistory(FoodTrackingResetFrequency frequency, Map<String, int> counts, DateTime periodStart, DateTime periodEnd) async {
    final prefs = await SharedPreferences.getInstance();

    final healthy = counts['healthy'] ?? 0;
    final processed = counts['processed'] ?? 0;
    final total = healthy + processed;

    if (total == 0) return; // Don't save empty periods

    final percentage = (healthy / total * 100).round();

    // Create period record with the correct period dates
    final periodRecord = {
      'percentage': percentage,
      'healthy': healthy,
      'processed': processed,
      'total': total,
      'frequency': frequency.name,
      'endDate': periodEnd.toIso8601String(),
      'periodLabel': frequency == FoodTrackingResetFrequency.monthly
          ? _getMonthLabel(periodStart)
          : _getWeekLabel(periodStart, periodEnd)
    };

    // Load existing history
    final historyJson = prefs.getStringList(_periodHistoryKey) ?? [];
    final history = historyJson.map((json) => Map<String, dynamic>.from(
        Map<String, dynamic>.from(jsonDecode(json)))).toList();

    // Add new record at beginning (most recent first)
    history.insert(0, periodRecord);

    // Keep only last 12 periods (months or weeks)
    if (history.length > 12) {
      history.removeRange(12, history.length);
    }

    // Save back to preferences
    final updatedJson = history.map((record) => jsonEncode(record)).toList();
    await prefs.setStringList(_periodHistoryKey, updatedJson);
  }

  static String _getMonthLabel(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String _getWeekLabel(DateTime start, DateTime end) {
    return '${start.day}/${start.month} - ${end.day}/${end.month}';
  }

  // Get period history for display
  static Future<List<Map<String, dynamic>>> getPeriodHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_periodHistoryKey) ?? [];

    return historyJson.map((json) => Map<String, dynamic>.from(
        jsonDecode(json))).toList();
  }

  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - 1) % 7;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
  }

  static DateTime getCurrentMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static Future<Map<String, int>> getCurrentPeriodCounts() async {
    // Check if reset is needed before returning counts
    await _checkAndPerformReset();

    final frequency = await getResetFrequency();
    if (frequency == FoodTrackingResetFrequency.monthly) {
      return getMonthlyCount();
    } else {
      return getWeeklyCounts();
    }
  }

  static Future<Map<String, int>> getWeeklyCounts([DateTime? weekStart]) async {
    weekStart ??= getCurrentWeekStart();
    final weekEntries = await getEntriesForWeek(weekStart);

    int healthyCount = 0;
    int processedCount = 0;

    for (final entry in weekEntries) {
      if (entry.type == FoodType.healthy) {
        healthyCount++;
      } else {
        processedCount++;
      }
    }

    return {
      'healthy': healthyCount,
      'processed': processedCount,
    };
  }

  static Future<Map<String, int>> getMonthlyCount([DateTime? monthStart]) async {
    monthStart ??= getCurrentMonthStart();
    final monthEntries = await getEntriesForMonth(monthStart);

    int healthyCount = 0;
    int processedCount = 0;

    for (final entry in monthEntries) {
      if (entry.type == FoodType.healthy) {
        healthyCount++;
      } else {
        processedCount++;
      }
    }

    return {
      'healthy': healthyCount,
      'processed': processedCount,
    };
  }

  static Future<String> getResetInfo() async {
    final frequency = await getResetFrequency();
    if (frequency == FoodTrackingResetFrequency.monthly) {
      return getMonthResetInfo();
    } else {
      return getWeekResetInfo();
    }
  }

  static String getWeekResetInfo() {
    final now = DateTime.now();

    final daysUntilReset = 7 - now.weekday;
    final nextMonday = now.add(Duration(days: daysUntilReset));

    if (daysUntilReset == 0) {
      return 'Week resets tomorrow (Monday)';
    } else if (daysUntilReset == 1) {
      return 'Week resets tomorrow (Monday)';
    } else {
      return 'Week resets on ${_formatDate(nextMonday)} (Monday)';
    }
  }

  static String getMonthResetInfo() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final daysUntilReset = nextMonth.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (daysUntilReset == 1) {
      return 'Resets tomorrow';
    } else if (daysUntilReset <= 7) {
      return 'Resets on ${_formatDate(nextMonth)}';
    } else {
      return 'Resets ${_formatDate(nextMonth)}';
    }
  }

  static String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  static Future<List<Map<String, dynamic>>> getAllWeeklyStats() async {
    final entries = await getAllEntries();
    if (entries.isEmpty) return [];

    final Map<String, Map<String, int>> weeklyStats = {};
    
    for (final entry in entries) {
      final weekStart = _getWeekStart(entry.timestamp);
      final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
      
      weeklyStats[weekKey] ??= {
        'healthy': 0,
        'processed': 0,
        'weekStart': weekStart.millisecondsSinceEpoch,
      };
      
      if (entry.type == FoodType.healthy) {
        weeklyStats[weekKey]!['healthy'] = weeklyStats[weekKey]!['healthy']! + 1;
      } else {
        weeklyStats[weekKey]!['processed'] = weeklyStats[weekKey]!['processed']! + 1;
      }
    }
    
    // Convert to list and sort by week (newest first)
    final statsList = weeklyStats.entries.map((entry) {
      final weekStart = DateTime.fromMillisecondsSinceEpoch(entry.value['weekStart']!);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final healthy = entry.value['healthy']!;
      final processed = entry.value['processed']!;
      final total = healthy + processed;
      
      return {
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'weekLabel': '${_formatDateShort(weekStart)} - ${_formatDateShort(weekEnd)}',
        'healthy': healthy,
        'processed': processed,
        'total': total,
        'healthyPercentage': total > 0 ? (healthy / total * 100).round() : 0,
      };
    }).toList();
    
    // Sort by week start (newest first)
    statsList.sort((a, b) => (b['weekStart'] as DateTime).compareTo(a['weekStart'] as DateTime));
    
    return statsList;
  }

  static DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = (date.weekday - 1) % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromMonday));
  }

  static String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}';
  }

  // Target goal percentage settings
  static Future<int> getTargetGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_targetGoalKey) ?? 80; // Default to 80%
  }

  static Future<void> setTargetGoal(int percentage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_targetGoalKey, percentage);
    FirebaseBackupService.triggerBackup();
  }

  // Get days until reset
  static Future<int> getDaysUntilReset() async {
    final frequency = await getResetFrequency();
    final now = DateTime.now();

    if (frequency == FoodTrackingResetFrequency.monthly) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      return nextMonth.difference(DateTime(now.year, now.month, now.day)).inDays;
    } else {
      // Weekly - calculate days until next Monday
      final daysUntilReset = 7 - now.weekday;
      return daysUntilReset == 0 ? 7 : daysUntilReset;
    }
  }
}