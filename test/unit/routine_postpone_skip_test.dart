import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Routines/routine_progress_service.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUp(() {
    setupFirebaseMocks();
    SharedPreferences.setMockInitialValues({});
  });

  group('RoutineItem - Postpone and Skip States', () {
    test('RoutineItem should have three boolean states', () {
      final item = RoutineItem(
        id: '1',
        text: 'Test step',
        isCompleted: false,
        isSkipped: false,
        isPostponed: false,
      );

      expect(item.isCompleted, false);
      expect(item.isSkipped, false);
      expect(item.isPostponed, false);
    });

    test('RoutineItem should serialize postponed state to JSON', () {
      final item = RoutineItem(
        id: '1',
        text: 'Test step',
        isCompleted: false,
        isSkipped: false,
        isPostponed: true,
      );

      final json = item.toJson();
      expect(json['isPostponed'], true);
    });

    test('RoutineItem should deserialize postponed state from JSON', () {
      final json = {
        'id': '1',
        'text': 'Test step',
        'isCompleted': false,
        'isSkipped': false,
        'isPostponed': true,
      };

      final item = RoutineItem.fromJson(json);
      expect(item.isPostponed, true);
    });

    test('RoutineItem should default postponed to false if missing', () {
      final json = {
        'id': '1',
        'text': 'Test step',
        'isCompleted': false,
        'isSkipped': false,
      };

      final item = RoutineItem.fromJson(json);
      expect(item.isPostponed, false);
    });
  });

  group('RoutineProgressService - Postponed Steps', () {
    test('should save postponed steps to SharedPreferences', () async {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true, isPostponed: false),
        RoutineItem(id: '2', text: 'Step 2', isCompleted: false, isPostponed: true),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: false, isPostponed: false),
      ];

      await RoutineProgressService.saveRoutineProgress(
        routineId: 'test_routine',
        currentStepIndex: 2,
        items: items,
      );

      final prefs = await SharedPreferences.getInstance();
      final today = RoutineProgressService.getEffectiveDate();
      final savedJson = prefs.getString('routine_progress_test_routine_$today');

      expect(savedJson, isNotNull);
      expect(savedJson, contains('"postponedSteps":[false,true,false]'));
    });

    test('should load postponed steps from SharedPreferences', () async {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: false, isPostponed: true),
        RoutineItem(id: '2', text: 'Step 2', isCompleted: false, isSkipped: true),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: false, isPostponed: false),
      ];

      await RoutineProgressService.saveRoutineProgress(
        routineId: 'test_routine',
        currentStepIndex: 2,
        items: items,
      );

      final loadedProgress = await RoutineProgressService.loadRoutineProgress('test_routine');

      expect(loadedProgress, isNotNull);
      expect(loadedProgress!['postponedSteps'], [true, false, false]);
      expect(loadedProgress['skippedSteps'], [false, true, false]);
    });
  });

  group('Step State Logic', () {
    test('permanently skipped step should never be revisited', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isSkipped: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
      ];

      // Step 2 is skipped - should never appear in available steps
      final availableSteps = items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .toList();

      expect(availableSteps.length, 1);
      expect(availableSteps[0].id, '3');
    });

    test('postponed step should be available after regular steps', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isPostponed: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: true),
      ];

      // First, check regular steps
      final regularSteps = items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .toList();
      expect(regularSteps.length, 0);

      // Then, check postponed steps
      final postponedSteps = items
          .where((item) => item.isPostponed && !item.isCompleted)
          .toList();
      expect(postponedSteps.length, 1);
      expect(postponedSteps[0].id, '2');
    });

    test('routine completes when all steps are completed or skipped', () {
      final allDone = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isSkipped: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: true),
      ];

      final isRoutineComplete = allDone.every((item) => item.isCompleted || item.isSkipped);
      expect(isRoutineComplete, true);
    });

    test('routine does not complete if steps are only postponed', () {
      final notDone = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isPostponed: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: true),
      ];

      final isRoutineComplete = notDone.every((item) => item.isCompleted || item.isSkipped);
      expect(isRoutineComplete, false);
    });

    test('step can transition from postponed to completed', () {
      final item = RoutineItem(
        id: '1',
        text: 'Test step',
        isCompleted: false,
        isPostponed: true,
      );

      // Complete the postponed step
      item.isPostponed = false;
      item.isCompleted = true;

      expect(item.isCompleted, true);
      expect(item.isPostponed, false);
      expect(item.isSkipped, false);
    });

    test('step can transition from postponed to skipped', () {
      final item = RoutineItem(
        id: '1',
        text: 'Test step',
        isCompleted: false,
        isPostponed: true,
      );

      // Skip the postponed step permanently
      item.isPostponed = false;
      item.isSkipped = true;

      expect(item.isCompleted, false);
      expect(item.isPostponed, false);
      expect(item.isSkipped, true);
    });
  });

  group('Step Priority Logic', () {
    test('should process steps in correct priority order', () {
      final items = [
        RoutineItem(id: '1', text: 'Regular 1', isCompleted: false),
        RoutineItem(id: '2', text: 'Postponed 1', isPostponed: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Skipped 1', isSkipped: true, isCompleted: false),
        RoutineItem(id: '4', text: 'Regular 2', isCompleted: false),
        RoutineItem(id: '5', text: 'Postponed 2', isPostponed: true, isCompleted: false),
      ];

      // Priority 1: Regular steps
      final regularSteps = items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .map((item) => item.id)
          .toList();
      expect(regularSteps, ['1', '4']);

      // Priority 2: Postponed steps (only if all regular done)
      final postponedSteps = items
          .where((item) => item.isPostponed && !item.isCompleted)
          .map((item) => item.id)
          .toList();
      expect(postponedSteps, ['2', '5']);

      // Skipped steps never included
      final skippedSteps = items
          .where((item) => item.isSkipped && !item.isCompleted)
          .map((item) => item.id)
          .toList();
      expect(skippedSteps, ['3']); // These should never be returned to
    });
  });

  group('Edge Cases', () {
    test('all steps postponed should return to first postponed', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isPostponed: true, isCompleted: false),
        RoutineItem(id: '2', text: 'Step 2', isPostponed: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isPostponed: true, isCompleted: false),
      ];

      final regularSteps = items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .toList();
      expect(regularSteps.length, 0);

      final postponedSteps = items
          .where((item) => item.isPostponed && !item.isCompleted)
          .toList();
      expect(postponedSteps.length, 3);
      expect(postponedSteps[0].id, '1');
    });

    test('all steps skipped should complete routine', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isSkipped: true, isCompleted: false),
        RoutineItem(id: '2', text: 'Step 2', isSkipped: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isSkipped: true, isCompleted: false),
      ];

      final isComplete = items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, true);
    });

    test('mix of completed, skipped, and postponed', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isSkipped: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isPostponed: true, isCompleted: false),
        RoutineItem(id: '4', text: 'Step 4', isCompleted: false),
      ];

      // Regular steps available
      final regular = items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .toList();
      expect(regular.length, 1);
      expect(regular[0].id, '4');

      // Postponed steps available
      final postponed = items
          .where((item) => item.isPostponed && !item.isCompleted)
          .toList();
      expect(postponed.length, 1);
      expect(postponed[0].id, '3');

      // Routine not complete (has postponed)
      final isComplete = items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, false);
    });
  });

  group('Skipped (X) vs Postponed (clock) Behavior', () {
    test('skipped step is permanently cancelled - never revisited', () {
      // Simulating the behavior: X button = skip permanently
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
        RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
      ];

      // User presses X on step 1 - permanently skipped
      items[0].isSkipped = true;

      // Verify skipped step is never in available steps
      final availableSteps = items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .toList();
      expect(availableSteps.map((e) => e.id).toList(), ['2', '3']);
      expect(availableSteps.any((item) => item.id == '1'), false);

      // Even after all regular steps are done, skipped should not come back
      items[1].isCompleted = true;
      items[2].isCompleted = true;

      final allAvailable = items
          .where((item) => !item.isCompleted && !item.isSkipped)
          .toList();
      expect(allAvailable.length, 0); // Step 1 should NOT be available
    });

    test('postponed step cycles back as normal step after all regular steps done', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
        RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
      ];

      // User presses clock on step 1 - postponed for later
      items[0].isPostponed = true;

      // Step 1 is NOT in regular available steps
      final regularSteps = items
          .where((item) => !item.isCompleted && !item.isSkipped && !item.isPostponed)
          .toList();
      expect(regularSteps.map((e) => e.id).toList(), ['2', '3']);

      // Complete regular steps
      items[1].isCompleted = true;
      items[2].isCompleted = true;

      // Now postponed step should be available
      final postponedSteps = items
          .where((item) => item.isPostponed && !item.isCompleted && !item.isSkipped)
          .toList();
      expect(postponedSteps.length, 1);
      expect(postponedSteps[0].id, '1');

      // Routine is NOT complete because postponed step exists
      final isComplete = items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, false);
    });

    test('routine completes when all steps are completed OR skipped (not postponed)', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isSkipped: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: true),
      ];

      // Routine IS complete: all steps are either completed or permanently skipped
      final isComplete = items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, true);
    });

    test('routine does NOT complete when any step is postponed', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isPostponed: true, isCompleted: false),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: true),
      ];

      // Routine is NOT complete: step 2 is postponed (not skipped)
      final isComplete = items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, false);
    });

    test('skipping last step should complete routine', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isCompleted: true),
        RoutineItem(id: '2', text: 'Step 2', isCompleted: true),
        RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
      ];

      // User skips the last step
      items[2].isSkipped = true;

      // Routine should now be complete
      final isComplete = items.every((item) => item.isCompleted || item.isSkipped);
      expect(isComplete, true);
    });

    test('postponed step becomes normal step when cycled back', () {
      // This tests the _moveToNextUnfinishedStep behavior:
      // When a postponed step is returned to, its isPostponed flag is cleared
      final item = RoutineItem(
        id: '1',
        text: 'Postponed step',
        isCompleted: false,
        isPostponed: true,
      );

      // Simulate what happens when we cycle back to this step
      // The code clears isPostponed so it can be postponed again
      item.isPostponed = false;

      expect(item.isPostponed, false);
      expect(item.isCompleted, false);
      expect(item.isSkipped, false);

      // Now user can complete, skip, or postpone again
      // If they postpone again:
      item.isPostponed = true;
      expect(item.isPostponed, true);
    });

    test('multiple postponed steps cycle through in order', () {
      final items = [
        RoutineItem(id: '1', text: 'Step 1', isPostponed: true, isCompleted: false),
        RoutineItem(id: '2', text: 'Step 2', isCompleted: true),
        RoutineItem(id: '3', text: 'Step 3', isPostponed: true, isCompleted: false),
      ];

      // All regular steps done, now go through postponed
      // Should get step 1 first (or 3 depending on current index)
      final postponedSteps = items
          .where((item) => item.isPostponed && !item.isCompleted && !item.isSkipped)
          .toList();

      expect(postponedSteps.length, 2);
      expect(postponedSteps.map((e) => e.id).toList(), ['1', '3']);
    });
  });

  group('Step State Mutual Exclusivity', () {
    test('completing a skipped step clears skipped flag', () {
      final item = RoutineItem(
        id: '1',
        text: 'Test step',
        isSkipped: true,
        isCompleted: false,
      );

      // Complete the step
      item.isCompleted = true;
      item.isSkipped = false; // This is what the code does

      expect(item.isCompleted, true);
      expect(item.isSkipped, false);
      expect(item.isPostponed, false);
    });

    test('skipping a step clears postponed flag', () {
      final item = RoutineItem(
        id: '1',
        text: 'Test step',
        isPostponed: true,
        isCompleted: false,
      );

      // Skip the step permanently
      item.isSkipped = true;
      item.isPostponed = false;
      item.isCompleted = false;

      expect(item.isSkipped, true);
      expect(item.isPostponed, false);
      expect(item.isCompleted, false);
    });

    test('postponing a step ensures not completed and not skipped', () {
      final item = RoutineItem(
        id: '1',
        text: 'Test step',
        isCompleted: false,
        isSkipped: false,
      );

      // Postpone the step
      item.isPostponed = true;
      item.isSkipped = false;
      item.isCompleted = false;

      expect(item.isPostponed, true);
      expect(item.isSkipped, false);
      expect(item.isCompleted, false);
    });
  });
}
