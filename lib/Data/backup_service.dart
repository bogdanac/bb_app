import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../Notifications/notification_service.dart';

class BackupService {
  static const String _backupFileName = 'bbetter_backup';
  
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
    
    // Process all SharedPreferences keys intelligently
    for (String key in allKeys) {
      final value = _getPreferenceValue(prefs, key);
      
      if (key.startsWith('fasting_') || key.contains('fast') || key == 'is_fasting' || key.startsWith('current_fast_') || key == 'scheduled_fastings') {
        backupData['fasting'][key] = value;
      } else if (key.startsWith('menstrual_') || key.contains('cycle') || key.contains('period') || key.startsWith('last_period_') || key == 'average_cycle_length' || key == 'period_ranges' || key == 'intercourse_records') {
        backupData['menstrual_cycle'][key] = value;
      } else if (key.startsWith('task') || key.contains('todo') || key.contains('priority')) {
        if (key.contains('categor') || key == 'task_categories') {
          backupData['task_categories'][key] = value;
        } else {
          backupData['tasks'][key] = value;
        }
      } else if (key.contains('categor')) {
        backupData['task_categories'][key] = value;
      } else if (key.startsWith('routine') || key.contains('morning') || key.startsWith('routines')) {
        backupData['routines'][key] = value;
      } else if (key == 'habits' || key.startsWith('habit')) {
        backupData['habits'][key] = value;
      } else if (key.startsWith('food_') || key.contains('food') || key == 'food_entries') {
        backupData['food_tracking'][key] = value;
      } else if (key.startsWith('water_') || key.contains('water') || key == 'last_water_reset_date') {
        backupData['water_tracking'][key] = value;
      } else if (key.contains('notification') || key.contains('alarm') || key.contains('reminder') || key.endsWith('_enabled') || key.endsWith('_hour') || key.endsWith('_minute')) {
        backupData['notifications'][key] = value;
      } else if (key.contains('settings') || key.contains('config') || key == 'last_auto_backup' || key == 'last_backup') {
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
      // Request storage permission for Android
      if (Platform.isAndroid) {
        // For Android 10+ (API 29+), try scoped storage first
        try {
          // Try the newer scoped storage approach
          await getApplicationDocumentsDirectory();
          // If we can access app docs directory, we don't need external storage permissions
        } catch (e) {
          // Fallback to requesting external storage permissions
          var status = await Permission.storage.request();
          if (!status.isGranted) {
            // For Android 11+ try manage external storage
            status = await Permission.manageExternalStorage.request();
            if (!status.isGranted) {
              throw Exception('Storage permission denied');
            }
          }
        }
      }
      
      // Get app data
      final backupData = await _getAllAppData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      
      // Create file name with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = '${_backupFileName}_$timestamp.json';
      
      // Get appropriate directory
      Directory? directory;
      
      try {
        if (Platform.isAndroid) {
          // Try Downloads directory first (more accessible to users)
          try {
            directory = await getDownloadsDirectory();
            if (directory != null) {
              // Create BBetter subfolder in Downloads
              final backupDir = Directory('${directory.path}/BBetter_Backups');
              if (!await backupDir.exists()) {
                await backupDir.create(recursive: true);
              }
              directory = backupDir;
            }
          } catch (e) {
            debugPrint('Could not use Downloads directory: $e');
            directory = null;
          }
          
          // Fallback to app documents directory
          if (directory == null) {
            directory = await getApplicationDocumentsDirectory();
            final backupDir = Directory('${directory.path}/Backups');
            if (!await backupDir.exists()) {
              await backupDir.create(recursive: true);
            }
            directory = backupDir;
          }
        } else {
          // For other platforms
          try {
            directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          } catch (e) {
            directory = await getApplicationDocumentsDirectory();
          }
        }
        
        if (!await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        // Final fallback - use app documents directory
        directory = await getApplicationDocumentsDirectory();
      }
      
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(jsonString);
      
      // Update last backup time if requested
      if (updateLastBackupTime) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final timestamp = DateTime.now().toIso8601String();
          
          // Save both manual and auto backup timestamp for manual backups
          // This ensures manual backups are always recognized
          await prefs.setString('last_backup', timestamp);
          await prefs.setString('last_manual_backup', timestamp); // Additional key for manual backups
          
          debugPrint('Manual backup timestamp saved: $timestamp');
          
        } catch (e) {
          debugPrint('Could not update last backup timestamp: $e');
        }
      }
      
      debugPrint('Backup exported to: ${file.path}');
      debugPrint('File exists: ${await file.exists()}');
      debugPrint('File size: ${await file.length()} bytes');
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
      
      // Validate backup format
      if (!backupData.containsKey('version') || !backupData.containsKey('timestamp')) {
        return {'success': false, 'error': 'Invalid backup file format - missing version or timestamp'};
      }
      
      final prefs = await SharedPreferences.getInstance();
      int restoredCount = 0;
      List<String> errors = [];
      
      // Restore each category
      for (String category in ['fasting', 'menstrual_cycle', 'tasks', 'task_categories', 'routines', 'habits', 'food_tracking', 'water_tracking', 'notifications', 'settings', 'app_preferences']) {
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
        if (value.isNotEmpty && value.first is String) {
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
      final lastBackup = prefs.getString('last_auto_backup');
      final now = DateTime.now();
      
      // Check if we need to backup (every 1 day)
      if (lastBackup != null) {
        final lastBackupDate = DateTime.parse(lastBackup);
        final daysSinceBackup = now.difference(lastBackupDate).inDays;
        if (daysSinceBackup < 1) {
          return; // Too recent
        }
      }
      
      // Perform backup
      final backupPath = await exportToFile();
      if (backupPath != null) {
        await prefs.setString('last_auto_backup', now.toIso8601String());
        await prefs.reload(); // Ensure timestamp is persisted
        debugPrint('Daily auto backup completed: $backupPath');
        
        // Schedule next backup
        await _scheduleNextAutoBackup();
      }
      
    } catch (e) {
      debugPrint('Daily auto backup failed: $e');
    }
  }

  // Schedule nightly auto backup
  static Future<void> scheduleNightlyBackups() async {
    try {
      await _scheduleNextAutoBackup();
      debugPrint('Nightly backup scheduling enabled');
    } catch (e) {
      debugPrint('Failed to schedule nightly backups: $e');
    }
  }

  // Schedule the next auto backup notification for tonight
  static Future<void> _scheduleNextAutoBackup() async {
    try {
      final notificationService = NotificationService();
      
      // Schedule for 2 AM tonight (or tomorrow if it's already past 2 AM)
      final now = DateTime.now();
      final backupTime = DateTime(now.year, now.month, now.day, 2, 0); // 2:00 AM
      final scheduledTime = backupTime.isBefore(now) 
          ? backupTime.add(const Duration(days: 1))
          : backupTime;
      
      const androidDetails = AndroidNotificationDetails(
        'auto_backup',
        'Automatic Backups',
        channelDescription: 'Automatic nightly data backups',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: false,
        playSound: false,
        enableVibration: false,
        ongoing: false,
      );
      
      const notificationDetails = NotificationDetails(android: androidDetails);
      
      // Convert to timezone-aware datetime
      final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
      
      await notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        8888, // Unique ID for auto backup
        '🔄 Auto Backup',
        'Performing nightly backup...',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'auto_backup_trigger',
      );
      
      debugPrint('Next auto backup scheduled for: $scheduledTime');
      
    } catch (e) {
      debugPrint('Failed to schedule next auto backup: $e');
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
  
  // Check and schedule weekly cloud backup reminder
  static Future<void> checkWeeklyCloudBackupReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCloudReminder = prefs.getString('last_cloud_backup_reminder');
      final now = DateTime.now();
      
      // Check if we need to remind (every 7 days)
      bool shouldRemind = false;
      if (lastCloudReminder != null) {
        final lastReminderDate = DateTime.parse(lastCloudReminder);
        final daysSinceReminder = now.difference(lastReminderDate).inDays;
        if (daysSinceReminder >= 7) {
          shouldRemind = true;
        }
      } else {
        // First time - remind after 3 days of using the app
        shouldRemind = true;
      }
      
      if (shouldRemind) {
        await _scheduleCloudBackupNotification();
        await prefs.setString('last_cloud_backup_reminder', now.toIso8601String());
        debugPrint('Weekly cloud backup reminder scheduled');
      }
      
    } catch (e) {
      debugPrint('Cloud backup reminder check failed: $e');
    }
  }
  
  // Schedule the cloud backup reminder notification
  static Future<void> _scheduleCloudBackupNotification() async {
    try {
      // Import the notification service and get direct access to the plugin
      final notificationService = NotificationService();
      
      // Schedule notification for later today or tomorrow
      final now = DateTime.now();
      final reminderTime = DateTime(now.year, now.month, now.day, 19, 0); // 7 PM
      final scheduledTime = reminderTime.isBefore(now) 
          ? reminderTime.add(const Duration(days: 1))
          : reminderTime;
      
      // Use the same pattern as other notifications in the service
      const androidDetails = AndroidNotificationDetails(
        'backup_reminders',
        'Backup Reminders',
        channelDescription: 'Weekly reminders to backup data to cloud storage',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
      );
      
      const notificationDetails = NotificationDetails(android: androidDetails);
      
      // Convert to timezone-aware datetime
      final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
      
      await notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
        9999, // Unique ID for cloud backup reminders
        '☁️ Weekly Cloud Backup Reminder',
        'Don\'t forget to backup your data to cloud storage (Google Drive, etc.) for extra safety!',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'cloud_backup_reminder',
      );
      
      debugPrint('Cloud backup reminder notification scheduled for: $scheduledTime');
      
    } catch (e) {
      debugPrint('Failed to schedule cloud backup notification: $e');
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
        
        // Check Downloads/BBetter_Backups (new location)
        try {
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            final bbetterBackupsDir = Directory('${downloadsDir.path}/BBetter_Backups');
            possiblePaths.add(bbetterBackupsDir.path);
            if (await bbetterBackupsDir.exists()) {
              locations['current_location'] = bbetterBackupsDir.path;
            }
          }
        } catch (e) {
          debugPrint('Could not check Downloads: $e');
        }
        
        // Check Downloads root
        try {
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            possiblePaths.add(downloadsDir.path);
          }
        } catch (e) {
          debugPrint('Could not check Downloads root: $e');
        }
        
        // Check app documents/Backups (old location)
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final backupsDir = Directory('${appDir.path}/Backups');
          possiblePaths.add(backupsDir.path);
          if (await backupsDir.exists()) {
            locations['current_location'] ??= backupsDir.path;
          }
        } catch (e) {
          debugPrint('Could not check app Backups: $e');
        }
        
        // Check app documents root
        try {
          final appDir = await getApplicationDocumentsDirectory();
          possiblePaths.add(appDir.path);
        } catch (e) {
          debugPrint('Could not check app documents: $e');
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
                      locations['found_files'].add({
                        'path': file.path,
                        'name': file.path.split(Platform.pathSeparator).last,
                        'size': stat.size,
                        'modified': stat.modified.toIso8601String(),
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
      
      for (String category in ['fasting', 'menstrual_cycle', 'tasks', 'task_categories', 'routines', 'food_tracking', 'water_tracking', 'notifications', 'settings', 'app_preferences']) {
        final categoryData = backupData[category] as Map<String, dynamic>;
        final count = categoryData.keys.length;
        categories[category] = count;
        totalItems += count;
      }
      
      return {
        'total_items': totalItems,
        'categories': categories,
        'backup_size_kb': (json.encode(backupData).length / 1024).round(),
        'last_backup_time': await _getLastBackup(),
      };
      
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  static Future<String?> _getLastBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Ensure we have the latest values
      
      final lastManual = prefs.getString('last_backup');
      final lastManualSpecific = prefs.getString('last_manual_backup');
      final lastAuto = prefs.getString('last_auto_backup');
      
      debugPrint('Getting last backup: manual=$lastManual, manual_specific=$lastManualSpecific, auto=$lastAuto');
      
      // Prioritize manual backups - if we have any manual backup, use the most recent one
      String? mostRecentManual;
      if (lastManual != null && lastManualSpecific != null) {
        final manualDate = DateTime.parse(lastManual);
        final manualSpecificDate = DateTime.parse(lastManualSpecific);
        mostRecentManual = manualDate.isAfter(manualSpecificDate) ? lastManual : lastManualSpecific;
      } else {
        mostRecentManual = lastManual ?? lastManualSpecific;
      }
      
      // If we have a manual backup, compare with auto backup
      if (mostRecentManual != null && lastAuto != null) {
        final manualDate = DateTime.parse(mostRecentManual);
        final autoDate = DateTime.parse(lastAuto);
        return manualDate.isAfter(autoDate) ? mostRecentManual : lastAuto;
      } else if (mostRecentManual != null) {
        return mostRecentManual;
      } else if (lastAuto != null) {
        return lastAuto;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error getting last backup: $e');
      return null;
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