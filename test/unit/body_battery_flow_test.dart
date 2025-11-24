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
      expect(FlowCalculator.calculateFlowPoints(-5), 15);
      expect(FlowCalculator.calculateFlowPoints(-4), 14);
      expect(FlowCalculator.calculateFlowPoints(-3), 13);
      expect(FlowCalculator.calculateFlowPoints(-2), 12);
      expect(FlowCalculator.calculateFlowPoints(-1), 11);
    });

    test('should calculate flow points for neutral tasks', () {
      expect(FlowCalculator.calculateFlowPoints(0), 10);
    });

    test('should calculate flow points for charging tasks', () {
      expect(FlowCalculator.calculateFlowPoints(1), 9);
      expect(FlowCalculator.calculateFlowPoints(2), 8);
      expect(FlowCalculator.calculateFlowPoints(3), 7);
      expect(FlowCalculator.calculateFlowPoints(4), 6);
      expect(FlowCalculator.calculateFlowPoints(5), 5);
    });

    test('should clamp out-of-range energy levels', () {
      expect(FlowCalculator.calculateFlowPoints(-10), 15); // Clamped to -5
      expect(FlowCalculator.calculateFlowPoints(10), 5); // Clamped to +5
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
      // -3 = 13pts, -2 = 12pts, +2 = 8pts = 33 total
      expect(totalFlow, 33);
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

    test('should break streak when goal not met', () {
      final streak = FlowCalculator.updateStreak(
        goalMetToday: false,
        goalMetYesterday: true,
        currentStreak: 10,
      );
      expect(streak, 0);
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
        'Drains 50%, Earns 15 pts',
      );
      expect(
        FlowCalculator.getFlowDescription(0),
        'Neutral, Earns 10 pts',
      );
      expect(
        FlowCalculator.getFlowDescription(5),
        'Charges 50%, Earns 5 pts',
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

  group('Task - Energy Level Migration', () {
    test('should default to -1 for new tasks', () {
      final task = Task(
        id: 'test1',
        title: 'New Task',
      );
      expect(task.energyLevel, -1);
    });

    test('should accept new energy range', () {
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

    test('should migrate old energy values (1-5) to new system', () {
      final json1 = {
        'id': 'old1',
        'title': 'Old Task 1',
        'categoryIds': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
        'energyLevel': 1,
      };
      expect(Task.fromJson(json1).energyLevel, -1);

      final json2 = {
        'id': 'old2',
        'title': 'Old Task 2',
        'categoryIds': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
        'energyLevel': 3,
      };
      expect(Task.fromJson(json2).energyLevel, -3);

      final json5 = {
        'id': 'old5',
        'title': 'Old Task 5',
        'categoryIds': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
        'energyLevel': 5,
      };
      expect(Task.fromJson(json5).energyLevel, -5);
    });

    test('should not migrate already-migrated values', () {
      final jsonNew = {
        'id': 'new1',
        'title': 'New Task',
        'categoryIds': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
        'energyLevel': -3,
      };
      expect(Task.fromJson(jsonNew).energyLevel, -3);
    });
  });

  group('RoutineItem - Energy Level Migration', () {
    test('should still default to null', () {
      final item = RoutineItem(
        id: 'item1',
        text: 'Test Item',
        isCompleted: false,
      );
      expect(item.energyLevel, null);
    });

    test('should accept new energy range', () {
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

    test('should migrate old energy values', () {
      final json1 = {
        'id': 'old1',
        'text': 'Old Item 1',
        'isCompleted': false,
        'energyLevel': 2,
      };
      expect(RoutineItem.fromJson(json1).energyLevel, -2);

      final json4 = {
        'id': 'old4',
        'text': 'Old Item 4',
        'isCompleted': true,
        'energyLevel': 4,
      };
      expect(RoutineItem.fromJson(json4).energyLevel, -4);
    });

    test('should not migrate already-migrated values', () {
      final jsonNew = {
        'id': 'new1',
        'text': 'New Item',
        'isCompleted': false,
        'energyLevel': -3,
      };
      expect(RoutineItem.fromJson(jsonNew).energyLevel, -3);
    });
  });
}
