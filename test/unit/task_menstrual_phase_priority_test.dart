import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Tasks/services/task_priority_service.dart';
import 'package:bb_app/MenstrualCycle/menstrual_cycle_constants.dart';
import 'package:flutter/material.dart';

void main() {
  late TaskPriorityService service;
  late List<TaskCategory> categories;
  late DateTime now;
  late DateTime today;

  setUp(() {
    service = TaskPriorityService();
    categories = [
      TaskCategory(id: '1', name: 'Health', color: Colors.red, order: 0),
    ];
    now = DateTime(2025, 11, 20, 11, 50); // Nov 20, 11:50 AM
    today = DateTime(now.year, now.month, now.day);
  });

  int score(Task task, {String? phase}) => service.calculateTaskPriorityScore(
    task,
    now,
    today,
    categories,
    currentMenstrualPhase: phase,
  );

  group('Menstrual Phase Priority - Phase Matching', () {
    test('menstrual phase task with matching phase and no reminder gets high priority', () {
      final task = Task(
        id: '1',
        title: 'Menstrual Phase Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      // Phase matches, no reminder
      final matchingScore = score(task, phase: MenstrualCycleConstants.menstrualPhase);

      // Phase doesn't match, no reminder
      final notMatchingScore = score(task, phase: MenstrualCycleConstants.follicularPhase);

      // When phase matches, daysUntilTarget will be calculated
      // Since we can't mock the calculation, we expect it to be 700 (daysUntilTarget <= 1)
      // or 400/100/200 depending on days
      expect(matchingScore, greaterThanOrEqualTo(200));

      // When phase doesn't match, should get 125 (low priority)
      expect(notMatchingScore, equals(125));

      // Phase matching should have higher priority
      expect(matchingScore, greaterThan(notMatchingScore));
    });

    test('menstrual phase task with matching phase but distant reminder gets low priority', () {
      final task = Task(
        id: '1',
        title: 'Menstrual Phase Task with Distant Reminder',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
          reminderTime: TimeOfDay(hour: 16, minute: 30),
        ),
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 20, 16, 30), // 4h 40min away
        createdAt: now,
      );

      // Even though phase matches, distant reminder means low priority
      final matchingWithDistantReminder = score(task, phase: MenstrualCycleConstants.menstrualPhase);

      // Should get 125 (deprioritized due to distant reminder)
      expect(matchingWithDistantReminder, equals(125));
    });

    test('menstrual phase task with matching phase and close reminder gets very high priority', () {
      final task = Task(
        id: '1',
        title: 'Menstrual Phase Task with Close Reminder',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
          reminderTime: TimeOfDay(hour: 12, minute: 0),
        ),
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 20, 12, 0), // 10 min away
        createdAt: now,
      );

      // Phase matches and reminder is close (<30 min)
      final matchingWithCloseReminder = score(task, phase: MenstrualCycleConstants.menstrualPhase);

      // Should get:
      // - 1100 (reminder < 30 min from section 1)
      // - +700 or +400 or +100 or +200 (menstrual task with matching phase from section 5)
      // Total should be >= 1300
      expect(matchingWithCloseReminder, greaterThanOrEqualTo(1300));
    });

    test('menstrual phase task without matching phase and distant reminder gets low priority', () {
      final task = Task(
        id: '1',
        title: 'Menstrual Phase Task - No Match',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
          reminderTime: TimeOfDay(hour: 16, minute: 30),
        ),
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 20, 16, 30), // 4h 40min away
        createdAt: now,
      );

      // Phase doesn't match
      final notMatchingWithDistantReminder = score(task, phase: MenstrualCycleConstants.follicularPhase);

      // Should get 125 (low priority)
      expect(notMatchingWithDistantReminder, equals(125));
    });
  });

  group('Menstrual Phase Priority - Different Phases', () {
    test('follicular phase task only gets high priority when in follicular phase', () {
      final task = Task(
        id: '1',
        title: 'Follicular Phase Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.follicularPhase, RecurrenceType.daily],
          type: RecurrenceType.follicularPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      final follicularScore = score(task, phase: MenstrualCycleConstants.follicularPhase);
      final menstrualScore = score(task, phase: MenstrualCycleConstants.menstrualPhase);
      final ovulationScore = score(task, phase: MenstrualCycleConstants.ovulationPhase);

      // Follicular phase matches: should get >= 200
      expect(follicularScore, greaterThanOrEqualTo(200));

      // Other phases don't match: should get 125
      expect(menstrualScore, equals(125));
      expect(ovulationScore, equals(125));

      // Matching phase should be higher than non-matching
      expect(follicularScore, greaterThan(menstrualScore));
      expect(follicularScore, greaterThan(ovulationScore));
    });

    test('ovulation phase task only gets high priority when in ovulation phase', () {
      final task = Task(
        id: '1',
        title: 'Ovulation Phase Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.ovulationPhase, RecurrenceType.daily],
          type: RecurrenceType.ovulationPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      final ovulationScore = score(task, phase: MenstrualCycleConstants.ovulationPhase);
      final follicularScore = score(task, phase: MenstrualCycleConstants.follicularPhase);

      expect(ovulationScore, greaterThanOrEqualTo(200));
      expect(follicularScore, equals(125));
      expect(ovulationScore, greaterThan(follicularScore));
    });

    test('early luteal phase task only gets high priority when in early luteal phase', () {
      final task = Task(
        id: '1',
        title: 'Early Luteal Phase Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.earlyLutealPhase, RecurrenceType.daily],
          type: RecurrenceType.earlyLutealPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      final earlyLutealScore = score(task, phase: MenstrualCycleConstants.earlyLutealPhase);
      final lateLutealScore = score(task, phase: MenstrualCycleConstants.lateLutealPhase);

      expect(earlyLutealScore, greaterThanOrEqualTo(200));
      expect(lateLutealScore, equals(125));
      expect(earlyLutealScore, greaterThan(lateLutealScore));
    });

    test('late luteal phase task only gets high priority when in late luteal phase', () {
      final task = Task(
        id: '1',
        title: 'Late Luteal Phase Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.lateLutealPhase, RecurrenceType.daily],
          type: RecurrenceType.lateLutealPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      final lateLutealScore = score(task, phase: MenstrualCycleConstants.lateLutealPhase);
      final menstrualScore = score(task, phase: MenstrualCycleConstants.menstrualPhase);

      expect(lateLutealScore, greaterThanOrEqualTo(200));
      expect(menstrualScore, equals(125));
      expect(lateLutealScore, greaterThan(menstrualScore));
    });
  });

  group('Menstrual Phase Priority - No Phase Data', () {
    test('menstrual task with no phase data gets low priority', () {
      final task = Task(
        id: '1',
        title: 'Menstrual Task No Phase Data',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      // No phase data (null)
      final noPhaseScore = score(task, phase: null);

      // Should get 125 (low priority when no phase data)
      expect(noPhaseScore, equals(125));
    });

    test('menstrual task with unknown phase string gets low priority', () {
      final task = Task(
        id: '1',
        title: 'Menstrual Task Unknown Phase',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      // Unknown phase
      final unknownPhaseScore = score(task, phase: 'Unknown Phase');

      // Should get 125 (low priority when phase doesn't match)
      expect(unknownPhaseScore, equals(125));
    });
  });

  group('Menstrual Phase Priority - Comparison with Non-Menstrual Tasks', () {
    test('menstrual task with matching phase beats non-menstrual task with distant reminder', () {
      final menstrualTask = Task(
        id: '1',
        title: 'Menstrual Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      final regularTask = Task(
        id: '2',
        title: 'Regular Daily Task',
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
        ),
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 20, 16, 30), // distant
        createdAt: now,
      );

      final menstrualScore = score(menstrualTask, phase: MenstrualCycleConstants.menstrualPhase);
      final regularScore = score(regularTask, phase: MenstrualCycleConstants.menstrualPhase);

      // Menstrual with matching phase (200) should beat regular with distant reminder (125)
      expect(menstrualScore, greaterThan(regularScore));
    });

    test('menstrual task without matching phase equals non-menstrual task with distant reminder', () {
      final menstrualTask = Task(
        id: '1',
        title: 'Menstrual Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      final regularTask = Task(
        id: '2',
        title: 'Regular Daily Task',
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
        ),
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 20, 16, 30), // distant
        createdAt: now,
      );

      final menstrualScore = score(menstrualTask, phase: MenstrualCycleConstants.follicularPhase);
      final regularScore = score(regularTask, phase: MenstrualCycleConstants.follicularPhase);

      // Both should get 125 (deprioritized)
      expect(menstrualScore, equals(125));
      expect(regularScore, equals(125));
      expect(menstrualScore, equals(regularScore));
    });

    test('menstrual task with distant reminder and matching phase gets same priority as non-matching', () {
      final menstrualTaskMatching = Task(
        id: '1',
        title: 'Menstrual Task Matching',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
          reminderTime: TimeOfDay(hour: 16, minute: 30),
        ),
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 20, 16, 30), // distant
        createdAt: now,
      );

      final menstrualTaskNotMatching = Task(
        id: '2',
        title: 'Menstrual Task Not Matching',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
          reminderTime: TimeOfDay(hour: 16, minute: 30),
        ),
        scheduledDate: today,
        reminderTime: DateTime(2025, 11, 20, 16, 30), // distant
        createdAt: now,
      );

      final matchingScore = score(menstrualTaskMatching, phase: MenstrualCycleConstants.menstrualPhase);
      final notMatchingScore = score(menstrualTaskNotMatching, phase: MenstrualCycleConstants.follicularPhase);

      // Both should get 125 due to distant reminder
      expect(matchingScore, equals(125));
      expect(notMatchingScore, equals(125));
    });
  });

  group('Menstrual Phase Priority - Edge Cases', () {
    test('non-recurring task is not affected by menstrual phase', () {
      final task = Task(
        id: '1',
        title: 'Non-Recurring Task',
        scheduledDate: today,
        createdAt: now,
      );

      final withPhase = score(task, phase: MenstrualCycleConstants.menstrualPhase);
      final withoutPhase = score(task, phase: null);

      // Should get same score regardless of phase (600 for scheduled today, no reminder, no categories)
      expect(withPhase, equals(withoutPhase));
      expect(withPhase, equals(600));
    });

    test('regular daily task without menstrual phase is not affected by cycle phase', () {
      final task = Task(
        id: '1',
        title: 'Regular Daily Task',
        recurrence: TaskRecurrence(
          type: RecurrenceType.daily,
        ),
        scheduledDate: today,
        createdAt: now,
      );

      final withPhase = score(task, phase: MenstrualCycleConstants.menstrualPhase);
      final withoutPhase = score(task, phase: null);

      // Should get same score regardless of phase
      expect(withPhase, equals(withoutPhase));
      expect(withPhase, equals(700));
    });

    test('menstrual task scheduled in future is not affected by current phase', () {
      final futureDate = today.add(Duration(days: 3));
      final task = Task(
        id: '1',
        title: 'Future Menstrual Task',
        recurrence: TaskRecurrence(
          types: [RecurrenceType.menstrualPhase, RecurrenceType.daily],
          type: RecurrenceType.menstrualPhase,
        ),
        scheduledDate: futureDate,
        createdAt: now,
      );

      final matchingScore = score(task, phase: MenstrualCycleConstants.menstrualPhase);
      final notMatchingScore = score(task, phase: MenstrualCycleConstants.follicularPhase);

      // Future scheduled tasks should have same score regardless of current phase
      // (they follow different logic in section 4b of priority calculation)
      expect(matchingScore, equals(notMatchingScore));
      expect(matchingScore, equals(110)); // Day 3 future = 110
    });
  });
}
