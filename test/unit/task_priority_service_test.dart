import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/services/task_priority_service.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

void main() {
  group('TaskPriorityService - Priority Hierarchy', () {
    late TaskPriorityService service;
    late List<TaskCategory> categories;
    late DateTime now;
    late DateTime today;

    setUp(() {
      service = TaskPriorityService();
      categories = [
        TaskCategory(id: '1', name: 'Work', color: Colors.blue, order: 0),
        TaskCategory(id: '2', name: 'Personal', color: Colors.green, order: 1),
        TaskCategory(id: '3', name: 'Health', color: Colors.red, order: 2),
      ];
      now = DateTime(2025, 11, 5, 14, 0); // Nov 5, 2:00 PM
      today = DateTime(now.year, now.month, now.day);
    });

    int score(Task task) => service.calculateTaskPriorityScore(task, now, today, categories);

    group('Reminder Priority Rules', () {
      test('reminder < 30 min beats everything except overdue', () {
        final soonReminder = Task(
          id: '1',
          title: 'Soon',
          reminderTime: DateTime(2025, 11, 5, 14, 20), // 20 min away
          createdAt: now,
        );

        final scheduledToday = Task(
          id: '2',
          title: 'Scheduled Today',
          scheduledDate: today,
          categoryIds: ['1'], // Cat1 = 100 points
          isImportant: true,
          createdAt: now,
        );

        expect(score(soonReminder), greaterThan(score(scheduledToday)));
      });

      test('overdue reminder beats reminder < 30 min', () {
        final overdue = Task(
          id: '1',
          title: 'Overdue',
          reminderTime: DateTime(2025, 11, 5, 13, 0), // 1 hr ago
          createdAt: now,
        );

        final soon = Task(
          id: '2',
          title: 'Soon',
          reminderTime: DateTime(2025, 11, 5, 14, 20), // 20 min away
          createdAt: now,
        );

        expect(score(overdue), greaterThan(score(soon)));
      });

      test('reminder 30-120 min away gets reduced priority plus symbolic bonus', () {
        final laterReminder = Task(
          id: '1',
          title: 'Later',
          reminderTime: DateTime(2025, 11, 5, 15, 0), // 60 min away
          createdAt: now,
        );

        // Unscheduled task with distant reminder gets 120 (reduced) + 15 (symbolic for 30-120 min)
        expect(score(laterReminder), equals(135));
      });

      test('reminder > 120 min away gets reduced priority', () {
        final distantReminder = Task(
          id: '1',
          title: 'Distant',
          reminderTime: DateTime(2025, 11, 5, 18, 0), // 4 hours away
          createdAt: now,
        );

        // Unscheduled task with very distant reminder gets 120 (same as tomorrow)
        expect(score(distantReminder), equals(120));
      });
    });

    group('Scheduled Today Priority', () {
      test('scheduled today with no reminder beats unscheduled', () {
        final scheduledToday = Task(
          id: '1',
          title: 'Scheduled Today',
          scheduledDate: today,
          createdAt: now,
        );

        final unscheduled = Task(
          id: '2',
          title: 'Unscheduled',
          createdAt: now,
        );

        expect(score(scheduledToday), greaterThan(score(unscheduled)));
      });

      test('scheduled today with reminder < 30 min gets categories and important', () {
        final scheduledWithNearReminder = Task(
          id: '1',
          title: 'Scheduled + Near Reminder',
          scheduledDate: today,
          reminderTime: DateTime(2025, 11, 5, 14, 20), // 20 min away
          categoryIds: ['1'], // Cat1 = 100 points
          isImportant: true,
          createdAt: now,
        );

        final scheduledNoReminder = Task(
          id: '2',
          title: 'Scheduled No Reminder',
          scheduledDate: today,
          createdAt: now,
        );

        // Near reminder task should get: 1100 + 600 + 100 (cat) + 100 (important)
        // No reminder task should get: 600
        expect(score(scheduledWithNearReminder), greaterThan(score(scheduledNoReminder) + 1000));
      });

      test('scheduled today with reminder > 30 min gets 125 + no categories/important', () {
        final scheduledWithDistantReminder = Task(
          id: '1',
          title: 'Scheduled + Distant Reminder',
          scheduledDate: today,
          reminderTime: DateTime(2025, 11, 5, 15, 30), // 90 min away
          categoryIds: ['1'], // Should NOT get category points
          isImportant: true, // Should NOT get important points
          createdAt: now,
        );

        final tomorrow = Task(
          id: '2',
          title: 'Tomorrow',
          scheduledDate: today.add(const Duration(days: 1)),
          createdAt: now,
        );

        // Scheduled today with distant reminder (30-120min): 15 + 125 = 140
        // Tomorrow: 120
        expect(score(scheduledWithDistantReminder), equals(140));
        expect(score(scheduledWithDistantReminder), greaterThan(score(tomorrow)));
      });
    });

    group('Unscheduled Tasks Priority', () {
      test('unscheduled tasks beat future scheduled tasks', () {
        final unscheduled = Task(
          id: '1',
          title: 'Unscheduled',
          createdAt: now,
        );

        final tomorrow = Task(
          id: '2',
          title: 'Tomorrow',
          scheduledDate: today.add(const Duration(days: 1)),
          createdAt: now,
        );

        expect(score(unscheduled), greaterThan(score(tomorrow)));
      });

      test('unscheduled tasks get category bonuses', () {
        final unscheduledWithCat1 = Task(
          id: '1',
          title: 'Unscheduled Cat1',
          categoryIds: ['1'], // Cat1 = 100 points
          createdAt: now,
        );

        final unscheduledNoCat = Task(
          id: '2',
          title: 'Unscheduled No Cat',
          createdAt: now,
        );

        // Cat1 task: 400 + 100 = 500
        // No cat task: 400
        expect(score(unscheduledWithCat1), equals(score(unscheduledNoCat) + 100));
      });

      test('unscheduled with multiple categories sums all category points', () {
        final multiCat = Task(
          id: '1',
          title: 'Multi Cat',
          categoryIds: ['1', '2'], // Cat1=100, Cat2=90 = 190
          createdAt: now,
        );

        final singleCat = Task(
          id: '2',
          title: 'Single Cat',
          categoryIds: ['1'], // Cat1=100
          createdAt: now,
        );

        // Multi: 400 + 190 = 590
        // Single: 400 + 100 = 500
        expect(score(multiCat), equals(score(singleCat) + 90));
      });

      test('unscheduled with distant reminder gets reduced priority (no bonuses)', () {
        final unscheduledDistantReminder = Task(
          id: '1',
          title: 'Unscheduled Distant Reminder',
          reminderTime: DateTime(2025, 11, 5, 18, 0), // 4 hours away
          categoryIds: ['1'],
          isImportant: true,
          createdAt: now,
        );

        // Should get: 120 (reduced for distant reminder, no categories/important bonus)
        expect(score(unscheduledDistantReminder), equals(120));
      });
    });

    group('Future Scheduled Tasks Priority', () {
      test('tomorrow beats day after tomorrow', () {
        final tomorrow = Task(
          id: '1',
          title: 'Tomorrow',
          scheduledDate: today.add(const Duration(days: 1)),
          createdAt: now,
        );

        final dayAfter = Task(
          id: '2',
          title: 'Day After',
          scheduledDate: today.add(const Duration(days: 2)),
          createdAt: now,
        );

        expect(score(tomorrow), greaterThan(score(dayAfter)));
      });

      test('future scheduled tasks get date-based priority in strict order', () {
        final day1 = Task(
          id: '1',
          title: 'Day 1',
          scheduledDate: today.add(const Duration(days: 1)),
          createdAt: now,
        );
        final day2 = Task(
          id: '2',
          title: 'Day 2',
          scheduledDate: today.add(const Duration(days: 2)),
          createdAt: now,
        );

        // Tomorrow gets 120, day after gets 115
        expect(score(day1), equals(120));
        expect(score(day2), equals(115));
        // Tomorrow beats day after
        expect(score(day1), greaterThan(score(day2)));
      });

      test('future scheduled tasks do NOT get category bonuses', () {
        final futureCat1 = Task(
          id: '1',
          title: 'Future Cat1',
          scheduledDate: today.add(const Duration(days: 5)),
          categoryIds: ['1'],
          createdAt: now,
        );

        final futureNoCat = Task(
          id: '2',
          title: 'Future No Cat',
          scheduledDate: today.add(const Duration(days: 5)),
          createdAt: now,
        );

        expect(score(futureCat1), equals(score(futureNoCat)));
      });

      test('future scheduled tasks do NOT get important bonus', () {
        final futureImportant = Task(
          id: '1',
          title: 'Future Important',
          scheduledDate: today.add(const Duration(days: 5)),
          isImportant: true,
          createdAt: now,
        );

        final futureRegular = Task(
          id: '2',
          title: 'Future Regular',
          scheduledDate: today.add(const Duration(days: 5)),
          createdAt: now,
        );

        expect(score(futureImportant), equals(score(futureRegular)));
      });

      test('day 21+ decreases by 1 until minimum of 1', () {
        final day21 = Task(
          id: '1',
          title: 'Day 21',
          scheduledDate: today.add(const Duration(days: 21)),
          createdAt: now,
        );

        final day30 = Task(
          id: '2',
          title: 'Day 30',
          scheduledDate: today.add(const Duration(days: 30)),
          createdAt: now,
        );

        final day50 = Task(
          id: '3',
          title: 'Day 50',
          scheduledDate: today.add(const Duration(days: 50)),
          createdAt: now,
        );

        // Day 21: 10 - (21-20) = 9
        // Day 30: 10 - (30-20) = max(1, 0) = 1
        // Day 50: minimum of 1
        expect(score(day21), greaterThan(score(day30)));
        expect(score(day30), equals(1));
        expect(score(day50), equals(1));
      });
    });

    group('Category Scoring', () {
      test('category priority 1 = 100 points', () {
        final cat1 = Task(
          id: '1',
          title: 'Cat1',
          categoryIds: ['1'], // order=0
          createdAt: now,
        );

        final noCat = Task(
          id: '2',
          title: 'No Cat',
          createdAt: now,
        );

        // Cat1: 400 + 100 = 500
        // No cat: 400
        expect(score(cat1), equals(score(noCat) + 100));
      });

      test('category priority 2 = 90 points', () {
        final cat2 = Task(
          id: '1',
          title: 'Cat2',
          categoryIds: ['2'], // order=1
          createdAt: now,
        );

        final noCat = Task(
          id: '2',
          title: 'No Cat',
          createdAt: now,
        );

        // Cat2: 400 + 90 = 490
        // No cat: 400
        expect(score(cat2), equals(score(noCat) + 90));
      });

      test('category priority 3 = 80 points', () {
        final cat3 = Task(
          id: '1',
          title: 'Cat3',
          categoryIds: ['3'], // order=2
          createdAt: now,
        );

        final noCat = Task(
          id: '2',
          title: 'No Cat',
          createdAt: now,
        );

        // Cat3: 400 + 80 = 480
        // No cat: 400
        expect(score(cat3), equals(score(noCat) + 80));
      });
    });

    group('Deadlines Priority', () {
      test('overdue deadline beats scheduled today', () {
        final overdueDeadline = Task(
          id: '1',
          title: 'Overdue Deadline',
          deadline: today.subtract(const Duration(days: 2)),
          createdAt: now,
        );

        final scheduledToday = Task(
          id: '2',
          title: 'Scheduled Today',
          scheduledDate: today,
          categoryIds: ['1'],
          isImportant: true,
          createdAt: now,
        );

        expect(score(overdueDeadline), greaterThan(score(scheduledToday)));
      });

      test('deadline today beats scheduled today', () {
        final deadlineToday = Task(
          id: '1',
          title: 'Deadline Today',
          deadline: today,
          createdAt: now,
        );

        final scheduledToday = Task(
          id: '2',
          title: 'Scheduled Today',
          scheduledDate: today,
          categoryIds: ['1'],
          isImportant: true,
          createdAt: now,
        );

        expect(score(deadlineToday), greaterThan(score(scheduledToday)));
      });
    });

    group('Recurring Tasks Priority', () {
      test('recurring task due today gets high priority', () {
        final recurring = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: today,
          createdAt: now,
        );

        final scheduledToday = Task(
          id: '2',
          title: 'Scheduled Today',
          scheduledDate: today,
          createdAt: now,
        );

        // Recurring: 700, Scheduled today: 600
        expect(score(recurring), equals(700));
        expect(score(scheduledToday), equals(600));
        expect(score(recurring), greaterThan(score(scheduledToday)));
      });

      test('recurring task due today with distant reminder gets deprioritized to 125 (+ symbolic if 30-120min)', () {
        final recurringDistant = Task(
          id: '1',
          title: 'Daily Task Distant Reminder',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: today,
          reminderTime: DateTime(2025, 11, 5, 15, 0), // 60 min away
          createdAt: now,
        );

        final unscheduledWithCategories = Task(
          id: '2',
          title: 'Unscheduled With Categories',
          categoryIds: ['1', '2', '3'], // 100 + 90 + 80 = 270
          createdAt: now,
        );

        // Recurring with distant reminder (30-120min): 15 + 125 = 140
        // Unscheduled with 3 categories: 400 + 270 = 670
        expect(score(recurringDistant), equals(140));
        expect(score(unscheduledWithCategories), equals(670));
        expect(score(unscheduledWithCategories), greaterThan(score(recurringDistant)));
      });

      test('recurring task scheduled in future gets very low priority', () {
        final recurringFuture = Task(
          id: '1',
          title: 'Future Recurring',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: today.add(const Duration(days: 5)),
          createdAt: now,
        );

        expect(score(recurringFuture), equals(1));
      });
    });

    group('Edge Cases', () {
      test('postponed task without scheduled date gets minimal priority', () {
        final postponed = Task(
          id: '1',
          title: 'Postponed',
          isPostponed: true,
          createdAt: now,
        );

        expect(score(postponed), equals(2));
      });

      test('task with no attributes gets unscheduled priority', () {
        final plain = Task(
          id: '1',
          title: 'Plain',
          createdAt: now,
        );

        // Unscheduled tasks now get 400 base priority
        expect(score(plain), equals(400));
      });
    });

    group('Complete Priority Hierarchy', () {
      test('overall hierarchy is correct', () {
        final tasks = [
          Task(
            id: 'overdue_reminder',
            title: 'Overdue Reminder',
            reminderTime: now.subtract(const Duration(hours: 1)),
            createdAt: now,
          ),
          Task(
            id: 'reminder_soon',
            title: 'Reminder Soon',
            reminderTime: now.add(const Duration(minutes: 20)),
            createdAt: now,
          ),
          Task(
            id: 'overdue_deadline',
            title: 'Overdue Deadline',
            deadline: today.subtract(const Duration(days: 2)),
            createdAt: now,
          ),
          Task(
            id: 'deadline_today',
            title: 'Deadline Today',
            deadline: today,
            createdAt: now,
          ),
          Task(
            id: 'recurring_today',
            title: 'Recurring Today',
            recurrence: TaskRecurrence(type: RecurrenceType.daily),
            scheduledDate: today,
            createdAt: now,
          ),
          Task(
            id: 'scheduled_today',
            title: 'Scheduled Today',
            scheduledDate: today,
            categoryIds: ['1'],
            isImportant: true,
            createdAt: now,
          ),
          Task(
            id: 'unscheduled',
            title: 'Unscheduled',
            categoryIds: ['1'],
            isImportant: true,
            createdAt: now,
          ),
          Task(
            id: 'scheduled_today_distant',
            title: 'Scheduled Today Distant',
            scheduledDate: today,
            reminderTime: now.add(const Duration(minutes: 90)), // 90 min = symbolic priority
            createdAt: now,
          ),
          Task(
            id: 'tomorrow',
            title: 'Tomorrow',
            scheduledDate: today.add(const Duration(days: 1)),
            createdAt: now,
          ),
        ];

        final scores = tasks.map((t) => score(t)).toList();

        // Overdue reminder > Reminder soon
        expect(scores[0], greaterThan(scores[1]));
        // Reminder soon > Overdue deadline
        expect(scores[1], greaterThan(scores[2]));
        // Overdue deadline > Scheduled today
        expect(scores[2], greaterThan(scores[5]));
        // Deadline today > Scheduled today (800 > 600+100+100)
        expect(scores[3], greaterThan(scores[5]));
        // Scheduled today > Recurring today (600+100+100=800 > 700)
        expect(scores[5], greaterThan(scores[4]));
        // Scheduled today > Unscheduled (600+100+100 > 400+100+100)
        expect(scores[5], greaterThan(scores[6]));
        // Unscheduled > Scheduled today distant (400+100+100 > 15+125)
        expect(scores[6], greaterThan(scores[7]));
        // Scheduled today distant > Tomorrow (15+125=140 > 120)
        expect(scores[7], greaterThan(scores[8]));
      });
    });
  });
}
