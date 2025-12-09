import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/error_logger.dart';

/// One-time helper to recover tasks from Firestore after the sync bug
class TaskRecoveryHelper {
  static Future<bool> recoverTasksFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ERROR: No user logged in');
        return false;
      }

      print('Attempting to recover tasks for user: ${user.uid}');

      // Get tasks from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('data')
          .doc('tasks')
          .get();

      if (!doc.exists) {
        print('ERROR: No tasks document found in Firestore');
        return false;
      }

      final data = doc.data();
      if (data == null) {
        print('ERROR: Tasks document has no data');
        return false;
      }

      final tasksJson = data['tasks'] as String?;
      if (tasksJson == null) {
        print('ERROR: No tasks field in document');
        return false;
      }

      print('Found tasks data in Firestore');
      print('Tasks JSON length: ${tasksJson.length} characters');

      // Parse the JSON string back to StringList
      final List<dynamic> tasksList = jsonDecode(tasksJson);
      final List<String> tasksStringList = tasksList.map((e) => e.toString()).toList();

      print('Parsed ${tasksStringList.length} tasks');

      // Save to SharedPreferences with correct format
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tasks', tasksStringList);

      print('✓ SUCCESS: Restored ${tasksStringList.length} tasks to local storage');

      return true;
    } catch (e, stackTrace) {
      print('ERROR recovering tasks: $e');
      await ErrorLogger.logError(
        source: 'TaskRecoveryHelper.recoverTasksFromFirestore',
        error: 'Failed to recover tasks: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }

  /// Check if tasks are corrupted (stored as String instead of StringList)
  static Future<bool> areTasksCorrupted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to get as StringList (correct format)
      final stringListValue = prefs.getStringList('tasks');
      if (stringListValue != null) {
        print('Tasks are in correct format (StringList with ${stringListValue.length} items)');
        return false;
      }

      // Check if stored as String (corrupted format)
      final stringValue = prefs.getString('tasks');
      if (stringValue != null) {
        print('Tasks are CORRUPTED (stored as String instead of StringList)');
        return true;
      }

      print('No tasks found in local storage');
      return true; // Consider empty as corrupted to trigger recovery
    } catch (e) {
      print('Error checking tasks: $e');
      return true;
    }
  }
}
