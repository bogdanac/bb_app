import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/error_logger.dart';
import '../Routines/routine_recovery_helper.dart';
import '../Tasks/repositories/task_repository.dart';

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

      // Check if same user - but still do recovery check
      final isSameUser = newUserId == _userId;

      // Set user ID
      _userId = newUserId;

      // AUTO-RECOVERY: Check for corrupted routines and recover from Firestore
      // Only run on web where SharedPreferences doesn't persist, or on new user login
      // Skip for mobile same-user case to prevent hanging
      if (kIsWeb || !isSameUser) {
        try {
          final isRoutinesCorrupted = await RoutineRecoveryHelper.areRoutinesCorrupted();
          if (isRoutinesCorrupted) {
            await ErrorLogger.logError(
              source: 'RealtimeSyncService._onAuthStateChanged',
              error: 'Corrupted routines detected, attempting recovery...',
              stackTrace: '',
            );
            final recovered = await RoutineRecoveryHelper.recoverRoutinesFromFirestore();
            await ErrorLogger.logError(
              source: 'RealtimeSyncService._onAuthStateChanged',
              error: recovered ? 'Routines recovered successfully!' : 'Routine recovery failed',
              stackTrace: '',
            );
          }
        } catch (e) {
          await ErrorLogger.logError(
            source: 'RealtimeSyncService._onAuthStateChanged',
            error: 'Routine recovery check failed: $e',
            stackTrace: '',
          );
        }
      }

      // Skip listener setup if same user (already set up)
      if (isSameUser) {
        return;
      }

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

        // Skip if this is our own sync (use 2s tolerance for server timestamp drift)
        if (localTimestamp > 0 && (remoteTimestamp - localTimestamp).abs() < 2000) {
          return;
        }
        // Skip if remote is older than our last sync
        if (remoteTimestamp < localTimestamp) {
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
    final userId = _userId ?? _auth.currentUser?.uid;
    if (!_syncEnabled || userId == null || _isRestoringTasks) return;

    // SAFETY: Never sync empty tasks data - this prevents data loss
    try {
      final List<dynamic> tasksList = jsonDecode(tasksJson);
      if (tasksList.isEmpty) {
        debugPrint('RealtimeSyncService.syncTasks: BLOCKED - refusing to sync empty tasks!');
        return;
      }
    } catch (e) {
      debugPrint('RealtimeSyncService.syncTasks: BLOCKED - invalid tasks JSON!');
      return;
    }

    try {
      _lastSyncTimestamps['tasks'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(userId)
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

  /// Sync categories to Firestore (stored in the same 'tasks' document)
  Future<void> syncCategories(String categoriesJson) async {
    final userId = _userId ?? _auth.currentUser?.uid;
    if (!_syncEnabled || userId == null) return;

    // SAFETY: Allow empty categories (user might delete all custom categories)
    try {
      _lastSyncTimestamps['categories'] = DateTime.now().millisecondsSinceEpoch;

      // Use update to preserve existing 'tasks' field
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc('tasks')
          .set({
        'categories': categoriesJson,
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('RealtimeSyncService.syncCategories: Categories synced to Firestore');
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.syncCategories',
        error: 'Categories sync failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  Future<void> _restoreTasksData(Map<String, dynamic> data) async {
    try {
      final tasksJson = data['tasks'] as String?;
      if (tasksJson == null) return;

      final prefs = await SharedPreferences.getInstance();
      // Decode the outer JSON array
      final List<dynamic> tasksList = jsonDecode(tasksJson);

      // Process each item - could be a Map (object) or String (already JSON)
      final List<String> tasksStringList = [];
      for (final item in tasksList) {
        if (item is Map) {
          // Item is a parsed object, encode it
          tasksStringList.add(jsonEncode(item));
        } else if (item is String) {
          // Item is already a JSON string, use as-is (validate first)
          try {
            jsonDecode(item); // Validate it's valid JSON
            tasksStringList.add(item);
          } catch (_) {
            // Invalid JSON string, skip
          }
        }
      }
      await prefs.setStringList('tasks', tasksStringList);

      // Mark web data as verified — Firestore listener confirmed fresh data,
      // so future saves from TaskRepository can safely sync back to Firestore
      if (kIsWeb) {
        TaskRepository().markWebDataVerified();
      }

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

        // Check if local routines are empty - if so, always restore from remote
        final prefs = await SharedPreferences.getInstance();
        final localRoutines = prefs.getStringList('routines');
        final localIsEmpty = localRoutines == null || localRoutines.isEmpty;

        // For timestamp comparison (only if lastSync exists)
        final lastSync = data['lastSync'] as Timestamp?;
        if (lastSync != null) {
          final remoteTimestamp = lastSync.millisecondsSinceEpoch;
          final localTimestamp = _lastSyncTimestamps['routines'] ?? 0;

          // Skip if this is our own sync (use 2s tolerance for server timestamp drift)
          if (localTimestamp > 0 && (remoteTimestamp - localTimestamp).abs() < 2000 && !localIsEmpty) {
            return;
          }
          // Skip if remote is older than our last sync AND local is not empty
          if (remoteTimestamp < localTimestamp && !localIsEmpty) {
            return;
          }
        } else if (!localIsEmpty) {
          // No lastSync field and local has data - don't overwrite
          return;
        }

        if (kDebugMode) {
          await ErrorLogger.logError(
            source: 'RealtimeSyncService._setupRoutinesListener',
            error: localIsEmpty
                ? 'Local routines empty - restoring from Firestore...'
                : 'Routines changed remotely - syncing...',
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
    final userId = _userId ?? _auth.currentUser?.uid;
    if (!_syncEnabled || userId == null || _isRestoringRoutines) return;

    // SAFETY: Never sync empty routines data - this prevents data loss
    try {
      final List<dynamic> routinesList = jsonDecode(routinesJson);
      if (routinesList.isEmpty) {
        debugPrint('RealtimeSyncService.syncRoutines: BLOCKED - refusing to sync empty routines!');
        return;
      }
    } catch (e) {
      debugPrint('RealtimeSyncService.syncRoutines: BLOCKED - invalid routines JSON!');
      return;
    }

    try {
      _lastSyncTimestamps['routines'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(userId)
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
      final prefs = await SharedPreferences.getInstance();
      final List<String> routinesStringList = [];

      // Check for new format: 'routines' field with JSON array
      final routinesJson = data['routines'] as String?;
      if (routinesJson != null) {
        // Decode the outer JSON array
        final List<dynamic> routinesList = jsonDecode(routinesJson);

        // Process each item - could be a Map (object) or String
        for (final item in routinesList) {
          if (item is Map) {
            // Item is already a parsed object, encode it
            routinesStringList.add(jsonEncode(item));
          } else if (item is String) {
            // Item is a string - check if it's valid JSON
            try {
              jsonDecode(item); // Validate it's valid JSON
              routinesStringList.add(item); // It's valid, use as-is
            } catch (_) {
              // Invalid JSON string, skip it
            }
          }
        }
      }

      // Check for legacy format: any field that contains a valid routine JSON
      if (routinesStringList.isEmpty) {
        for (final entry in data.entries) {
          // Skip known non-routine fields
          if (entry.key == 'lastSync' || entry.key == 'progress') continue;

          final value = entry.value;
          if (value is String) {
            try {
              final parsed = jsonDecode(value);
              // Verify it looks like a routine (has id and title or items)
              if (parsed is Map && (parsed.containsKey('id') && (parsed.containsKey('title') || parsed.containsKey('items')))) {
                routinesStringList.add(value);
              }
            } catch (_) {
              // Invalid JSON, skip
            }
          }
        }
      }

      if (routinesStringList.isEmpty) {
        await ErrorLogger.logError(
          source: 'RealtimeSyncService._restoreRoutinesData',
          error: 'No valid routines found in Firestore data',
          stackTrace: '',
        );
        return;
      }

      await prefs.setStringList('routines', routinesStringList);

      // Restore progress data
      final progressData = data['progress'] as Map<String, dynamic>?;
      if (progressData != null) {
        for (final entry in progressData.entries) {
          final value = entry.value;
          if (value is String) {
            await prefs.setString(entry.key, value);
          }
        }
      }

      await ErrorLogger.logError(
        source: 'RealtimeSyncService._restoreRoutinesData',
        error: 'Routines restored from Firestore: ${routinesStringList.length} routines',
        stackTrace: '',
      );
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

        // Skip if this is our own sync (use 2s tolerance for server timestamp drift)
        if (localTimestamp > 0 && (remoteTimestamp - localTimestamp).abs() < 2000) {
          return;
        }
        if (remoteTimestamp < localTimestamp) {
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
    final userId = _userId ?? _auth.currentUser?.uid;
    if (!_syncEnabled || userId == null || _isRestoringHabits) return;

    // SAFETY: Never sync empty habits data - this prevents data loss
    try {
      final List<dynamic> habitsList = jsonDecode(habitsJson);
      if (habitsList.isEmpty) {
        debugPrint('RealtimeSyncService.syncHabits: BLOCKED - refusing to sync empty habits!');
        return;
      }
    } catch (e) {
      debugPrint('RealtimeSyncService.syncHabits: BLOCKED - invalid habits JSON!');
      return;
    }

    try {
      _lastSyncTimestamps['habits'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(userId)
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
      // Decode the outer JSON array
      final List<dynamic> habitsList = jsonDecode(habitsJson);

      // Process each item - could be a Map (object) or String (already JSON)
      final List<String> habitsStringList = [];
      for (final item in habitsList) {
        if (item is Map) {
          // Item is a parsed object, encode it
          habitsStringList.add(jsonEncode(item));
        } else if (item is String) {
          // Item is already a JSON string, use as-is (validate first)
          try {
            jsonDecode(item); // Validate it's valid JSON
            habitsStringList.add(item);
          } catch (_) {
            // Invalid JSON string, skip
          }
        }
      }
      await prefs.setStringList('habits', habitsStringList);

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

        // Skip if this is our own sync (use 2s tolerance for server timestamp drift)
        if (localTimestamp > 0 && (remoteTimestamp - localTimestamp).abs() < 2000) {
          return;
        }
        if (remoteTimestamp < localTimestamp) {
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
    final userId = _userId ?? _auth.currentUser?.uid;
    if (!_syncEnabled || userId == null || _isRestoringEnergy) return;

    try {
      _lastSyncTimestamps['energy'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('users')
          .doc(userId)
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

  /// Fetch habits directly from Firestore (for web where SharedPreferences is unreliable)
  Future<List<String>?> fetchHabitsFromFirestore() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? _userId;

    if (userId == null) {
      debugPrint('RealtimeSyncService.fetchHabitsFromFirestore: No user logged in');
      return null;
    }

    debugPrint('RealtimeSyncService.fetchHabitsFromFirestore: Fetching for user $userId');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc('habits')
          .get();

      if (!doc.exists) {
        debugPrint('RealtimeSyncService.fetchHabitsFromFirestore: No habits doc in Firestore');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('RealtimeSyncService.fetchHabitsFromFirestore: Habits doc is empty');
        return null;
      }

      final habitsJson = data['habits'] as String?;
      if (habitsJson == null) {
        debugPrint('RealtimeSyncService.fetchHabitsFromFirestore: No habits field');
        return null;
      }

      final List<dynamic> habitsList = jsonDecode(habitsJson);
      debugPrint('RealtimeSyncService.fetchHabitsFromFirestore: Found ${habitsList.length} habits');

      final List<String> habitsStringList = [];
      for (final item in habitsList) {
        if (item is Map) {
          habitsStringList.add(jsonEncode(item));
        } else if (item is String) {
          try {
            jsonDecode(item);
            habitsStringList.add(item);
          } catch (_) {}
        }
      }

      return habitsStringList;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.fetchHabitsFromFirestore',
        error: 'Failed to fetch habits from Firestore: $e',
        stackTrace: stackTrace.toString(),
      );
      return null;
    }
  }

  /// Fetch tasks directly from Firestore (for web where SharedPreferences is unreliable)
  Future<List<String>?> fetchTasksFromFirestore() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? _userId;

    if (userId == null) {
      debugPrint('RealtimeSyncService.fetchTasksFromFirestore: No user logged in');
      return null;
    }

    debugPrint('RealtimeSyncService.fetchTasksFromFirestore: Fetching for user $userId');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc('tasks')
          .get();

      if (!doc.exists) {
        debugPrint('RealtimeSyncService.fetchTasksFromFirestore: No tasks doc in Firestore');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('RealtimeSyncService.fetchTasksFromFirestore: Tasks doc is empty');
        return null;
      }

      final tasksJson = data['tasks'] as String?;
      if (tasksJson == null) {
        debugPrint('RealtimeSyncService.fetchTasksFromFirestore: No tasks field');
        return null;
      }

      final List<dynamic> tasksList = jsonDecode(tasksJson);
      debugPrint('RealtimeSyncService.fetchTasksFromFirestore: Found ${tasksList.length} tasks');

      final List<String> tasksStringList = [];
      for (final item in tasksList) {
        if (item is Map) {
          tasksStringList.add(jsonEncode(item));
        } else if (item is String) {
          try {
            jsonDecode(item);
            tasksStringList.add(item);
          } catch (_) {}
        }
      }

      return tasksStringList;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.fetchTasksFromFirestore',
        error: 'Failed to fetch tasks from Firestore: $e',
        stackTrace: stackTrace.toString(),
      );
      return null;
    }
  }

  /// Fetch routines directly from Firestore (for web where SharedPreferences is unreliable)
  /// Returns null if not available, empty list if no routines in Firestore
  Future<List<String>?> fetchRoutinesFromFirestore() async {
    // Get user directly from FirebaseAuth (don't rely on _userId which may not be set yet)
    final user = _auth.currentUser;
    final userId = user?.uid ?? _userId;

    if (userId == null) {
      debugPrint('RealtimeSyncService.fetchRoutinesFromFirestore: No user logged in');
      return null;
    }

    debugPrint('RealtimeSyncService.fetchRoutinesFromFirestore: Fetching for user $userId');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc('routines')
          .get();

      if (!doc.exists) {
        debugPrint('RealtimeSyncService.fetchRoutinesFromFirestore: No routines doc in Firestore');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('RealtimeSyncService.fetchRoutinesFromFirestore: Routines doc is empty');
        return null;
      }

      final List<String> routinesStringList = [];

      // Check for new format: 'routines' field with JSON array
      final routinesJson = data['routines'] as String?;
      if (routinesJson != null) {
        final List<dynamic> routinesList = jsonDecode(routinesJson);
        debugPrint('RealtimeSyncService.fetchRoutinesFromFirestore: Found ${routinesList.length} routines in Firestore');

        for (final item in routinesList) {
          if (item is Map) {
            routinesStringList.add(jsonEncode(item));
          } else if (item is String) {
            try {
              jsonDecode(item);
              routinesStringList.add(item);
            } catch (_) {}
          }
        }
      }

      // Check for legacy format if new format didn't work
      if (routinesStringList.isEmpty) {
        for (final entry in data.entries) {
          if (entry.key == 'lastSync' || entry.key == 'progress') continue;
          final value = entry.value;
          if (value is String) {
            try {
              final parsed = jsonDecode(value);
              if (parsed is Map && (parsed.containsKey('id') && (parsed.containsKey('title') || parsed.containsKey('items')))) {
                routinesStringList.add(value);
              }
            } catch (_) {}
          }
        }
      }

      debugPrint('RealtimeSyncService.fetchRoutinesFromFirestore: Returning ${routinesStringList.length} routines');
      return routinesStringList;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.fetchRoutinesFromFirestore',
        error: 'Failed to fetch routines from Firestore: $e',
        stackTrace: stackTrace.toString(),
      );
      return null;
    }
  }

  /// Fetch categories directly from Firestore (for web where SharedPreferences is unreliable)
  Future<List<String>?> fetchCategoriesFromFirestore() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? _userId;

    if (userId == null) {
      debugPrint('RealtimeSyncService.fetchCategoriesFromFirestore: No user logged in');
      return null;
    }

    debugPrint('RealtimeSyncService.fetchCategoriesFromFirestore: Fetching for user $userId');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc('tasks')
          .get();

      if (!doc.exists) {
        debugPrint('RealtimeSyncService.fetchCategoriesFromFirestore: No tasks doc in Firestore');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('RealtimeSyncService.fetchCategoriesFromFirestore: Tasks doc is empty');
        return null;
      }

      final categoriesJson = data['categories'] as String?;
      if (categoriesJson == null) {
        debugPrint('RealtimeSyncService.fetchCategoriesFromFirestore: No categories field');
        return null;
      }

      final List<dynamic> categoriesList = jsonDecode(categoriesJson);
      debugPrint('RealtimeSyncService.fetchCategoriesFromFirestore: Found ${categoriesList.length} categories');

      final List<String> categoriesStringList = [];
      for (final item in categoriesList) {
        if (item is Map) {
          categoriesStringList.add(jsonEncode(item));
        } else if (item is String) {
          try {
            jsonDecode(item);
            categoriesStringList.add(item);
          } catch (_) {}
        }
      }

      return categoriesStringList;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RealtimeSyncService.fetchCategoriesFromFirestore',
        error: 'Failed to fetch categories from Firestore: $e',
        stackTrace: stackTrace.toString(),
      );
      return null;
    }
  }

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
