import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

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
      'water_tracking': {},
      'notifications': {},
      'settings': {},
      'app_preferences': {},
    };
    
    // Process all SharedPreferences keys intelligently
    for (String key in allKeys) {
      final value = _getPreferenceValue(prefs, key);
      
      if (key.startsWith('fasting_') || key.contains('fast') || key == 'is_fasting' || key.startsWith('current_fast_')) {
        backupData['fasting'][key] = value;
      } else if (key.startsWith('menstrual_') || key.contains('cycle') || key.contains('period') || key.startsWith('last_period_') || key == 'average_cycle_length' || key == 'period_ranges') {
        backupData['menstrual_cycle'][key] = value;
      } else if (key.startsWith('task') || key.contains('todo') || key.contains('priority')) {
        backupData['tasks'][key] = value;
      } else if (key.contains('categor')) {
        backupData['task_categories'][key] = value;
      } else if (key.startsWith('routine') || key.contains('morning') || key.startsWith('routines')) {
        backupData['routines'][key] = value;
      } else if (key.startsWith('water_') || key.contains('water') || key == 'last_water_reset_date') {
        backupData['water_tracking'][key] = value;
      } else if (key.contains('notification') || key.contains('alarm') || key.contains('reminder') || key.endsWith('_enabled') || key.endsWith('_hour') || key.endsWith('_minute')) {
        backupData['notifications'][key] = value;
      } else if (key.contains('settings') || key.contains('config') || key == 'last_auto_backup') {
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
  static Future<String?> exportToFile() async {
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
          // Use app's documents directory first (more reliable on modern Android)
          directory = await getApplicationDocumentsDirectory();
          
          // Try to create a "Backups" subfolder for better organization
          final backupDir = Directory('${directory.path}/Backups');
          if (!await backupDir.exists()) {
            await backupDir.create(recursive: true);
          }
          directory = backupDir;
        } else {
          // For other platforms
          try {
            directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          } catch (e) {
            directory = await getApplicationDocumentsDirectory();
          }
        }
        
        if (directory == null || !await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        // Final fallback - use app documents directory
        directory = await getApplicationDocumentsDirectory();
      }
      
      final file = File('${directory!.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(jsonString);
      
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
  
  // Import from file
  static Future<bool> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }
      
      final jsonString = await file.readAsString();
      final backupData = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate backup format
      if (!backupData.containsKey('version') || !backupData.containsKey('timestamp')) {
        throw Exception('Invalid backup file format');
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Restore each category
      for (String category in ['fasting', 'menstrual_cycle', 'tasks', 'task_categories', 'routines', 'water_tracking', 'notifications', 'settings', 'app_preferences']) {
        if (backupData.containsKey(category)) {
          final categoryData = backupData[category] as Map<String, dynamic>;
          for (String key in categoryData.keys) {
            final value = categoryData[key];
            await _setPreferenceValue(prefs, key, value);
          }
        }
      }
      
      debugPrint('Backup restored successfully from: $filePath');
      return true;
      
    } catch (e) {
      debugPrint('Error importing backup: $e');
      return false;
    }
  }
  
  static Future<void> _setPreferenceValue(SharedPreferences prefs, String key, dynamic value) async {
    if (value == null) return;
    
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      // Convert complex objects to JSON string
      await prefs.setString(key, json.encode(value));
    }
  }
  
  // Auto backup (called periodically)
  static Future<void> performAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackup = prefs.getString('last_auto_backup');
      final now = DateTime.now();
      
      // Check if we need to backup (every 7 days)
      if (lastBackup != null) {
        final lastBackupDate = DateTime.parse(lastBackup);
        final daysSinceBackup = now.difference(lastBackupDate).inDays;
        if (daysSinceBackup < 7) {
          return; // Too recent
        }
      }
      
      // Perform backup
      final backupPath = await exportToFile();
      if (backupPath != null) {
        await prefs.setString('last_auto_backup', now.toIso8601String());
        debugPrint('Auto backup completed: $backupPath');
      }
      
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }
  
  // Get backup info
  static Future<Map<String, dynamic>> getBackupInfo() async {
    try {
      final backupData = await _getAllAppData();
      
      int totalItems = 0;
      final categories = <String, int>{};
      
      for (String category in ['fasting', 'menstrual_cycle', 'tasks', 'task_categories', 'routines', 'water_tracking', 'notifications', 'settings', 'app_preferences']) {
        final categoryData = backupData[category] as Map<String, dynamic>;
        final count = categoryData.keys.length;
        categories[category] = count;
        totalItems += count;
      }
      
      return {
        'total_items': totalItems,
        'categories': categories,
        'backup_size_kb': (json.encode(backupData).length / 1024).round(),
        'last_auto_backup': await _getLastAutoBackup(),
      };
      
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  static Future<String?> _getLastAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('last_auto_backup');
    } catch (e) {
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