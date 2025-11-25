import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../shared/error_logger.dart';

class FastingUtils {
  // Fast type constants
  static const String weeklyFast = '24h weekly fast';
  static const String monthlyFast = '36h monthly fast';
  static const String quarterlyFast = '48h quarterly fast';
  static const String waterFast = '3-day water fast';

  // List of all fast types for dropdowns
  static const List<String> fastTypes = [
    weeklyFast,
    monthlyFast,
    quarterlyFast,
    waterFast,
  ];
  /// Format duration to readable string (e.g., "12h 30m")
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  /// Get duration for different fast types
  static Duration getFastDuration(String fastType) {
    switch (fastType) {
      case '24h weekly fast':
      case '24h':
        return const Duration(hours: 24);
      case '36h monthly fast':
      case '36h':
        return const Duration(hours: 36);
      case '48h quarterly fast':
      case '48h':
        return const Duration(hours: 48);
      case '3-day water fast':
      case '3-days':
        return const Duration(days: 3);
      default:
        return const Duration(hours: 24);
    }
  }

  /// Get recommended fast type based on scheduled fasts and completion status
  static Future<String> getRecommendedFastType() async {
    try {
      // Import here to avoid circular dependency issues
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      debugPrint('[FastingUtils] Checking recommendation for: $today');

      // First check if already completed a fast today
      List<String> historyStr;
      try {
        historyStr = prefs.getStringList('fasting_history') ?? [];
      } catch (e) {
        debugPrint('Warning: Fasting history data type mismatch, clearing corrupted data');
        await prefs.remove('fasting_history');
        historyStr = [];
      }
      debugPrint('[FastingUtils] History entries count: ${historyStr.length}');
      
      final todayHistory = historyStr.where((item) {
        try {
          final Map<String, dynamic> fast = Map<String, dynamic>.from(jsonDecode(item) as Map);
          final startTime = DateTime.parse(fast['startTime']);
          final startDate = DateTime(startTime.year, startTime.month, startTime.day);
          debugPrint('[FastingUtils] Checking history: $startDate vs $today');
          return startDate == today;
        } catch (e) {
          return false;
        }
      });

      // If already completed a fast today, don't recommend another
      if (todayHistory.isNotEmpty) {
        debugPrint('[FastingUtils] Fast already completed today, no recommendation');
        return '';
      }

      // Check scheduled fasts for today
      final scheduledFastingsJson = prefs.getString('scheduled_fastings');
      debugPrint('[FastingUtils] Scheduled fastings JSON: $scheduledFastingsJson');
      
      if (scheduledFastingsJson != null) {
        final List<dynamic> scheduledList = jsonDecode(scheduledFastingsJson);
        debugPrint('[FastingUtils] Scheduled fastings count: ${scheduledList.length}');
        
        for (final item in scheduledList) {
          final scheduledDate = DateTime.parse(item['date']);
          final scheduledDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
          final isEnabled = item['isEnabled'] ?? true;
          
          debugPrint('[FastingUtils] Checking scheduled: $scheduledDay vs $today, enabled: $isEnabled, type: ${item['fastType']}');
          
          if (scheduledDay == today && isEnabled) {
            debugPrint('[FastingUtils] Found scheduled fast for today: ${item['fastType']}');
            return item['fastType'] as String;
          }
        }
      }

      // If no scheduled fast found, return empty (no recommendation)
      debugPrint('[FastingUtils] No scheduled fast found for today');
      return '';
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FastingUtils.getRecommendedFastType',
        error: 'Error getting recommended fast type: $e',
        stackTrace: stackTrace.toString(),
      );
      return '';
    }
  }

  /// Calculate progress percentage
  static double getProgress(Duration elapsedTime, Duration totalDuration) {
    if (totalDuration.inMinutes <= 0) return 0.0;
    return (elapsedTime.inMinutes / totalDuration.inMinutes).clamp(0.0, 1.0);
  }

  /// Get the longest fast duration from history
  static String getLongestFast(List<Map<String, dynamic>> fastingHistory) {
    if (fastingHistory.isEmpty) return '0h 0m';

    int longestMinutes = 0;
    for (final fast in fastingHistory) {
      final actualDuration = fast['actualDuration'] as int? ?? 0;
      if (actualDuration > longestMinutes) {
        longestMinutes = actualDuration;
      }
    }

    final hours = longestMinutes ~/ 60;
    final minutes = longestMinutes % 60;
    return '${hours}h ${minutes}m';
  }

}