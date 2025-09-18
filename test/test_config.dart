import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test configuration and utilities for backup system tests
class BackupTestConfig {
  /// Set up common test environment
  static Future<void> setUp() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Set mock initial values for SharedPreferences
    SharedPreferences.setMockInitialValues({
      'auto_backup_enabled': true,
      'backup_overdue_threshold': 7,
    });
  }

  /// Clean up after tests
  static Future<void> tearDown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Create mock backup status data for testing
  static Map<String, dynamic> createMockBackupStatus({
    bool anyOverdue = false,
    int daysSinceManual = 3,
    int daysSinceAuto = 1,
    int daysSinceCloud = 5,
  }) {
    final now = DateTime.now();

    return {
      'last_manual_backup': daysSinceManual > 0
          ? now.subtract(Duration(days: daysSinceManual)).toIso8601String()
          : null,
      'last_auto_backup': daysSinceAuto > 0
          ? now.subtract(Duration(days: daysSinceAuto)).toIso8601String()
          : null,
      'last_cloud_share': daysSinceCloud > 0
          ? now.subtract(Duration(days: daysSinceCloud)).toIso8601String()
          : null,
      'manual_overdue': daysSinceManual > 7,
      'auto_overdue': daysSinceAuto > 7,
      'cloud_overdue': daysSinceCloud > 7,
      'any_overdue': anyOverdue,
      'days_since_manual': daysSinceManual,
      'days_since_auto': daysSinceAuto,
      'days_since_cloud': daysSinceCloud,
    };
  }

  /// Create mock backup info data for testing
  static Map<String, dynamic> createMockBackupInfo() {
    return {
      'total_items': 150,
      'backup_size_kb': 45,
      'last_backup_time': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'categories': {
        'fasting': 5,
        'menstrual_cycle': 8,
        'tasks': 25,
        'task_categories': 3,
        'routines': 10,
        'habits': 15,
        'food_tracking': 30,
        'water_tracking': 20,
        'notifications': 12,
        'settings': 10,
        'app_preferences': 7,
      },
    };
  }

  /// Create a valid backup data structure for testing
  static Map<String, dynamic> createValidBackupData() {
    return {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'fasting': {
        'fasting_current_start': DateTime.now().subtract(const Duration(hours: 16)).toIso8601String(),
        'fasting_goal_hours': '16',
      },
      'menstrual_cycle': {
        'cycle_length': '28',
        'period_length': '5',
      },
      'tasks': {
        'task_daily_items': '[]',
        'task_completed_today': '0',
      },
      'task_categories': {
        'task_categories': '["Work", "Personal", "Health"]',
      },
      'routines': {
        'routine_morning': '{"enabled": true, "tasks": []}',
      },
      'habits': {
        'habit_exercise': 'true',
        'habit_meditation': 'false',
      },
      'food_tracking': {
        'food_entries': '[]',
        'daily_calories': '2000',
      },
      'water_tracking': {
        'water_intake': '2000',
        'water_goal': '2500',
      },
      'notifications': {
        'notification_enabled': 'true',
        'notification_time': '09:00',
      },
      'settings': {
        'backup_overdue_threshold': '7',
        'last_manual_backup': DateTime.now().toIso8601String(),
      },
      'app_preferences': {
        'app_theme': 'dark',
        'language': 'en',
      },
    };
  }

  /// Create an invalid backup data structure for testing
  static Map<String, dynamic> createInvalidBackupData({
    bool missingVersion = false,
    bool wrongVersion = false,
    bool invalidTimestamp = false,
    bool missingCategories = false,
  }) {
    final data = <String, dynamic>{};

    if (!missingVersion) {
      data['version'] = wrongVersion ? '2.0' : '1.0';
    }

    if (!invalidTimestamp) {
      data['timestamp'] = DateTime.now().toIso8601String();
    } else {
      data['timestamp'] = 'invalid-timestamp';
    }

    if (!missingCategories) {
      data.addAll({
        'fasting': {},
        'menstrual_cycle': {},
        'tasks': {},
        'task_categories': {},
        'routines': {},
        'habits': {},
        'food_tracking': {},
        'water_tracking': {},
        'notifications': {},
        'settings': {},
        'app_preferences': {},
      });
    }

    return data;
  }
}

/// Custom matchers for backup testing
class BackupMatchers {
  /// Matcher for valid backup structure
  static Matcher isValidBackupStructure() {
    return predicate<Map<String, dynamic>>((data) {
      final requiredFields = ['version', 'timestamp'];
      final requiredCategories = [
        'fasting', 'menstrual_cycle', 'tasks', 'task_categories',
        'routines', 'habits', 'food_tracking', 'water_tracking',
        'notifications', 'settings', 'app_preferences'
      ];

      // Check required fields
      for (final field in requiredFields) {
        if (!data.containsKey(field)) return false;
      }

      // Check required categories
      for (final category in requiredCategories) {
        if (!data.containsKey(category)) return false;
      }

      // Validate version
      if (data['version'] != '1.0') return false;

      // Validate timestamp
      try {
        DateTime.parse(data['timestamp']);
      } catch (e) {
        return false;
      }

      return true;
    }, 'is a valid backup structure');
  }

  /// Matcher for overdue backup status
  static Matcher isOverdueBackupStatus() {
    return predicate<Map<String, dynamic>>((status) {
      return status.containsKey('any_overdue') &&
             status['any_overdue'] == true;
    }, 'indicates overdue backup status');
  }

  /// Matcher for recent backup status
  static Matcher isRecentBackupStatus() {
    return predicate<Map<String, dynamic>>((status) {
      return status.containsKey('any_overdue') &&
             status['any_overdue'] == false;
    }, 'indicates recent backup status');
  }
}