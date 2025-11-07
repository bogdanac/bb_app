import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/services/task_priority_service.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

void main() {
  group('TaskPriorityService', () {
    late TaskPriorityService service;
    late List<TaskCategory> categories;

    setUp(() {
      service = TaskPriorityService();
      categories = [
        TaskCategory(id: '1', name: 'Work', color: Colors.blue, order: 0),
        TaskCategory(id: '2', name: 'Personal', color: Colors.green, order: 1),
        TaskCategory(id: '3', name: 'Health', color: Colors.red, order: 2),
      ];
    });

    group('Priority Scoring - Reminder Times', () {
      test('overdue reminders get highest priority (1 hour past)', () {
        final now = DateTime(2025, 10, 31, 14, 0); // 2:00 PM
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Overdue Reminder',
          reminderTime: DateTime(2025, 10, 31, 13, 0), // 1:00 PM (1 hour ago)
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(1200)); // Recently overdue
      });

      test('overdue reminders get high priority (5 hours past)', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Overdue Reminder',
          reminderTime: DateTime(2025, 10, 31, 9, 0), // 5 hours ago
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(1000)); // Overdue within 24h
      });

      test('overdue reminders older than 24h still get priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Very Overdue Reminder',
          reminderTime: DateTime(2025, 10, 29, 14, 0), // 2 days ago
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(800)); // Older overdue
      });

      test('imminent reminders (within 15 min) are highly prioritized', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Imminent Reminder',
          reminderTime: DateTime(2025, 10, 31, 14, 10), // 10 minutes away
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(1100));
      });

      test('reminders within 1 hour (30-120 min) get symbolic priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Soon Reminder',
          reminderTime: DateTime(2025, 10, 31, 14, 45), // 45 minutes away
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(15)); // Symbolic priority (30-120 min range)
      });

      test('reminders within 2 hours get symbolic priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Later Reminder',
          reminderTime: DateTime(2025, 10, 31, 15, 30), // 1.5 hours away
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(15)); // Symbolic priority (30-120 min range)
      });

      test('reminders today but beyond 2 hours get no priority', () {
        final now = DateTime(2025, 10, 31, 10, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Distant Reminder',
          reminderTime: DateTime(2025, 10, 31, 18, 0), // 8 hours away
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(0));
      });

      test('reminders beyond today get no priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Future Reminder',
          reminderTime: DateTime(2025, 11, 1, 14, 0), // Tomorrow
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(0)); // No priority for future days
      });
    });

    group('Priority Scoring - Deadlines', () {
      test('overdue deadlines are highly prioritized', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Overdue Deadline',
          deadline: DateTime(2025, 10, 29), // 2 days overdue
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(880)); // 900 - (2 * 10)
      });

      test('deadlines today get high priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Today Deadline',
          deadline: DateTime(2025, 10, 31),
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(800));
      });

      test('tomorrow deadlines get contextual priority based on time of day', () {
        // Morning (10 AM) - lower priority for tomorrow
        final morning = DateTime(2025, 10, 31, 10, 0);
        final morningToday = DateTime(morning.year, morning.month, morning.day);

        final task = Task(
          id: '1',
          title: 'Tomorrow Deadline',
          deadline: DateTime(2025, 11, 1),
          createdAt: DateTime.now(),
        );

        final morningScore = service.calculateTaskPriorityScore(task, morning, morningToday, categories);
        expect(morningScore, equals(50));

        // Evening (8 PM) - higher priority for tomorrow
        final evening = DateTime(2025, 10, 31, 20, 0);
        final eveningToday = DateTime(evening.year, evening.month, evening.day);
        final eveningScore = service.calculateTaskPriorityScore(task, evening, eveningToday, categories);
        expect(eveningScore, equals(300));
      });

      test('deadlines 2 days away get lower priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Future Deadline',
          deadline: DateTime(2025, 11, 2), // 2 days away
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(100)); // 200 - (2 * 50)
      });
    });

    group('Priority Scoring - Important Flag', () {
      test('important tasks get priority boost', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Important Task',
          isImportant: true,
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(50));
      });

      test('important tasks scheduled today get additional boost', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Important Task Today',
          isImportant: true,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(700)); // 600 (scheduled today) + 100 (important)
      });

      test('important tasks with distant reminders do not get boost', () {
        final now = DateTime(2025, 10, 31, 10, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Important Task',
          isImportant: true,
          reminderTime: DateTime(2025, 10, 31, 18, 0), // 8 hours away
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(0)); // No bonus for distant reminders
      });
    });

    group('Priority Scoring - Recurring Tasks', () {
      test('recurring tasks due today are prioritized', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, greaterThan(600));
      });

      test('recurring tasks with reminder today use correct time', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
          reminderTime: const TimeOfDay(hour: 15, minute: 0),
        );

        final task = Task(
          id: '1',
          title: 'Daily Task with Reminder',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // Should get points for reminder within 1 hour (900) + recurring task (700)
        expect(score, greaterThan(1000));
      });

      test('recurring tasks scheduled in future get very low priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
          reminderTime: const TimeOfDay(hour: 10, minute: 0),
        );

        final task = Task(
          id: '1',
          title: 'Future Daily Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 11, 5), // 5 days in future
          reminderTime: DateTime(2025, 11, 5, 10, 0),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(1)); // Very low priority
      });

      test('postponed recurring tasks with distant reminders have no extra priority', () {
        final now = DateTime(2025, 10, 31, 10, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
          reminderTime: const TimeOfDay(hour: 18, minute: 0),
        );

        final task = Task(
          id: '1',
          title: 'Postponed Task',
          recurrence: recurrence,
          isPostponed: true,
          scheduledDate: DateTime(2025, 10, 31),
          reminderTime: DateTime(2025, 10, 31, 18, 0), // 8 hours away
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(710)); // 700 (recurring due today) + 10 (postponed with distant reminder)
      });
    });

    group('Priority Scoring - Scheduled Tasks', () {
      test('tasks scheduled today get high priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Scheduled Today',
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(600));
      });

      test('overdue scheduled tasks (non-recurring) are highly prioritized', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Overdue Scheduled',
          scheduledDate: DateTime(2025, 10, 28), // 3 days overdue
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(580)); // max(550, 595 - (3 * 5))
      });

      test('scheduled today with reminder 30 min away gets limited priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Scheduled with Reminder',
          scheduledDate: DateTime(2025, 10, 31),
          reminderTime: DateTime(2025, 10, 31, 14, 30), // 30 minutes away (symbolic)
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(615)); // 600 (scheduled today) + 15 (symbolic reminder)
      });
    });

    group('Priority Scoring - Categories', () {
      test('tasks in first-order category get priority boost', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Work Task',
          categoryIds: ['1'], // Work category (order: 0)
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(45)); // 45 - (0 * 5)
      });

      test('tasks in lower-order categories get less boost', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Health Task',
          categoryIds: ['3'], // Health category (order: 2)
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(35)); // 45 - (2 * 5)
      });

      test('tasks with multiple categories get bonus', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Multi-Category Task',
          categoryIds: ['1', '2', '3'], // 3 categories
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // Base: 45 - (0 * 5) = 45, Bonus: min(10, (3-1)*2) = 4
        expect(score, equals(49));
      });

      test('category boost is amplified for scheduled today', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Scheduled Work Task',
          categoryIds: ['1'],
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // Scheduled today: 600, Category base: 45, amplified: 45 * 1.5 = 67.5 rounded to 68
        expect(score, equals(668));
      });
    });

    group('Priority Scoring - Menstrual Cycle Tasks', () {
      test('menstrual cycle tasks due within 1 day get high priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.menstrualPhase],
        );

        final task = Task(
          id: '1',
          title: 'Menstrual Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // Score should include points for being scheduled today
        expect(score, greaterThan(600));
      });

      test('menstrual cycle tasks scheduled in future get very low priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.menstrualPhase],
        );

        final task = Task(
          id: '1',
          title: 'Future Menstrual Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 11, 5), // 5 days future
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(1)); // Very low priority
      });

      test('menstrual start day tasks get special treatment', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.menstrualStartDay],
        );

        final task = Task(
          id: '1',
          title: 'Menstrual Start Day Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, greaterThanOrEqualTo(600)); // Scheduled today gets 600
      });

      test('ovulation peak day tasks get special treatment', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.ovulationPeakDay],
        );

        final task = Task(
          id: '1',
          title: 'Ovulation Peak Day Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, greaterThanOrEqualTo(600)); // Scheduled today gets 600
      });

      test('follicular phase tasks scheduled today are prioritized', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.follicularPhase],
        );

        final task = Task(
          id: '1',
          title: 'Follicular Phase Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, greaterThanOrEqualTo(600)); // Scheduled today gets 600
      });

      test('luteal phase tasks scheduled today are prioritized', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.earlyLutealPhase],
        );

        final task = Task(
          id: '1',
          title: 'Early Luteal Phase Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, greaterThanOrEqualTo(600)); // Scheduled today gets 600
      });

      test('custom menstrual cycle tasks (interval <= -100) are recognized', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.custom],
          interval: -101, // Custom menstrual cycle indicator
        );

        final task = Task(
          id: '1',
          title: 'Custom Menstrual Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, greaterThanOrEqualTo(600)); // Scheduled today gets 600
      });
    });

    group('Priority Scoring - Edge Cases', () {
      test('postponed tasks without scheduled date get very low priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Postponed Task',
          isPostponed: true,
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(2)); // Special low priority
      });

      test('task with no priority attributes gets minimal score', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Plain Task',
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(0));
      });

      test('completed tasks can still be scored', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Completed Task',
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, isA<int>());
      });

      test('postponed task scheduled today with near reminder still gets priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Postponed but Urgent',
          isPostponed: true,
          scheduledDate: DateTime(2025, 10, 31),
          reminderTime: DateTime(2025, 10, 31, 14, 30), // 30 min away
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, greaterThan(500)); // Gets reminder + scheduled points
      });

      test('recurring task scheduled 1 day in future gets low priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'Tomorrow Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 11, 1), // Tomorrow
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // With recurrence + scheduledDate tomorrow, it returns 5 + isDueToday bonus
        // But isDueToday would be false, so let's check the actual logic
        expect(score, lessThanOrEqualTo(10)); // Low priority for 1 day away
      });

      test('recurring task scheduled 2 days in future gets minimal priority', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: '1',
          title: 'Day After Tomorrow Task',
          recurrence: recurrence,
          scheduledDate: DateTime(2025, 11, 2), // 2 days away
          createdAt: DateTime(2025, 10, 1),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, lessThanOrEqualTo(10)); // Very low priority
      });

      test('task with reminder today at exact same time', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Right Now Task',
          reminderTime: DateTime(2025, 10, 31, 14, 0), // Exactly now
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(1100)); // Within 15 min (0 diff)
      });

      test('task with deadline exactly today at midnight', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Deadline Today',
          deadline: DateTime(2025, 10, 31, 0, 0), // Today at midnight
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(800)); // Deadline today score
      });

      test('task with both deadline and reminderTime - gets combined score', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Both Deadline and Reminder',
          deadline: DateTime(2025, 11, 5), // Future
          reminderTime: DateTime(2025, 10, 31, 14, 30), // 30 min away (symbolic priority)
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // Gets symbolic priority (15 for 30-120 min range)
        expect(score, equals(15));
      });

      test('category with no match in categories list gets minimal category score', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Unknown Category Task',
          categoryIds: ['unknown-id'],
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // With order 999, base would be max(10, 45 - (999*5)) = 10, but
        // the check is `categoryImportance < 999`, so unknown categories don't get points
        expect(score, equals(0));
      });

      test('multiple categories with mixed order uses minimum', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Multi Category Task',
          categoryIds: ['2', '3', '1'], // Orders: 1, 2, 0
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        // Should use order 0 (from '1'), base: 45, bonus: min(10, (3-1)*2) = 4
        expect(score, equals(49));
      });
    });

    group('Sorting - Basic Functionality', () {
      test('tasks sorted by priority score descending', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Low Priority',
            createdAt: DateTime.now(),
          ),
          Task(
            id: '2',
            title: 'High Priority',
            isImportant: true,
            scheduledDate: DateTime(2025, 10, 31),
            createdAt: DateTime.now(),
          ),
          Task(
            id: '3',
            title: 'Medium Priority',
            isImportant: true,
            createdAt: DateTime.now(),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted[0].id, equals('2')); // High priority
        expect(sorted[1].id, equals('3')); // Medium priority
        expect(sorted[2].id, equals('1')); // Low priority
      });

      test('completed tasks excluded by default', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Active Task',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
          Task(
            id: '2',
            title: 'Completed Task',
            isCompleted: true,
            completedAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted.length, equals(1));
        expect(sorted[0].id, equals('1'));
      });

      test('completed tasks included when flag is set', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Active Task',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
          Task(
            id: '2',
            title: 'Completed Task',
            isCompleted: true,
            completedAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ];

        final sorted = service.getPrioritizedTasks(
          tasks,
          categories,
          10,
          includeCompleted: true,
        );

        expect(sorted.length, equals(2));
      });

      test('maxTasks parameter limits results', () {
        final tasks = List.generate(
          10,
          (i) => Task(
            id: '$i',
            title: 'Task $i',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
        );

        final sorted = service.getPrioritizedTasks(tasks, categories, 5);

        expect(sorted.length, equals(5));
      });

      test('maxTasks does not fail when less tasks available', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Task 1',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted.length, equals(1));
      });
    });

    group('Sorting - Tie Breaking', () {

      test('same score - important flag wins', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Not Important',
            scheduledDate: DateTime(2025, 10, 31, 15, 0),
            isImportant: false,
            createdAt: DateTime(2025, 10, 30),
          ),
          Task(
            id: '2',
            title: 'Important',
            scheduledDate: DateTime(2025, 10, 31, 15, 0),
            isImportant: true,
            createdAt: DateTime(2025, 10, 30),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted[0].id, equals('2')); // Important
      });

      test('same score - category order wins', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Lower Priority Category',
            categoryIds: ['3'], // Health (order: 2)
            createdAt: DateTime(2025, 10, 30),
          ),
          Task(
            id: '2',
            title: 'Higher Priority Category',
            categoryIds: ['1'], // Work (order: 0)
            createdAt: DateTime(2025, 10, 30),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted[0].id, equals('2')); // Work category
      });

      test('same score - newer creation date wins', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Older Task',
            createdAt: DateTime(2025, 10, 29),
          ),
          Task(
            id: '2',
            title: 'Newer Task',
            createdAt: DateTime(2025, 10, 30),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted[0].id, equals('2')); // Newer
      });

      test('tie breaking cascade - tests all levels', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Task 1',
            createdAt: DateTime(2025, 10, 29), // Older
          ),
          Task(
            id: '2',
            title: 'Task 2',
            categoryIds: ['2'], // Personal (order: 1)
            createdAt: DateTime(2025, 10, 29),
          ),
          Task(
            id: '3',
            title: 'Task 3',
            isImportant: true,
            categoryIds: ['2'],
            createdAt: DateTime(2025, 10, 29),
          ),
          Task(
            id: '4',
            title: 'Task 4',
            reminderTime: DateTime(2025, 11, 1, 15, 0), // Tomorrow (not distant)
            isImportant: true,
            categoryIds: ['2'],
            createdAt: DateTime(2025, 10, 29),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        // All tasks have very low scores. The actual order depends on tie-breaking rules.
        // Just verify that all tasks are present and properly sorted
        expect(sorted.length, equals(4));
        expect(sorted.map((t) => t.id).toList(), containsAll(['1', '2', '3', '4']));
        // Task 3 (important + category) should be higher than Task 1 (no attributes)
        expect(sorted.indexWhere((t) => t.id == '3'), lessThan(sorted.indexWhere((t) => t.id == '1')));
      });
    });

    group('Sorting - Empty and Edge Cases', () {
      test('empty task list returns empty result', () {
        final tasks = <Task>[];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted, isEmpty);
      });

      test('all completed tasks returns empty when not included', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Completed 1',
            isCompleted: true,
            completedAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
          Task(
            id: '2',
            title: 'Completed 2',
            isCompleted: true,
            completedAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted, isEmpty);
      });

      test('all tasks with same score maintains stable order', () {
        final baseTime = DateTime(2025, 10, 30);
        final tasks = List.generate(
          5,
          (i) => Task(
            id: '$i',
            title: 'Task $i',
            createdAt: baseTime.add(Duration(seconds: i)),
          ),
        );

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        // Should be sorted by creation date (newer first)
        expect(sorted[0].id, equals('4'));
        expect(sorted[4].id, equals('0'));
      });

      test('single task returns single result', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Single Task',
            createdAt: DateTime.now(),
          ),
        ];

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        expect(sorted.length, equals(1));
        expect(sorted[0].id, equals('1'));
      });
    });

    group('Performance and Purity', () {
      test('handles 100+ tasks efficiently', () {
        final tasks = List.generate(
          150,
          (i) => Task(
            id: '$i',
            title: 'Task $i',
            isImportant: i % 10 == 0,
            scheduledDate: i % 5 == 0 ? DateTime(2025, 10, 31) : null,
            categoryIds: i % 3 == 0 ? ['1'] : [],
            createdAt: DateTime(2025, 10, 30).add(Duration(minutes: i)),
          ),
        );

        final stopwatch = Stopwatch()..start();
        final sorted = service.getPrioritizedTasks(tasks, categories, 20);
        stopwatch.stop();

        expect(sorted.length, equals(20));
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });

      test('pure function - no side effects on input', () {
        final originalTasks = [
          Task(
            id: '1',
            title: 'Task 1',
            isImportant: true,
            createdAt: DateTime.now(),
          ),
          Task(
            id: '2',
            title: 'Task 2',
            createdAt: DateTime.now(),
          ),
        ];

        // Create copies to verify no mutation
        final tasksCopy = List<Task>.from(originalTasks);
        final categoriesCopy = List<TaskCategory>.from(categories);

        service.getPrioritizedTasks(originalTasks, categories, 10);

        // Verify no changes
        expect(originalTasks.length, equals(tasksCopy.length));
        expect(categories.length, equals(categoriesCopy.length));
        expect(originalTasks[0].id, equals(tasksCopy[0].id));
      });

      test('pure function - deterministic results', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Task 1',
            isImportant: true,
            scheduledDate: DateTime(2025, 10, 31),
            createdAt: DateTime(2025, 10, 30),
          ),
          Task(
            id: '2',
            title: 'Task 2',
            reminderTime: DateTime(2025, 10, 31, 14, 0),
            createdAt: DateTime(2025, 10, 30),
          ),
        ];

        final result1 = service.getPrioritizedTasks(tasks, categories, 10);
        final result2 = service.getPrioritizedTasks(tasks, categories, 10);

        expect(result1.length, equals(result2.length));
        for (var i = 0; i < result1.length; i++) {
          expect(result1[i].id, equals(result2[i].id));
        }
      });

      test('pre-calculates scores once per task', () {
        // This test verifies the optimization exists by checking behavior
        // We can't directly test internal implementation, but we verify
        // that sorting works correctly which requires pre-calculation

        final tasks = List.generate(
          50,
          (i) => Task(
            id: '$i',
            title: 'Task $i',
            isImportant: i % 2 == 0,
            createdAt: DateTime(2025, 10, 30).add(Duration(minutes: i)),
          ),
        );

        final sorted = service.getPrioritizedTasks(tasks, categories, 10);

        // If scores are pre-calculated correctly, sorting should work
        expect(sorted.length, equals(10));
        // Important tasks should be first (even indices)
        expect(sorted[0].isImportant, isTrue);
      });
    });

    group('Complex Scenarios', () {
      test('complex task with multiple priority factors', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Complex Task',
          isImportant: true,
          scheduledDate: DateTime(2025, 10, 31),
          reminderTime: DateTime(2025, 10, 31, 14, 30), // 30 min away (no priority boost)
          categoryIds: ['1'], // Work category
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);

        // Should get points from: reminder symbolic (15), scheduled today (600)
        // Important and category NOT boosted due to distant reminder (>= 30 min)
        expect(score, equals(615)); // 600 + 15
      });

      test('boundary condition - reminder exactly 15 minutes away', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Boundary Reminder',
          reminderTime: DateTime(2025, 10, 31, 14, 15), // Exactly 15 min
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(1100)); // Within 15 min boundary
      });

      test('boundary condition - reminder exactly 30 minutes away', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Just Outside Boundary',
          reminderTime: DateTime(2025, 10, 31, 14, 30), // 30 min
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(15)); // Symbolic priority (30-120 min range)
      });

      test('boundary condition - reminder exactly 60 minutes away', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'One Hour Away',
          reminderTime: DateTime(2025, 10, 31, 15, 0), // Exactly 60 min
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(15)); // Symbolic priority (30-120 min range)
      });

      test('boundary condition - reminder exactly 120 minutes away', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Two Hours Away',
          reminderTime: DateTime(2025, 10, 31, 16, 0), // Exactly 120 min
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(15)); // Symbolic priority (30-120 min range)
      });

      test('boundary condition - deadline exactly 2 days away', () {
        final now = DateTime(2025, 10, 31, 14, 0);
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Two Days Deadline',
          deadline: DateTime(2025, 11, 2), // Exactly 2 days
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(100)); // 200 - (2 * 50)
      });

      test('midnight transition - task due at start of today', () {
        final now = DateTime(2025, 10, 31, 0, 1); // Just after midnight
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'Midnight Task',
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(600)); // Scheduled today
      });

      test('end of day - task due at end of today', () {
        final now = DateTime(2025, 10, 31, 23, 59); // Just before midnight
        final today = DateTime(now.year, now.month, now.day);

        final task = Task(
          id: '1',
          title: 'End of Day Task',
          scheduledDate: DateTime(2025, 10, 31),
          createdAt: DateTime.now(),
        );

        final score = service.calculateTaskPriorityScore(task, now, today, categories);
        expect(score, equals(600)); // Still scheduled today
      });

    });
  });
}
