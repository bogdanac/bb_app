import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/error_logger.dart';

/// Real-time sync service for granular collection syncing
/// Handles high-frequency data (Tasks, Routines, Habits, Energy) with Firestore real-time listeners
/// Works alongside FirebaseBackupService which handles settings/preferences
class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userId;
  bool _syncEnabled = true;
  bool _hasSetupListener = false;

  // Separate listeners for each collection
  StreamSubscription<DocumentSnapshot>? _tasksListener;
  StreamSubscription<DocumentSnapshot>? _routinesListener;
  StreamSubscription<DocumentSnapshot>? _habitsListener;
  StreamSubscription<DocumentSnapshot>? _energyListener;

  // Track last sync timestamps to prevent loops
  final Map<String, int> _lastSyncTimestamps = {};

  // Flags to prevent restore → save loops
  bool _isRestoringTasks = false;
  bool _isRestoringRoutines = false;
  bool _isRestoringHabits = false;
  bool _isRestoringEnergy = false;

  // Sync event callbacks for UI refresh
  final List<VoidCallback> _syncEventListeners = [];

  /// Add listener for sync events (UI refresh)
  void addSyncEventListener(VoidCallback listener) {
    if (!_syncEventListeners.contains(listener)) {
      _syncEventListeners.add(listener);
    }
  }

  /// Remove sync event listener
  void removeSyncEventListener(VoidCallback listener) {
    _syncEventListeners.remove(listener);
  }

  /// Notify all listeners that sync occurred
  void _notifySyncEvent() {
    for (final listener in _syncEventListeners) {
      try {
        listener();
      } catch (e) {
        // Ignore listener errors
      }
    }
  }

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
        source: 'RealtimeSyncService.initialize',
        error: 'Real-time sync initialization failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _onAuthStateChanged(User? user) async {
    try {
      final newUserId = user?.uid;

      // User logged out - cancel all listeners
      if (newUserId == null) {
        await _cancelAllListeners();
        _userId = null;
        return;
      }

      // Same user, no change
      if (newUserId == _userId) {
        return;
      }

      // New user logged in
      _userId = newUserId;

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._onAuthStateChanged',
          error: 'Real-time sync initialized for user: $_userId',
          stackTrace: '',
        );
      }

      // Cancel old listeners if exist
      await _cancelAllListeners();

      // Set up real-time listeners for all collections
      _setupTasksListener();
      _setupRoutinesListener();
      _setupHabitsListener();
      _setupEnergyListener();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService._onAuthStateChanged',
        error: 'Auth state change failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _cancelAllListeners() async {
    await _tasksListener?.cancel();
    await _routinesListener?.cancel();
    await _habitsListener?.cancel();
    await _energyListener?.cancel();

    _tasksListener = null;
    _routinesListener = null;
    _habitsListener = null;
    _energyListener = null;
  }

  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
  }

  // ========================
  // TASKS SYNC
  // ========================

  void _setupTasksListener() {
    if (_userId == null || !_syncEnabled) return;

    _tasksListener = _firestore
        .collection('users')
        .doc(_userId)
        .collection('data')
        .doc('tasks')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || _isRestoringTasks) return;

      try {
        final data = snapshot.data();
        if (data == null) return;

        final lastSync = data['lastSync'] as Timestamp?;
        if (lastSync == null) return;

        final remoteTimestamp = lastSync.millisecondsSinceEpoch;
        final localTimestamp = _lastSyncTimestamps['tasks'] ?? 0;

        // Skip if this is our own sync
        if (remoteTimestamp <= localTimestamp) {
          return;
        }

        // Remote data is newer - restore it
        if (kDebugMode) {
          await ErrorLogger.logError(
            source: 'RealtimeSyncService._setupTasksListener',
            error: 'Tasks changed remotely - syncing...',
            stackTrace: '',
          );
        }

        _isRestoringTasks = true;
        await _restoreTasksData(data);
        await Future.delayed(const Duration(milliseconds: 100));
        _isRestoringTasks = false;

        _notifySyncEvent();
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._setupTasksListener',
          error: 'Tasks sync error: $e',
          stackTrace: stackTrace.toString(),
        );
        _isRestoringTasks = false;
      }
    });
  }

  Future<void> syncTasks(String tasksJson) async {
    if (!_syncEnabled || _userId == null || _isRestoringTasks) return;

    try {
      _lastSyncTimestamps['tasks'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('data')
          .doc('tasks')
          .set({
        'tasks': tasksJson,
        'lastSync': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService.syncTasks',
          error: 'Tasks synced to Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.syncTasks',
        error: 'Tasks sync failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _restoreTasksData(Map<String, dynamic> data) async {
    try {
      final tasksJson = data['tasks'] as String?;
      if (tasksJson == null) return;

      final prefs = await SharedPreferences.getInstance();
      // FIX: Tasks must be stored as StringList, not String
      // The JSON string contains an array of task JSON strings
      final List<dynamic> tasksList = jsonDecode(tasksJson);
      final List<String> tasksStringList = tasksList.map((e) => e.toString()).toList();
      await prefs.setStringList('tasks', tasksStringList);

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._restoreTasksData',
          error: 'Tasks restored from Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService._restoreTasksData',
        error: 'Tasks restore failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // ========================
  // ROUTINES SYNC
  // ========================

  void _setupRoutinesListener() {
    if (_userId == null || !_syncEnabled) return;

    _routinesListener = _firestore
        .collection('users')
        .doc(_userId)
        .collection('data')
        .doc('routines')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || _isRestoringRoutines) return;

      try {
        final data = snapshot.data();
        if (data == null) return;

        final lastSync = data['lastSync'] as Timestamp?;
        if (lastSync == null) return;

        final remoteTimestamp = lastSync.millisecondsSinceEpoch;
        final localTimestamp = _lastSyncTimestamps['routines'] ?? 0;

        if (remoteTimestamp <= localTimestamp) {
          return;
        }

        if (kDebugMode) {
          await ErrorLogger.logError(
            source: 'RealtimeSyncService._setupRoutinesListener',
            error: 'Routines changed remotely - syncing...',
            stackTrace: '',
          );
        }

        _isRestoringRoutines = true;
        await _restoreRoutinesData(data);
        await Future.delayed(const Duration(milliseconds: 100));
        _isRestoringRoutines = false;

        _notifySyncEvent();
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._setupRoutinesListener',
          error: 'Routines sync error: $e',
          stackTrace: stackTrace.toString(),
        );
        _isRestoringRoutines = false;
      }
    });
  }

  Future<void> syncRoutines(String routinesJson, Map<String, String> progressData) async {
    if (!_syncEnabled || _userId == null || _isRestoringRoutines) return;

    try {
      _lastSyncTimestamps['routines'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('data')
          .doc('routines')
          .set({
        'routines': routinesJson,
        'progress': progressData,
        'lastSync': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService.syncRoutines',
          error: 'Routines synced to Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.syncRoutines',
        error: 'Routines sync failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _restoreRoutinesData(Map<String, dynamic> data) async {
    try {
      final routinesJson = data['routines'] as String?;
      final progressData = data['progress'] as Map<String, dynamic>?;

      if (routinesJson == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('routines', routinesJson);

      // Restore progress data
      if (progressData != null) {
        for (final entry in progressData.entries) {
          final value = entry.value;
          if (value is String) {
            await prefs.setString(entry.key, value);
          }
        }
      }

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._restoreRoutinesData',
          error: 'Routines restored from Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService._restoreRoutinesData',
        error: 'Routines restore failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // ========================
  // HABITS SYNC
  // ========================

  void _setupHabitsListener() {
    if (_userId == null || !_syncEnabled) return;

    _habitsListener = _firestore
        .collection('users')
        .doc(_userId)
        .collection('data')
        .doc('habits')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || _isRestoringHabits) return;

      try {
        final data = snapshot.data();
        if (data == null) return;

        final lastSync = data['lastSync'] as Timestamp?;
        if (lastSync == null) return;

        final remoteTimestamp = lastSync.millisecondsSinceEpoch;
        final localTimestamp = _lastSyncTimestamps['habits'] ?? 0;

        if (remoteTimestamp <= localTimestamp) {
          return;
        }

        if (kDebugMode) {
          await ErrorLogger.logError(
            source: 'RealtimeSyncService._setupHabitsListener',
            error: 'Habits changed remotely - syncing...',
            stackTrace: '',
          );
        }

        _isRestoringHabits = true;
        await _restoreHabitsData(data);
        await Future.delayed(const Duration(milliseconds: 100));
        _isRestoringHabits = false;

        _notifySyncEvent();
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._setupHabitsListener',
          error: 'Habits sync error: $e',
          stackTrace: stackTrace.toString(),
        );
        _isRestoringHabits = false;
      }
    });
  }

  Future<void> syncHabits(String habitsJson) async {
    if (!_syncEnabled || _userId == null || _isRestoringHabits) return;

    try {
      _lastSyncTimestamps['habits'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('data')
          .doc('habits')
          .set({
        'habits': habitsJson,
        'lastSync': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService.syncHabits',
          error: 'Habits synced to Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.syncHabits',
        error: 'Habits sync failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _restoreHabitsData(Map<String, dynamic> data) async {
    try {
      final habitsJson = data['habits'] as String?;
      if (habitsJson == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('habits', habitsJson);

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._restoreHabitsData',
          error: 'Habits restored from Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService._restoreHabitsData',
        error: 'Habits restore failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // ========================
  // ENERGY SYNC
  // ========================

  void _setupEnergyListener() {
    if (_userId == null || !_syncEnabled) return;

    _energyListener = _firestore
        .collection('users')
        .doc(_userId)
        .collection('data')
        .doc('energy')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || _isRestoringEnergy) return;

      try {
        final data = snapshot.data();
        if (data == null) return;

        final lastSync = data['lastSync'] as Timestamp?;
        if (lastSync == null) return;

        final remoteTimestamp = lastSync.millisecondsSinceEpoch;
        final localTimestamp = _lastSyncTimestamps['energy'] ?? 0;

        if (remoteTimestamp <= localTimestamp) {
          return;
        }

        if (kDebugMode) {
          await ErrorLogger.logError(
            source: 'RealtimeSyncService._setupEnergyListener',
            error: 'Energy data changed remotely - syncing...',
            stackTrace: '',
          );
        }

        _isRestoringEnergy = true;
        await _restoreEnergyData(data);
        await Future.delayed(const Duration(milliseconds: 100));
        _isRestoringEnergy = false;

        _notifySyncEvent();
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._setupEnergyListener',
          error: 'Energy sync error: $e',
          stackTrace: stackTrace.toString(),
        );
        _isRestoringEnergy = false;
      }
    });
  }

  Future<void> syncEnergy(Map<String, String> energyData) async {
    if (!_syncEnabled || _userId == null || _isRestoringEnergy) return;

    try {
      _lastSyncTimestamps['energy'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('data')
          .doc('energy')
          .set({
        'data': energyData,
        'lastSync': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService.syncEnergy',
          error: 'Energy data synced to Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.syncEnergy',
        error: 'Energy sync failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _restoreEnergyData(Map<String, dynamic> data) async {
    try {
      final energyData = data['data'] as Map<String, dynamic>?;
      if (energyData == null) return;

      final prefs = await SharedPreferences.getInstance();

      // Restore all energy-related keys
      for (final entry in energyData.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        }
      }

      if (kDebugMode) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._restoreEnergyData',
          error: 'Energy data restored from Firestore',
          stackTrace: '',
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService._restoreEnergyData',
        error: 'Energy restore failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  // ========================
  // UTILITY METHODS
  // ========================

  /// Check if user is logged in
  bool get isLoggedIn => _userId != null;

  /// Get current user ID
  String? get userId => _userId;

  /// Dispose all listeners
  Future<void> dispose() async {
    await _cancelAllListeners();
    _syncEventListeners.clear();
  }
}
