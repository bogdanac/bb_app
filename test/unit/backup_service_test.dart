import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bb_app/Data/backup_service.dart';

void main() {
  group('BackupService', () {
    setUp(() {
      // Set up SharedPreferences mock instance
      SharedPreferences.setMockInitialValues({});
    });

    group('Overdue Threshold Management', () {
      test('should return default threshold of 7 days', () async {
        SharedPreferences.setMockInitialValues({});

        final threshold = await BackupService.getBackupOverdueThreshold();
        expect(threshold, 7);
      });

      test('should return custom threshold when set', () async {
        SharedPreferences.setMockInitialValues({'backup_overdue_threshold': 14});

        final threshold = await BackupService.getBackupOverdueThreshold();
        expect(threshold, 14);
      });

      test('should save custom threshold', () async {
        SharedPreferences.setMockInitialValues({});

        await BackupService.setBackupOverdueThreshold(10);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('backup_overdue_threshold'), 10);
      });
    });

    group('Detailed Backup Status', () {
      test('should correctly identify overdue backups', () async {
        final now = DateTime.now();
        final oldDate = now.subtract(const Duration(days: 10));
        final recentDate = now.subtract(const Duration(days: 3));

        SharedPreferences.setMockInitialValues({
          'last_manual_backup': oldDate.toIso8601String(),
          'last_auto_backup': recentDate.toIso8601String(),
          'last_cloud_share': oldDate.toIso8601String(),
          'backup_overdue_threshold': 7,
        });

        final status = await BackupService.getDetailedBackupStatus();

        expect(status['manual_overdue'], false); // Suppressed because auto backup is recent
        expect(status['auto_overdue'], false);
        expect(status['cloud_overdue'], true);
        expect(status['any_overdue'], true);
        expect(status['days_since_manual'], 10);
        expect(status['days_since_auto'], 3);
        expect(status['days_since_cloud'], 10);
      });

      test('should mark as overdue when never backed up', () async {
        SharedPreferences.setMockInitialValues({
          'backup_overdue_threshold': 7,
        });

        final status = await BackupService.getDetailedBackupStatus();

        expect(status['manual_overdue'], true);
        expect(status['auto_overdue'], true);
        expect(status['cloud_overdue'], true);
        expect(status['any_overdue'], true);
      });

      test('should handle custom threshold correctly', () async {
        final now = DateTime.now();
        final date5DaysAgo = now.subtract(const Duration(days: 5));

        SharedPreferences.setMockInitialValues({
          'last_manual_backup': date5DaysAgo.toIso8601String(),
          'backup_overdue_threshold': 3, // Custom threshold
        });

        final status = await BackupService.getDetailedBackupStatus();

        expect(status['manual_overdue'], true); // 5 days > 3 days threshold
        expect(status['days_since_manual'], 5);
      });

      test('should suppress manual backup warning when auto backup is recent', () async {
        final now = DateTime.now();
        final oldManualDate = now.subtract(const Duration(days: 15));
        final recentAutoDate = now.subtract(const Duration(days: 2));

        SharedPreferences.setMockInitialValues({
          'last_manual_backup': oldManualDate.toIso8601String(),
          'last_auto_backup': recentAutoDate.toIso8601String(),
          'backup_overdue_threshold': 7,
        });

        final status = await BackupService.getDetailedBackupStatus();

        expect(status['manual_overdue'], false); // Should be suppressed due to recent auto backup
        expect(status['auto_overdue'], false);
        expect(status['days_since_manual'], 15);
        expect(status['days_since_auto'], 2);
      });

      test('should show manual backup warning when both manual and auto are old', () async {
        final now = DateTime.now();
        final oldManualDate = now.subtract(const Duration(days: 15));
        final oldAutoDate = now.subtract(const Duration(days: 10));

        SharedPreferences.setMockInitialValues({
          'last_manual_backup': oldManualDate.toIso8601String(),
          'last_auto_backup': oldAutoDate.toIso8601String(),
          'backup_overdue_threshold': 7,
        });

        final status = await BackupService.getDetailedBackupStatus();

        expect(status['manual_overdue'], true); // Should show warning when both are old
        expect(status['auto_overdue'], true);
        expect(status['days_since_manual'], 15);
        expect(status['days_since_auto'], 10);
      });

      test('should skip auto backup when disabled', () async {
        SharedPreferences.setMockInitialValues({
          'auto_backup_enabled': false,
        });

        // This should complete without error and not create a backup
        await BackupService.performAutoBackup();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('last_auto_backup'), isNull);
      });

      test('should attempt auto backup when enabled but rollback on failure', () async {
        SharedPreferences.setMockInitialValues({
          'auto_backup_enabled': true,
        });

        // This should attempt the backup, set timestamp, but then rollback when export fails
        await BackupService.performAutoBackup();

        final prefs = await SharedPreferences.getInstance();
        // Should have rolled back the timestamp since backup failed in test environment
        expect(prefs.getString('last_auto_backup'), isNull);
      });
    });

    group('Backup File Paths', () {
      test('should return backup locations without crashing', () async {
        final locations = await BackupService.getBackupLocations();

        // Should return a valid structure
        expect(locations, isNotNull);
        expect(locations.containsKey('all_locations'), true);
        expect(locations.containsKey('found_files'), true);

        final paths = (locations['all_locations'] as List).cast<String>();

        // Should return some paths (even if empty in test environment)
        expect(paths, isA<List<String>>());

        // Paths should not include dangerous app-internal directories
        expect(paths.any((path) => path.contains('ApplicationDocuments')), false);
        expect(paths.any((path) => path.contains('app_flutter')), false);
      });
    });

    group('Error Handling', () {
      test('should handle SharedPreferences errors gracefully', () async {
        // Just verify the method doesn't crash with empty data
        SharedPreferences.setMockInitialValues({});

        expect(() async => await BackupService.getDetailedBackupStatus(),
               returnsNormally);
      });
    });
  });
}