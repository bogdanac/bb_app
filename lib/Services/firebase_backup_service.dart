import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple Firebase backup service - backs up entire SharedPreferences
class FirebaseBackupService {
  static final FirebaseBackupService _instance = FirebaseBackupService._internal();
  factory FirebaseBackupService() => _instance;
  FirebaseBackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  bool _syncEnabled = true;

  Future<void> initialize() async {
    try {
      // Wait for user to be authenticated (handled by AuthWrapper)
      _userId = _auth.currentUser?.uid;

      if (_userId != null) {
        if (kDebugMode) {
          print('🔥 Firebase Backup Service initialized for user: $_userId');
        }

        // Try to restore data from Firebase on first launch for this device
        final prefs = await SharedPreferences.getInstance();
        final hasRestoredKey = 'has_restored_from_firebase_$_userId';
        final hasRestoredBefore = prefs.getBool(hasRestoredKey) ?? false;

        if (!hasRestoredBefore) {
          final restored = await restoreAllData();
          if (restored) {
            await prefs.setBool(hasRestoredKey, true);
            if (kDebugMode) {
              print('✅ Initial data restore from Firebase completed');
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No authenticated user - backup service waiting for login');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firebase Backup Service initialization failed: $e');
      }
    }
  }

  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
  }

  // Backup ALL SharedPreferences data
  Future<void> backupAllData() async {
    if (!_syncEnabled || _userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final Map<String, dynamic> allData = {};

      // Export all data from SharedPreferences (exclude Firebase-specific keys)
      for (final key in allKeys) {
        if (key != 'has_restored_from_firebase' && key != 'device_id') {
          final value = prefs.get(key);
          if (value != null) {
            allData[key] = value;
          }
        }
      }

      await _firestore.collection('users').doc(_userId).set({
        'data': allData,
        'lastBackup': FieldValue.serverTimestamp(),
      });

      // Save local timestamp for display
      await prefs.setString('last_firebase_backup', DateTime.now().toIso8601String());

      if (kDebugMode) {
        print('✅ Backed up ${allData.length} keys to Firebase for user $_userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase backup failed: $e');
      }
    }
  }

  // Restore ALL SharedPreferences data
  Future<bool> restoreAllData() async {
    if (!_syncEnabled || _userId == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(_userId).get();

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
          print('✅ Restored ${data.length} keys from Firebase for user $_userId');
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
    if (_userId == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get current user ID
  String? get userId => _userId;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Trigger backup (non-blocking) - call this after any data change
  static void triggerBackup() {
    FirebaseBackupService().backupAllData().catchError((e) {
      if (kDebugMode) {
        print('⚠️ Firebase backup failed: $e');
      }
    });
  }
}
