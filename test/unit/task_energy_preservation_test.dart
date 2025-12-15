import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/task_builder.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

/// Tests for energy level preservation across task operations.
///
/// Bug fix: Energy level was not being preserved when:
/// - Adding a task to today's schedule (_addTaskToToday)
/// - Postponing a task to tomorrow (_postponeTask)
/// - Creating next occurrence of recurring tasks
void main() {
  group('Task Energy Level Preservation', () {
    group('Task.copyWith preserves energyLevel', () {
      test('should preserve energyLevel when not specified', () {
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          categoryIds: [],
          energyLevel: -4,
        );

        final copied = task.copyWith(title: 'Updated Title');

        expect(copied.energyLevel, -4);
        expect(copied.title, 'Updated Title');
      });

      test('should allow energyLevel to be changed', () {
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          categoryIds: [],
          energyLevel: -4,
        );

        final copied = task.copyWith(energyLevel: 3);

        expect(copied.energyLevel, 3);
      });

      test('should preserve energyLevel through multiple copyWith calls', () {
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          categoryIds: [],
          energyLevel: -3,
        );

        final step1 = task.copyWith(scheduledDate: DateTime(2025, 12, 1));
        final step2 = step1.copyWith(isPostponed: true);
        final step3 = step2.copyWith(isCompleted: true);

        expect(step1.energyLevel, -3);
        expect(step2.energyLevel, -3);
        expect(step3.energyLevel, -3);
      });
    });

    group('TaskBuilder.buildFromEditScreen preserves energyLevel', () {
      test('should use provided energyLevel for new task', () {
        final task = TaskBuilder.buildFromEditScreen(
          currentTaskId: null,
          title: 'New Task',
          categoryIds: [],
          deadline: null,
          scheduledDate: null,
          reminderTime: null,
          isImportant: false,
          isPostponed: false,
          recurrence: null,
          hasUserModifiedScheduledDate: false,
          currentTask: null,
          energyLevel: -4,
        );

        expect(task.energyLevel, -4);
      });

      test('should default to -1 when energyLevel not specified', () {
        final task = TaskBuilder.buildFromEditScreen(
          currentTaskId: null,
          title: 'New Task',
          categoryIds: [],
          deadline: null,
          scheduledDate: null,
          reminderTime: null,
          isImportant: false,
          isPostponed: false,
          recurrence: null,
          hasUserModifiedScheduledDate: false,
          currentTask: null,
        );

        expect(task.energyLevel, -1);
      });

      test('should preserve energyLevel when updating existing task', () {
        final existingTask = Task(
          id: 'existing-123',
          title: 'Old Title',
          categoryIds: [],
          energyLevel: -5,
          createdAt: DateTime(2025, 9, 1),
        );

        final task = TaskBuilder.buildFromEditScreen(
          currentTaskId: existingTask.id,
          title: 'New Title',
          categoryIds: [],
          deadline: null,
          scheduledDate: null,
          reminderTime: null,
          isImportant: false,
          isPostponed: false,
          recurrence: null,
          hasUserModifiedScheduledDate: false,
          currentTask: existingTask,
          energyLevel: existingTask.energyLevel,
        );

        expect(task.energyLevel, -5);
      });

      test('should handle all energy levels from -5 to +5', () {
        for (int energy = -5; energy <= 5; energy++) {
          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'Energy Test Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: null,
            energyLevel: energy,
          );

          expect(task.energyLevel, energy, reason: 'Energy level $energy should be preserved');
        }
      });
    });

    group('TaskBuilder.updateScheduledDate preserves energyLevel', () {
      test('should preserve energyLevel when updating scheduled date', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          energyLevel: -4,
          createdAt: DateTime(2025, 9, 1),
        );

        final newScheduledDate = DateTime(2025, 11, 1);
        final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

        expect(updated.energyLevel, -4);
        expect(updated.scheduledDate, newScheduledDate);
      });

      test('should preserve energyLevel when resetting completion', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          isCompleted: true,
          completedAt: DateTime(2025, 10, 1, 12, 0),
          energyLevel: -3,
          createdAt: DateTime(2025, 9, 1),
        );

        final newScheduledDate = DateTime(2025, 11, 1);
        final updated = TaskBuilder.updateScheduledDate(
          task,
          newScheduledDate,
          resetCompletion: true,
        );

        expect(updated.energyLevel, -3);
        expect(updated.isCompleted, false);
      });

      test('should preserve energyLevel for recurring task rescheduling', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: 'task-1',
          title: 'Daily Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          recurrence: recurrence,
          energyLevel: -2,
          createdAt: DateTime(2025, 9, 1),
        );

        final nextOccurrence = DateTime(2025, 10, 2);
        final updated = TaskBuilder.updateScheduledDate(task, nextOccurrence);

        expect(updated.energyLevel, -2);
        expect(updated.scheduledDate, nextOccurrence);
        expect(updated.recurrence, isNotNull);
      });
    });

    group('TaskBuilder.postponeToDate preserves energyLevel', () {
      test('should preserve energyLevel when postponing task', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          energyLevel: -4,
          createdAt: DateTime(2025, 9, 1),
        );

        final postponeDate = DateTime(2025, 11, 15);
        final postponed = TaskBuilder.postponeToDate(task, postponeDate);

        expect(postponed.energyLevel, -4);
        expect(postponed.scheduledDate, postponeDate);
        expect(postponed.isPostponed, true);
      });

      test('should preserve energyLevel for recurring task postponement', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 1,
          weekDays: [1, 3, 5],
        );

        final task = Task(
          id: 'task-1',
          title: 'Weekly Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          recurrence: recurrence,
          energyLevel: -5,
          createdAt: DateTime(2025, 9, 1),
        );

        final postponeDate = DateTime(2025, 10, 8);
        final postponed = TaskBuilder.postponeToDate(task, postponeDate);

        expect(postponed.energyLevel, -5);
        expect(postponed.scheduledDate, postponeDate);
        expect(postponed.isPostponed, true);
      });

      test('should preserve energyLevel across multiple postponements', () {
        var task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          energyLevel: -3,
          createdAt: DateTime(2025, 9, 1),
        );

        // Postpone multiple times
        task = TaskBuilder.postponeToDate(task, DateTime(2025, 10, 5));
        expect(task.energyLevel, -3);

        task = TaskBuilder.postponeToDate(task, DateTime(2025, 10, 10));
        expect(task.energyLevel, -3);

        task = TaskBuilder.postponeToDate(task, DateTime(2025, 10, 15));
        expect(task.energyLevel, -3);
      });
    });

    group('TaskBuilder.complete preserves energyLevel', () {
      test('should preserve energyLevel when completing task', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          energyLevel: -4,
          isCompleted: false,
          createdAt: DateTime(2025, 9, 1),
        );

        final completed = TaskBuilder.complete(task);

        expect(completed.energyLevel, -4);
        expect(completed.isCompleted, true);
      });

      test('should preserve energyLevel for charging task', () {
        final task = Task(
          id: 'task-1',
          title: 'Energizing Task',
          categoryIds: [],
          energyLevel: 3, // Charging task
          isCompleted: false,
          createdAt: DateTime(2025, 9, 1),
        );

        final completed = TaskBuilder.complete(task);

        expect(completed.energyLevel, 3);
        expect(completed.isCompleted, true);
      });
    });

    group('TaskBuilder.uncomplete preserves energyLevel', () {
      test('should preserve energyLevel when uncompleting task', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          energyLevel: -4,
          isCompleted: true,
          completedAt: DateTime(2025, 10, 1),
          createdAt: DateTime(2025, 9, 1),
        );

        final uncompleted = TaskBuilder.uncomplete(task);

        expect(uncompleted.energyLevel, -4);
        expect(uncompleted.isCompleted, false);
      });
    });

    group('Recurring Task Energy Preservation', () {
      test('should preserve energyLevel when creating next occurrence via updateScheduledDate', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        final task = Task(
          id: 'recurring-1',
          title: 'Daily Draining Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          recurrence: recurrence,
          energyLevel: -4,
          isCompleted: false,
          createdAt: DateTime(2025, 9, 1),
        );

        // Simulate completing and rescheduling to next occurrence
        final nextDate = DateTime(2025, 10, 2);
        final nextOccurrence = TaskBuilder.updateScheduledDate(task, nextDate);

        expect(nextOccurrence.energyLevel, -4, reason: 'Energy should be preserved for next occurrence');
        expect(nextOccurrence.scheduledDate, nextDate);
        expect(nextOccurrence.isCompleted, false);
      });

      test('should preserve energyLevel through complete recurring task workflow', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 1,
          weekDays: [1], // Monday
        );

        var task = Task(
          id: 'weekly-1',
          title: 'Weekly Review',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 6), // Monday
          recurrence: recurrence,
          energyLevel: -3,
          isCompleted: false,
          createdAt: DateTime(2025, 9, 1),
        );

        // Week 1: Complete the task
        task = TaskBuilder.complete(task);
        expect(task.energyLevel, -3);
        expect(task.isCompleted, true);

        // Week 1 -> Week 2: Reschedule to next occurrence
        task = TaskBuilder.updateScheduledDate(task, DateTime(2025, 10, 13));
        expect(task.energyLevel, -3, reason: 'Energy preserved after rescheduling');
        expect(task.isCompleted, false);

        // Week 2: Complete again
        task = TaskBuilder.complete(task);
        expect(task.energyLevel, -3);

        // Week 2 -> Week 3: Reschedule again
        task = TaskBuilder.updateScheduledDate(task, DateTime(2025, 10, 20));
        expect(task.energyLevel, -3, reason: 'Energy still preserved after multiple cycles');
      });

      test('should preserve extreme energy values through recurring cycles', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
        );

        // Test with most draining task (-5)
        var drainingTask = Task(
          id: 'drain-1',
          title: 'Most Draining Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          recurrence: recurrence,
          energyLevel: -5,
          createdAt: DateTime(2025, 9, 1),
        );

        for (int day = 1; day <= 5; day++) {
          drainingTask = TaskBuilder.updateScheduledDate(
            drainingTask,
            DateTime(2025, 10, day + 1),
          );
          expect(drainingTask.energyLevel, -5,
            reason: 'Most draining energy level should persist on day ${day + 1}');
        }

        // Test with most charging task (+5)
        var chargingTask = Task(
          id: 'charge-1',
          title: 'Most Charging Task',
          categoryIds: [],
          scheduledDate: DateTime(2025, 10, 1),
          recurrence: recurrence,
          energyLevel: 5,
          createdAt: DateTime(2025, 9, 1),
        );

        for (int day = 1; day <= 5; day++) {
          chargingTask = TaskBuilder.updateScheduledDate(
            chargingTask,
            DateTime(2025, 10, day + 1),
          );
          expect(chargingTask.energyLevel, 5,
            reason: 'Most charging energy level should persist on day ${day + 1}');
        }
      });
    });

    group('Task JSON Serialization preserves energyLevel', () {
      test('should preserve energyLevel through JSON round-trip', () {
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          categoryIds: ['cat1'],
          energyLevel: -4,
          createdAt: DateTime(2025, 9, 1),
        );

        final json = task.toJson();
        final restored = Task.fromJson(json);

        expect(restored.energyLevel, -4);
      });

      test('should default to -1 when energyLevel missing from JSON', () {
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'categoryIds': <String>[],
          'createdAt': DateTime(2025, 9, 1).toIso8601String(),
          // energyLevel intentionally missing
        };

        final task = Task.fromJson(json);

        expect(task.energyLevel, -1);
      });

      test('should preserve all energy levels through JSON', () {
        for (int energy = -5; energy <= 5; energy++) {
          final task = Task(
            id: 'task-$energy',
            title: 'Energy $energy Task',
            categoryIds: [],
            energyLevel: energy,
            createdAt: DateTime(2025, 9, 1),
          );

          final json = task.toJson();
          final restored = Task.fromJson(json);

          expect(restored.energyLevel, energy,
            reason: 'Energy level $energy should survive JSON round-trip');
        }
      });
    });

    group('Edge Cases', () {
      test('should handle neutral energy (0) correctly', () {
        final task = Task(
          id: 'task-1',
          title: 'Neutral Task',
          categoryIds: [],
          energyLevel: 0,
          createdAt: DateTime(2025, 9, 1),
        );

        final postponed = TaskBuilder.postponeToDate(task, DateTime(2025, 10, 5));
        final completed = TaskBuilder.complete(task);
        final updated = TaskBuilder.updateScheduledDate(
          task.copyWith(scheduledDate: DateTime(2025, 10, 1)),
          DateTime(2025, 10, 2),
        );

        expect(postponed.energyLevel, 0);
        expect(completed.energyLevel, 0);
        expect(updated.energyLevel, 0);
      });

      test('should preserve energyLevel with all task properties populated', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 2,
          weekDays: [1, 3, 5],
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        );

        final task = Task(
          id: 'full-task',
          title: 'Full Task',
          description: 'A complete task with all fields',
          categoryIds: ['work', 'important'],
          deadline: DateTime(2025, 12, 31),
          scheduledDate: DateTime(2025, 10, 7),
          reminderTime: DateTime(2025, 10, 7, 9, 0),
          isImportant: true,
          isPostponed: false,
          recurrence: recurrence,
          isCompleted: false,
          energyLevel: -4,
          createdAt: DateTime(2025, 9, 1),
        );

        // Test all operations preserve energy
        final postponed = TaskBuilder.postponeToDate(task, DateTime(2025, 10, 14));
        expect(postponed.energyLevel, -4);
        expect(postponed.title, 'Full Task');
        expect(postponed.description, 'A complete task with all fields');
        expect(postponed.categoryIds, ['work', 'important']);
        expect(postponed.deadline, DateTime(2025, 12, 31));
        expect(postponed.isImportant, true);
        expect(postponed.recurrence, isNotNull);

        final completed = TaskBuilder.complete(task);
        expect(completed.energyLevel, -4);

        final updated = TaskBuilder.updateScheduledDate(task, DateTime(2025, 10, 14));
        expect(updated.energyLevel, -4);
      });
    });
  });
}
