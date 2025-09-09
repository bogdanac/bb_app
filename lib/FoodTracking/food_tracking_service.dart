import 'package:shared_preferences/shared_preferences.dart';
import 'food_tracking_data_models.dart';

class FoodTrackingService {
  static const String _entriesKey = 'food_entries';

  static Future<List<FoodEntry>> getAllEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_entriesKey) ?? [];
    
    return entriesJson
        .map((json) => FoodEntry.fromJsonString(json))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> addEntry(FoodEntry entry) async {
    final entries = await getAllEntries();
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
  }

  static Future<List<FoodEntry>> getEntriesForWeek(DateTime weekStart) async {
    final entries = await getAllEntries();
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    return entries.where((entry) =>
        entry.timestamp.isAtSameMomentAs(weekStart) ||
        (entry.timestamp.isAfter(weekStart) && entry.timestamp.isBefore(weekEnd))).toList();
  }

  static Future<List<FoodEntry>> getEntriesForDay(DateTime day) async {
    final entries = await getAllEntries();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    return entries.where((entry) =>
        entry.timestamp.isAfter(dayStart) &&
        entry.timestamp.isBefore(dayEnd)).toList();
  }

  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - 1) % 7;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
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
}