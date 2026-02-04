import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/firebase_backup_service.dart';
import '../shared/error_logger.dart';
import 'timer_data_models.dart';

class TimerService {
  static const String _activitiesKey = 'timer_activities';
  static const String _sessionsKey = 'timer_sessions';
  static const String _activeTimerKey = 'timer_active_state';
  static const String _pomodoroWorkKey = 'timer_pomodoro_work_minutes';
  static const String _pomodoroBreakKey = 'timer_pomodoro_break_minutes';
  static const String _countdownKey = 'timer_countdown_minutes';

  // --- Activity CRUD ---

  static Future<List<Activity>> loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> activitiesJson = [];
    try {
      activitiesJson = prefs.getStringList(_activitiesKey) ?? [];
    } catch (e) {
      await ErrorLogger.logError(
        source: 'TimerService.loadActivities',
        error: 'Activities data corrupted, clearing: $e',
        stackTrace: '',
      );
      await prefs.remove(_activitiesKey);
      return [];
    }

    final activities = <Activity>[];
    for (int i = 0; i < activitiesJson.length; i++) {
      try {
        activities.add(Activity.fromJson(jsonDecode(activitiesJson[i])));
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'TimerService.loadActivities',
          error: 'Skipping corrupted activity $i: $e',
          stackTrace: stackTrace.toString(),
        );
      }
    }
    return activities;
  }

  static Future<void> saveActivities(List<Activity> activities) async {
    final prefs = await SharedPreferences.getInstance();
    final json = activities.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_activitiesKey, json);
    FirebaseBackupService.triggerBackup();
  }

  static Future<void> addActivity(Activity activity) async {
    final activities = await loadActivities();
    activities.add(activity);
    await saveActivities(activities);
  }

  static Future<void> deleteActivity(String activityId) async {
    final activities = await loadActivities();
    activities.removeWhere((a) => a.id == activityId);
    await saveActivities(activities);
    await deleteSessionsForActivity(activityId);
  }

  // --- Session CRUD ---

  static Future<List<TimerSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> sessionsJson = [];
    try {
      sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
    } catch (e) {
      await ErrorLogger.logError(
        source: 'TimerService.loadSessions',
        error: 'Sessions data corrupted, clearing: $e',
        stackTrace: '',
      );
      await prefs.remove(_sessionsKey);
      return [];
    }

    final sessions = <TimerSession>[];
    for (int i = 0; i < sessionsJson.length; i++) {
      try {
        sessions.add(TimerSession.fromJson(jsonDecode(sessionsJson[i])));
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'TimerService.loadSessions',
          error: 'Skipping corrupted session $i: $e',
          stackTrace: stackTrace.toString(),
        );
      }
    }
    return sessions;
  }

  static Future<void> _saveSessions(List<TimerSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final json = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_sessionsKey, json);
    FirebaseBackupService.triggerBackup();
  }

  static Future<List<TimerSession>> getSessionsForActivity(
      String activityId) async {
    final sessions = await loadSessions();
    return sessions.where((s) => s.activityId == activityId).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  static Future<void> addSession(TimerSession session) async {
    final sessions = await loadSessions();
    sessions.add(session);
    await _saveSessions(sessions);
  }

  static Future<void> deleteSessionsForActivity(String activityId) async {
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.activityId == activityId);
    await _saveSessions(sessions);
  }

  // --- Active timer state persistence ---

  static Future<void> saveActiveTimerState(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeTimerKey, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadActiveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_activeTimerKey);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      await prefs.remove(_activeTimerKey);
      return null;
    }
  }

  static Future<void> clearActiveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeTimerKey);
  }

  // --- Timer settings ---

  static Future<int> getPomodoroWorkMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pomodoroWorkKey) ?? 25;
  }

  static Future<void> setPomodoroWorkMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pomodoroWorkKey, minutes);
  }

  static Future<int> getPomodoroBreakMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pomodoroBreakKey) ?? 5;
  }

  static Future<void> setPomodoroBreakMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pomodoroBreakKey, minutes);
  }

  static Future<int> getCountdownMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_countdownKey) ?? 0;
  }

  static Future<void> setCountdownMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countdownKey, minutes);
  }

  // --- Aggregation ---

  static Future<Map<String, Duration>> getDailyTotals(
      String activityId) async {
    final sessions = await getSessionsForActivity(activityId);
    final Map<String, Duration> dailyMap = {};
    for (final session in sessions) {
      final dateKey =
          '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}-${session.startTime.day.toString().padLeft(2, '0')}';
      dailyMap[dateKey] = (dailyMap[dateKey] ?? Duration.zero) + session.duration;
    }
    return Map.fromEntries(
      dailyMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  static Future<Duration> getGrandTotal(String activityId) async {
    final sessions = await getSessionsForActivity(activityId);
    return sessions.fold<Duration>(
      Duration.zero,
      (total, s) => total + s.duration,
    );
  }
}
