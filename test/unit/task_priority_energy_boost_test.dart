import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Tasks/services/task_priority_service.dart';

void main() {
  group('Task Priority - Energy Boost for Today\'s Tasks', () {
    final priorityService = TaskPriorityService();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final categories = <TaskCategory>[];

    test('Energy boost applied to non-recurring task scheduled today: -5 energy', () {
      final drainingTask = Task(
        id: 'test1',
        title: 'Very draining task',
        scheduledDate: today,
        energyLevel: -5, // Most draining
      );

      final score = priorityService.calculateTaskPriorityScore(
        drainingTask,
        now,
        today,
        categories,
      );

      // Base for scheduled today: 600
      // Energy boost: 200 - ((-5 + 5) × 18) = 200 - 0 = 200
      // Expected: 600 + 200 = 800
      expect(score, greaterThanOrEqualTo(800));
    });

    test('Energy boost applied to non-recurring task scheduled today: -1 energy', () {
      final slightlyDrainingTask = Task(
        id: 'test2',
        title: 'Slightly draining task',
        scheduledDate: today,
        energyLevel: -1, // Default draining
      );

      final score = priorityService.calculateTaskPriorityScore(
        slightlyDrainingTask,
        now,
        today,
        categories,
      );

      // Base for scheduled today: 600
      // Energy boost: 200 - ((-1 + 5) × 18) = 200 - 72 = 128
      // Expected: 600 + 128 = 728
      expect(score, greaterThanOrEqualTo(728));
      expect(score, lessThan(800)); // Less than -5 energy
    });

    test('Energy boost applied to non-recurring task scheduled today: 0 energy', () {
      final neutralTask = Task(
        id: 'test3',
        title: 'Neutral task',
        scheduledDate: today,
        energyLevel: 0, // Neutral
      );

      final score = priorityService.calculateTaskPriorityScore(
        neutralTask,
        now,
        today,
        categories,
      );

      // Base for scheduled today: 600
      // Energy boost: 200 - ((0 + 5) × 18) = 200 - 90 = 110
      // Expected: 600 + 110 = 710
      expect(score, greaterThanOrEqualTo(710));
      expect(score, lessThan(728)); // Less than -1 energy
    });

    test('Energy boost applied to non-recurring task scheduled today: +5 energy', () {
      final chargingTask = Task(
        id: 'test4',
        title: 'Charging task',
        scheduledDate: today,
        energyLevel: 5, // Most charging
      );

      final score = priorityService.calculateTaskPriorityScore(
        chargingTask,
        now,
        today,
        categories,
      );

      // Base for scheduled today: 600
      // Energy boost: 200 - ((5 + 5) × 18) = 200 - 180 = 20
      // Expected: 600 + 20 = 620
      expect(score, greaterThanOrEqualTo(620));
      expect(score, lessThan(710)); // Less than neutral
    });

    test('Energy boost NOT applied to unscheduled tasks', () {
      final unscheduledDrainingTask = Task(
        id: 'test5',
        title: 'Unscheduled draining task',
        energyLevel: -5, // Most draining
        // No scheduledDate
      );

      final score = priorityService.calculateTaskPriorityScore(
        unscheduledDrainingTask,
        now,
        today,
        categories,
      );

      // Base for unscheduled: 400
      // No energy boost (only for today's tasks)
      // Expected: 400 (no energy boost added)
      expect(score, 400);
    });

    test('Energy boost NOT applied to future scheduled tasks', () {
      final tomorrow = today.add(const Duration(days: 1));
      final futureDrainingTask = Task(
        id: 'test6',
        title: 'Future draining task',
        scheduledDate: tomorrow,
        energyLevel: -5, // Most draining
      );

      final score = priorityService.calculateTaskPriorityScore(
        futureDrainingTask,
        now,
        today,
        categories,
      );

      // Base for tomorrow: 120
      // No energy boost (only for today's tasks)
      // Expected: 120
      expect(score, 120);
    });

    test('Draining tasks scheduled today rank higher than charging tasks', () {
      final drainingTask = Task(
        id: 'draining',
        title: 'Draining task',
        scheduledDate: today,
        energyLevel: -5,
      );

      final chargingTask = Task(
        id: 'charging',
        title: 'Charging task',
        scheduledDate: today,
        energyLevel: 5,
      );

      final drainingScore = priorityService.calculateTaskPriorityScore(
        drainingTask,
        now,
        today,
        categories,
      );

      final chargingScore = priorityService.calculateTaskPriorityScore(
        chargingTask,
        now,
        today,
        categories,
      );

      // Draining task should have higher priority
      expect(drainingScore, greaterThan(chargingScore));
      // Difference should be 180 points (200 - 20)
      expect(drainingScore - chargingScore, 180);
    });

    test('Energy levels create gradual priority differences', () {
      final scores = <int, int>{};

      for (int energy = -5; energy <= 5; energy++) {
        final task = Task(
          id: 'energy_$energy',
          title: 'Task with energy $energy',
          scheduledDate: today,
          energyLevel: energy,
        );

        scores[energy] = priorityService.calculateTaskPriorityScore(
          task,
          now,
          today,
          categories,
        );
      }

      // Verify scores decrease as energy increases
      for (int energy = -5; energy < 5; energy++) {
        expect(scores[energy]!, greaterThan(scores[energy + 1]!),
            reason: 'Energy $energy should have higher priority than ${energy + 1}');
      }

      // Verify consistent 18-point differences
      for (int energy = -5; energy < 5; energy++) {
        final diff = scores[energy]! - scores[energy + 1]!;
        expect(diff, 18,
            reason: 'Adjacent energy levels should differ by 18 points');
      }
    });

    test('Energy boost formula verification', () {
      // Direct formula test
      int calculateBoost(int energyLevel) {
        return 200 - ((energyLevel + 5) * 18);
      }

      expect(calculateBoost(-5), 200); // Most draining
      expect(calculateBoost(-4), 182);
      expect(calculateBoost(-3), 164);
      expect(calculateBoost(-2), 146);
      expect(calculateBoost(-1), 128);
      expect(calculateBoost(0), 110);
      expect(calculateBoost(1), 92);
      expect(calculateBoost(2), 74);
      expect(calculateBoost(3), 56);
      expect(calculateBoost(4), 38);
      expect(calculateBoost(5), 20); // Most charging
    });

    test('Recurring tasks scheduled today also get energy boost', () {
      final recurringDrainingTask = Task(
        id: 'recurring',
        title: 'Recurring draining task',
        scheduledDate: today,
        energyLevel: -5,
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
      );

      final score = priorityService.calculateTaskPriorityScore(
        recurringDrainingTask,
        now,
        today,
        categories,
      );

      // Recurring tasks scheduled today get base 700 + energy boost 200
      // Expected: 900
      expect(score, greaterThanOrEqualTo(900));
    });

    test('Energy boost respects existing priority hierarchy', () {
      // Deadline today should still outrank draining task scheduled today
      final deadlineTask = Task(
        id: 'deadline',
        title: 'Task with deadline today',
        deadline: today,
        energyLevel: 5, // Charging (low priority)
      );

      final drainingScheduledTask = Task(
        id: 'scheduled',
        title: 'Draining task scheduled today',
        scheduledDate: today,
        energyLevel: -5, // Most draining
      );

      final deadlineScore = priorityService.calculateTaskPriorityScore(
        deadlineTask,
        now,
        today,
        categories,
      );

      final scheduledScore = priorityService.calculateTaskPriorityScore(
        drainingScheduledTask,
        now,
        today,
        categories,
      );

      // Deadline today (800) should still outrank scheduled today with energy boost (600 + 200 = 800)
      // They should be roughly equal, but deadline takes precedence
      expect(deadlineScore, greaterThanOrEqualTo(scheduledScore));
    });
  });
}
