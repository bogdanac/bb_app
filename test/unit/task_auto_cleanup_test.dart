import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

void main() {
  group('Auto-Cleanup of Old Completed Tasks', () {
    late DateTime now;
    late DateTime today;
    late DateTime thirtyDaysAgo;
    late DateTime thirtyOneDaysAgo;
    late DateTime twentyNineDaysAgo;

    setUp(() {
      now = DateTime.now();
      today = DateTime(now.year, now.month, now.day);
      thirtyDaysAgo = today.subtract(const Duration(days: 30));
      thirtyOneDaysAgo = today.subtract(const Duration(days: 31));
      twentyNineDaysAgo = today.subtract(const Duration(days: 29));
    });

    test('completed task older than 30 days should be deleted', () {
      final oldTask = Task(
        id: '1',
        title: 'Old Completed Task',
        isCompleted: true,
        completedAt: thirtyOneDaysAgo, // 31 days ago
        createdAt: DateTime(2025, 10, 1),
      );

      final shouldDelete = oldTask.isCompleted &&
          oldTask.completedAt != null &&
          oldTask.completedAt!.isBefore(thirtyDaysAgo);

      expect(shouldDelete, isTrue,
          reason: 'Tasks completed more than 30 days ago should be deleted');
    });

    test('completed task exactly 30 days old should NOT be deleted', () {
      final taskAtBoundary = Task(
        id: '2',
        title: 'Task Exactly 30 Days Old',
        isCompleted: true,
        completedAt: thirtyDaysAgo, // Exactly 30 days ago
        createdAt: DateTime(2025, 10, 1),
      );

      final shouldDelete = taskAtBoundary.isCompleted &&
          taskAtBoundary.completedAt != null &&
          taskAtBoundary.completedAt!.isBefore(thirtyDaysAgo);

      expect(shouldDelete, isFalse,
          reason: 'Tasks completed exactly 30 days ago should be kept (not before)');
    });

    test('completed task less than 30 days old should NOT be deleted', () {
      final recentTask = Task(
        id: '3',
        title: 'Recent Completed Task',
        isCompleted: true,
        completedAt: twentyNineDaysAgo, // 29 days ago
        createdAt: DateTime(2025, 10, 1),
      );

      final shouldDelete = recentTask.isCompleted &&
          recentTask.completedAt != null &&
          recentTask.completedAt!.isBefore(thirtyDaysAgo);

      expect(shouldDelete, isFalse,
          reason: 'Tasks completed less than 30 days ago should be kept');
    });

    test('incomplete task should NEVER be deleted regardless of age', () {
      final oldIncompleteTask = Task(
        id: '4',
        title: 'Old Incomplete Task',
        isCompleted: false,
        createdAt: DateTime(2024, 1, 1), // Very old
      );

      final shouldDelete = oldIncompleteTask.isCompleted &&
          oldIncompleteTask.completedAt != null &&
          oldIncompleteTask.completedAt!.isBefore(thirtyDaysAgo);

      expect(shouldDelete, isFalse,
          reason: 'Incomplete tasks should never be deleted');
    });

    test('completed task without completedAt should NOT be deleted', () {
      final taskWithoutCompletedAt = Task(
        id: '5',
        title: 'Completed Task Without Timestamp',
        isCompleted: true,
        completedAt: null, // No completion timestamp
        createdAt: DateTime(2024, 1, 1),
      );

      final shouldDelete = taskWithoutCompletedAt.isCompleted &&
          taskWithoutCompletedAt.completedAt != null &&
          taskWithoutCompletedAt.completedAt!.isBefore(thirtyDaysAgo);

      expect(shouldDelete, isFalse,
          reason: 'Completed tasks without completedAt timestamp should be kept (safety)');
    });

    test('completed task from today should NOT be deleted', () {
      final todayTask = Task(
        id: '6',
        title: 'Task Completed Today',
        isCompleted: true,
        completedAt: now,
        createdAt: now,
      );

      final shouldDelete = todayTask.isCompleted &&
          todayTask.completedAt != null &&
          todayTask.completedAt!.isBefore(thirtyDaysAgo);

      expect(shouldDelete, isFalse,
          reason: 'Tasks completed today should not be deleted');
    });

    group('Bulk Deletion Scenarios', () {
      test('filter keeps recent completed and all incomplete tasks', () {
        final tasks = [
          Task(
            id: '1',
            title: 'Old Completed 1',
            isCompleted: true,
            completedAt: thirtyOneDaysAgo,
            createdAt: DateTime(2025, 10, 1),
          ),
          Task(
            id: '2',
            title: 'Old Completed 2',
            isCompleted: true,
            completedAt: DateTime(2025, 9, 1), // Very old
            createdAt: DateTime(2025, 9, 1),
          ),
          Task(
            id: '3',
            title: 'Recent Completed',
            isCompleted: true,
            completedAt: twentyNineDaysAgo,
            createdAt: DateTime(2025, 10, 1),
          ),
          Task(
            id: '4',
            title: 'Incomplete Task',
            isCompleted: false,
            createdAt: DateTime(2024, 1, 1), // Very old but incomplete
          ),
          Task(
            id: '5',
            title: 'Today Completed',
            isCompleted: true,
            completedAt: now,
            createdAt: now,
          ),
        ];

        // Simulate the cleanup filter
        final tasksBeforeCleanup = tasks.length;
        final remainingTasks = tasks.where((task) {
          return !(task.isCompleted &&
              task.completedAt != null &&
              task.completedAt!.isBefore(thirtyDaysAgo));
        }).toList();

        expect(tasksBeforeCleanup, equals(5));
        expect(remainingTasks.length, equals(3),
            reason: 'Should keep: Recent Completed, Incomplete, Today Completed');

        // Verify which tasks remain
        expect(remainingTasks.any((t) => t.id == '1'), isFalse,
            reason: 'Old Completed 1 should be deleted');
        expect(remainingTasks.any((t) => t.id == '2'), isFalse,
            reason: 'Old Completed 2 should be deleted');
        expect(remainingTasks.any((t) => t.id == '3'), isTrue,
            reason: 'Recent Completed should be kept');
        expect(remainingTasks.any((t) => t.id == '4'), isTrue,
            reason: 'Incomplete Task should be kept');
        expect(remainingTasks.any((t) => t.id == '5'), isTrue,
            reason: 'Today Completed should be kept');
      });

      test('count deleted tasks correctly', () {
        final tasks = List.generate(10, (i) {
          return Task(
            id: '$i',
            title: 'Task $i',
            isCompleted: i < 7, // First 7 are completed
            completedAt: i < 7
                ? (i < 5
                    ? thirtyOneDaysAgo // First 5 are old
                    : twentyNineDaysAgo) // Next 2 are recent
                : null,
            createdAt: DateTime(2025, 10, 1),
          );
        });

        final tasksBeforeCleanup = tasks.length;
        final remainingTasks = tasks.where((task) {
          return !(task.isCompleted &&
              task.completedAt != null &&
              task.completedAt!.isBefore(thirtyDaysAgo));
        }).toList();

        final deletedCount = tasksBeforeCleanup - remainingTasks.length;

        expect(tasksBeforeCleanup, equals(10));
        expect(deletedCount, equals(5),
            reason: 'Should delete 5 old completed tasks');
        expect(remainingTasks.length, equals(5),
            reason: 'Should keep 2 recent completed + 3 incomplete');
      });
    });

    group('Edge Cases', () {
      test('empty task list should not crash', () {
        final tasks = <Task>[];
        final tasksBeforeCleanup = tasks.length;

        tasks.removeWhere((task) {
          return task.isCompleted &&
              task.completedAt != null &&
              task.completedAt!.isBefore(thirtyDaysAgo);
        });

        expect(tasks.length, equals(0));
        expect(tasksBeforeCleanup, equals(0));
      });

      test('task list with only incomplete tasks should not delete any', () {
        final tasks = List.generate(5, (i) {
          return Task(
            id: '$i',
            title: 'Incomplete Task $i',
            isCompleted: false,
            createdAt: DateTime(2020, 1, 1), // Very old
          );
        });

        final tasksBeforeCleanup = tasks.length;
        tasks.removeWhere((task) {
          return task.isCompleted &&
              task.completedAt != null &&
              task.completedAt!.isBefore(thirtyDaysAgo);
        });

        expect(tasks.length, equals(tasksBeforeCleanup),
            reason: 'No incomplete tasks should be deleted');
      });

      test('task completed in future should not be deleted', () {
        final futureTask = Task(
          id: '1',
          title: 'Future Completed Task',
          isCompleted: true,
          completedAt: today.add(const Duration(days: 1)), // Tomorrow
          createdAt: now,
        );

        final shouldDelete = futureTask.isCompleted &&
            futureTask.completedAt != null &&
            futureTask.completedAt!.isBefore(thirtyDaysAgo);

        expect(shouldDelete, isFalse,
            reason: 'Future completion dates should not be deleted');
      });
    });
  });
}
