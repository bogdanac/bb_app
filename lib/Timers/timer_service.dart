import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/firebase_backup_service.dart';
import '../shared/error_logger.dart';
import 'timer_data_models.dart';

class TimerService {
  static const String _activitiesKey = 'timer_activities';

  // --- Real-time sync stream for timer state changes ---
  static final StreamController<Map<String, dynamic>?> _timerStateController =
      StreamController<Map<String, dynamic>?>.broadcast();

  /// Stream that broadcasts timer state changes.
  /// Subscribe to this to get real-time updates when timer starts/stops/pauses.
  static Stream<Map<String, dynamic>?> get timerStateStream =>
      _timerStateController.stream;
  static const String _sessionsKey = 'timer_sessions';
  static const String _activeTimerKey = 'timer_active_state';
  static const String _pomodoroWorkKey = 'timer_pomodoro_work_minutes';
  static const String _pomodoroBreakKey = 'timer_pomodoro_break_minutes';
  static const String _countdownKey = 'timer_countdown_minutes';
  static const String _autoFlowModeKey = 'timer_auto_flow_mode';
  static const String _longestFlowSessionKey = 'timer_longest_flow_session';
  static const String _totalFlowTimeKey = 'timer_total_flow_time';

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

  static Future<void> updateActivity(Activity updatedActivity) async {
    final activities = await loadActivities();
    final index = activities.indexWhere((a) => a.id == updatedActivity.id);
    if (index >= 0) {
      activities[index] = updatedActivity;
      await saveActivities(activities);
    }
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
    // Notify listeners of state change
    _timerStateController.add(state);
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
    // Notify listeners that timer was cleared
    _timerStateController.add(null);
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
    return prefs.getInt(_countdownKey) ?? 25;
  }

  static Future<void> setCountdownMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countdownKey, minutes);
  }

  /// Auto Flow Mode: when enabled, timer continues counting up after work period ends
  static Future<bool> getAutoFlowMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoFlowModeKey) ?? true;
  }

  static Future<void> setAutoFlowMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoFlowModeKey, enabled);
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

  // --- Global aggregation (all activities) ---

  /// Get daily totals across ALL activities
  static Future<Map<String, Duration>> getGlobalDailyTotals() async {
    final sessions = await loadSessions();
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

  /// Get sessions for a specific date across all activities
  static Future<List<TimerSession>> getSessionsForDate(DateTime date) async {
    final sessions = await loadSessions();
    return sessions.where((s) {
      return s.startTime.year == date.year &&
          s.startTime.month == date.month &&
          s.startTime.day == date.day;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Get breakdown by activity for a specific date
  static Future<Map<String, Duration>> getActivityBreakdownForDate(DateTime date) async {
    final sessions = await getSessionsForDate(date);
    final activities = await loadActivities();
    final activityNames = {for (var a in activities) a.id: a.name};

    // Add built-in productivity session names
    const builtInNames = {
      'productivity_pomodoro': 'Pomodoro Focus',
      'productivity_countdown': 'Countdown Timer',
    };

    final Map<String, Duration> breakdown = {};
    for (final session in sessions) {
      final name = activityNames[session.activityId]
          ?? builtInNames[session.activityId]
          ?? 'Unknown';
      breakdown[name] = (breakdown[name] ?? Duration.zero) + session.duration;
    }
    return breakdown;
  }

  /// Get grand total across all activities
  static Future<Duration> getGlobalGrandTotal() async {
    final sessions = await loadSessions();
    return sessions.fold<Duration>(
      Duration.zero,
      (total, s) => total + s.duration,
    );
  }

  /// Get total focus time (pomodoro work sessions + countdown timers)
  static Future<Duration> getTotalFocusTime() async {
    final sessions = await loadSessions();
    return sessions
        .where((s) =>
            s.activityId == 'productivity_pomodoro' ||
            s.activityId == 'productivity_countdown' ||
            s.type == TimerSessionType.pomodoro ||
            s.type == TimerSessionType.countdown)
        .fold<Duration>(
          Duration.zero,
          (total, s) => total + s.duration,
        );
  }

  /// Get today's focus time
  static Future<Duration> getTodaysFocusTime() async {
    final now = DateTime.now();
    final sessions = await getSessionsForDate(now);
    return sessions
        .where((s) =>
            s.activityId == 'productivity_pomodoro' ||
            s.activityId == 'productivity_countdown' ||
            s.type == TimerSessionType.pomodoro ||
            s.type == TimerSessionType.countdown)
        .fold<Duration>(
          Duration.zero,
          (total, s) => total + s.duration,
        );
  }

  /// Get weekly total for an activity (current week)
  static Future<Duration> getWeeklyTotal(String activityId) async {
    final sessions = await getSessionsForActivity(activityId);
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    return sessions
        .where((s) => s.startTime.isAfter(weekStart) ||
            (s.startTime.year == weekStart.year &&
             s.startTime.month == weekStart.month &&
             s.startTime.day == weekStart.day))
        .fold<Duration>(Duration.zero, (total, s) => total + s.duration);
  }

  /// Get monthly total for an activity (current month)
  static Future<Duration> getMonthlyTotal(String activityId) async {
    final sessions = await getSessionsForActivity(activityId);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return sessions
        .where((s) => s.startTime.isAfter(monthStart) ||
            (s.startTime.year == monthStart.year &&
             s.startTime.month == monthStart.month &&
             s.startTime.day == monthStart.day))
        .fold<Duration>(Duration.zero, (total, s) => total + s.duration);
  }

  // --- Session edit/delete ---

  /// Delete a specific session by ID
  static Future<void> deleteSession(String sessionId) async {
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await _saveSessions(sessions);
  }

  /// Update a session's duration
  static Future<void> updateSessionDuration(String sessionId, Duration newDuration) async {
    final sessions = await loadSessions();
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      final oldSession = sessions[index];
      sessions[index] = TimerSession(
        id: oldSession.id,
        activityId: oldSession.activityId,
        startTime: oldSession.startTime,
        endTime: oldSession.startTime.add(newDuration),
        duration: newDuration,
        type: oldSession.type,
      );
      await _saveSessions(sessions);
    }
  }

  // --- Flow stats ---

  /// Get the longest flow session duration (in minutes)
  static Future<int> getLongestFlowSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_longestFlowSessionKey) ?? 0;
  }

  /// Get total flow time (in minutes)
  static Future<int> getTotalFlowTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalFlowTimeKey) ?? 0;
  }

  /// Record a completed flow session and update stats
  static Future<void> recordFlowSession(int durationMinutes) async {
    final prefs = await SharedPreferences.getInstance();

    // Update longest session if this one is longer
    final currentLongest = prefs.getInt(_longestFlowSessionKey) ?? 0;
    if (durationMinutes > currentLongest) {
      await prefs.setInt(_longestFlowSessionKey, durationMinutes);
    }

    // Add to total flow time
    final currentTotal = prefs.getInt(_totalFlowTimeKey) ?? 0;
    await prefs.setInt(_totalFlowTimeKey, currentTotal + durationMinutes);
  }

  /// Get flow stats as a map
  static Future<Map<String, int>> getFlowStats() async {
    final longest = await getLongestFlowSession();
    final total = await getTotalFlowTime();
    return {
      'longestSession': longest,
      'totalTime': total,
    };
  }
}
