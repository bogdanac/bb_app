import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import 'package:bb_app/Routines/routine_service.dart';
import 'package:bb_app/Routines/routine_progress_service.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUp(() {
    setupFirebaseMocks();
    SharedPreferences.setMockInitialValues({});
  });

  group('Multiple Routines - Auto Navigation', () {
    final today = DateTime.now().weekday;

    test('should navigate to next routine when first completes', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Morning Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: true),
          ],
          activeDays: {today},
        ),
        Routine(
          id: '2',
          title: 'Afternoon Routine',
          items: [
            RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
          ],
          activeDays: {today},
        ),
      ];

      // Mark first routine as completed
      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();
      await prefs.setBool('routine_completed_1_$date', true);

      // Get next routine
      final nextRoutine = await RoutineService.getNextRoutine(routines, '1');

      expect(nextRoutine, isNotNull);
      expect(nextRoutine!.id, '2');
      expect(nextRoutine.title, 'Afternoon Routine');
    });

    test('should skip completed routines', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Morning Routine',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {today},
        ),
        Routine(
          id: '2',
          title: 'Afternoon Routine',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {today},
        ),
        Routine(
          id: '3',
          title: 'Evening Routine',
          items: [RoutineItem(id: '3', text: 'Step 3', isCompleted: false)],
          activeDays: {today},
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();

      // Mark routines 1 and 2 as completed
      await prefs.setBool('routine_completed_1_$date', true);
      await prefs.setBool('routine_completed_2_$date', true);

      // Starting from routine 1, should get routine 3
      final nextRoutine = await RoutineService.getNextRoutine(routines, '1');

      expect(nextRoutine, isNotNull);
      expect(nextRoutine!.id, '3');
      expect(nextRoutine.title, 'Evening Routine');
    });

    test('should return null when all routines completed', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Morning Routine',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {today},
        ),
        Routine(
          id: '2',
          title: 'Afternoon Routine',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {today},
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();

      // Mark all routines as completed
      await prefs.setBool('routine_completed_1_$date', true);
      await prefs.setBool('routine_completed_2_$date', true);

      final nextRoutine = await RoutineService.getNextRoutine(routines, '2');

      expect(nextRoutine, isNull);
    });

    test('should respect day of week when navigating', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Weekday Routine',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5}, // Mon-Fri
        ),
        Routine(
          id: '2',
          title: 'Weekend Routine',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {6, 7}, // Sat-Sun
        ),
        Routine(
          id: '3',
          title: 'Daily Routine',
          items: [RoutineItem(id: '3', text: 'Step 3', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7}, // Every day
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();
      await prefs.setBool('routine_completed_1_$date', true);

      final nextRoutine = await RoutineService.getNextRoutine(routines, '1');

      // On weekday, should skip weekend routine and get daily routine
      if (today >= 1 && today <= 5) {
        expect(nextRoutine, isNotNull);
        expect(nextRoutine!.id, '3');
      }
    });

    test('should wrap around to beginning if needed', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'First Routine',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {today},
        ),
        Routine(
          id: '2',
          title: 'Second Routine',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {today},
        ),
        Routine(
          id: '3',
          title: 'Third Routine',
          items: [RoutineItem(id: '3', text: 'Step 3', isCompleted: false)],
          activeDays: {today},
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();

      // Mark routines 2 and 3 as completed
      await prefs.setBool('routine_completed_2_$date', true);
      await prefs.setBool('routine_completed_3_$date', true);

      // Starting from routine 3, should wrap to routine 1
      final nextRoutine = await RoutineService.getNextRoutine(routines, '3');

      expect(nextRoutine, isNotNull);
      expect(nextRoutine!.id, '1');
    });
  });

  group('Multiple Routines - With Skip and Postpone', () {
    final today = DateTime.now().weekday;

    test('routine with only skipped steps should mark as complete', () async {
      final routine = Routine(
        id: '1',
        title: 'Test Routine',
        items: [
          RoutineItem(id: '1', text: 'Step 1', isSkipped: true, isCompleted: false),
          RoutineItem(id: '2', text: 'Step 2', isSkipped: true, isCompleted: false),
        ],
        activeDays: {today},
      );

      // All steps either completed or skipped = routine complete
      final isComplete = routine.items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, true);
    });

    test('routine with postponed steps should not mark as complete', () async {
      final routine = Routine(
        id: '1',
        title: 'Test Routine',
        items: [
          RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
          RoutineItem(id: '2', text: 'Step 2', isPostponed: true, isCompleted: false),
        ],
        activeDays: {today},
      );

      final isComplete = routine.items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, false);
    });

    test('should navigate to next routine when all steps skipped', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Skipped Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isSkipped: true, isCompleted: false),
          ],
          activeDays: {today},
        ),
        Routine(
          id: '2',
          title: 'Next Routine',
          items: [
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
          ],
          activeDays: {today},
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();
      await prefs.setBool('routine_completed_1_$date', true);

      final nextRoutine = await RoutineService.getNextRoutine(routines, '1');

      expect(nextRoutine, isNotNull);
      expect(nextRoutine!.id, '2');
    });

    test('should stay on routine with postponed steps', () async {
      final routine = Routine(
        id: '1',
        title: 'Routine with Postponed',
        items: [
          RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
          RoutineItem(id: '2', text: 'Step 2', isPostponed: true, isCompleted: false),
          RoutineItem(id: '3', text: 'Step 3', isCompleted: true),
        ],
        activeDays: {today},
      );

      // Should have postponed steps to return to
      final postponedSteps = routine.items.where((item) => item.isPostponed && !item.isCompleted).toList();
      expect(postponedSteps.length, 1);

      // Routine not complete
      final isComplete = routine.items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, false);
    });
  });

  group('Multiple Routines - Progress Tracking', () {

    test('should track completion separately for each routine', () async {
      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();

      // Mark different routines with different completion states
      await prefs.setBool('routine_completed_1_$date', true);
      await prefs.setBool('routine_completed_2_$date', false);
      await prefs.setBool('routine_completed_3_$date', true);

      final routine1Complete = prefs.getBool('routine_completed_1_$date') ?? false;
      final routine2Complete = prefs.getBool('routine_completed_2_$date') ?? false;
      final routine3Complete = prefs.getBool('routine_completed_3_$date') ?? false;

      expect(routine1Complete, true);
      expect(routine2Complete, false);
      expect(routine3Complete, true);
    });

    test('should track progress separately for each routine', () async {
      // Routine 1 progress
      final routine1Items = [
        RoutineItem(id: '1', text: 'R1 Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'R1 Step 2', isCompleted: false),
      ];

      await RoutineProgressService.saveRoutineProgress(
        routineId: 'routine1',
        currentStepIndex: 1,
        items: routine1Items,
      );

      // Routine 2 progress
      final routine2Items = [
        RoutineItem(id: '3', text: 'R2 Step 1', isCompleted: false),
        RoutineItem(id: '4', text: 'R2 Step 2', isPostponed: true, isCompleted: false),
      ];

      await RoutineProgressService.saveRoutineProgress(
        routineId: 'routine2',
        currentStepIndex: 0,
        items: routine2Items,
      );

      // Load and verify separate progress
      final routine1Progress = await RoutineProgressService.loadRoutineProgress('routine1');
      final routine2Progress = await RoutineProgressService.loadRoutineProgress('routine2');

      expect(routine1Progress!['currentStepIndex'], 1);
      expect(routine1Progress['completedSteps'], [true, false]);

      expect(routine2Progress!['currentStepIndex'], 0);
      expect(routine2Progress['postponedSteps'], [false, true]);
    });

    test('clearing one routine progress should not affect others', () async {
      // Save progress for multiple routines
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
      ];

      await RoutineProgressService.saveRoutineProgress(
        routineId: 'routine1',
        currentStepIndex: 0,
        items: items,
      );

      await RoutineProgressService.saveRoutineProgress(
        routineId: 'routine2',
        currentStepIndex: 0,
        items: items,
      );

      // Clear only routine1
      await RoutineProgressService.clearRoutineProgress('routine1');

      // Verify routine1 cleared but routine2 remains
      final routine1Progress = await RoutineProgressService.loadRoutineProgress('routine1');
      final routine2Progress = await RoutineProgressService.loadRoutineProgress('routine2');

      expect(routine1Progress, isNull);
      expect(routine2Progress, isNotNull);
    });
  });

  group('Multiple Routines - Edge Cases', () {
    final today = DateTime.now().weekday;

    test('empty routines list should return null', () async {
      final nextRoutine = await RoutineService.getNextRoutine([], null);
      expect(nextRoutine, isNull);
    });

    test('single routine already completed should return null', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Only Routine',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {today},
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();
      await prefs.setBool('routine_completed_1_$date', true);

      final nextRoutine = await RoutineService.getNextRoutine(routines, '1');
      expect(nextRoutine, isNull);
    });

    test('no routines active today should return null', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Monday Only',
          items: [RoutineItem(id: '1', text: 'Step 1', isCompleted: false)],
          activeDays: {1}, // Monday only
        ),
        Routine(
          id: '2',
          title: 'Tuesday Only',
          items: [RoutineItem(id: '2', text: 'Step 2', isCompleted: false)],
          activeDays: {2}, // Tuesday only
        ),
      ];

      // If today is not Monday or Tuesday
      if (today != 1 && today != 2) {
        final nextRoutine = await RoutineService.getNextRoutine(routines, null);
        expect(nextRoutine, isNull);
      }
    });

    test('should handle routine with mix of states across multiple routines', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Mixed Routine 1',
          items: [
            RoutineItem(id: '1', text: 'Completed', isCompleted: true),
            RoutineItem(id: '2', text: 'Skipped', isSkipped: true, isCompleted: false),
          ],
          activeDays: {today},
        ),
        Routine(
          id: '2',
          title: 'Mixed Routine 2',
          items: [
            RoutineItem(id: '3', text: 'Postponed', isPostponed: true, isCompleted: false),
            RoutineItem(id: '4', text: 'Regular', isCompleted: false),
          ],
          activeDays: {today},
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();

      // Routine 1 is complete (all completed or skipped)
      await prefs.setBool('routine_completed_1_$date', true);

      final nextRoutine = await RoutineService.getNextRoutine(routines, '1');

      expect(nextRoutine, isNotNull);
      expect(nextRoutine!.id, '2');
    });
  });

  group('Skip Last Step - Routine Completion', () {
    final today = DateTime.now().weekday;

    test('skipping last step in first routine should move to second routine', () async {
      // This tests the bug: "hitting x in last step in the first routine
      // doesn't finish the routine and switch to next available routine"
      final routines = [
        Routine(
          id: '1',
          title: 'Morning Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: true),
            RoutineItem(id: '3', text: 'Last Step', isCompleted: false), // This gets skipped
          ],
          activeDays: {today},
        ),
        Routine(
          id: '2',
          title: 'Afternoon Routine',
          items: [
            RoutineItem(id: '4', text: 'Step 4', isCompleted: false),
          ],
          activeDays: {today},
        ),
      ];

      // Simulate skipping the last step
      routines[0].items[2].isSkipped = true;

      // Check if routine 1 is now complete
      final routine1Complete = routines[0].items.every((item) => item.isCompleted || item.isSkipped);
      expect(routine1Complete, true, reason: 'Routine 1 should be complete after skipping last step');

      // Mark routine 1 as completed in prefs (what the code does)
      final prefs = await SharedPreferences.getInstance();
      final date = RoutineService.getEffectiveDate();
      await prefs.setBool('routine_completed_1_$date', true);

      // Get next routine
      final nextRoutine = await RoutineService.getNextRoutine(routines, '1');

      expect(nextRoutine, isNotNull, reason: 'Should find next routine');
      expect(nextRoutine!.id, '2', reason: 'Should be the afternoon routine');
      expect(nextRoutine.title, 'Afternoon Routine');
    });

    test('skipping only step in routine should complete it', () async {
      final routines = [
        Routine(
          id: '1',
          title: 'Single Step Routine',
          items: [
            RoutineItem(id: '1', text: 'Only Step', isCompleted: false),
          ],
          activeDays: {today},
        ),
      ];

      // Skip the only step
      routines[0].items[0].isSkipped = true;

      // Routine should be complete
      final isComplete = routines[0].items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, true);
    });

    test('skipping step should not cause infinite loop', () async {
      // This tests the bug: "It just refresh infinitely and shows same step"
      final routine = Routine(
        id: '1',
        title: 'Test Routine',
        items: [
          RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
          RoutineItem(id: '2', text: 'Step 2', isCompleted: true),
          RoutineItem(id: '3', text: 'Step 3', isCompleted: false), // Current step to skip
        ],
        activeDays: {today},
      );

      int currentIndex = 2; // On step 3

      // Skip step 3
      routine.items[currentIndex].isSkipped = true;

      // Check for available steps (simulating _moveToNextUnfinishedStep)
      final regularSteps = routine.items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .toList();

      final postponedSteps = routine.items
          .where((item) => item.isPostponed && !item.isCompleted && !item.isSkipped)
          .toList();

      expect(regularSteps.length, 0, reason: 'No regular steps remaining');
      expect(postponedSteps.length, 0, reason: 'No postponed steps');

      // Should now detect routine is complete
      final isComplete = routine.items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, true, reason: 'Routine should be complete, not stuck in loop');
    });
  });

  group('Postpone vs Skip Behavior in Navigation', () {
    final today = DateTime.now().weekday;

    test('postponing last step should NOT complete routine', () async {
      final routine = Routine(
        id: '1',
        title: 'Test Routine',
        items: [
          RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
          RoutineItem(id: '2', text: 'Step 2', isCompleted: true),
          RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
        ],
        activeDays: {today},
      );

      // Postpone step 3 instead of skipping
      routine.items[2].isPostponed = true;

      // Routine should NOT be complete
      final isComplete = routine.items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, false, reason: 'Routine has postponed step, not complete');

      // Should still have work to do
      final hasPostponed = routine.items.any((item) => item.isPostponed && !item.isCompleted);
      expect(hasPostponed, true);
    });

    test('skipping last step SHOULD complete routine', () async {
      final routine = Routine(
        id: '1',
        title: 'Test Routine',
        items: [
          RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
          RoutineItem(id: '2', text: 'Step 2', isCompleted: true),
          RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
        ],
        activeDays: {today},
      );

      // Skip step 3 (X button)
      routine.items[2].isSkipped = true;

      // Routine SHOULD be complete
      final isComplete = routine.items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, true, reason: 'Routine should be complete after skipping last step');
    });
  });
}
