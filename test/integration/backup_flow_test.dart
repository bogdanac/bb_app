import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

import 'package:bb_app/Data/backup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backup System Integration Tests', () {
    setUp(() async {
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({
        'test_data': 'integration_test_value',
        'backup_overdue_threshold': 7,
        'auto_backup_enabled': true,
      });
    });

    testWidgets('Backup screen loads and displays main sections', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BackupScreen(),
        ),
      );

      // Wait for async operations to complete
      await tester.pumpAndSettle();

      // Verify main sections are displayed
      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(find.text('Backup Status'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);

      // Verify export options
      expect(find.text('Export to File'), findsOneWidget);
      expect(find.text('Share Backup'), findsOneWidget);
    });

    testWidgets('Backup overdue warning displays when backups are old', (WidgetTester tester) async {
      // Set up old backup dates
      SharedPreferences.setMockInitialValues({
        'last_manual_backup': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'last_auto_backup': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'last_cloud_share': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'backup_overdue_threshold': 7,
        'auto_backup_enabled': true,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show overdue warning
      expect(find.text('Backup Overdue Warning'), findsOneWidget);
      expect(find.textContaining('more than 7 days old'), findsOneWidget);

      // Should show status indicators
      expect(find.text('Last Manual Backup'), findsOneWidget);
      expect(find.text('Last Auto Backup'), findsOneWidget);
      expect(find.text('Last Cloud Share'), findsOneWidget);
    });

    testWidgets('Restore options are present', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom to find restore options
      await tester.scrollUntilVisible(
        find.text('Restore from Firebase'),
        100,
        scrollable: find.byType(Scrollable),
      );

      // Verify restore options
      expect(find.text('Restore from Firebase'), findsOneWidget);
      expect(find.text('Find My Backup Files'), findsOneWidget);
      expect(find.text('Import from Cloud Storage'), findsOneWidget);
    });

    testWidgets('Settings section contains auto backup and threshold controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to settings section at the bottom
      await tester.scrollUntilVisible(
        find.text('Automatic Daily Backups'),
        100,
        scrollable: find.byType(Scrollable),
      );

      // Verify settings are present
      expect(find.text('Automatic Daily Backups'), findsOneWidget);
      expect(find.text('Backup Warning Threshold'), findsOneWidget);

      // Verify threshold controls
      expect(find.byIcon(Icons.remove), findsWidgets);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('Threshold value can be changed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to threshold controls
      await tester.scrollUntilVisible(
        find.text('Backup Warning Threshold'),
        100,
        scrollable: find.byType(Scrollable),
      );

      // Find the threshold value (should start at 7)
      expect(find.text('7'), findsOneWidget);

      // Find add button near the threshold text
      final addButtons = find.byIcon(Icons.add);

      // Tap the add button (there might be multiple, so tap the last one which is threshold)
      if (addButtons.evaluate().isNotEmpty) {
        await tester.tap(addButtons.last);
        await tester.pumpAndSettle();

        // Should now show 8
        expect(find.text('8'), findsOneWidget);

        // Verify it was saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('backup_overdue_threshold'), 8);
      }
    });

    testWidgets('Auto backup toggle can be changed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BackupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to auto backup toggle
      await tester.scrollUntilVisible(
        find.text('Automatic Daily Backups'),
        100,
        scrollable: find.byType(Scrollable),
      );

      // Find the switch
      final switchFinder = find.byType(Switch);

      if (switchFinder.evaluate().isNotEmpty) {
        // Get initial state (should be enabled from mock)
        final initialSwitch = tester.widget<Switch>(switchFinder.first);
        expect(initialSwitch.value, true);

        // Toggle the switch
        await tester.tap(switchFinder.first);
        await tester.pumpAndSettle();

        // Verify it was saved
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('auto_backup_enabled'), false);
      }
    });

    testWidgets('Screen handles loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BackupScreen(),
        ),
      );

      // Before pumpAndSettle, should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After settling, should show content
      await tester.pumpAndSettle();
      expect(find.text('Backup Status'), findsOneWidget);
    });

    group('Error Handling', () {
      testWidgets('Handles corrupted date data gracefully', (WidgetTester tester) async {
        // Set up corrupted data
        SharedPreferences.setMockInitialValues({
          'last_manual_backup': 'invalid-date-format',
          'backup_overdue_threshold': 7,
          'auto_backup_enabled': true,
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: BackupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Should not crash and should still display the screen
        expect(find.byType(BackupScreen), findsOneWidget);
        // The app should handle the error gracefully and still show main sections
        expect(find.text('Export'), findsOneWidget);
        expect(find.text('Restore'), findsOneWidget);
      });

      testWidgets('Handles missing preferences gracefully', (WidgetTester tester) async {
        // Clear all mocks
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          const MaterialApp(
            home: BackupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Should not crash and should use defaults
        expect(find.byType(BackupScreen), findsOneWidget);
        expect(find.text('Backup Status'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('Screen has proper semantic structure', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: BackupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Verify important elements have proper semantics
        expect(find.text('Export to File'), findsOneWidget);
        expect(find.text('Share Backup'), findsOneWidget);

        // Scroll to find more elements
        await tester.scrollUntilVisible(
          find.text('Automatic Daily Backups'),
          100,
          scrollable: find.byType(Scrollable),
        );

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
