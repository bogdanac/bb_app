import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

import 'package:bb_app/Data/backup_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Backup System Integration Tests', () {
    setUp(() async {
      // Clear any existing preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Set up some test data
      await prefs.setString('test_data', 'integration_test_value');
      await prefs.setInt('backup_overdue_threshold', 7);
      await prefs.setBool('auto_backup_enabled', true);
    });

    testWidgets('Backup screen loads and displays status', (WidgetTester tester) async {
      // Test the backup screen directly rather than full navigation
      await tester.pumpWidget(
        MaterialApp(
          home: const BackupScreen(),
        ),
      );

      // Wait for async operations to complete
      await tester.pumpAndSettle();

      // Verify backup screen is displayed
      expect(find.text('Backup Status'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);

      // Verify threshold controls are present
      expect(find.text('Overdue Warning Threshold'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Backup overdue warning display', (WidgetTester tester) async {
      // Set up old backup dates
      final prefs = await SharedPreferences.getInstance();
      final oldDate = DateTime.now().subtract(const Duration(days: 10));
      await prefs.setString('last_manual_backup', oldDate.toIso8601String());
      await prefs.setString('last_auto_backup', oldDate.toIso8601String());
      await prefs.setString('last_cloud_share', oldDate.toIso8601String());
      await prefs.setInt('backup_overdue_threshold', 7);

      await tester.pumpWidget(
        MaterialApp(
          home: const BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show overdue warning in backup screen
      expect(find.text('Backup Overdue Warning'), findsOneWidget);
      expect(find.textContaining('more than 7 days old'), findsOneWidget);

      // Should show overdue indicators for each backup type
      expect(find.textContaining('⚠️'), findsAtLeastNWidgets(1));
    });

    testWidgets('Threshold customization affects warnings', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find current threshold value (should be 7 by default)
      expect(find.text('7'), findsOneWidget);

      // Increase threshold
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Should show updated threshold
      expect(find.text('8'), findsOneWidget);

      // Warning message should update too (if warning is shown)
      // Note: This only appears if there are actually overdue backups

      // Decrease threshold back
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Should be back to 7
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('Auto backup toggle persistence', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the auto backup switch
      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsOneWidget);

      // Get initial state (should be enabled)
      var switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, true);

      // Toggle the switch
      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      // Verify SharedPreferences was updated
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auto_backup_enabled'), false);

      // Create a new instance to verify persistence
      await tester.pumpWidget(
        MaterialApp(
          home: const BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch should still be off
      switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, false);
    });

    testWidgets('Import UI elements are present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify import options are available
      expect(find.text('Import from Cloud Storage'), findsOneWidget);
      expect(find.text('Find My Backup Files'), findsOneWidget);
    });

    testWidgets('Performance: Threshold changes are efficient', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Record current time
      final startTime = DateTime.now();

      // Change threshold multiple times rapidly
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump(const Duration(milliseconds: 50));
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Should complete quickly (under 2 seconds for 5 changes)
      expect(duration.inSeconds, lessThan(2));

      // Final threshold should be 12 (7 + 5)
      expect(find.text('12'), findsOneWidget);
    });

    group('Error Scenarios', () {
      testWidgets('Handle corrupted preferences data gracefully', (WidgetTester tester) async {
        // Set up corrupted data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_manual_backup', 'invalid-date');

        await tester.pumpWidget(
          MaterialApp(
            home: const BackupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Should handle corrupted data gracefully
        expect(find.text('Backup Status'), findsOneWidget);
        // Should not crash the app
        expect(find.byType(BackupScreen), findsOneWidget);
      });
    });

    group('Accessibility Integration', () {
      testWidgets('Backup screen is accessible', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const BackupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Test that semantic elements exist
        final semanticsFinder = find.byWidgetPredicate(
          (widget) => widget is Semantics,
        );

        expect(semanticsFinder, findsAtLeastNWidgets(1));

        // Verify important text elements are present (screen readers can access them)
        expect(find.text('Export to File'), findsOneWidget);
        expect(find.text('Automatic Daily Backups'), findsOneWidget);
      });
    });
  });
}

// Helper functions for integration tests
class BackupTestHelpers {
  static Future<String> createTestBackupFile() async {
    final testData = {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'fasting': {'test': 'data'},
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
    };

    final tempDir = Directory.systemTemp;
    final testFile = File('${tempDir.path}/test_backup.json');
    await testFile.writeAsString(json.encode(testData));
    return testFile.path;
  }

  static Future<String> createInvalidBackupFile() async {
    final invalidData = {
      'version': '2.0', // Incompatible version
      'timestamp': DateTime.now().toIso8601String(),
    };

    final tempDir = Directory.systemTemp;
    final testFile = File('${tempDir.path}/invalid_backup.json');
    await testFile.writeAsString(json.encode(invalidData));
    return testFile.path;
  }

  static Future<void> cleanupTestFiles() async {
    final tempDir = Directory.systemTemp;
    final testFiles = [
      File('${tempDir.path}/test_backup.json'),
      File('${tempDir.path}/invalid_backup.json'),
    ];

    for (final file in testFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}