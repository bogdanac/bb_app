// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'routine_data_models.dart';
import 'routine_widget_service.dart';
import '../shared/timezone_utils.dart';

class RoutineProgressService {
  static const String _progressPrefix = 'routine_progress_';
  static const String _activeRoutineKey = 'active_routine_';
  
  /// Get today's date in yyyy-MM-dd format
  static String getTodayString() {
    return TimezoneUtils.getTodayString();
  }

  /// Get the effective date for routine purposes (after 2 AM)
  static String getEffectiveDate() {
    return TimezoneUtils.getEffectiveDateString();
  }
  
  /// Mark a routine as in progress
  static Future<void> markRoutineInProgress(String routineId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = getEffectiveDate();
    
    final progressData = {
      'routineId': routineId,
      'status': 'in_progress',
      'startedAt': DateTime.now().toIso8601String(),
      'date': today,
    };
    
    await prefs.setString('$_activeRoutineKey$today', jsonEncode(progressData));
    
    // Update widget
    await RoutineWidgetService.updateWidget();
  }
  
  /// Get the current in-progress routine
  static Future<String?> getInProgressRoutineId() async {
    final prefs = await SharedPreferences.getInstance();
    final today = getEffectiveDate();
    
    final progressJson = prefs.getString('${_activeRoutineKey}$today');
    if (progressJson == null) return null;
    
    try {
      final progressData = jsonDecode(progressJson);
      if (progressData['status'] == 'in_progress') {
        return progressData['routineId'];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting in-progress routine: $e');
      }
    }
    
    return null;
  }
  
  /// Clear the in-progress status for a routine
  static Future<void> clearInProgressStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = getEffectiveDate();
    
    await prefs.remove('${_activeRoutineKey}$today');
    
    // Update widget
    await RoutineWidgetService.updateWidget();
  }
  
  /// Save routine progress
  static Future<void> saveRoutineProgress({
    required String routineId,
    required int currentStepIndex,
    required List<RoutineItem> items,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();
    
    final progressData = {
      'routineId': routineId,
      'currentStepIndex': currentStepIndex,
      'completedSteps': items.map((item) => item.isCompleted).toList(),
      'skippedSteps': items.map((item) => item.isSkipped).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
      'itemCount': items.length,
    };
    
    // Save with routine-specific key
    await prefs.setString('${_progressPrefix}${routineId}_$today', jsonEncode(progressData));
    
    // Legacy: Also save as morning_routine_progress for backwards compatibility
    await prefs.setString('morning_routine_progress_$today', jsonEncode(progressData));
    await prefs.setString('morning_routine_last_date', today);
    
    // Update widget
    await RoutineWidgetService.updateWidget();
  }
  
  /// Load routine progress
  static Future<Map<String, dynamic>?> loadRoutineProgress(String routineId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();
    
    // Try routine-specific key first
    var progressJson = prefs.getString('${_progressPrefix}${routineId}_$today');
    
    // Fallback to legacy morning routine progress for backwards compatibility
    progressJson ??= prefs.getString('morning_routine_progress_$today');
    
    if (progressJson == null) return null;
    
    try {
      final progressData = jsonDecode(progressJson);
      
      // Validate that progress is for today
      final lastUpdated = progressData['lastUpdated'];
      if (lastUpdated != null) {
        final updatedDate = DateTime.tryParse(lastUpdated);
        if (updatedDate != null) {
          final updatedDateString = DateFormat('yyyy-MM-dd').format(updatedDate);
          if (updatedDateString != today) {
            return null; // Progress is from a different day
          }
        }
      }
      
      return progressData;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading routine progress: $e');
      }
      return null;
    }
  }
  
  /// Clear routine progress
  static Future<void> clearRoutineProgress(String routineId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = getTodayString();
    
    await prefs.remove('${_progressPrefix}${routineId}_$today');
    
    // Also clear legacy morning routine progress for backwards compatibility
    await prefs.remove('morning_routine_progress_$today');
    
    // Update widget
    await RoutineWidgetService.updateWidget();
  }
  
}