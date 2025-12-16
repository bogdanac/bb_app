import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/error_logger.dart';

/// Helper class for detecting and recovering corrupted routines data
class RoutineRecoveryHelper {
  static const String _routinesKey = 'routines';

  /// Check if local routines data is corrupted (empty when it shouldn't be)
  static Future<bool> areRoutinesCorrupted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to load routines
      List<String>? routinesJson;
      try {
        routinesJson = prefs.getStringList(_routinesKey);
      } catch (e) {
        // Data type mismatch indicates corruption
        return true;
      }

      // If routines is null or empty, check if we have data in Firestore
      // If Firestore has data but local is empty, consider it corrupted
      if (routinesJson == null || routinesJson.isEmpty) {
        final hasFirestoreData = await _hasRoutinesInFirestore();
        return hasFirestoreData;
      }

      return false;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RoutineRecoveryHelper.areRoutinesCorrupted',
        error: 'Error checking routines corruption: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }

  /// Check if Firestore has routines data for the current user
  static Future<bool> _hasRoutinesInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('data')
          .doc('routines')
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final routinesJson = data['routines'] as String?;
      if (routinesJson == null || routinesJson.isEmpty) return false;

      // Try to parse the routines to verify it's valid data
      final List<dynamic> routinesList = jsonDecode(routinesJson);
      return routinesList.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Recover routines from Firestore real-time sync collection
  static Future<bool> recoverRoutinesFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await ErrorLogger.logError(
          source: 'RoutineRecoveryHelper.recoverRoutinesFromFirestore',
          error: 'No user logged in, cannot recover routines',
          stackTrace: '',
        );
        return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('data')
          .doc('routines')
          .get();

      if (!doc.exists) {
        await ErrorLogger.logError(
          source: 'RoutineRecoveryHelper.recoverRoutinesFromFirestore',
          error: 'No routines document found in Firestore',
          stackTrace: '',
        );
        return false;
      }

      final data = doc.data();
      if (data == null) {
        await ErrorLogger.logError(
          source: 'RoutineRecoveryHelper.recoverRoutinesFromFirestore',
          error: 'Routines document is empty',
          stackTrace: '',
        );
        return false;
      }

      final routinesJson = data['routines'] as String?;
      if (routinesJson == null || routinesJson.isEmpty) {
        await ErrorLogger.logError(
          source: 'RoutineRecoveryHelper.recoverRoutinesFromFirestore',
          error: 'No routines data in Firestore document',
          stackTrace: '',
        );
        return false;
      }

      // Parse and save to SharedPreferences
      // Each routine must be re-encoded as JSON string (not .toString())
      final List<dynamic> routinesList = jsonDecode(routinesJson);
      final List<String> routinesStringList = routinesList.map((e) => jsonEncode(e)).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_routinesKey, routinesStringList);

      // Also restore progress data if available
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
        source: 'RoutineRecoveryHelper.recoverRoutinesFromFirestore',
        error: 'Successfully recovered ${routinesStringList.length} routines from Firestore',
        stackTrace: '',
      );

      return true;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RoutineRecoveryHelper.recoverRoutinesFromFirestore',
        error: 'Failed to recover routines: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }
}
