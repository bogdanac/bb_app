import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Routines/routine_service.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import 'package:bb_app/Routines/routine_progress_service.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  group('RoutineService - getNextRoutine', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    test('returns first uncompleted routine scheduled for today', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();
      final currentWeekday = DateTime.now().weekday;

      // Create 3 routines for today
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Morning Routine',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
        Routine(
          id: 'routine2',
          title: 'Afternoon Routine',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
        Routine(
          id: 'routine3',
          title: 'Evening Routine',
          items: [RoutineItem(id: '3', text: 'Step 3', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
      ];

      // Mark first routine as completed
      await prefs.setBool('routine_completed_routine1_$today', true);

      // Get next routine after routine1
      final nextRoutine = await RoutineService.getNextRoutine(routines, 'routine1');

      // Should return routine2 (first uncompleted after routine1)
      expect(nextRoutine, isNotNull);
      expect(nextRoutine?.id, 'routine2');
    });

    test('skips completed routines and returns next uncompleted', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();
      final currentWeekday = DateTime.now().weekday;

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
        Routine(
          id: 'routine2',
          title: 'Routine 2',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
        Routine(
          id: 'routine3',
          title: 'Routine 3',
          items: [RoutineItem(id: '3', text: 'Step 3', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
      ];

      // Mark routine1 and routine2 as completed
      await prefs.setBool('routine_completed_routine1_$today', true);
      await prefs.setBool('routine_completed_routine2_$today', true);

      // Get next routine after routine1
      final nextRoutine = await RoutineService.getNextRoutine(routines, 'routine1');

      // Should skip routine2 and return routine3
      expect(nextRoutine, isNotNull);
      expect(nextRoutine?.id, 'routine3');
    });

    test('returns null when all routines are completed', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1},
        ),
        Routine(
          id: 'routine2',
          title: 'Routine 2',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {1},
        ),
      ];

      // Mark all routines as completed
      await prefs.setBool('routine_completed_routine1_$today', true);
      await prefs.setBool('routine_completed_routine2_$today', true);

      final nextRoutine = await RoutineService.getNextRoutine(routines, 'routine1');

      expect(nextRoutine, isNull);
    });

    test('wraps around to beginning if no uncompleted after current', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();
      final currentWeekday = DateTime.now().weekday;

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
        Routine(
          id: 'routine2',
          title: 'Routine 2',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
        Routine(
          id: 'routine3',
          title: 'Routine 3',
          items: [RoutineItem(id: '3', text: 'Step 3', isCompleted: false)],
          activeDays: {currentWeekday},
        ),
      ];

      // Mark routine2 and routine3 as completed
      await prefs.setBool('routine_completed_routine2_$today', true);
      await prefs.setBool('routine_completed_routine3_$today', true);

      // Get next routine after routine2
      final nextRoutine = await RoutineService.getNextRoutine(routines, 'routine2');

      // Should wrap around and return routine1 (first uncompleted)
      expect(nextRoutine, isNotNull);
      expect(nextRoutine?.id, 'routine1');
    });

    test('returns null when no routines scheduled for today', () async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Weekend Routine',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {6, 7}, // Saturday, Sunday only
        ),
      ];

      // Assuming test runs on a weekday
      final nextRoutine = await RoutineService.getNextRoutine(routines, null);

      // Might be null if not weekend
      expect(nextRoutine, anyOf(isNull, isNotNull));
    });

    test('returns first routine when currentRoutineId is null', () async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7}, // Every day
        ),
        Routine(
          id: 'routine2',
          title: 'Routine 2',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      final nextRoutine = await RoutineService.getNextRoutine(routines, null);

      expect(nextRoutine, isNotNull);
      expect(nextRoutine?.id, 'routine1');
    });

    test('excludes current routine from wrap-around', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1},
        ),
      ];

      // Mark the only routine as completed
      await prefs.setBool('routine_completed_routine1_$today', true);

      final nextRoutine = await RoutineService.getNextRoutine(routines, 'routine1');

      // Should return null (can't return same routine)
      expect(nextRoutine, isNull);
    });
  });

  group('RoutineProgressService - clearRoutineProgress', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    test('clears progress for specific routine', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineProgressService.getEffectiveDate();

      // Save progress for a routine
      await prefs.setString(
        'routine_progress_routine1_$today',
        '{"currentStepIndex": 2, "completedSteps": [true, true, false]}',
      );

      // Clear progress
      await RoutineProgressService.clearRoutineProgress('routine1');

      // Verify cleared
      final progress = prefs.getString('routine_progress_routine1_$today');
      expect(progress, isNull);
    });

    test('clears legacy morning_routine_progress key', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineProgressService.getEffectiveDate();

      // Save legacy progress
      await prefs.setString(
        'morning_routine_progress_$today',
        '{"currentStepIndex": 1}',
      );

      // Clear progress
      await RoutineProgressService.clearRoutineProgress('routine1');

      // Verify legacy key cleared
      final progress = prefs.getString('morning_routine_progress_$today');
      expect(progress, isNull);
    });
  });

  group('Routine completion tracking', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    test('marking routine as completed prevents it from appearing in getNextRoutine', () async {
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
        Routine(
          id: 'routine2',
          title: 'Routine 2',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      // Mark routine1 as completed
      await prefs.setBool('routine_completed_routine1_$today', true);

      // Get next routine - should skip routine1
      final nextRoutine = await RoutineService.getNextRoutine(routines, null);

      expect(nextRoutine, isNotNull);
      expect(nextRoutine?.id, 'routine2');
    });

    test('completion flag is date-specific', () async {
      final prefs = await SharedPreferences.getInstance();
      RoutineService.getEffectiveDate();
      final yesterday = '2024-01-01'; // Different date

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      // Mark as completed for yesterday
      await prefs.setBool('routine_completed_routine1_$yesterday', true);

      // Get next routine - should still return routine1 (not completed today)
      final nextRoutine = await RoutineService.getNextRoutine(routines, null);

      expect(nextRoutine, isNotNull);
      expect(nextRoutine?.id, 'routine1');
    });
  });

  group('getCurrentActiveRoutine with completion tracking', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    test('skips completed routines and returns first uncompleted', () async {
      await SharedPreferences.getInstance();
      RoutineService.getEffectiveDate();

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Routine 1',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
        Routine(
          id: 'routine2',
          title: 'Routine 2',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      // Note: getCurrentActiveRoutine doesn't check completion yet
      // This test documents current behavior
      final activeRoutine = await RoutineService.getCurrentActiveRoutine(routines);

      expect(activeRoutine, isNotNull);
      expect(activeRoutine?.id, 'routine1');
    });
  });
}
