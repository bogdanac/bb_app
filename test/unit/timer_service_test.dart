import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Timers/timer_data_models.dart';
import 'package:bb_app/Timers/timer_service.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  group('Activity Model', () {
    test('serializes to JSON and back', () {
      final activity = Activity(
        id: '123',
        name: 'Piano Practice',
        createdAt: DateTime(2025, 1, 15, 10, 30),
      );

      final json = activity.toJson();
      final restored = Activity.fromJson(json);

      expect(restored.id, '123');
      expect(restored.name, 'Piano Practice');
      expect(restored.createdAt, DateTime(2025, 1, 15, 10, 30));
    });

    test('defaults createdAt to now when not provided', () {
      final before = DateTime.now();
      final activity = Activity(id: '1', name: 'Test');
      final after = DateTime.now();

      expect(activity.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(activity.createdAt.isBefore(after.add(const Duration(seconds: 1))), true);
    });
  });

  group('TimerSession Model', () {
    test('serializes to JSON and back', () {
      final session = TimerSession(
        id: '456',
        activityId: '123',
        startTime: DateTime(2025, 1, 15, 10, 0),
        endTime: DateTime(2025, 1, 15, 10, 25),
        duration: const Duration(minutes: 25),
        type: TimerSessionType.pomodoro,
      );

      final json = session.toJson();
      final restored = TimerSession.fromJson(json);

      expect(restored.id, '456');
      expect(restored.activityId, '123');
      expect(restored.startTime, DateTime(2025, 1, 15, 10, 0));
      expect(restored.endTime, DateTime(2025, 1, 15, 10, 25));
      expect(restored.duration, const Duration(minutes: 25));
      expect(restored.type, TimerSessionType.pomodoro);
    });

    test('preserves all session types', () {
      for (final type in TimerSessionType.values) {
        final session = TimerSession(
          id: '1',
          activityId: '1',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 5),
          type: type,
        );
        final restored = TimerSession.fromJson(session.toJson());
        expect(restored.type, type);
      }
    });
  });

  group('TimerService', () {
    setUp(() {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    group('Activity CRUD', () {
      test('loadActivities returns empty list when none saved', () async {
        final activities = await TimerService.loadActivities();
        expect(activities, isEmpty);
      });

      test('addActivity and loadActivities round-trip', () async {
        final activity = Activity(
          id: '1',
          name: 'Piano Practice',
          createdAt: DateTime(2025, 1, 15),
        );

        await TimerService.addActivity(activity);
        final loaded = await TimerService.loadActivities();

        expect(loaded.length, 1);
        expect(loaded.first.id, '1');
        expect(loaded.first.name, 'Piano Practice');
      });

      test('saveActivities replaces all activities', () async {
        await TimerService.addActivity(
            Activity(id: '1', name: 'Activity 1'));
        await TimerService.addActivity(
            Activity(id: '2', name: 'Activity 2'));

        final newList = [Activity(id: '3', name: 'Activity 3')];
        await TimerService.saveActivities(newList);

        final loaded = await TimerService.loadActivities();
        expect(loaded.length, 1);
        expect(loaded.first.id, '3');
      });

      test('deleteActivity removes activity and its sessions', () async {
        await TimerService.addActivity(
            Activity(id: 'act1', name: 'Test'));
        await TimerService.addSession(TimerSession(
          id: 'sess1',
          activityId: 'act1',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 10),
          type: TimerSessionType.activity,
        ));

        await TimerService.deleteActivity('act1');

        final activities = await TimerService.loadActivities();
        final sessions =
            await TimerService.getSessionsForActivity('act1');

        expect(activities, isEmpty);
        expect(sessions, isEmpty);
      });
    });

    group('Session CRUD', () {
      test('addSession and loadSessions round-trip', () async {
        final session = TimerSession(
          id: '1',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 15, 10, 0),
          endTime: DateTime(2025, 1, 15, 10, 25),
          duration: const Duration(minutes: 25),
          type: TimerSessionType.countdown,
        );

        await TimerService.addSession(session);
        final loaded = await TimerService.loadSessions();

        expect(loaded.length, 1);
        expect(loaded.first.id, '1');
        expect(loaded.first.duration, const Duration(minutes: 25));
      });

      test('getSessionsForActivity filters by activityId', () async {
        await TimerService.addSession(TimerSession(
          id: '1',
          activityId: 'act1',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 10),
          type: TimerSessionType.activity,
        ));
        await TimerService.addSession(TimerSession(
          id: '2',
          activityId: 'act2',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 20),
          type: TimerSessionType.activity,
        ));
        await TimerService.addSession(TimerSession(
          id: '3',
          activityId: 'act1',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 15),
          type: TimerSessionType.pomodoro,
        ));

        final act1Sessions =
            await TimerService.getSessionsForActivity('act1');
        final act2Sessions =
            await TimerService.getSessionsForActivity('act2');

        expect(act1Sessions.length, 2);
        expect(act2Sessions.length, 1);
      });

      test('getSessionsForActivity returns sorted by start time descending', () async {
        await TimerService.addSession(TimerSession(
          id: '1',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 10),
          endTime: DateTime(2025, 1, 10),
          duration: const Duration(minutes: 10),
          type: TimerSessionType.activity,
        ));
        await TimerService.addSession(TimerSession(
          id: '2',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 15),
          endTime: DateTime(2025, 1, 15),
          duration: const Duration(minutes: 20),
          type: TimerSessionType.activity,
        ));

        final sessions =
            await TimerService.getSessionsForActivity('act1');

        expect(sessions.first.startTime.isAfter(sessions.last.startTime),
            true);
      });

      test('deleteSessionsForActivity only deletes matching sessions', () async {
        await TimerService.addSession(TimerSession(
          id: '1',
          activityId: 'act1',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 10),
          type: TimerSessionType.activity,
        ));
        await TimerService.addSession(TimerSession(
          id: '2',
          activityId: 'act2',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 20),
          type: TimerSessionType.activity,
        ));

        await TimerService.deleteSessionsForActivity('act1');

        final allSessions = await TimerService.loadSessions();
        expect(allSessions.length, 1);
        expect(allSessions.first.activityId, 'act2');
      });
    });

    group('Aggregation', () {
      test('getDailyTotals groups sessions by date', () async {
        await TimerService.addSession(TimerSession(
          id: '1',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 15, 10, 0),
          endTime: DateTime(2025, 1, 15, 10, 25),
          duration: const Duration(minutes: 25),
          type: TimerSessionType.pomodoro,
        ));
        await TimerService.addSession(TimerSession(
          id: '2',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 15, 14, 0),
          endTime: DateTime(2025, 1, 15, 14, 30),
          duration: const Duration(minutes: 30),
          type: TimerSessionType.countdown,
        ));
        await TimerService.addSession(TimerSession(
          id: '3',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 16, 9, 0),
          endTime: DateTime(2025, 1, 16, 9, 15),
          duration: const Duration(minutes: 15),
          type: TimerSessionType.activity,
        ));

        final dailyTotals =
            await TimerService.getDailyTotals('act1');

        expect(dailyTotals.length, 2);
        expect(dailyTotals['2025-01-15'], const Duration(minutes: 55));
        expect(dailyTotals['2025-01-16'], const Duration(minutes: 15));
      });

      test('getDailyTotals returns sorted by date descending', () async {
        await TimerService.addSession(TimerSession(
          id: '1',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 10),
          endTime: DateTime(2025, 1, 10),
          duration: const Duration(minutes: 10),
          type: TimerSessionType.activity,
        ));
        await TimerService.addSession(TimerSession(
          id: '2',
          activityId: 'act1',
          startTime: DateTime(2025, 1, 20),
          endTime: DateTime(2025, 1, 20),
          duration: const Duration(minutes: 20),
          type: TimerSessionType.activity,
        ));

        final dailyTotals =
            await TimerService.getDailyTotals('act1');
        final keys = dailyTotals.keys.toList();

        expect(keys.first.compareTo(keys.last) > 0, true);
      });

      test('getGrandTotal sums all sessions for an activity', () async {
        await TimerService.addSession(TimerSession(
          id: '1',
          activityId: 'act1',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 25),
          type: TimerSessionType.pomodoro,
        ));
        await TimerService.addSession(TimerSession(
          id: '2',
          activityId: 'act1',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 15),
          type: TimerSessionType.countdown,
        ));
        await TimerService.addSession(TimerSession(
          id: '3',
          activityId: 'act2',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          duration: const Duration(minutes: 100),
          type: TimerSessionType.activity,
        ));

        final total = await TimerService.getGrandTotal('act1');
        expect(total, const Duration(minutes: 40));
      });

      test('getGrandTotal returns zero for activity with no sessions', () async {
        final total = await TimerService.getGrandTotal('nonexistent');
        expect(total, Duration.zero);
      });
    });

    group('Active timer state', () {
      test('save and load round-trip', () async {
        final state = {
          'type': 'productivity',
          'activityId': 'act1',
          'mode': 'pomodoro',
          'wasRunning': true,
          'remainingSeconds': 1500,
        };

        await TimerService.saveActiveTimerState(state);
        final loaded = await TimerService.loadActiveTimerState();

        expect(loaded, isNotNull);
        expect(loaded!['type'], 'productivity');
        expect(loaded['activityId'], 'act1');
        expect(loaded['wasRunning'], true);
        expect(loaded['remainingSeconds'], 1500);
      });

      test('clearActiveTimerState removes state', () async {
        await TimerService.saveActiveTimerState({'test': true});
        await TimerService.clearActiveTimerState();

        final loaded = await TimerService.loadActiveTimerState();
        expect(loaded, isNull);
      });

      test('loadActiveTimerState returns null when nothing saved', () async {
        final loaded = await TimerService.loadActiveTimerState();
        expect(loaded, isNull);
      });
    });

    group('Timer settings', () {
      test('pomodoro work minutes default to 25', () async {
        final minutes = await TimerService.getPomodoroWorkMinutes();
        expect(minutes, 25);
      });

      test('pomodoro break minutes default to 5', () async {
        final minutes = await TimerService.getPomodoroBreakMinutes();
        expect(minutes, 5);
      });

      test('countdown minutes default to 25', () async {
        final minutes = await TimerService.getCountdownMinutes();
        expect(minutes, 25);
      });

      test('set and get pomodoro work minutes', () async {
        await TimerService.setPomodoroWorkMinutes(45);
        final minutes = await TimerService.getPomodoroWorkMinutes();
        expect(minutes, 45);
      });

      test('set and get pomodoro break minutes', () async {
        await TimerService.setPomodoroBreakMinutes(10);
        final minutes = await TimerService.getPomodoroBreakMinutes();
        expect(minutes, 10);
      });

      test('set and get countdown minutes', () async {
        await TimerService.setCountdownMinutes(60);
        final minutes = await TimerService.getCountdownMinutes();
        expect(minutes, 60);
      });
    });

    group('Error handling', () {
      test('loadActivities handles corrupted data gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'timer_activities': ['{"id":"1","name":"Good","createdAt":"2025-01-15T10:00:00.000"}', 'not-valid-json'],
        });

        final activities = await TimerService.loadActivities();
        expect(activities.length, 1);
        expect(activities.first.name, 'Good');
      });

      test('loadSessions handles corrupted data gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'timer_sessions': [
            jsonEncode(TimerSession(
              id: '1',
              activityId: 'a1',
              startTime: DateTime(2025, 1, 1),
              endTime: DateTime(2025, 1, 1),
              duration: const Duration(minutes: 10),
              type: TimerSessionType.activity,
            ).toJson()),
            'corrupted-json',
          ],
        });

        final sessions = await TimerService.loadSessions();
        expect(sessions.length, 1);
        expect(sessions.first.id, '1');
      });

      test('loadActiveTimerState handles corrupted JSON', () async {
        SharedPreferences.setMockInitialValues({
          'timer_active_state': 'not-json',
        });

        final state = await TimerService.loadActiveTimerState();
        expect(state, isNull);
      });
    });
  });
}
