import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../shared/error_logger.dart';

/// Firebase backup service with real-time sync
class FirebaseBackupService {
  static final FirebaseBackupService _instance = FirebaseBackupService._internal();
  factory FirebaseBackupService() => _instance;
  FirebaseBackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  bool _syncEnabled = true;
  bool _hasSetupListener = false;
  StreamSubscription<DocumentSnapshot>? _firestoreListener;
  int _lastBackupTimestamp = 0;  // Track last backup time in milliseconds
  bool _isRestoring = false;  // Flag to prevent restore → backup loops

  Future<void> initialize() async {
    try {
      // Set up auth state listener if not already done
      if (!_hasSetupListener) {
        _auth.authStateChanges().listen((User? user) {
          _onAuthStateChanged(user);
        });
        _hasSetupListener = true;
      }

      // Initialize for current user if logged in
      await _onAuthStateChanged(_auth.currentUser);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FirebaseBackupService.initialize',
        error: 'Firebase Backup Service initialization failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _onAuthStateChanged(User? user) async {
    try {
      final newUserId = user?.uid;

      // User logged out - cancel listener
      if (newUserId == null) {
        await ErrorLogger.logError(
          source: 'FirebaseBackupService._onAuthStateChanged',
          error: 'Firebase Backup Service: User logged out',
          stackTrace: '',
        );
        await _firestoreListener?.cancel();
        _firestoreListener = null;
        _userId = null;
        return;
      }

      // Same user, no change
      if (newUserId == _userId) {
        return;
      }

      // New user logged in
      _userId = newUserId;

      await ErrorLogger.logError(
        source: 'FirebaseBackupService._onAuthStateChanged',
        error: 'Firebase Backup Service initialized for user: $_userId',
        stackTrace: '',
      );

      // Cancel old listener if exists
      await _firestoreListener?.cancel();

      // Initial restore
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final hasLocalData = allKeys.any((key) =>
        !key.startsWith('has_restored_from_firebase') &&
        !key.startsWith('last_firebase_backup') &&
        key != 'device_id' &&
        key != 'last_user_id'
      );

      final backupExists = await hasBackup();
      if (backupExists) {
        final shouldRestore = await _shouldRestoreFromFirebase(prefs, hasLocalData);
        if (shouldRestore) {
          _isRestoring = true;  // Prevent triggering backup during restore
          final restored = await restoreAllData();
          await Future.delayed(const Duration(milliseconds: 100)); // Let services settle
          _isRestoring = false;
          if (restored) {
            await ErrorLogger.logError(
              source: 'FirebaseBackupService._onAuthStateChanged',
              error: 'Initial data synced from Firebase',
              stackTrace: '',
            );
          }
        }
      }

      // Set up real-time listener for continuous sync
      _setupRealtimeListener();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FirebaseBackupService._onAuthStateChanged',
        error: 'Firebase Backup Service auth state change failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  void _setupRealtimeListener() {
    if (_userId == null || !_syncEnabled) return;

    if (kDebugMode) {
      ErrorLogger.logError(
        source: 'FirebaseBackupService._setupRealtimeListener',
        error: 'Setting up real-time sync listener for user: $_userId',
        stackTrace: '',
      );
    }

    _firestoreListener = _firestore
        .collection('users')
        .doc(_userId)
        .snapshots()
        .listen((snapshot) async {
      // Ignore if document doesn't exist or we're restoring
      if (!snapshot.exists || _isRestoring) return;

      try {
        final data = snapshot.data();
        if (data == null) return;

        final lastBackup = data['lastBackup'] as Timestamp?;
        if (lastBackup == null) return;

        final remoteTimestamp = lastBackup.millisecondsSinceEpoch;

        // Check if this is our own backup (compare timestamps)
        if (remoteTimestamp <= _lastBackupTimestamp) {
          if (kDebugMode) {
            ErrorLogger.logError(
              source: 'FirebaseBackupService._setupRealtimeListener',
              error: 'Skipping sync - this is our own backup',
              stackTrace: '',
            );
          }
          return;
        }

        // Remote data is newer - restore it
        if (kDebugMode) {
          ErrorLogger.logError(
            source: 'FirebaseBackupService._setupRealtimeListener',
            error: 'Remote data changed - syncing... (remote: $remoteTimestamp, local: $_lastBackupTimestamp)',
            stackTrace: '',
          );
        }

        _isRestoring = true;  // Prevent sync loop
        await restoreAllData();
        await Future.delayed(const Duration(milliseconds: 100)); // Let services settle
        _isRestoring = false;

        if (kDebugMode) {
          ErrorLogger.logError(
            source: 'FirebaseBackupService._setupRealtimeListener',
            error: 'Real-time sync completed',
            stackTrace: '',
          );
        }
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'FirebaseBackupService._setupRealtimeListener',
          error: 'Real-time sync error: $e',
          stackTrace: stackTrace.toString(),
        );
        _isRestoring = false;
      }
    });
  }

  Future<bool> _shouldRestoreFromFirebase(SharedPreferences prefs, bool hasLocalData) async {
    try {
      // If no local data, always restore
      if (!hasLocalData) return true;

      // Get Firebase backup timestamp
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      final lastBackup = data?['lastBackup'] as Timestamp?;
      if (lastBackup == null) return false;

      // Get local backup timestamp
      final localBackupStr = prefs.getString('last_firebase_backup');
      if (localBackupStr == null) {
        // No local timestamp, restore if Firebase has data
        return true;
      }

      final localBackup = DateTime.parse(localBackupStr);
      final firebaseBackup = lastBackup.toDate();

      // Restore if Firebase is newer (with 5 second tolerance for clock differences)
      final isNewer = firebaseBackup.isAfter(localBackup.add(const Duration(seconds: 5)));

      if (kDebugMode) {
        ErrorLogger.logError(
          source: 'FirebaseBackupService.shouldBackup',
          error: 'Sync check: Local: $localBackup, Firebase: $firebaseBackup, Newer: $isNewer',
          stackTrace: '',
        );
      }

      return isNewer;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FirebaseBackupService._shouldRestoreFromFirebase',
        error: 'Error checking if should restore: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }

  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
  }

  // Keys handled by RealtimeSyncService (excluded from full backup)
  static const Set<String> _realtimeSyncedKeys = {
    'tasks',
    'task_categories',
    'task_settings',
    'selected_category_filters',
    'routines',
    'habits',
    'energy_settings',
  };

  // Keys that should NEVER be restored from remote because they represent
  // time-sensitive local state (e.g., active fasting sessions)
  static const Set<String> _neverRestoreKeys = {
    'is_fasting',
    'current_fast_start',
    'current_fast_end',
    'current_fast_type',
  };

  // Backup ALL SharedPreferences data (except real-time synced collections)
  Future<void> backupAllData() async {
    if (!_syncEnabled || _userId == null || _isRestoring) return;

    try {
      // Record timestamp before backup to identify our own changes
      _lastBackupTimestamp = DateTime.now().millisecondsSinceEpoch;

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final Map<String, dynamic> allData = {};

      // Export all data from SharedPreferences
      // Exclude: Firebase-specific keys, real-time synced collections, and their progress data
      for (final key in allKeys) {
        // Skip Firebase-specific keys
        if (key == 'has_restored_from_firebase' || key == 'device_id') {
          continue;
        }

        // Skip real-time synced collections
        if (_realtimeSyncedKeys.contains(key)) {
          continue;
        }

        // Skip routine progress data (synced with routines)
        if (key.startsWith('routine_progress_') ||
            key.startsWith('active_routine_') ||
            key.startsWith('morning_routine_progress_') ||
            key == 'morning_routine_last_date' ||
            key == 'routine_last_date') {
          continue;
        }

        // Skip energy data (synced separately)
        if (key.startsWith('energy_today_') || key.startsWith('energy_settings')) {
          continue;
        }

        final value = prefs.get(key);
        if (value != null) {
          allData[key] = value;
        }
      }

      await _firestore.collection('users').doc(_userId).set({
        'data': allData,
        'lastBackup': FieldValue.serverTimestamp(),
      });

      // Save local timestamp for display
      await prefs.setString('last_firebase_backup', DateTime.now().toIso8601String());

      if (kDebugMode) {
        ErrorLogger.logError(
          source: 'FirebaseBackupService.backupAllData',
          error: 'Backed up ${allData.length} keys to Firebase for user $_userId (timestamp: $_lastBackupTimestamp)',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FirebaseBackupService.backupAllData',
        error: 'Firebase backup failed: $e',
        stackTrace: stackTrace.toString(),
        context: {'userId': _userId},
      );
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

          // Skip keys that should never be restored from remote
          // (time-sensitive local state like active fasting sessions)
          if (_neverRestoreKeys.contains(key)) {
            continue;
          }

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
          ErrorLogger.logError(
            source: 'FirebaseBackupService.restoreAllData',
            error: 'Restored ${data.length} keys from Firebase for user $_userId',
            stackTrace: '',
          );
        }
        return true;
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FirebaseBackupService.restoreAllData',
        error: 'Firebase restore failed: $e',
        stackTrace: stackTrace.toString(),
        context: {'userId': _userId},
      );
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
    FirebaseBackupService().backupAllData().catchError((e, stackTrace) async {
      await ErrorLogger.logError(
        source: 'FirebaseBackupService.triggerBackup',
        error: 'Firebase backup failed: $e',
        stackTrace: stackTrace.toString(),
      );
    });
  }
}
