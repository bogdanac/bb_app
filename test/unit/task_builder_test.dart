import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/task_builder.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

void main() {
  group('TaskBuilder', () {
    group('buildFromEditScreen', () {
      group('New Task Creation', () {
        test('should create new task with auto-generated ID when currentTask is null', () {
          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'New Task',
            categoryIds: ['cat1'],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: null,
          );

          expect(task.id, isNotEmpty);
          expect(task.title, 'New Task');
          expect(task.categoryIds, ['cat1']);
          expect(task.isCompleted, false);
          expect(task.completedAt, isNull);
        });

        test('should create new task with all fields populated', () {
          final deadline = DateTime(2025, 12, 31);
          final scheduledDate = DateTime(2025, 11, 15);
          final reminderTime = DateTime(2025, 11, 15, 9, 0);
          final recurrence = TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'Complete Task',
            categoryIds: ['cat1', 'cat2'],
            deadline: deadline,
            scheduledDate: scheduledDate,
            reminderTime: reminderTime,
            isImportant: true,
            isPostponed: false,
            recurrence: recurrence,
            hasUserModifiedScheduledDate: true,
            currentTask: null,
          );

          expect(task.title, 'Complete Task');
          expect(task.categoryIds, ['cat1', 'cat2']);
          expect(task.deadline, deadline);
          expect(task.scheduledDate, scheduledDate);
          expect(task.reminderTime, reminderTime);
          expect(task.isImportant, true);
          expect(task.recurrence, isNotNull);
          expect(task.recurrence!.types, contains(RecurrenceType.daily));
        });

        test('should set isPostponed=true when scheduledDate is provided', () {
          final scheduledDate = DateTime(2025, 11, 15);

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'Scheduled Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: scheduledDate,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: true,
            currentTask: null,
          );

          expect(task.isPostponed, true);
          expect(task.scheduledDate, scheduledDate);
        });

        test('should preserve isPostponed=true flag even when scheduledDate is null', () {
          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: true,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: null,
          );

          expect(task.isPostponed, true);
        });
      });

      group('Existing Task Update', () {
        test('should update existing task preserving ID', () {
          final existingTask = Task(
            id: 'existing-123',
            title: 'Old Title',
            categoryIds: ['cat1'],
            isCompleted: true,
            completedAt: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'New Title',
            categoryIds: ['cat2'],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: true,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: existingTask,
          );

          expect(task.id, 'existing-123');
          expect(task.title, 'New Title');
          expect(task.categoryIds, ['cat2']);
          expect(task.isImportant, true);
          expect(task.createdAt, existingTask.createdAt);
        });

        test('should preserve createdAt from existing task', () {
          final createdAt = DateTime(2025, 1, 1);
          final existingTask = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            createdAt: createdAt,
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'Updated Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: existingTask,
          );

          expect(task.createdAt, createdAt);
        });
      });

      group('hasUserModifiedScheduledDate Logic', () {
        test('should use provided scheduledDate when hasUserModifiedScheduledDate=true', () {
          final existingTask = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 1);

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: newScheduledDate,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: true,
            currentTask: existingTask,
          );

          expect(task.scheduledDate, newScheduledDate);
        });

        test('should use provided scheduledDate even when hasUserModifiedScheduledDate=false if scheduledDate is not null', () {
          final existingScheduledDate = DateTime(2025, 10, 1);
          final existingTask = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: existingScheduledDate,
            createdAt: DateTime(2025, 9, 1),
          );

          final providedScheduledDate = DateTime(2025, 11, 1);
          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: providedScheduledDate,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: existingTask,
          );

          // When hasUserModifiedScheduledDate=false but scheduledDate is provided,
          // it uses the provided scheduledDate (scheduledDate ?? currentTask.scheduledDate)
          expect(task.scheduledDate, providedScheduledDate);
        });

        test('should handle null scheduledDate when hasUserModifiedScheduledDate=false', () {
          final existingTask = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: existingTask,
          );

          expect(task.scheduledDate, existingTask.scheduledDate);
        });
      });

      group('Completion Status Preservation', () {
        test('should reset completion when preserveCompletionStatus=false', () {
          final existingTask = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            isCompleted: true,
            completedAt: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: existingTask,
            preserveCompletionStatus: false,
          );

          expect(task.isCompleted, false);
          expect(task.completedAt, isNull);
        });

        test('should preserve completion when preserveCompletionStatus=true', () {
          final completedAt = DateTime(2025, 10, 1);
          final existingTask = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            isCompleted: true,
            completedAt: completedAt,
            createdAt: DateTime(2025, 9, 1),
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: existingTask,
            preserveCompletionStatus: true,
          );

          expect(task.isCompleted, true);
          expect(task.completedAt, completedAt);
        });

        test('should handle uncompleted task with preserveCompletionStatus=true', () {
          final existingTask = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            isCompleted: false,
            createdAt: DateTime(2025, 9, 1),
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: existingTask.id,
            title: 'Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: existingTask,
            preserveCompletionStatus: true,
          );

          expect(task.isCompleted, false);
          expect(task.completedAt, isNull);
        });
      });

      group('Edge Cases', () {
        test('should handle task with all optional fields null', () {
          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'Minimal Task',
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

          expect(task.title, 'Minimal Task');
          expect(task.categoryIds, isEmpty);
          expect(task.deadline, isNull);
          expect(task.scheduledDate, isNull);
          expect(task.reminderTime, isNull);
          expect(task.recurrence, isNull);
          expect(task.isCompleted, false);
          expect(task.completedAt, isNull);
        });

        test('should handle recurring task', () {
          final recurrence = TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 2,
            weekDays: [1, 3, 5], // Mon, Wed, Fri
          );

          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'Weekly Task',
            categoryIds: [],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: recurrence,
            hasUserModifiedScheduledDate: false,
            currentTask: null,
          );

          expect(task.recurrence, isNotNull);
          expect(task.recurrence!.types, contains(RecurrenceType.weekly));
          expect(task.recurrence!.interval, 2);
          expect(task.recurrence!.weekDays, [1, 3, 5]);
        });

        test('should handle task with multiple categories', () {
          final task = TaskBuilder.buildFromEditScreen(
            currentTaskId: null,
            title: 'Multi-Category Task',
            categoryIds: ['work', 'urgent', 'personal'],
            deadline: null,
            scheduledDate: null,
            reminderTime: null,
            isImportant: false,
            isPostponed: false,
            recurrence: null,
            hasUserModifiedScheduledDate: false,
            currentTask: null,
          );

          expect(task.categoryIds, ['work', 'urgent', 'personal']);
        });
      });
    });

    group('updateScheduledDate', () {
      group('Basic Updates', () {
        test('should update scheduledDate correctly', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 1);
          final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

          expect(updated.scheduledDate, newScheduledDate);
          expect(updated.id, task.id);
          expect(updated.title, task.title);
        });

        test('should clear isPostponed flag when updating scheduled date', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            isPostponed: true,
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 1);
          final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

          expect(updated.isPostponed, false);
          expect(updated.scheduledDate, newScheduledDate);
        });
      });

      group('ReminderTime Updates', () {
        test('should update reminderTime to match new date keeping time-of-day', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            reminderTime: DateTime(2025, 10, 1, 9, 30),
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 15);
          final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

          expect(updated.reminderTime, isNotNull);
          expect(updated.reminderTime!.year, 2025);
          expect(updated.reminderTime!.month, 11);
          expect(updated.reminderTime!.day, 15);
          expect(updated.reminderTime!.hour, 9);
          expect(updated.reminderTime!.minute, 30);
        });

        test('should use recurrence reminderTime when task reminderTime is null', () {
          final recurrence = TaskRecurrence(
            types: [RecurrenceType.daily],
            reminderTime: const TimeOfDay(hour: 14, minute: 30),
          );

          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            reminderTime: null,
            recurrence: recurrence,
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 15);
          final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

          expect(updated.reminderTime, isNotNull);
          expect(updated.reminderTime!.year, 2025);
          expect(updated.reminderTime!.month, 11);
          expect(updated.reminderTime!.day, 15);
          expect(updated.reminderTime!.hour, 14);
          expect(updated.reminderTime!.minute, 30);
        });

        test('should handle task without reminderTime or recurrence reminderTime', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            reminderTime: null,
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 15);
          final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

          expect(updated.reminderTime, isNull);
          expect(updated.scheduledDate, newScheduledDate);
        });

        test('should prioritize task reminderTime over recurrence reminderTime', () {
          final recurrence = TaskRecurrence(
            types: [RecurrenceType.daily],
            reminderTime: const TimeOfDay(hour: 14, minute: 30),
          );

          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            reminderTime: DateTime(2025, 10, 1, 9, 0),
            recurrence: recurrence,
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 15);
          final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

          expect(updated.reminderTime!.hour, 9);
          expect(updated.reminderTime!.minute, 0);
        });
      });

      group('Completion Reset', () {
        test('should clear completion when resetCompletion=true', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            isCompleted: true,
            completedAt: DateTime(2025, 10, 1, 12, 0),
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 1);
          final updated = TaskBuilder.updateScheduledDate(
            task,
            newScheduledDate,
            resetCompletion: true,
          );

          expect(updated.isCompleted, false);
          expect(updated.completedAt, isNull);
        });

        test('should preserve completion when resetCompletion=false', () {
          final completedAt = DateTime(2025, 10, 1, 12, 0);
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            isCompleted: true,
            completedAt: completedAt,
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 1);
          final updated = TaskBuilder.updateScheduledDate(
            task,
            newScheduledDate,
            resetCompletion: false,
          );

          expect(updated.isCompleted, true);
          expect(updated.completedAt, completedAt);
        });

        test('should default to resetCompletion=true', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            isCompleted: true,
            completedAt: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 1);
          final updated = TaskBuilder.updateScheduledDate(task, newScheduledDate);

          expect(updated.isCompleted, false);
          expect(updated.completedAt, isNull);
        });
      });

      group('Immutability', () {
        test('should not modify original task', () {
          final originalScheduledDate = DateTime(2025, 10, 1);
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: originalScheduledDate,
            isPostponed: true,
            isCompleted: true,
            completedAt: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final newScheduledDate = DateTime(2025, 11, 1);
          TaskBuilder.updateScheduledDate(task, newScheduledDate);

          // Original task should be unchanged
          expect(task.scheduledDate, originalScheduledDate);
          expect(task.isPostponed, true);
          expect(task.isCompleted, true);
          expect(task.completedAt, isNotNull);
        });
      });
    });

    group('postponeToDate', () {
      group('Basic Postpone', () {
        test('should set new scheduledDate', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            createdAt: DateTime(2025, 9, 1),
          );

          final postponeDate = DateTime(2025, 11, 15);
          final postponed = TaskBuilder.postponeToDate(task, postponeDate);

          expect(postponed.scheduledDate, postponeDate);
        });

        test('should set isPostponed=true', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            isPostponed: false,
            createdAt: DateTime(2025, 9, 1),
          );

          final postponeDate = DateTime(2025, 11, 15);
          final postponed = TaskBuilder.postponeToDate(task, postponeDate);

          expect(postponed.isPostponed, true);
        });

        test('should preserve completion status', () {
          final completedAt = DateTime(2025, 10, 1, 12, 0);
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            isCompleted: true,
            completedAt: completedAt,
            createdAt: DateTime(2025, 9, 1),
          );

          final postponeDate = DateTime(2025, 11, 15);
          final postponed = TaskBuilder.postponeToDate(task, postponeDate);

          expect(postponed.isCompleted, true);
          expect(postponed.completedAt, completedAt);
        });
      });

      group('ReminderTime Updates', () {
        test('should update reminderTime to new date keeping time-of-day', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            reminderTime: DateTime(2025, 10, 1, 8, 45),
            createdAt: DateTime(2025, 9, 1),
          );

          final postponeDate = DateTime(2025, 11, 20);
          final postponed = TaskBuilder.postponeToDate(task, postponeDate);

          expect(postponed.reminderTime, isNotNull);
          expect(postponed.reminderTime!.year, 2025);
          expect(postponed.reminderTime!.month, 11);
          expect(postponed.reminderTime!.day, 20);
          expect(postponed.reminderTime!.hour, 8);
          expect(postponed.reminderTime!.minute, 45);
        });

        test('should use recurrence reminderTime when task reminderTime is null', () {
          final recurrence = TaskRecurrence(
            types: [RecurrenceType.daily],
            reminderTime: const TimeOfDay(hour: 16, minute: 15),
          );

          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            reminderTime: null,
            recurrence: recurrence,
            createdAt: DateTime(2025, 9, 1),
          );

          final postponeDate = DateTime(2025, 11, 20);
          final postponed = TaskBuilder.postponeToDate(task, postponeDate);

          expect(postponed.reminderTime, isNotNull);
          expect(postponed.reminderTime!.year, 2025);
          expect(postponed.reminderTime!.month, 11);
          expect(postponed.reminderTime!.day, 20);
          expect(postponed.reminderTime!.hour, 16);
          expect(postponed.reminderTime!.minute, 15);
        });

        test('should handle task without reminderTime', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: DateTime(2025, 10, 1),
            reminderTime: null,
            createdAt: DateTime(2025, 9, 1),
          );

          final postponeDate = DateTime(2025, 11, 20);
          final postponed = TaskBuilder.postponeToDate(task, postponeDate);

          expect(postponed.reminderTime, isNull);
          expect(postponed.scheduledDate, postponeDate);
          expect(postponed.isPostponed, true);
        });
      });

      group('Immutability', () {
        test('should not modify original task', () {
          final originalScheduledDate = DateTime(2025, 10, 1);
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            scheduledDate: originalScheduledDate,
            isPostponed: false,
            isCompleted: false,
            createdAt: DateTime(2025, 9, 1),
          );

          final postponeDate = DateTime(2025, 11, 20);
          TaskBuilder.postponeToDate(task, postponeDate);

          // Original task should be unchanged
          expect(task.scheduledDate, originalScheduledDate);
          expect(task.isPostponed, false);
        });
      });
    });

    group('complete', () {
      test('should set isCompleted=true', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          isCompleted: false,
          createdAt: DateTime(2025, 9, 1),
        );

        final completed = TaskBuilder.complete(task);

        expect(completed.isCompleted, true);
      });

      test('should set completedAt to current time', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          isCompleted: false,
          createdAt: DateTime(2025, 9, 1),
        );

        final before = DateTime.now();
        final completed = TaskBuilder.complete(task);
        final after = DateTime.now();

        expect(completed.completedAt, isNotNull);
        expect(completed.completedAt!.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(completed.completedAt!.isBefore(after.add(const Duration(seconds: 1))), true);
      });

      test('should preserve all other fields', () {
        final deadline = DateTime(2025, 12, 31);
        final scheduledDate = DateTime(2025, 11, 15);
        final reminderTime = DateTime(2025, 11, 15, 9, 0);
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 1,
        );

        final task = Task(
          id: 'task-1',
          title: 'Complete Task',
          description: 'Description',
          categoryIds: ['cat1', 'cat2'],
          deadline: deadline,
          scheduledDate: scheduledDate,
          reminderTime: reminderTime,
          isImportant: true,
          isPostponed: true,
          recurrence: recurrence,
          isCompleted: false,
          createdAt: DateTime(2025, 9, 1),
        );

        final completed = TaskBuilder.complete(task);

        expect(completed.id, task.id);
        expect(completed.title, task.title);
        expect(completed.description, task.description);
        expect(completed.categoryIds, task.categoryIds);
        expect(completed.deadline, task.deadline);
        expect(completed.scheduledDate, task.scheduledDate);
        expect(completed.reminderTime, task.reminderTime);
        expect(completed.isImportant, task.isImportant);
        expect(completed.isPostponed, task.isPostponed);
        expect(completed.recurrence, task.recurrence);
        expect(completed.createdAt, task.createdAt);
      });

      test('should work on already completed task', () {
        final oldCompletedAt = DateTime(2025, 10, 1);
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          isCompleted: true,
          completedAt: oldCompletedAt,
          createdAt: DateTime(2025, 9, 1),
        );

        final completed = TaskBuilder.complete(task);

        expect(completed.isCompleted, true);
        expect(completed.completedAt, isNot(oldCompletedAt));
      });

      group('Immutability', () {
        test('should not modify original task', () {
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            isCompleted: false,
            completedAt: null,
            createdAt: DateTime(2025, 9, 1),
          );

          TaskBuilder.complete(task);

          // Original task should be unchanged
          expect(task.isCompleted, false);
          expect(task.completedAt, isNull);
        });
      });
    });

    group('uncomplete', () {
      test('should set isCompleted=false', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          isCompleted: true,
          completedAt: DateTime(2025, 10, 1),
          createdAt: DateTime(2025, 9, 1),
        );

        final uncompleted = TaskBuilder.uncomplete(task);

        expect(uncompleted.isCompleted, false);
      });

      test('should clear completedAt', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          isCompleted: true,
          completedAt: DateTime(2025, 10, 1),
          createdAt: DateTime(2025, 9, 1),
        );

        final uncompleted = TaskBuilder.uncomplete(task);

        expect(uncompleted.completedAt, isNull);
      });

      test('should preserve all other fields', () {
        final deadline = DateTime(2025, 12, 31);
        final scheduledDate = DateTime(2025, 11, 15);
        final reminderTime = DateTime(2025, 11, 15, 9, 0);
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.weekly],
          interval: 1,
        );

        final task = Task(
          id: 'task-1',
          title: 'Complete Task',
          description: 'Description',
          categoryIds: ['cat1', 'cat2'],
          deadline: deadline,
          scheduledDate: scheduledDate,
          reminderTime: reminderTime,
          isImportant: true,
          isPostponed: true,
          recurrence: recurrence,
          isCompleted: true,
          completedAt: DateTime(2025, 10, 1),
          createdAt: DateTime(2025, 9, 1),
        );

        final uncompleted = TaskBuilder.uncomplete(task);

        expect(uncompleted.id, task.id);
        expect(uncompleted.title, task.title);
        expect(uncompleted.description, task.description);
        expect(uncompleted.categoryIds, task.categoryIds);
        expect(uncompleted.deadline, task.deadline);
        expect(uncompleted.scheduledDate, task.scheduledDate);
        expect(uncompleted.reminderTime, task.reminderTime);
        expect(uncompleted.isImportant, task.isImportant);
        expect(uncompleted.isPostponed, task.isPostponed);
        expect(uncompleted.recurrence, task.recurrence);
        expect(uncompleted.createdAt, task.createdAt);
      });

      test('should work on already uncompleted task', () {
        final task = Task(
          id: 'task-1',
          title: 'Task',
          categoryIds: [],
          isCompleted: false,
          completedAt: null,
          createdAt: DateTime(2025, 9, 1),
        );

        final uncompleted = TaskBuilder.uncomplete(task);

        expect(uncompleted.isCompleted, false);
        expect(uncompleted.completedAt, isNull);
      });

      group('Immutability', () {
        test('should not modify original task', () {
          final completedAt = DateTime(2025, 10, 1);
          final task = Task(
            id: 'task-1',
            title: 'Task',
            categoryIds: [],
            isCompleted: true,
            completedAt: completedAt,
            createdAt: DateTime(2025, 9, 1),
          );

          TaskBuilder.uncomplete(task);

          // Original task should be unchanged
          expect(task.isCompleted, true);
          expect(task.completedAt, completedAt);
        });
      });
    });

    group('Edge Cases and Integration', () {
      test('should handle recurring task with menstrual cycle phase', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.ovulationPhase],
          phaseDay: 3,
        );

        final task = TaskBuilder.buildFromEditScreen(
          currentTaskId: null,
          title: 'Ovulation Task',
          categoryIds: [],
          deadline: null,
          scheduledDate: null,
          reminderTime: null,
          isImportant: false,
          isPostponed: false,
          recurrence: recurrence,
          hasUserModifiedScheduledDate: false,
          currentTask: null,
        );

        expect(task.recurrence, isNotNull);
        expect(task.recurrence!.types, contains(RecurrenceType.ovulationPhase));
      });

      test('should handle complex recurring task with multiple types', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily, RecurrenceType.weekly],
          interval: 2,
          weekDays: [1, 3, 5],
        );

        final task = TaskBuilder.buildFromEditScreen(
          currentTaskId: null,
          title: 'Complex Task',
          categoryIds: [],
          deadline: null,
          scheduledDate: null,
          reminderTime: null,
          isImportant: false,
          isPostponed: false,
          recurrence: recurrence,
          hasUserModifiedScheduledDate: false,
          currentTask: null,
        );

        expect(task.recurrence!.types.length, 2);
        expect(task.recurrence!.types, containsAll([RecurrenceType.daily, RecurrenceType.weekly]));
      });

      test('should handle task workflow: create -> complete -> uncomplete -> postpone', () {
        // Create task
        var task = TaskBuilder.buildFromEditScreen(
          currentTaskId: null,
          title: 'Workflow Task',
          categoryIds: ['cat1'],
          deadline: DateTime(2025, 12, 31),
          scheduledDate: DateTime(2025, 11, 1),
          reminderTime: DateTime(2025, 11, 1, 10, 0),
          isImportant: true,
          isPostponed: false,
          recurrence: null,
          hasUserModifiedScheduledDate: true,
          currentTask: null,
        );

        expect(task.isCompleted, false);
        expect(task.scheduledDate, DateTime(2025, 11, 1));

        // Complete task
        task = TaskBuilder.complete(task);
        expect(task.isCompleted, true);
        expect(task.completedAt, isNotNull);

        // Uncomplete task
        task = TaskBuilder.uncomplete(task);
        expect(task.isCompleted, false);
        expect(task.completedAt, isNull);

        // Postpone task
        final postponeDate = DateTime(2025, 11, 15);
        task = TaskBuilder.postponeToDate(task, postponeDate);
        expect(task.scheduledDate, postponeDate);
        expect(task.isPostponed, true);
        expect(task.reminderTime!.day, 15);
      });

      test('should handle recurring task workflow: create -> updateScheduledDate -> complete', () {
        final recurrence = TaskRecurrence(
          types: [RecurrenceType.daily],
          interval: 1,
          reminderTime: const TimeOfDay(hour: 9, minute: 0),
        );

        // Create recurring task
        var task = TaskBuilder.buildFromEditScreen(
          currentTaskId: null,
          title: 'Daily Task',
          categoryIds: [],
          deadline: null,
          scheduledDate: DateTime(2025, 11, 1),
          reminderTime: null,
          isImportant: false,
          isPostponed: false,
          recurrence: recurrence,
          hasUserModifiedScheduledDate: true,
          currentTask: null,
        );

        expect(task.recurrence, isNotNull);
        expect(task.scheduledDate, DateTime(2025, 11, 1));

        // Update scheduled date (next occurrence)
        task = TaskBuilder.updateScheduledDate(task, DateTime(2025, 11, 2));
        expect(task.scheduledDate, DateTime(2025, 11, 2));
        expect(task.isCompleted, false);
        expect(task.isPostponed, false);
        expect(task.reminderTime!.day, 2);

        // Complete task
        task = TaskBuilder.complete(task);
        expect(task.isCompleted, true);
        expect(task.completedAt, isNotNull);
      });

      test('should preserve task immutability through multiple operations', () {
        final original = Task(
          id: 'task-1',
          title: 'Original',
          categoryIds: ['cat1'],
          scheduledDate: DateTime(2025, 11, 1),
          isCompleted: false,
          isPostponed: false,
          createdAt: DateTime(2025, 9, 1),
        );

        // Perform multiple operations
        final completed = TaskBuilder.complete(original);
        final postponed = TaskBuilder.postponeToDate(original, DateTime(2025, 11, 15));
        final updated = TaskBuilder.updateScheduledDate(original, DateTime(2025, 11, 10));

        // Original should remain unchanged
        expect(original.isCompleted, false);
        expect(original.scheduledDate, DateTime(2025, 11, 1));
        expect(original.isPostponed, false);

        // Each operation should create independent copies
        expect(completed.isCompleted, true);
        expect(completed.scheduledDate, DateTime(2025, 11, 1));

        expect(postponed.isPostponed, true);
        expect(postponed.scheduledDate, DateTime(2025, 11, 15));

        expect(updated.scheduledDate, DateTime(2025, 11, 10));
        expect(updated.isPostponed, false);
      });
    });
  });
}
