import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupService {
  static const String _backupFileName = 'bbetter_backup';

  // ===================================================================
  // CENTRALIZED BACKUP PATHS - NEVER HARDCODE PATHS ANYWHERE ELSE!!!
  // ===================================================================
  // ALL backup paths MUST come from these centralized variables.
  // If you need to change backup location, change ONLY these constants.
  // If you hardcode a path anywhere else, you will be fired! 🔥
  // ===================================================================

  static const String _externalDownloadsPath = '/storage/emulated/0/Download';
  static const String _backupFolderName = 'BBetter_Backups';

  /// Get the main backup directory path (external Downloads/BBetter_Backups)
  /// USE THIS for all backup operations! Never hardcode paths!
  static String get backupDirectoryPath => '$_externalDownloadsPath/$_backupFolderName';

  /// Get the external Downloads directory path
  /// USE THIS for fallback searches! Never hardcode paths!
  static String get externalDownloadsPath => _externalDownloadsPath;

  /// Get the backup directory (creates it if it doesn't exist)
  static Future<Directory> getBackupDirectory() async {
    final backupDir = Directory(backupDirectoryPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }
  
  // Comprehensive backup data structure
  static Future<Map<String, dynamic>> _getAllAppData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    // Smart categorization of data
    final Map<String, dynamic> backupData = {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'fasting': {},
      'menstrual_cycle': {},
      'friends': {},
      'tasks': {},
      'task_categories': {},
      'routines': {},
      'habits': {},
      'food_tracking': {},
      'water_tracking': {},
      'timers': {},
      'notifications': {},
      'settings': {},
      'app_preferences': {},
    };
    
    // Process all SharedPreferences keys intelligently
    for (String key in allKeys) {
      final value = _getPreferenceValue(prefs, key);
      
      if (key.startsWith('fasting_') || key.contains('fast') || key == 'is_fasting' || key.startsWith('current_fast_') || key == 'scheduled_fastings') {
        backupData['fasting'][key] = value;
      } else if (key.startsWith('menstrual_') || key.contains('cycle') || key.contains('period') || key.startsWith('last_period_') || key == 'average_cycle_length' || key == 'period_ranges' || key == 'intercourse_records') {
        backupData['menstrual_cycle'][key] = value;
      } else if (key == 'circle_of_friends' || key.startsWith('friend_') || key.contains('friends')) {
        backupData['friends'][key] = value;
      } else if (key.startsWith('task') || key.contains('todo') || key.contains('priority') || key.contains('categor') || key == 'task_categories') {
        if (key.contains('categor') || key == 'task_categories') {
          backupData['task_categories'][key] = value;
        } else {
          backupData['tasks'][key] = value;
        }
      } else if (key.startsWith('routine') || key.contains('morning') || key.startsWith('routines')) {
        backupData['routines'][key] = value;
      } else if (key == 'habits' || key.startsWith('habit')) {
        backupData['habits'][key] = value;
      } else if (key.startsWith('food_') || key.contains('food') || key == 'food_entries') {
        backupData['food_tracking'][key] = value;
      } else if (key.startsWith('water_') || key.contains('water') || key == 'last_water_reset_date') {
        backupData['water_tracking'][key] = value;
      } else if (key.startsWith('timer_')) {
        backupData['timers'][key] = value;
      } else if (key.contains('notification') || key.contains('alarm') || key.contains('reminder') || key.endsWith('_enabled') || key.endsWith('_hour') || key.endsWith('_minute')) {
        backupData['notifications'][key] = value;
      } else if (key.contains('settings') || key.contains('config') || key == 'last_auto_backup' || key == 'last_backup' || key == 'backup_overdue_threshold' || key == 'last_manual_backup' || key == 'last_cloud_share') {
        backupData['settings'][key] = value;
      } else {
        // Catch-all for other important app preferences
        backupData['app_preferences'][key] = value;
      }
    }
    
    return backupData;
  }
  
  static dynamic _getPreferenceValue(SharedPreferences prefs, String key) {
    // Try different types to get the actual value
    try {
      return prefs.getString(key);
    } catch (e) {
      try {
        return prefs.getInt(key);
      } catch (e) {
        try {
          return prefs.getDouble(key);
        } catch (e) {
          try {
            return prefs.getBool(key);
          } catch (e) {
            try {
              return prefs.getStringList(key);
            } catch (e) {
              return null;
            }
          }
        }
      }
    }
  }
  
  // Export to local file
  static Future<String?> exportToFile({bool updateLastBackupTime = true}) async {
    try {
      // Request storage permission for Android - ALWAYS request for external storage
      if (Platform.isAndroid) {
        // For Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE
        var status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Fallback to regular storage permission for older Android versions
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Storage permission denied. Backups require external storage access to survive app uninstalls.');
          }
        }
      }

      // Update backup timestamps BEFORE creating backup data so they're included
      if (updateLastBackupTime) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final timestamp = DateTime.now().toIso8601String();

          // Update manual backup timestamp before creating backup data
          await prefs.setString('last_backup', timestamp);
          await prefs.setString('last_manual_backup', timestamp);
          await prefs.reload(); // Ensure changes are applied
        } catch (e) {
          debugPrint('Error updating backup timestamp before backup: $e');
        }
      }

      // Get app data (now includes the updated timestamps)
      final backupData = await _getAllAppData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      
      // Create file name with readable timestamp  
      final timestamp = DateFormat('yyyy-MM-dd HH.mm').format(DateTime.now());
      final fileName = '$timestamp - $_backupFileName.json';
      
      // Get appropriate directory
      Directory? directory;
      
      try {
        if (Platform.isAndroid) {
          // Use centralized backup directory - external storage that survives uninstalls
          directory = await getBackupDirectory();
        } else {
          // For other platforms - use external storage if available
          throw Exception('Backups are only supported on Android. External storage path required.');
        }
      } catch (e) {
        // No dangerous fallbacks - let it fail with clear error message
        rethrow;
      }
      
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(jsonString);

      // Validate backup file was created correctly
      if (!await file.exists()) {
        throw Exception('Backup file was not created successfully');
      }

      // Validate backup file is readable and contains expected data
      try {
        final validationContent = await file.readAsString();
        final validationData = json.decode(validationContent);
        if (validationData['version'] == null || validationData['timestamp'] == null) {
          throw Exception('Backup file is corrupted - missing required fields');
        }
      } catch (e) {
        throw Exception('Backup file validation failed: $e');
      }

      // Backup timestamp was already updated before creating backup data
      // No need to update again here
      
      // Clean up old backups after successful export
      try {
        final locations = await getBackupLocations();
        await _cleanupOldBackups(locations['found_files']);
      } catch (e) {
        debugPrint('Cleanup after backup export failed: $e');
      }
      
      return file.path;
      
    } catch (e, stackTrace) {
      debugPrint('Error exporting backup: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
  
  // Import from file with detailed error reporting
  static Future<Map<String, dynamic>> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'error': 'Backup file not found at: $filePath'};
      }
      
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) {
        return {'success': false, 'error': 'Backup file is empty'};
      }
      
      final backupData = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate backup format and version compatibility
      if (!backupData.containsKey('version') || !backupData.containsKey('timestamp')) {
        return {'success': false, 'error': 'Invalid backup file format - missing version or timestamp'};
      }

      // Check version compatibility
      final backupVersion = backupData['version'].toString();
      if (backupVersion != '1.0') {
        return {'success': false, 'error': 'Incompatible backup version: $backupVersion. This app supports version 1.0.'};
      }

      // Validate backup timestamp
      try {
        DateTime.parse(backupData['timestamp']);
      } catch (e) {
        return {'success': false, 'error': 'Invalid backup timestamp format'};
      }

      // Validate backup contains expected categories
      final expectedCategories = ['fasting', 'menstrual_cycle', 'friends', 'tasks', 'task_categories', 'routines', 'habits', 'food_tracking', 'water_tracking', 'notifications', 'settings', 'app_preferences'];
      for (String category in expectedCategories) {
        if (!backupData.containsKey(category)) {
          return {'success': false, 'error': 'Backup file is incomplete - missing category: $category'};
        }
      }

      final prefs = await SharedPreferences.getInstance();
      int restoredCount = 0;
      List<String> errors = [];

      // Restore each category
      for (String category in ['fasting', 'menstrual_cycle', 'friends', 'tasks', 'task_categories', 'routines', 'habits', 'food_tracking', 'water_tracking', 'timers', 'notifications', 'settings', 'app_preferences']) {
        if (backupData.containsKey(category)) {
          final categoryData = backupData[category] as Map<String, dynamic>;
          for (String key in categoryData.keys) {
            try {
              final value = categoryData[key];
              await _setPreferenceValue(prefs, key, value);
              restoredCount++;
            } catch (e) {
              errors.add('Failed to restore $key: $e');
              debugPrint('Failed to restore $key: $e');
            }
          }
        }
      }
      
      debugPrint('Backup restored successfully from: $filePath ($restoredCount items)');
      return {
        'success': true, 
        'restored_count': restoredCount,
        'errors': errors,
        'backup_timestamp': backupData['timestamp']
      };
      
    } catch (e, stackTrace) {
      debugPrint('Error importing backup: $e');
      debugPrint('Stack trace: $stackTrace');
      return {'success': false, 'error': 'Failed to import backup: $e'};
    }
  }
  
  static Future<void> _setPreferenceValue(SharedPreferences prefs, String key, dynamic value) async {
    if (value == null) return;
    
    try {
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List) {
        // Handle different list types
        if (value.isEmpty || value.first is String) {
          // Handle empty lists and string lists
          await prefs.setStringList(key, value.cast<String>());
        } else {
          // Convert complex lists to JSON string
          await prefs.setString(key, json.encode(value));
        }
      } else {
        // Convert complex objects to JSON string
        await prefs.setString(key, json.encode(value));
      }
    } catch (e) {
      debugPrint('Failed to set preference $key with value $value: $e');
      // Try as string fallback
      try {
        await prefs.setString(key, value.toString());
      } catch (e2) {
        debugPrint('Failed string fallback for $key: $e2');
        rethrow;
      }
    }
  }
  
  // Auto backup (called periodically) - now daily
  static Future<void> performAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if auto backup is enabled
      final autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;
      if (!autoBackupEnabled) {
        debugPrint('Auto backup skipped - disabled by user');
        return;
      }

      final lastBackup = prefs.getString('last_auto_backup');
      final now = DateTime.now();

      // Check if we need to backup (every 1 day)
      if (lastBackup != null) {
        final lastBackupDate = DateTime.parse(lastBackup);
        final daysSinceBackup = now.difference(lastBackupDate).inDays;
        if (daysSinceBackup < 1) {
          debugPrint('Auto backup skipped - too recent (last: $lastBackup)');
          return;
        }
      }

      // Update auto backup timestamp BEFORE creating backup so it's included in the backup data
      await prefs.setString('last_auto_backup', now.toIso8601String());
      await prefs.reload(); // Ensure timestamp is applied

      // Perform backup (without updating manual backup timestamps)
      final backupPath = await exportToFile(updateLastBackupTime: false);
      if (backupPath != null) {
        debugPrint('Daily auto backup completed: $backupPath');
      } else {
        debugPrint('Daily auto backup failed - likely storage permission issue');
        // Rollback auto backup timestamp if backup failed
        await prefs.remove('last_auto_backup');
        if (lastBackup != null) {
          await prefs.setString('last_auto_backup', lastBackup); // Restore previous timestamp
        }
      }

    } catch (e) {
      debugPrint('Daily auto backup failed: $e');
    }
  }

  // Check and perform auto backup on app startup
  static Future<void> checkStartupAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;

      if (!autoBackupEnabled) {
        debugPrint('Startup auto backup skipped - disabled by user');
        return;
      }

      final now = DateTime.now();
      final lastAutoBackup = prefs.getString('last_auto_backup');

      // Check if we should do backup (once per day)
      bool shouldBackup = false;

      if (lastAutoBackup == null) {
        // Never backed up automatically
        shouldBackup = true;
        debugPrint('Auto backup needed - never backed up');
      } else {
        final lastBackupDate = DateTime.parse(lastAutoBackup);
        final daysSinceBackup = now.difference(lastBackupDate).inDays;

        if (daysSinceBackup >= 1) {
          shouldBackup = true;
          debugPrint('Auto backup needed - $daysSinceBackup days since last backup');
        }
      }

      if (shouldBackup) {
        debugPrint('Performing startup auto backup...');
        await performAutoBackup();
      } else {
        debugPrint('Auto backup not needed - recent backup exists');
      }
    } catch (e) {
      debugPrint('Error in startup auto backup check: $e');
    }
  }
  
  // Manual trigger for daily backup
  static Future<String?> performDailyBackup() async {
    try {
      final backupPath = await exportToFile();
      if (backupPath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_auto_backup', DateTime.now().toIso8601String());
        await prefs.reload(); // Ensure timestamp is persisted
        debugPrint('Manual daily backup completed: $backupPath');
      }
      return backupPath;
    } catch (e) {
      debugPrint('Manual daily backup failed: $e');
      return null;
    }
  }
  
  
  // Get all possible backup locations and existing files
  static Future<Map<String, dynamic>> getBackupLocations() async {
    Map<String, dynamic> locations = {
      'current_location': null,
      'all_locations': [],
      'found_files': [],
    };
    
    try {
      if (Platform.isAndroid) {
        List<String> possiblePaths = [];
        
        // Use centralized backup paths
        try {
          final bbetterBackupsDir = Directory(backupDirectoryPath);
          final downloadsDir = Directory(externalDownloadsPath);

          possiblePaths.add(backupDirectoryPath);
          possiblePaths.add(externalDownloadsPath);

          if (await bbetterBackupsDir.exists()) {
            locations['current_location'] = backupDirectoryPath;
          } else if (await downloadsDir.exists()) {
            locations['current_location'] = externalDownloadsPath;
          }
        } catch (e) {
          debugPrint('Could not check external Downloads: $e');
        }
        
        locations['all_locations'] = possiblePaths;
        
        // Search for backup files in all locations
        for (String path in possiblePaths) {
          try {
            final dir = Directory(path);
            if (await dir.exists()) {
              final files = await dir.list().toList();
              for (var file in files) {
                if (file is File && file.path.endsWith('.json')) {
                  final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
                  // Look for backup files with broader search criteria
                  bool isLikelyBackup = fileName.contains('bbetter_backup') || 
                      fileName.contains('backup') ||
                      fileName.contains('bbetter');
                  
                  // Also check size for potential backup files (larger than 1KB)
                  if (!isLikelyBackup) {
                    try {
                      final stat = await file.stat();
                      if (stat.size > 1000) { // Larger than 1KB might be a backup
                        isLikelyBackup = true;
                      }
                    } catch (e) {
                      // Skip if we can't check size
                    }
                  }
                  
                  if (isLikelyBackup) {
                    try {
                      final stat = await file.stat();
                      // Ensure the modified time is in local timezone
                      final modifiedLocal = stat.modified.toLocal();
                      locations['found_files'].add({
                        'path': file.path,
                        'name': file.path.split(Platform.pathSeparator).last,
                        'size': stat.size,
                        'modified': modifiedLocal.toIso8601String(),
                        'location': path,
                      });
                    } catch (e) {
                      debugPrint('Could not stat file ${file.path}: $e');
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Could not scan $path: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting backup locations: $e');
    }
    
    // Sort found files by date descending (newest first)
    if (locations['found_files'] is List) {
      (locations['found_files'] as List).sort((a, b) {
        try {
          final dateA = DateTime.parse(a['modified']);
          final dateB = DateTime.parse(b['modified']);
          return dateB.compareTo(dateA); // Descending order (newest first)
        } catch (e) {
          return 0; // If parsing fails, keep original order
        }
      });
    }
    
    // Clean up old backups (older than 7 days) if newer ones exist
    await _cleanupOldBackups(locations['found_files']);
    
    return locations;
  }

  // Clean up old backup files (older than 7 days) if newer ones exist
  static Future<void> _cleanupOldBackups(List<dynamic> foundFiles) async {
    try {
      if (foundFiles.isEmpty) return;
      
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      // Check if we have at least one backup newer than 7 days
      bool hasNewerBackup = false;
      for (var file in foundFiles) {
        try {
          final modifiedDate = DateTime.parse(file['modified']);
          if (modifiedDate.isAfter(sevenDaysAgo)) {
            hasNewerBackup = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      // Only delete old backups if we have newer ones
      if (!hasNewerBackup) {
        debugPrint('No newer backups found, skipping cleanup');
        return;
      }
      
      int deletedCount = 0;
      for (var file in foundFiles) {
        try {
          final modifiedDate = DateTime.parse(file['modified']);
          if (modifiedDate.isBefore(sevenDaysAgo)) {
            final backupFile = File(file['path']);
            if (await backupFile.exists()) {
              await backupFile.delete();
              deletedCount++;
              debugPrint('Deleted old backup: ${file['name']}');
            }
          }
        } catch (e) {
          debugPrint('Could not delete backup ${file['name']}: $e');
        }
      }
      
      if (deletedCount > 0) {
        debugPrint('Cleanup completed: deleted $deletedCount old backup files');
      }
    } catch (e) {
      debugPrint('Error during backup cleanup: $e');
    }
  }

  // Get backup info
  static Future<Map<String, dynamic>> getBackupInfo() async {
    try {
      final backupData = await _getAllAppData();
      
      int totalItems = 0;
      final categories = <String, int>{};

      for (String category in ['fasting', 'menstrual_cycle', 'friends', 'tasks', 'task_categories', 'routines', 'food_tracking', 'water_tracking', 'timers', 'notifications', 'settings', 'app_preferences']) {
        final categoryData = Map<String, dynamic>.from(backupData[category] ?? {});
        final count = categoryData.keys.length;
        categories[category] = count;
        totalItems += count;
      }
      
      final lastBackupTime = await _getLastBackup();
      
      return {
        'total_items': totalItems,
        'categories': categories,
        'backup_size_kb': (json.encode(backupData).length / 1024).round(),
        'last_backup_time': lastBackupTime,
      };
      
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  static Future<String?> _getLastBackup() async {
    try {
      // Scan for backup files directly without triggering cleanup
      Map<String, dynamic> locations = {
        'current_location': null,
        'all_locations': [],
        'found_files': [],
      };

      if (Platform.isAndroid) {
        List<String> possiblePaths = [];

        // Use centralized backup paths - external storage only
        possiblePaths.add(backupDirectoryPath);
        possiblePaths.add(externalDownloadsPath);

        // Search for backup files in all locations
        for (String path in possiblePaths) {
          try {
            final dir = Directory(path);
            if (await dir.exists()) {
              final files = await dir.list().toList();
              for (var file in files) {
                if (file is File && file.path.endsWith('.json')) {
                  final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
                  bool isLikelyBackup = fileName.contains('bbetter_backup') || 
                      fileName.contains('backup') ||
                      fileName.contains('bbetter');
                  
                  if (!isLikelyBackup) {
                    try {
                      final stat = await file.stat();
                      if (stat.size > 1000) {
                        isLikelyBackup = true;
                      }
                    } catch (e) {
                      // Skip if we can't check size
                    }
                  }
                  
                  if (isLikelyBackup) {
                    try {
                      final stat = await file.stat();
                      locations['found_files'].add({
                        'path': file.path,
                        'name': file.path.split(Platform.pathSeparator).last,
                        'size': stat.size,
                        'modified': stat.modified.toIso8601String(),
                        'location': path,
                      });
                    } catch (e) {
                      // Skip if we can't stat file
                    }
                  }
                }
              }
            }
          } catch (e) {
            // Skip if we can't scan path
          }
        }
      }
      
      // Sort found files by date descending (newest first)
      if (locations['found_files'] is List) {
        (locations['found_files'] as List).sort((a, b) {
          try {
            final dateA = DateTime.parse(a['modified']);
            final dateB = DateTime.parse(b['modified']);
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });
      }
      
      final foundFiles = locations['found_files'] as List<dynamic>;
      
      if (foundFiles.isNotEmpty) {
        final mostRecentFile = foundFiles.first;
        final lastBackupTime = mostRecentFile['modified'] as String;
        return lastBackupTime;
      } else {
        // Fallback to SharedPreferences for compatibility
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();
          
          final lastManual = prefs.getString('last_backup');
          final lastManualSpecific = prefs.getString('last_manual_backup');
          final lastAuto = prefs.getString('last_auto_backup');
          
          // Return the most recent timestamp from SharedPreferences
          List<String> timestamps = [lastManual, lastManualSpecific, lastAuto]
              .where((t) => t != null)
              .cast<String>()
              .toList();
              
          if (timestamps.isNotEmpty) {
            timestamps.sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
            return timestamps.first;
          }
        } catch (e) {
          // SharedPreferences fallback failed
        }
        return null;
      }
    } catch (e) {
      // Try SharedPreferences fallback on error
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastBackup = prefs.getString('last_backup');
        if (lastBackup != null) {
          return lastBackup;
        }
      } catch (e2) {
        // All fallback methods failed
      }
      return null;
    }
  }
  
  // Get customizable backup overdue threshold (default 7 days)
  static Future<int> getBackupOverdueThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('backup_overdue_threshold') ?? 7; // Default 7 days
    } catch (e) {
      return 7; // Fallback to 7 days
    }
  }

  // Set backup overdue threshold
  static Future<void> setBackupOverdueThreshold(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('backup_overdue_threshold', days);
    } catch (e) {
      debugPrint('Error setting backup overdue threshold: $e');
    }
  }

  // Get detailed backup status with overdue warnings
  static Future<Map<String, dynamic>> getDetailedBackupStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final lastManual = prefs.getString('last_manual_backup');
      final lastAuto = prefs.getString('last_auto_backup');
      final lastCloudShare = prefs.getString('last_cloud_share');

      final now = DateTime.now();
      final overdueThreshold = await getBackupOverdueThreshold();

      Map<String, dynamic> status = {
        'last_manual_backup': lastManual,
        'last_auto_backup': lastAuto,
        'last_cloud_share': lastCloudShare,
        'manual_overdue': false,
        'auto_overdue': false,
        'cloud_overdue': false,
        'any_overdue': false,
        'days_since_manual': null,
        'days_since_auto': null,
        'days_since_cloud': null,
      };

      // Check manual backup
      bool manualOverdue = false;
      if (lastManual != null) {
        final manualDate = DateTime.parse(lastManual);
        final daysSince = now.difference(manualDate).inDays;
        status['days_since_manual'] = daysSince;
        manualOverdue = daysSince > overdueThreshold;
      } else {
        manualOverdue = true; // Never backed up manually
      }

      // Check auto backup
      bool autoOverdue = false;
      if (lastAuto != null) {
        final autoDate = DateTime.parse(lastAuto);
        final daysSince = now.difference(autoDate).inDays;
        status['days_since_auto'] = daysSince;
        autoOverdue = daysSince > overdueThreshold;
      } else {
        autoOverdue = true; // Never backed up automatically
      }

      // If auto backup is recent, suppress manual backup warning
      if (!autoOverdue && lastAuto != null) {
        manualOverdue = false;
      }

      status['manual_overdue'] = manualOverdue;
      status['auto_overdue'] = autoOverdue;

      // Check cloud sharing
      if (lastCloudShare != null) {
        final cloudDate = DateTime.parse(lastCloudShare);
        final daysSince = now.difference(cloudDate).inDays;
        status['days_since_cloud'] = daysSince;
        status['cloud_overdue'] = daysSince > overdueThreshold;
      } else {
        status['cloud_overdue'] = true; // Never shared to cloud
      }

      // Set overall overdue flag
      status['any_overdue'] = status['manual_overdue'] || status['auto_overdue'] || status['cloud_overdue'];

      return status;
    } catch (e) {
      debugPrint('Error getting detailed backup status: $e');
      return {
        'error': e.toString(),
        'any_overdue': true, // Assume overdue if we can't check
      };
    }
  }

  // Clear all app data (for testing)
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('All app data cleared');
    } catch (e) {
      debugPrint('Error clearing data: $e');
    }
  }
}