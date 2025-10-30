import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple Firebase backup service - backs up entire SharedPreferences
class FirebaseBackupService {
  static final FirebaseBackupService _instance = FirebaseBackupService._internal();
  factory FirebaseBackupService() => _instance;
  FirebaseBackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _deviceId;
  bool _syncEnabled = true;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');

    if (_deviceId == null) {
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      await prefs.setString('device_id', _deviceId!);
    }

    if (kDebugMode) {
      print('🔥 Firebase initialized: $_deviceId');
    }
  }

  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
  }

  // Backup ALL SharedPreferences data
  Future<void> backupAllData() async {
    if (!_syncEnabled || _deviceId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final Map<String, dynamic> allData = {};

      // Export all data from SharedPreferences
      for (final key in allKeys) {
        final value = prefs.get(key);
        if (value != null) {
          allData[key] = value;
        }
      }

      await _firestore.collection('backups').doc(_deviceId).set({
        'data': allData,
        'lastBackup': FieldValue.serverTimestamp(),
      });

      // Save local timestamp for display
      await prefs.setString('last_firebase_backup', DateTime.now().toIso8601String());

      if (kDebugMode) {
        print('✅ Backed up ${allKeys.length} keys to Firebase');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase backup failed: $e');
      }
    }
  }

  // Restore ALL SharedPreferences data
  Future<bool> restoreAllData() async {
    if (!_syncEnabled || _deviceId == null) return false;

    try {
      final doc = await _firestore.collection('backups').doc(_deviceId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!['data'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();

        // Restore all data to SharedPreferences
        for (final entry in data.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is List) {
            await prefs.setStringList(key, List<String>.from(value));
          }
        }

        if (kDebugMode) {
          print('✅ Restored ${data.length} keys from Firebase');
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase restore failed: $e');
      }
    }

    return false;
  }

  Future<bool> hasBackup() async {
    if (_deviceId == null) return false;
    try {
      final doc = await _firestore.collection('backups').doc(_deviceId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Trigger backup (non-blocking) - call this after any data change
  static void triggerBackup() {
    FirebaseBackupService().backupAllData().catchError((e) {
      if (kDebugMode) {
        print('⚠️ Firebase backup failed: $e');
      }
    });
  }
}
