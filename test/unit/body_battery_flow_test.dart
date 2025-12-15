import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Energy/energy_settings_model.dart';
import 'package:bb_app/Energy/flow_calculator.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Routines/routine_data_models.dart';

void main() {
  group('EnergySettings - Body Battery & Flow', () {
    test('should create with new default values', () {
      const settings = EnergySettings();
      expect(settings.minBattery, 5);
      expect(settings.maxBattery, 120);
      expect(settings.minFlowGoal, 5);
      expect(settings.maxFlowGoal, 20);
      expect(settings.currentStreak, 0);
      expect(settings.personalRecord, 0);
    });

    test('should migrate from old field names', () {
      final json = {
        'lowEnergyPeak': 10,
        'highEnergyPeak': 25,
      };
      final settings = EnergySettings.fromJson(json);

      expect(settings.minBattery, 10);
      expect(settings.maxBattery, 25);
      expect(settings.minFlowGoal, 10);
      expect(settings.maxFlowGoal, 25);
    });

    test('should support all new fields in copyWith', () {
      const original = EnergySettings();
      final modified = original.copyWith(
        currentStreak: 7,
        personalRecord: 50,
      );

      expect(modified.currentStreak, 7);
      expect(modified.personalRecord, 50);
      expect(modified.minBattery, 5); // Unchanged
    });

    test('should serialize all new fields', () {
      const settings = EnergySettings(
        minBattery: 10,
        maxBattery: 100,
        minFlowGoal: 8,
        maxFlowGoal: 25,
        currentStreak: 5,
        personalRecord: 42,
      );
      final json = settings.toJson();

      expect(json['minBattery'], 10);
      expect(json['maxBattery'], 100);
      expect(json['minFlowGoal'], 8);
      expect(json['maxFlowGoal'], 25);
      expect(json['currentStreak'], 5);
      expect(json['personalRecord'], 42);
    });
  });

  group('DailyEnergyRecord - Battery & Flow Tracking', () {
    test('should track battery changes correctly', () {
      final record = DailyEnergyRecord(
        date: DateTime.now(),
        startingBattery: 100,
        currentBattery: 80,
        flowGoal: 15,
        menstrualPhase: 'follicular',
        cycleDayNumber: 8,
      );

      expect(record.batteryChange, -20);
      expect(record.startingBattery, 100);
      expect(record.currentBattery, 80);
    });

    test('should track flow points and goal achievement', () {
      final record = DailyEnergyRecord(
        date: DateTime.now(),
        currentBattery: 90,
        flowPoints: 20,
        flowGoal: 15,
        isGoalMet: true,
        menstrualPhase: 'follicular',
        cycleDayNumber: 8,
      );

      expect(record.flowPoints, 20);
      expect(record.flowGoal, 15);
      expect(record.isGoalMet, true);
      expect(record.flowPercentage, greaterThan(100));
    });

    test('should track personal records', () {
      final record = DailyEnergyRecord(
        date: DateTime.now(),
        currentBattery: 100,
        flowPoints: 35,
        flowGoal: 20,
        isGoalMet: true,
        isPR: true,
        menstrualPhase: 'ovulation',
        cycleDayNumber: 14,
      );

      expect(record.isPR, true);
    });

    test('should allow negative battery', () {
      final record = DailyEnergyRecord(
        date: DateTime.now(),
        startingBattery: 20,
        currentBattery: -10,
        flowGoal: 10,
        menstrualPhase: 'late luteal',
        cycleDayNumber: 28,
      );

      expect(record.currentBattery, -10);
      expect(record.batteryChange, -30);
    });

    test('should allow battery above 120%', () {
      final record = DailyEnergyRecord(
        date: DateTime.now(),
        startingBattery: 120,
        currentBattery: 150,
        flowGoal: 20,
        menstrualPhase: 'ovulation',
        cycleDayNumber: 14,
      );

      expect(record.currentBattery, 150);
      expect(record.batteryChange, 30);
    });

    test('should migrate from old format', () {
      final json = {
        'date': DateTime.now().toIso8601String(),
        'energyGoal': 15,
        'energyConsumed': 12,
        'menstrualPhase': 'follicular',
        'cycleDayNumber': 10,
        'entries': [],
      };

      final record = DailyEnergyRecord.fromJson(json);

      expect(record.flowGoal, 15);
      expect(record.startingBattery, 100); // Default
      expect(record.currentBattery, 100); // Default
    });

    test('should support copyWith for all fields', () {
      final original = DailyEnergyRecord(
        date: DateTime.now(),
        startingBattery: 100,
        currentBattery: 100,
        flowGoal: 15,
        menstrualPhase: 'follicular',
        cycleDayNumber: 8,
      );

      final modified = original.copyWith(
        currentBattery: 80,
        flowPoints: 12,
        isGoalMet: false,
      );

      expect(modified.currentBattery, 80);
      expect(modified.flowPoints, 12);
      expect(modified.isGoalMet, false);
      expect(modified.startingBattery, 100); // Unchanged
    });
  });

  group('FlowCalculator - Flow Points', () {
    test('should calculate flow points for draining tasks', () {
      expect(FlowCalculator.calculateFlowPoints(-5), 10);
      expect(FlowCalculator.calculateFlowPoints(-4), 8);
      expect(FlowCalculator.calculateFlowPoints(-3), 6);
      expect(FlowCalculator.calculateFlowPoints(-2), 4);
      expect(FlowCalculator.calculateFlowPoints(-1), 2);
    });

    test('should calculate flow points for neutral tasks', () {
      expect(FlowCalculator.calculateFlowPoints(0), 1);
    });

    test('should calculate flow points for charging tasks', () {
      expect(FlowCalculator.calculateFlowPoints(1), 2);
      expect(FlowCalculator.calculateFlowPoints(2), 3);
      expect(FlowCalculator.calculateFlowPoints(3), 4);
      expect(FlowCalculator.calculateFlowPoints(4), 5);
      expect(FlowCalculator.calculateFlowPoints(5), 6);
    });

    test('should clamp out-of-range energy levels', () {
      expect(FlowCalculator.calculateFlowPoints(-10), 10); // Clamped to -5
      expect(FlowCalculator.calculateFlowPoints(10), 6); // Clamped to +5
    });
  });

  group('FlowCalculator - Battery Changes', () {
    test('should calculate battery drain correctly', () {
      expect(FlowCalculator.calculateBatteryChange(-5), -50);
      expect(FlowCalculator.calculateBatteryChange(-3), -30);
      expect(FlowCalculator.calculateBatteryChange(-1), -10);
    });

    test('should calculate battery charge correctly', () {
      expect(FlowCalculator.calculateBatteryChange(5), 50);
      expect(FlowCalculator.calculateBatteryChange(3), 30);
      expect(FlowCalculator.calculateBatteryChange(1), 10);
    });

    test('should handle neutral energy', () {
      expect(FlowCalculator.calculateBatteryChange(0), 0);
    });
  });

  group('FlowCalculator - Multiple Entries', () {
    test('should calculate total flow points from entries', () {
      final entries = [
        EnergyConsumptionEntry(
          id: '1',
          title: 'Task 1',
          energyLevel: -3,
          completedAt: DateTime.now(),
          sourceType: EnergySourceType.task,
        ),
        EnergyConsumptionEntry(
          id: '2',
          title: 'Task 2',
          energyLevel: -2,
          completedAt: DateTime.now(),
          sourceType: EnergySourceType.task,
        ),
        EnergyConsumptionEntry(
          id: '3',
          title: 'Rest',
          energyLevel: 2,
          completedAt: DateTime.now(),
          sourceType: EnergySourceType.task,
        ),
      ];

      final totalFlow = FlowCalculator.calculateTotalFlowPoints(entries);
      // -3 = 6pts, -2 = 4pts, +2 = 3pts = 13 total
      expect(totalFlow, 13);
    });

    test('should calculate total battery change from entries', () {
      final entries = [
        EnergyConsumptionEntry(
          id: '1',
          title: 'Hard work',
          energyLevel: -5,
          completedAt: DateTime.now(),
          sourceType: EnergySourceType.task,
        ),
        EnergyConsumptionEntry(
          id: '2',
          title: 'Break',
          energyLevel: 3,
          completedAt: DateTime.now(),
          sourceType: EnergySourceType.task,
        ),
      ];

      final totalBattery = FlowCalculator.calculateTotalBatteryChange(entries);
      // -5 = -50%, +3 = +30% = -20% total
      expect(totalBattery, -20);
    });
  });

  group('FlowCalculator - Goal Achievement', () {
    test('should detect when goal is met', () {
      expect(FlowCalculator.isFlowGoalMet(15, 15), true);
      expect(FlowCalculator.isFlowGoalMet(20, 15), true);
      expect(FlowCalculator.isFlowGoalMet(14, 15), false);
    });

    test('should detect personal records', () {
      expect(FlowCalculator.isPersonalRecord(30, 25), true);
      expect(FlowCalculator.isPersonalRecord(25, 25), false);
      expect(FlowCalculator.isPersonalRecord(20, 25), false);
    });
  });

  group('FlowCalculator - Streaks', () {
    test('should start streak when goal met for first time', () {
      final streak = FlowCalculator.updateStreak(
        goalMetToday: true,
        goalMetYesterday: false,
        currentStreak: 0,
      );
      expect(streak, 1);
    });

    test('should continue streak when goal met consecutively', () {
      final streak = FlowCalculator.updateStreak(
        goalMetToday: true,
        goalMetYesterday: true,
        currentStreak: 5,
      );
      expect(streak, 6);
    });

    test('should not change streak when goal not met (breaking happens at day end)', () {
      final streak = FlowCalculator.updateStreak(
        goalMetToday: false,
        goalMetYesterday: true,
        currentStreak: 10,
      );
      // Streak is maintained - breaking happens at end of day check, not during updates
      expect(streak, 10);
    });

    test('should detect streak milestones', () {
      expect(FlowCalculator.getStreakMilestone(3), 3);
      expect(FlowCalculator.getStreakMilestone(7), 7);
      expect(FlowCalculator.getStreakMilestone(14), 14);
      expect(FlowCalculator.getStreakMilestone(30), 30);
      expect(FlowCalculator.getStreakMilestone(50), 50);
      expect(FlowCalculator.getStreakMilestone(100), 100);
      expect(FlowCalculator.getStreakMilestone(5), null); // Not a milestone
    });
  });

  group('FlowCalculator - Display Helpers', () {
    test('should generate correct flow descriptions', () {
      expect(
        FlowCalculator.getFlowDescription(-5),
        'Drains 50%, Earns 10 pts',
      );
      expect(
        FlowCalculator.getFlowDescription(0),
        'Neutral, Earns 1 pts',
      );
      expect(
        FlowCalculator.getFlowDescription(5),
        'Charges 50%, Earns 6 pts',
      );
    });

    test('should categorize battery levels', () {
      expect(FlowCalculator.getBatteryColor(100), 'green');
      expect(FlowCalculator.getBatteryColor(60), 'yellow');
      expect(FlowCalculator.getBatteryColor(35), 'orange');
      expect(FlowCalculator.getBatteryColor(15), 'red');
      expect(FlowCalculator.getBatteryColor(-10), 'critical');
    });

    test('should detect critical battery', () {
      expect(FlowCalculator.isBatteryCritical(25), false);
      expect(FlowCalculator.isBatteryCritical(20), false);
      expect(FlowCalculator.isBatteryCritical(19), true);
      expect(FlowCalculator.isBatteryCritical(0), true);
      expect(FlowCalculator.isBatteryCritical(-10), true);
    });

    test('should provide battery suggestions', () {
      final suggestion100 = FlowCalculator.getBatterySuggestion(100);
      expect(suggestion100, contains('High energy'));

      final suggestion10 = FlowCalculator.getBatterySuggestion(10);
      expect(suggestion10, contains('Low battery'));

      final suggestionNegative = FlowCalculator.getBatterySuggestion(-5);
      expect(suggestionNegative, contains('Critical'));
    });
  });

  group('FlowCalculator - Validation', () {
    test('should validate energy levels', () {
      expect(FlowCalculator.isValidEnergyLevel(-5), true);
      expect(FlowCalculator.isValidEnergyLevel(0), true);
      expect(FlowCalculator.isValidEnergyLevel(5), true);
      expect(FlowCalculator.isValidEnergyLevel(-6), false);
      expect(FlowCalculator.isValidEnergyLevel(6), false);
    });

    test('should validate all battery levels', () {
      expect(FlowCalculator.isValidBatteryLevel(-100), true);
      expect(FlowCalculator.isValidBatteryLevel(0), true);
      expect(FlowCalculator.isValidBatteryLevel(120), true);
      expect(FlowCalculator.isValidBatteryLevel(200), true);
    });
  });

  group('Task - Energy Level', () {
    test('should default to -1 for new tasks', () {
      final task = Task(
        id: 'test1',
        title: 'New Task',
      );
      expect(task.energyLevel, -1);
    });

    test('should accept full energy range (-5 to +5)', () {
      final taskDrain = Task(
        id: 'test2',
        title: 'Draining Task',
        energyLevel: -5,
      );
      expect(taskDrain.energyLevel, -5);

      final taskCharge = Task(
        id: 'test3',
        title: 'Charging Task',
        energyLevel: 3,
      );
      expect(taskCharge.energyLevel, 3);
    });
  });

  group('RoutineItem - Energy Level', () {
    test('should default to null', () {
      final item = RoutineItem(
        id: 'item1',
        text: 'Test Item',
        isCompleted: false,
      );
      expect(item.energyLevel, null);
    });

    test('should accept full energy range (-5 to +5)', () {
      final itemDrain = RoutineItem(
        id: 'item2',
        text: 'Hard Step',
        isCompleted: false,
        energyLevel: -4,
      );
      expect(itemDrain.energyLevel, -4);

      final itemCharge = RoutineItem(
        id: 'item3',
        text: 'Rest Step',
        isCompleted: false,
        energyLevel: 2,
      );
      expect(itemCharge.energyLevel, 2);
    });
  });

  group('Routine Step Energy - Default Behavior', () {
    test('should use default energy level 0 (neutral) when energyLevel is null', () {
      final item = RoutineItem(
        id: 'step1',
        text: 'Brush teeth',
        isCompleted: false,
        energyLevel: null,
      );

      // When energyLevel is null, should default to 0 (neutral)
      final effectiveEnergy = item.energyLevel ?? 0;
      expect(effectiveEnergy, 0);

      // Default 0 gives 1 flow point
      expect(FlowCalculator.calculateFlowPoints(effectiveEnergy), 1);

      // Default 0 has no battery impact
      expect(FlowCalculator.calculateBatteryChange(effectiveEnergy), 0);
    });

    test('should use explicit energy level when set', () {
      final item = RoutineItem(
        id: 'step2',
        text: 'Workout',
        isCompleted: false,
        energyLevel: -3,
      );

      final effectiveEnergy = item.energyLevel ?? 0;
      expect(effectiveEnergy, -3);

      // -3 gives 6 flow points
      expect(FlowCalculator.calculateFlowPoints(effectiveEnergy), 6);

      // -3 drains 30% battery
      expect(FlowCalculator.calculateBatteryChange(effectiveEnergy), -30);
    });

    test('should track energy for all routine steps including those with null energy', () {
      // Simulate routine steps with mixed energy values
      final steps = [
        RoutineItem(id: '1', text: 'Meditate', isCompleted: false, energyLevel: 2),
        RoutineItem(id: '2', text: 'Brush teeth', isCompleted: false, energyLevel: null),
        RoutineItem(id: '3', text: 'Exercise', isCompleted: false, energyLevel: -4),
        RoutineItem(id: '4', text: 'Shower', isCompleted: false, energyLevel: null),
      ];

      int totalFlowPoints = 0;
      int totalBatteryChange = 0;

      for (final step in steps) {
        final energy = step.energyLevel ?? 0;
        totalFlowPoints += FlowCalculator.calculateFlowPoints(energy);
        totalBatteryChange += FlowCalculator.calculateBatteryChange(energy);
      }

      // Step 1 (energy +2): 3 pts, +20% battery
      // Step 2 (energy null -> 0): 1 pt, 0% battery
      // Step 3 (energy -4): 8 pts, -40% battery
      // Step 4 (energy null -> 0): 1 pt, 0% battery
      // Total: 13 pts, -20% battery
      expect(totalFlowPoints, 13);
      expect(totalBatteryChange, -20);
    });

    test('should correctly display energy indicator for negative energy levels', () {
      final negativeEnergyItem = RoutineItem(
        id: 'neg',
        text: 'Hard task',
        isCompleted: false,
        energyLevel: -3,
      );

      // The UI check was: item.energyLevel != null && item.energyLevel! > 0
      // This incorrectly hid negative energy indicators
      // Fixed check: item.energyLevel != null
      final hasEnergyOld = negativeEnergyItem.energyLevel != null && negativeEnergyItem.energyLevel! > 0;
      final hasEnergyNew = negativeEnergyItem.energyLevel != null;

      expect(hasEnergyOld, false); // Old behavior - wrong!
      expect(hasEnergyNew, true);  // New behavior - correct!
    });

    test('should show energy indicator for zero energy level', () {
      final neutralItem = RoutineItem(
        id: 'neutral',
        text: 'Quick task',
        isCompleted: false,
        energyLevel: 0,
      );

      final hasEnergyOld = neutralItem.energyLevel != null && neutralItem.energyLevel! > 0;
      final hasEnergyNew = neutralItem.energyLevel != null;

      expect(hasEnergyOld, false); // Old behavior - wrong!
      expect(hasEnergyNew, true);  // New behavior - correct!
    });
  });
}
