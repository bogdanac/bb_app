import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FastingUtils {
  /// Format duration to readable string (e.g., "12h 30m")
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  /// Get duration for different fast types
  static Duration getFastDuration(String fastType) {
    switch (fastType) {
      case '24h Weekly Fast':
      case '24h':
        return const Duration(hours: 24);
      case '36h Monthly Fast':
      case '36h':
        return const Duration(hours: 36);
      case '48h Quarterly Fast':
      case '48h':
        return const Duration(hours: 48);
      case '3-Day Water Fast':
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
      final historyStr = prefs.getStringList('fasting_history') ?? [];
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
    } catch (e) {
      debugPrint('Error getting recommended fast type: $e');
      return '';
    }
  }

  /// Synchronous version for backwards compatibility (deprecated - use async version)
  @Deprecated('Use getRecommendedFastType() async version instead')
  static String getRecommendedFastTypeSync() {
    final now = DateTime.now();
    final isFriday = now.weekday == 5;
    final is25th = now.day == 25;

    // Smart scheduling: combine Friday and 25th fasts when close
    if (isFriday || is25th) {
      return _getSmartFastRecommendation(now, isFriday, is25th);
    }

    return '';
  }

  /// Smart scheduling logic to avoid double fasts when Friday and 25th are close
  static String _getSmartFastRecommendation(DateTime now, bool isFriday, bool is25th) {
    // If today is the 25th, check if there was a recent Friday or upcoming Friday
    if (is25th) {
      final month = now.month;
      String longerFastType;
      if (month == 1 || month == 9) {
        longerFastType = '3-days';
      } else if (month % 3 == 1) {
        longerFastType = '48h';
      } else {
        longerFastType = '36h';
      }
      
      // Check if Friday was within the last 4-6 days or will be within next 4-6 days
      final daysUntilFriday = (5 - now.weekday + 7) % 7; // Days until next Friday (0 if today is Friday)
      final daysSinceLastFriday = now.weekday >= 5 ? now.weekday - 5 : now.weekday + 2; // Days since last Friday
      
      // If Friday is close (within 6 days either way), do the longer fast today
      if (daysSinceLastFriday <= 6 || daysUntilFriday <= 6) {
        return longerFastType; // Do the longer fast on the 25th
      }
      
      return longerFastType;
    }
    
    // If today is Friday, check if 25th is close
    if (isFriday) {
      final daysUntil25th = 25 - now.day;
      
      // If 25th is within 4-6 days (past or future), do the longer fast on Friday instead
      if ((daysUntil25th >= 0 && daysUntil25th <= 6) || (now.day < 25 && (25 - now.day) <= 6)) {
        final month = daysUntil25th >= 0 ? now.month : (now.month == 1 ? 12 : now.month - 1);
        
        // Use the appropriate longer fast type
        if (month == 1 || month == 9) {
          return '3-days';
        } else if (month % 3 == 1) {
          return '48h';
        } else {
          return '36h';
        }
      }
      
      return '24h'; // Normal Friday fast
    }
    
    return '';
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