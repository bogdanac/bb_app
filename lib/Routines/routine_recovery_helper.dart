import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/error_logger.dart';

/// One-time helper to recover routines from Firestore after the sync bug
class RoutineRecoveryHelper {
  static Future<bool> recoverRoutinesFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Get routines from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('data')
          .doc('routines')
          .get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data();
      if (data == null) {
        return false;
      }

      final routinesJson = data['routines'] as String?;
      if (routinesJson == null) {
        return false;
      }

      // Parse the JSON string back to StringList
      final List<dynamic> routinesList = jsonDecode(routinesJson);
      final List<String> routinesStringList = routinesList.map((e) => e.toString()).toList();

      // Save to SharedPreferences with correct format
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('routines', routinesStringList);

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

  /// Check if routines are corrupted (stored as String instead of StringList)
  static Future<bool> areRoutinesCorrupted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to get as StringList (correct format)
      final stringListValue = prefs.getStringList('routines');
      if (stringListValue != null) {
        return false;
      }

      // Check if stored as String (corrupted format)
      final stringValue = prefs.getString('routines');
      if (stringValue != null) {
        return true;
      }

      return false; // No routines is not corrupted, just empty
    } catch (e) {
      return true;
    }
  }
}
