import 'package:shared_preferences/shared_preferences.dart';
import '../Notifications/centralized_notification_manager.dart';

class CycleCalculationUtils {
  /// Calculate average cycle length from period history
  /// Returns the calculated average or the default value if no valid cycles exist
  static Future<int> calculateAverageCycleLength({
    required List<Map<String, dynamic>> periodRanges,
    DateTime? currentActivePeriodStart,
    int defaultValue = 30,
  }) async {
    final cycles = <int>[];

    // For the first period, assume a default cycle of 30 days before it
    if (periodRanges.isNotEmpty) {
      cycles.add(defaultValue);
    }

    // Calculate cycles between completed periods in history
    for (int i = 1; i < periodRanges.length; i++) {
      final DateTime startCurrent = periodRanges[i]['start'] as DateTime;
      final DateTime startPrevious = periodRanges[i - 1]['start'] as DateTime;
      final cycleLength = startCurrent.difference(startPrevious).inDays;
      if (cycleLength > 15 && cycleLength < 45) {
        cycles.add(cycleLength);
      }
    }

    // Include cycle from last completed period to current active period
    if (periodRanges.isNotEmpty && currentActivePeriodStart != null) {
      final lastCompletedPeriod = periodRanges.last;
      final DateTime lastCompletedStart = lastCompletedPeriod['start'] as DateTime;
      final currentCycleLength = currentActivePeriodStart.difference(lastCompletedStart).inDays;

      // Add it if it's a valid cycle length
      if (currentCycleLength > 15 && currentCycleLength < 45) {
        cycles.add(currentCycleLength);
      }
    }

    // Calculate average if we have valid cycles
    if (cycles.isNotEmpty) {
      final calculatedAverage = (cycles.reduce((a, b) => a + b) / cycles.length).round();
      return calculatedAverage > 0 ? calculatedAverage : defaultValue;
    }

    return defaultValue;
  }

  /// Load period ranges from SharedPreferences
  static Future<List<Map<String, DateTime>>> loadPeriodRanges() async {
    final prefs = await SharedPreferences.getInstance();
    final rangesStr = prefs.getStringList('period_ranges') ?? [];

    return rangesStr.map((range) {
      final parts = range.split('|');
      return {
        'start': DateTime.parse(parts[0]),
        'end': DateTime.parse(parts[1]),
      };
    }).toList();
  }

  /// Load current active period start date from SharedPreferences
  static Future<DateTime?> loadActivePeriodStart() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStartStr = prefs.getString('last_period_start');
    return lastStartStr != null ? DateTime.parse(lastStartStr) : null;
  }

  /// Reschedule cycle notifications (ovulation and period reminders)
  /// Call this whenever cycle data changes (new period, edit history, etc.)
  static Future<void> rescheduleCycleNotifications() async {
    final notificationManager = CentralizedNotificationManager();
    await notificationManager.forceRescheduleAll();
  }
}
