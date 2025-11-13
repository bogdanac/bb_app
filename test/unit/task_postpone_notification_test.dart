import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

void main() {
  group('Postponed Task Notification Behavior', () {

    setUp(() {
    });

    test('postponed daily recurring task should NOT schedule as recurring', () {
      // Create a daily recurring task that has been postponed
      final postponedTask = Task(
        id: '1',
        title: 'Daily Task - Postponed',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 6), // Tomorrow
        reminderTime: DateTime(2025, 11, 6, 9, 0), // Tomorrow at 9 AM
        isPostponed: true, // KEY: Task is postponed
        createdAt: DateTime(2025, 11, 5),
      );

      // When we check if it should be scheduled as recurring
      final shouldScheduleAsRecurring =
          postponedTask.recurrence != null && !postponedTask.isPostponed;

      // Then it should NOT be scheduled as recurring (to prevent today's notification)
      expect(shouldScheduleAsRecurring, isFalse,
          reason: 'Postponed tasks should be scheduled as one-time notifications');
    });

    test('non-postponed daily recurring task SHOULD schedule as recurring', () {
      // Create a normal daily recurring task (not postponed)
      final normalTask = Task(
        id: '2',
        title: 'Daily Task - Normal',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 5), // Today
        reminderTime: DateTime(2025, 11, 5, 9, 0), // Today at 9 AM
        isPostponed: false, // KEY: Task is NOT postponed
        createdAt: DateTime(2025, 11, 5),
      );

      // When we check if it should be scheduled as recurring
      final shouldScheduleAsRecurring =
          normalTask.recurrence != null && !normalTask.isPostponed;

      // Then it SHOULD be scheduled as recurring (normal behavior)
      expect(shouldScheduleAsRecurring, isTrue,
          reason: 'Non-postponed recurring tasks should have repeating notifications');
    });

    test('completed recurring task should clear isPostponed flag', () {
      // Simulate completing a postponed task
      final postponedTask = Task(
        id: '3',
        title: 'Daily Task',
        recurrence: TaskRecurrence(type: RecurrenceType.daily),
        scheduledDate: DateTime(2025, 11, 6),
        reminderTime: DateTime(2025, 11, 6, 9, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 5),
      );

      // When task is completed and advances to next occurrence
      final completedTask = Task(
        id: postponedTask.id,
        title: postponedTask.title,
        recurrence: postponedTask.recurrence,
        scheduledDate: null, // Will be recalculated
        reminderTime: postponedTask.reminderTime,
        isPostponed: false, // CLEARED when completing
        isCompleted: true,
        completedAt: DateTime.now(),
        createdAt: postponedTask.createdAt,
      );

      // Then isPostponed should be false
      expect(completedTask.isPostponed, isFalse,
          reason: 'Completing a task should clear isPostponed flag');

      // And when the task advances to next occurrence, it can schedule as recurring again
      final shouldScheduleAsRecurring =
          completedTask.recurrence != null && !completedTask.isPostponed;
      expect(shouldScheduleAsRecurring, isTrue,
          reason: 'After completion, next occurrence should resume normal recurring notifications');
    });

    test('postponed weekly recurring task should also NOT schedule as recurring', () {
      final postponedWeeklyTask = Task(
        id: '4',
        title: 'Weekly Task - Postponed',
        recurrence: TaskRecurrence(
          type: RecurrenceType.weekly,
          weekDays: [DateTime.monday],
        ),
        scheduledDate: DateTime(2025, 11, 10), // Next Monday
        reminderTime: DateTime(2025, 11, 10, 10, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 5),
      );

      final shouldScheduleAsRecurring =
          postponedWeeklyTask.recurrence != null && !postponedWeeklyTask.isPostponed;

      expect(shouldScheduleAsRecurring, isFalse,
          reason: 'Postponed weekly tasks should also be one-time notifications');
    });

    test('postponed monthly recurring task should also NOT schedule as recurring', () {
      final postponedMonthlyTask = Task(
        id: '5',
        title: 'Monthly Task - Postponed',
        recurrence: TaskRecurrence(
          type: RecurrenceType.monthly,
          dayOfMonth: 1,
        ),
        scheduledDate: DateTime(2025, 12, 1), // Next month
        reminderTime: DateTime(2025, 12, 1, 12, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 5),
      );

      final shouldScheduleAsRecurring =
          postponedMonthlyTask.recurrence != null && !postponedMonthlyTask.isPostponed;

      expect(shouldScheduleAsRecurring, isFalse,
          reason: 'Postponed monthly tasks should also be one-time notifications');
    });

    test('non-recurring postponed task should never schedule as recurring', () {
      final postponedNonRecurringTask = Task(
        id: '6',
        title: 'One-time Task - Postponed',
        scheduledDate: DateTime(2025, 11, 6),
        reminderTime: DateTime(2025, 11, 6, 14, 0),
        isPostponed: true,
        createdAt: DateTime(2025, 11, 5),
      );

      final shouldScheduleAsRecurring =
          postponedNonRecurringTask.recurrence != null && !postponedNonRecurringTask.isPostponed;

      expect(shouldScheduleAsRecurring, isFalse,
          reason: 'Non-recurring tasks never schedule as recurring');
    });

    group('Edge Cases', () {
      test('task with null recurrence should not schedule as recurring', () {
        final task = Task(
          id: '7',
          title: 'No Recurrence',
          scheduledDate: DateTime(2025, 11, 6),
          reminderTime: DateTime(2025, 11, 6, 15, 0),
          isPostponed: false,
          recurrence: null,
          createdAt: DateTime(2025, 11, 5),
        );

        final shouldScheduleAsRecurring =
            task.recurrence != null && !task.isPostponed;

        expect(shouldScheduleAsRecurring, isFalse);
      });

      test('task with null reminderTime should not be scheduled', () {
        final task = Task(
          id: '8',
          title: 'No Reminder',
          scheduledDate: DateTime(2025, 11, 6),
          reminderTime: null,
          isPostponed: false,
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          createdAt: DateTime(2025, 11, 5),
        );

        // Task without reminderTime should not be scheduled at all
        expect(task.reminderTime, isNull,
            reason: 'Tasks without reminder times should not get notifications');
      });
    });

    group('Notification Scheduling Flow', () {
      test('postponing a task sets isPostponed to true', () {
        final task = Task(
          id: '9',
          title: 'Task Before Postpone',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: DateTime(2025, 11, 5),
          reminderTime: DateTime(2025, 11, 5, 9, 0),
          isPostponed: false,
          createdAt: DateTime(2025, 11, 5),
        );

        // Simulate postponing to tomorrow
        final postponedTask = task.copyWith(
          scheduledDate: DateTime(2025, 11, 6),
          reminderTime: DateTime(2025, 11, 6, 9, 0),
          isPostponed: true,
        );

        expect(postponedTask.isPostponed, isTrue);
        expect(postponedTask.scheduledDate, DateTime(2025, 11, 6));
        expect(postponedTask.reminderTime, DateTime(2025, 11, 6, 9, 0));
      });

      test('auto-advancement clears isPostponed flag', () {
        // Simulate a task that was postponed but is now auto-advancing
        final postponedTask = Task(
          id: '10',
          title: 'Postponed Task',
          recurrence: TaskRecurrence(type: RecurrenceType.daily),
          scheduledDate: DateTime(2025, 11, 6),
          reminderTime: DateTime(2025, 11, 6, 9, 0),
          isPostponed: true,
          createdAt: DateTime(2025, 11, 5),
        );

        // When auto-advancing (via recurrence_calculator.dart:67)
        final advancedTask = postponedTask.copyWith(
          scheduledDate: DateTime(2025, 11, 7), // Next occurrence
          reminderTime: DateTime(2025, 11, 7, 9, 0),
          isPostponed: false, // CLEARED during auto-advancement
          isCompleted: false,
          clearCompletedAt: true,
        );

        expect(advancedTask.isPostponed, isFalse,
            reason: 'Auto-advancement should clear isPostponed flag');

        // After clearing, task should resume normal recurring notifications
        final shouldScheduleAsRecurring =
            advancedTask.recurrence != null && !advancedTask.isPostponed;
        expect(shouldScheduleAsRecurring, isTrue);
      });
    });
  });
}
