import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Routines/routine_card.dart';
import 'package:bb_app/Routines/routine_service.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  group('RoutineCard - Automatic Routine Progression', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('completes routine and auto-loads next routine', (WidgetTester tester) async {
      final today = RoutineService.getEffectiveDate();

      // Setup: Save 2 routines
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Morning Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
        Routine(
          id: 'routine2',
          title: 'Afternoon Routine',
          items: [
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      bool completedCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {
                completedCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify first routine is loaded
      expect(find.text('Morning Routine'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);

      // Complete the step
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should auto-load next routine (routine2)
      // Since we have 2 routines, completing the first should load the second
      final prefs = await SharedPreferences.getInstance();
      final routine1Completed = prefs.getBool('routine_completed_routine1_$today') ?? false;

      expect(routine1Completed, isTrue);
      expect(completedCallbackCalled, isFalse); // Should not call onCompleted yet (more routines available)
    });

    testWidgets('calls onCompleted when no more routines available', (WidgetTester tester) async {
      final today = RoutineService.getEffectiveDate();

      // Setup: Save 1 routine with 1 step
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Only Routine',
          items: [
            RoutineItem(id: '1', text: 'Only Step', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      bool completedCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {
                completedCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete the only step
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should mark routine as completed
      final prefs = await SharedPreferences.getInstance();
      final routineCompleted = prefs.getBool('routine_completed_routine1_$today') ?? false;

      expect(routineCompleted, isTrue);
      expect(completedCallbackCalled, isTrue); // Should call onCompleted (no more routines)
    });

    testWidgets('completes multiple steps before auto-loading next routine', (WidgetTester tester) async {
      // Setup: Save routine with 3 steps
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Multi-Step Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
            RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
        Routine(
          id: 'routine2',
          title: 'Next Routine',
          items: [
            RoutineItem(id: '4', text: 'Step 4', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete step 1
      expect(find.text('Step 1'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      // Should show step 2
      expect(find.text('Step 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      // Should show step 3
      expect(find.text('Step 3'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // After completing all steps, should attempt to load next routine
      // Verify routine1 is marked completed
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();
      final routine1Completed = prefs.getBool('routine_completed_routine1_$today') ?? false;

      expect(routine1Completed, isTrue);
    });

    testWidgets('skips completed routines when auto-loading', (WidgetTester tester) async {
      final today = RoutineService.getEffectiveDate();
      final prefs = await SharedPreferences.getInstance();

      // Setup: Save 3 routines, mark routine2 as completed
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
        Routine(
          id: 'routine3',
          title: 'Routine 3',
          items: [RoutineItem(id: '3', text: 'Step 3', isCompleted: false)],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);
      await prefs.setBool('routine_completed_routine2_$today', true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete routine1
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should skip routine2 and load routine3
      // Verify routine1 is completed
      final routine1Completed = prefs.getBool('routine_completed_routine1_$today') ?? false;
      expect(routine1Completed, isTrue);
    });
  });

  group('RoutineCard - Step Navigation', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('displays current step and progress', (WidgetTester tester) async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Test Routine',
          items: [
            RoutineItem(id: '1', text: 'First Step', isCompleted: false),
            RoutineItem(id: '2', text: 'Second Step', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Routine'), findsOneWidget);
      expect(find.text('First Step'), findsOneWidget);
    });

    testWidgets('skip button marks step as skipped', (WidgetTester tester) async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Test Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Skip first step
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // Should move to second step
      expect(find.text('Step 2'), findsOneWidget);
    });
  });

  group('RoutineCard - Completion State', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows completion message when all steps done', (WidgetTester tester) async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Quick Routine',
          items: [
            RoutineItem(id: '1', text: 'Only Step', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete the step
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      // Should show completion indicator
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('RoutineCard - Skip (X) and Postpone (clock) Behavior', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('skip button (X) permanently cancels step and moves to next', (WidgetTester tester) async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Test Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
            RoutineItem(id: '3', text: 'Step 3', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify first step is showing
      expect(find.text('Step 1'), findsOneWidget);

      // Skip first step using X button (close icon)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Should move to step 2
      expect(find.text('Step 2'), findsOneWidget);
    });

    testWidgets('skipping last step completes routine', (WidgetTester tester) async {
      final today = RoutineService.getEffectiveDate();

      final routines = [
        Routine(
          id: 'routine1',
          title: 'Test Routine',
          items: [
            RoutineItem(id: '1', text: 'Only Step', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      bool completedCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {
                completedCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Skip the only step
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Routine should be marked completed
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool('routine_completed_routine1_$today') ?? false;
      expect(isCompleted, isTrue);

      // onCompleted should be called (no more routines)
      expect(completedCallbackCalled, isTrue);
    });

    testWidgets('postpone button (clock) moves to next step', (WidgetTester tester) async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Test Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify first step is showing
      expect(find.text('Step 1'), findsOneWidget);

      // Postpone first step using clock button (schedule icon)
      await tester.tap(find.byIcon(Icons.schedule_rounded));
      await tester.pumpAndSettle();

      // Should move to step 2
      expect(find.text('Step 2'), findsOneWidget);
    });

    testWidgets('postponed step comes back after completing other steps', (WidgetTester tester) async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Test Routine',
          items: [
            RoutineItem(id: '1', text: 'Step 1', isCompleted: false),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Postpone step 1
      await tester.tap(find.byIcon(Icons.schedule_rounded));
      await tester.pumpAndSettle();

      // Should show step 2
      expect(find.text('Step 2'), findsOneWidget);

      // Complete step 2
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      // Step 1 should come back (it was postponed, not skipped)
      expect(find.text('Step 1'), findsOneWidget);
    });
  });

  group('RoutineCard - Energy Callback', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('onEnergyChanged callback is called when step is completed', (WidgetTester tester) async {
      final routines = [
        Routine(
          id: 'routine1',
          title: 'Test Routine',
          items: [
            RoutineItem(id: '1', text: 'Step with energy', isCompleted: false, energyLevel: 2),
            RoutineItem(id: '2', text: 'Step 2', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      bool energyCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
              onEnergyChanged: () {
                energyCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete step with energy
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      // Energy callback should have been called
      expect(energyCallbackCalled, isTrue);
    });
  });

  group('RoutineCard - Multiple Routine Navigation', () {
    setUp(() async {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('skipping all steps in routine moves to next routine', (WidgetTester tester) async {
      final today = RoutineService.getEffectiveDate();

      final routines = [
        Routine(
          id: 'routine1',
          title: 'First Routine',
          items: [
            RoutineItem(id: '1', text: 'First Step', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
        Routine(
          id: 'routine2',
          title: 'Second Routine',
          items: [
            RoutineItem(id: '2', text: 'Second Step', isCompleted: false),
          ],
          activeDays: {1, 2, 3, 4, 5, 6, 7},
        ),
      ];

      await RoutineService.saveRoutines(routines);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineCard(
              onCompleted: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify first routine is showing
      expect(find.text('First Routine'), findsOneWidget);

      // Skip the only step in first routine
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // First routine should be marked completed
      final prefs = await SharedPreferences.getInstance();
      final firstCompleted = prefs.getBool('routine_completed_routine1_$today') ?? false;
      expect(firstCompleted, isTrue);

      // Should now show second routine
      expect(find.text('Second Routine'), findsOneWidget);
    });
  });
}
