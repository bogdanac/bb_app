import 'package:bb_app/Tasks/tasks_data_models.dart';
import 'package:bb_app/Tasks/services/task_priority_service.dart';
import 'package:flutter/material.dart';

void main() {
  final service = TaskPriorityService();
  final categories = [
    TaskCategory(id: '1', name: 'Work', color: Colors.blue, order: 0),
    TaskCategory(id: '2', name: 'Personal', color: Colors.green, order: 1),
  ];
  final now = DateTime(2025, 11, 10, 14, 0);
  final today = DateTime(now.year, now.month, now.day);

  final task1 = Task(
    id: 'overdue_recurring_1',
    title: 'Overdue Recurring 1 Day',
    recurrence: TaskRecurrence(type: RecurrenceType.daily),
    scheduledDate: DateTime(2025, 11, 9),
    isPostponed: false,
    createdAt: DateTime(2025, 11, 1),
  );

  final task2 = Task(
    id: 'overdue_recurring_2',
    title: 'Overdue Recurring 2 Days',
    recurrence: TaskRecurrence(type: RecurrenceType.weekly, weekDays: [DateTime.saturday]),
    scheduledDate: DateTime(2025, 11, 8),
    isPostponed: false,
    createdAt: DateTime(2025, 11, 1),
  );

  final task3 = Task(
    id: 'recurring_today',
    title: 'Recurring Due Today',
    recurrence: TaskRecurrence(type: RecurrenceType.daily),
    scheduledDate: today,
    createdAt: DateTime(2025, 11, 1),
  );

  print('Task 1 (overdue 1 day) score: ${service.calculateTaskPriorityScore(task1, now, today, categories)}');
  print('Task 2 (overdue 2 days) score: ${service.calculateTaskPriorityScore(task2, now, today, categories)}');
  print('Task 3 (due today) score: ${service.calculateTaskPriorityScore(task3, now, today, categories)}');
  print('Task 3 isDueToday: ${task3.isDueToday()}');
}
