import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/shared/error_logger.dart';
import 'dart:convert';
import '../helpers/firebase_mock_helper.dart';

void main() {
  group('ErrorLogger Tests', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    test('Local logs should be saved when logging an error', () async {
      await ErrorLogger.logError(
        source: 'TestSource',
        error: 'Test error message',
        stackTrace: 'Test stack trace',
        context: {'key': 'value'},
      );

      final logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 1);
      expect(logs[0]['source'], 'TestSource');
      expect(logs[0]['error'], 'Test error message');
      expect(logs[0]['stackTrace'], 'Test stack trace');
      expect(logs[0]['context']['key'], 'value');
    });

    test('Local logs should maintain order (newest first)', () async {
      await ErrorLogger.logError(source: 'Test', error: 'Error 1');
      await ErrorLogger.logError(source: 'Test', error: 'Error 2');
      await ErrorLogger.logError(source: 'Test', error: 'Error 3');

      final logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 3);
      expect(logs[0]['error'], 'Error 3'); // Newest first
      expect(logs[1]['error'], 'Error 2');
      expect(logs[2]['error'], 'Error 1'); // Oldest last
    });

    test('Local logs should be limited to max count', () async {
      // Add 510 logs (over the 500 limit)
      for (int i = 0; i < 510; i++) {
        await ErrorLogger.logError(
          source: 'Test',
          error: 'Error $i',
        );
      }

      final logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, lessThanOrEqualTo(500));

      // Verify newest logs are kept
      expect(logs[0]['error'], 'Error 509');
      expect(logs[1]['error'], 'Error 508');
    });

    test('Old local logs should be cleaned up after 7 days', () async {
      final prefs = await SharedPreferences.getInstance();

      // Create logs with different timestamps
      final now = DateTime.now();
      final eightDaysAgo = now.subtract(const Duration(days: 8));
      final sixDaysAgo = now.subtract(const Duration(days: 6));

      final oldLog = {
        'source': 'Test',
        'error': 'Old error',
        'timestamp': eightDaysAgo.toIso8601String(),
        'platform': 'android',
      };

      final recentLog = {
        'source': 'Test',
        'error': 'Recent error',
        'timestamp': sixDaysAgo.toIso8601String(),
        'platform': 'android',
      };

      // Manually add 501 logs to trigger cleanup (1 old, 500 recent)
      final logsList = <String>[];
      logsList.add(jsonEncode(oldLog));
      for (int i = 0; i < 500; i++) {
        logsList.add(jsonEncode(recentLog));
      }

      await prefs.setStringList('error_logs_local', logsList);

      // Add a new log to trigger cleanup
      await ErrorLogger.logError(source: 'Test', error: 'New error');

      final logs = await ErrorLogger.getLocalLogs();

      // Old log should be filtered out during cleanup
      expect(logs.any((log) => log['error'] == 'Old error'), false);
      expect(logs.any((log) => log['error'] == 'New error'), true);
    });

    test('Unparseable logs should be kept during cleanup', () async {
      final prefs = await SharedPreferences.getInstance();

      // Create 501 logs: 1 unparseable, 500 valid
      final logsList = <String>[];
      logsList.add('invalid json {{{');

      for (int i = 0; i < 500; i++) {
        final log = {
          'source': 'Test',
          'error': 'Error $i',
          'timestamp': DateTime.now().toIso8601String(),
          'platform': 'android',
        };
        logsList.add(jsonEncode(log));
      }

      await prefs.setStringList('error_logs_local', logsList);

      // Add a new log to trigger cleanup
      await ErrorLogger.logError(source: 'Test', error: 'New error');

      final savedLogs = prefs.getStringList('error_logs_local') ?? [];

      // Unparseable log should still be present
      expect(savedLogs.contains('invalid json {{{'), true);
    });

    test('clearLocalLogs should remove all local logs', () async {
      await ErrorLogger.logError(source: 'Test', error: 'Error 1');
      await ErrorLogger.logError(source: 'Test', error: 'Error 2');

      var logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 2);

      await ErrorLogger.clearLocalLogs();

      logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 0);
    });

    test('getLocalLogs should handle corrupted data gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('error_logs_local', ['invalid json', '{{}']);

      final logs = await ErrorLogger.getLocalLogs();

      // Should return empty list instead of throwing
      expect(logs, isEmpty);
    });

    test('logWidgetError should include task counts in context', () async {
      await ErrorLogger.logWidgetError(
        error: 'Widget failed',
        stackTrace: 'Stack trace here',
        taskCount: 10,
        filteredCount: 8,
        prioritizedCount: 5,
      );

      final logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 1);
      expect(logs[0]['source'], 'TaskListWidgetFilterService');
      expect(logs[0]['error'], 'Widget failed');
      expect(logs[0]['context']['taskCount'], 10);
      expect(logs[0]['context']['filteredCount'], 8);
      expect(logs[0]['context']['prioritizedCount'], 5);
    });

    test('Multiple rapid logs should all be saved', () async {
      // Simulate rapid error logging
      await Future.wait([
        ErrorLogger.logError(source: 'Test', error: 'Error 1'),
        ErrorLogger.logError(source: 'Test', error: 'Error 2'),
        ErrorLogger.logError(source: 'Test', error: 'Error 3'),
        ErrorLogger.logError(source: 'Test', error: 'Error 4'),
        ErrorLogger.logError(source: 'Test', error: 'Error 5'),
      ]);

      final logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 5);
    });

    test('uploadWidgetDebugLogs should clear logs after reading', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter.widget_debug_logs', '[{"test": "log"}]');

      // Upload will fail (no Firebase in tests) but should still clear
      await ErrorLogger.uploadWidgetDebugLogs();

      final remaining = prefs.getString('flutter.widget_debug_logs');
      expect(remaining, isNull);
    });

    test('uploadWidgetDebugLogs should not clear empty logs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter.widget_debug_logs', '[]');

      await ErrorLogger.uploadWidgetDebugLogs();

      // Empty logs should not trigger upload, so key should remain
      final remaining = prefs.getString('flutter.widget_debug_logs');
      expect(remaining, '[]');
    });

    test('Logging should handle null context gracefully', () async {
      await ErrorLogger.logError(
        source: 'Test',
        error: 'Error',
        context: null,
      );

      final logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 1);
      expect(logs[0]['context'], isNull);
    });

    test('Logging should handle null stackTrace gracefully', () async {
      await ErrorLogger.logError(
        source: 'Test',
        error: 'Error',
        stackTrace: null,
      );

      final logs = await ErrorLogger.getLocalLogs();
      expect(logs.length, 1);
      expect(logs[0]['stackTrace'], isNull);
    });
  });
}
