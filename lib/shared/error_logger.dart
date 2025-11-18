import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

/// Service to log errors both locally and to Firebase for debugging production issues
class ErrorLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _localLogsKey = 'error_logs_local';
  static const int _maxLocalLogs = 500;

  /// Log an error both locally and to Firebase with context
  static Future<void> logError({
    required String source,
    required String error,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final now = DateTime.now();
    final localLogEntry = {
      'source': source,
      'error': error,
      'stackTrace': stackTrace,
      'context': context,
      'timestamp': now.toIso8601String(),
      'platform': defaultTargetPlatform.name,
    };

    // Always log locally first (works offline)
    await _logLocally(localLogEntry, now);

    // Then try to log to Firebase
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('error_logs').add({
          'userId': user.uid,
          'source': source,
          'error': error,
          'stackTrace': stackTrace,
          'context': context,
          'timestamp': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.name,
        });

        // Clean up old logs (older than 7 days) - fire and forget
        unawaited(_cleanupOldLogs(user.uid, 'error_logs'));
      }
    } catch (e) {
      // Fail silently - don't let logging errors break the app
      if (kDebugMode) {
        print('Failed to log error to Firebase: $e');
      }
    }
  }

  /// Log error locally to SharedPreferences
  static Future<void> _logLocally(Map<String, dynamic> logEntry, DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = prefs.getStringList(_localLogsKey) ?? [];

      // Add new log at the beginning
      existingLogs.insert(0, jsonEncode(logEntry));

      // Only cleanup if we're over the limit (avoid expensive JSON decode on every log)
      if (existingLogs.length > _maxLocalLogs) {
        final sevenDaysAgo = now.subtract(const Duration(days: 7));

        // Filter out old logs first, then take the most recent _maxLocalLogs
        final recentLogs = <String>[];
        for (final logJson in existingLogs) {
          try {
            final log = jsonDecode(logJson) as Map<String, dynamic>;
            final timestamp = DateTime.parse(log['timestamp'] as String);
            if (timestamp.isAfter(sevenDaysAgo)) {
              recentLogs.add(logJson);
            }
          } catch (e) {
            recentLogs.add(logJson); // Keep if can't parse
          }
        }

        // Keep only the most recent logs (already sorted newest first)
        final filteredLogs = recentLogs.take(_maxLocalLogs).toList();
        await prefs.setStringList(_localLogsKey, filteredLogs);
      } else {
        await prefs.setStringList(_localLogsKey, existingLogs);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to log error locally: $e');
      }
    }
  }

  /// Get local error logs
  static Future<List<Map<String, dynamic>>> getLocalLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_localLogsKey) ?? [];
      return logs.map((log) => jsonDecode(log) as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get local logs: $e');
      }
      return [];
    }
  }

  /// Clear local error logs
  static Future<void> clearLocalLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localLogsKey);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear local logs: $e');
      }
    }
  }

  /// Clean up logs older than 7 days for the current user
  /// NOTE: Requires composite index in Firebase: userId (Ascending), timestamp (Ascending)
  static Future<void> _cleanupOldLogs(String userId, String collection, [int depth = 0]) async {
    // Prevent infinite recursion - max 10 batches (5000 logs)
    if (depth >= 10) return;

    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final oldLogs = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .limit(500) // Firestore batch limit
          .get();

      if (oldLogs.docs.isEmpty) return;

      // Delete old logs in batches (Firestore allows max 500 operations per batch)
      final batch = _firestore.batch();
      for (var doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // If we hit the limit, recursively delete more (with depth limit)
      if (oldLogs.docs.length == 500) {
        await _cleanupOldLogs(userId, collection, depth + 1);
      }
    } catch (e) {
      // Fail silently - might fail if index doesn't exist yet
      if (kDebugMode) {
        print('Failed to clean up old logs from $collection: $e');
      }
    }
  }

  /// Log widget update errors specifically
  static Future<void> logWidgetError({
    required String error,
    String? stackTrace,
    int? taskCount,
    int? filteredCount,
    int? prioritizedCount,
  }) async {
    await logError(
      source: 'TaskListWidgetFilterService',
      error: error,
      stackTrace: stackTrace,
      context: {
        'taskCount': taskCount,
        'filteredCount': filteredCount,
        'prioritizedCount': prioritizedCount,
      },
    );
  }

  /// Upload Android widget debug logs to Firebase
  static Future<void> uploadWidgetDebugLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString('flutter.widget_debug_logs');

    if (logsJson == null || logsJson.isEmpty || logsJson == '[]') {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Upload directly to Firebase as debug info (not an error)
        await _firestore.collection('widget_debug_logs').add({
          'userId': user.uid,
          'logs': logsJson,
          'timestamp': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.name,
        });

        // Clean up old widget debug logs - fire and forget
        unawaited(_cleanupOldLogs(user.uid, 'widget_debug_logs'));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to upload widget debug logs: $e');
      }
    } finally {
      // Always clear logs after attempt (even if upload failed)
      // This prevents accumulating logs that can't be uploaded
      try {
        await prefs.remove('flutter.widget_debug_logs');
      } catch (e) {
        if (kDebugMode) {
          print('Failed to clear widget debug logs: $e');
        }
      }
    }
  }
}
