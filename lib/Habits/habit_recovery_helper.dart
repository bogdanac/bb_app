import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/error_logger.dart';

/// One-time helper to recover habits from Firestore after the sync bug
class HabitRecoveryHelper {
  static Future<bool> recoverHabitsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ERROR: No user logged in');
        return false;
      }

      print('Attempting to recover habits for user: ${user.uid}');

      // Get habits from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('data')
          .doc('habits')
          .get();

      if (!doc.exists) {
        print('ERROR: No habits document found in Firestore');
        return false;
      }

      final data = doc.data();
      if (data == null) {
        print('ERROR: Habits document has no data');
        return false;
      }

      final habitsJson = data['habits'] as String?;
      if (habitsJson == null) {
        print('ERROR: No habits field in document');
        return false;
      }

      print('Found habits data in Firestore');
      print('Habits JSON length: ${habitsJson.length} characters');

      // Parse the JSON string back to StringList
      final List<dynamic> habitsList = jsonDecode(habitsJson);
      final List<String> habitsStringList = habitsList.map((e) => e.toString()).toList();

      print('Parsed ${habitsStringList.length} habits');

      // Save to SharedPreferences with correct format
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('habits', habitsStringList);

      print('SUCCESS: Restored ${habitsStringList.length} habits to local storage');

      return true;
    } catch (e, stackTrace) {
      print('ERROR recovering habits: $e');
      await ErrorLogger.logError(
        source: 'HabitRecoveryHelper.recoverHabitsFromFirestore',
        error: 'Failed to recover habits: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }

  /// Check if habits are corrupted (stored as String instead of StringList)
  static Future<bool> areHabitsCorrupted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to get as StringList (correct format)
      final stringListValue = prefs.getStringList('habits');
      if (stringListValue != null) {
        print('Habits are in correct format (StringList with ${stringListValue.length} items)');
        return false;
      }

      // Check if stored as String (corrupted format)
      final stringValue = prefs.getString('habits');
      if (stringValue != null) {
        print('Habits are CORRUPTED (stored as String instead of StringList)');
        return true;
      }

      print('No habits found in local storage');
      return false; // No habits is not corrupted, just empty
    } catch (e) {
      print('Error checking habits: $e');
      return true;
    }
  }
}
