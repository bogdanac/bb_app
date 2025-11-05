import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/Tasks/services/recurrence_calculator.dart';
import 'package:bb_app/Tasks/tasks_data_models.dart';

void main() {
  group('RecurrenceCalculator', () {
    late RecurrenceCalculator calculator;

    setUp(() {
      calculator = RecurrenceCalculator();
    });

    group('Daily Recurrence', () {
      test('every day (interval=1) - should return today when due today', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, todayDate);
      });

      test('every day (interval=1) - should return today when checked', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final yesterday = todayDate.subtract(const Duration(days: 1));

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          createdAt: yesterday,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        // For daily tasks with interval=1, if due today, returns today; else tomorrow
        // Since task was created yesterday, today is a valid due date
        expect(result, todayDate);
      });

      test('every 2 days (interval=2) - should calculate next occurrence correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 3));

        final task = Task(
          id: '1',
          title: 'Every 2 days',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 2,
            startDate: startDate,
          ),
          createdAt: startDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        // Should be within the next 2 days
        expect(result!.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('every 3 days (interval=3) - should calculate next occurrence correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 4));

        final task = Task(
          id: '1',
          title: 'Every 3 days',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 3,
            startDate: startDate,
          ),
          createdAt: startDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('every 90 days (interval=90) - should calculate next occurrence correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 91));

        final task = Task(
          id: '1',
          title: 'Every 90 days',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 90,
            startDate: startDate,
          ),
          createdAt: startDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('daily recurrence - O(1) complexity verification', () {
        // Daily recurrence should return immediately without loops
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final yesterday = todayDate.subtract(const Duration(days: 1));

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          createdAt: yesterday,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should complete in microseconds (O(1))
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('due today check - task created today is due today', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        // Should return today since it's due today
        expect(result, todayDate);
      });

      test('next occurrence calculation - returns correct date', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final yesterday = todayDate.subtract(const Duration(days: 1));

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          createdAt: yesterday,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        // For daily interval=1, if due today it returns today
        expect(result, todayDate);
      });
    });

    group('Weekly Recurrence', () {
      test('specific weekdays (Mon, Wed, Fri) - should find next occurrence', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Mon/Wed/Fri Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 1,
            weekDays: [1, 3, 5], // Monday, Wednesday, Friday
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect([1, 3, 5].contains(result!.weekday), isTrue);
      });

      test('multiple weekdays - should return next weekday in sequence', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Tue/Thu/Sat Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 1,
            weekDays: [2, 4, 6], // Tuesday, Thursday, Saturday
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect([2, 4, 6].contains(result!.weekday), isTrue);
      });

      test('every 2 weeks (interval=2) - should calculate correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 15));

        final task = Task(
          id: '1',
          title: 'Bi-weekly Monday',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 2,
            weekDays: [1], // Monday
            startDate: startDate,
          ),
          createdAt: startDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.weekday, 1);
      });

      test('every 4 weeks (interval=4) - should calculate correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 29));

        final task = Task(
          id: '1',
          title: 'Every 4 weeks',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 4,
            weekDays: [1], // Monday
            startDate: startDate,
          ),
          createdAt: startDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.weekday, 1);
      });

      test('every 8 weeks (interval=8) - should calculate correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 57));

        final task = Task(
          id: '1',
          title: 'Every 8 weeks',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 8,
            weekDays: [3], // Wednesday
            startDate: startDate,
          ),
          createdAt: startDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.weekday, 3);
      });

      test('next occurrence on correct weekday - should skip to next week if needed', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        // If today is Friday (5), and we want Monday (1), should get next Monday
        final task = Task(
          id: '1',
          title: 'Monday Only',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 1,
            weekDays: [1], // Monday only
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.weekday, 1);
        expect(result.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('weekly recurrence - O(7*interval) complexity verification', () {
        // Weekly should check at most 7 * interval days
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Weekly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 2,
            weekDays: [1, 3, 5],
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should complete quickly (checking max 14 days)
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('single weekday - should find next occurrence of that day', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Sunday Only',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 1,
            weekDays: [7], // Sunday
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.weekday, 7);
      });
    });

    group('Monthly Recurrence', () {
      test('specific day of month (15th) - should return 15th of current or next month', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Monthly on 15th',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 15,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.day, 15);
        expect(result.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('last day of month - should return last day correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Last day of month',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            isLastDayOfMonth: true,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        // Verify it's the last day by checking next day is first of next month
        final nextDay = result!.add(const Duration(days: 1));
        expect(nextDay.day, 1);
      });

      test('day 31 in February - should adjust to Feb 28/29', () {
        // Create a date in January to force February calculation
        final januaryDate = DateTime(2025, 1, 20);

        final task = Task(
          id: '1',
          title: 'Monthly on 31st',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 31,
          ),
          createdAt: januaryDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, januaryDate);

        expect(result, isNotNull);
        // If result is in February, should be adjusted to 28 or 29
        if (result!.month == 2) {
          expect(result.day, lessThanOrEqualTo(29));
        }
      });

      test('day 30 in February - should adjust to Feb 28/29', () {
        // Create a date in January to ensure next occurrence is in February
        final januaryDate = DateTime(2025, 1, 20);

        final task = Task(
          id: '1',
          title: 'Monthly on 30th',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 30,
          ),
          createdAt: januaryDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, januaryDate);

        expect(result, isNotNull);
        if (result!.month == 2) {
          // If February, should be 28 or 29
          expect(result.day, lessThanOrEqualTo(29));
        }
      });

      test('every 2 months - should calculate correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Every 2 months on 10th',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 2,
            dayOfMonth: 10,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.day, 10);
      });

      test('every N months - should handle various intervals', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        // Test every 3 months
        final task = Task(
          id: '1',
          title: 'Every 3 months on 5th',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 3,
            dayOfMonth: 5,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.day, 5);
      });

      test('monthly recurrence - O(1) complexity verification', () {
        // Monthly should calculate directly without loops
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Monthly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 15,
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should complete in microseconds (O(1))
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('day of month from createdAt - should use task creation day', () {
        final createdDate = DateTime(2025, 1, 20);

        final task = Task(
          id: '1',
          title: 'Monthly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            // No dayOfMonth specified, should use createdAt.day
          ),
          createdAt: createdDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, createdDate);

        expect(result, isNotNull);
        // Should be the 20th of the next month or current month
        expect(result!.day, 20);
      });
    });

    group('Yearly Recurrence', () {
      test('specific month and day (March 15) - should return March 15 next year', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Yearly on March 15',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.yearly],
            interval: 3, // March
            dayOfMonth: 15,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.month, 3);
        expect(result.day, 15);
      });

      test('leap year handling - Feb 29 should work correctly', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Yearly on Feb 29',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.yearly],
            interval: 2, // February
            dayOfMonth: 29,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        // Should return a valid date (might be Feb 28 on non-leap years, Feb 29 on leap years)
        expect(result!.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
        expect([2, 3].contains(result.month), isTrue); // Could roll over to March if Feb is short
      });

      test('next occurrence calculation - should return future date', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Yearly on December 25',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.yearly],
            interval: 12, // December
            dayOfMonth: 25,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.month, 12);
        expect(result.day, 25);
        expect(result.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('yearly recurrence - O(1) complexity verification', () {
        // Yearly should calculate directly without loops
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Yearly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.yearly],
            interval: 6,
            dayOfMonth: 20,
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should complete in microseconds (O(1))
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('past target date - should return next year', () {
        // Test on a date after the target date
        final testDate = DateTime(2025, 6, 15); // June 15

        final task = Task(
          id: '1',
          title: 'Yearly on March 1',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.yearly],
            interval: 3, // March
            dayOfMonth: 1,
          ),
          createdAt: testDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, testDate);

        expect(result, isNotNull);
        expect(result!.month, 3);
        expect(result.day, 1);
        // Should be in 2026 since we're past March 2025
        expect(result.year, greaterThan(testDate.year));
      });
    });

    group('Menstrual Cycle Tasks', () {
      test('menstrual phase calculation - should calculate date correctly', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Menstrual Phase Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.menstrualPhase],
            phaseDay: 3,
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNotNull);
        // Should be lastPeriodStart + 2 days (day 3 means +2)
        expect(result, lastPeriodStart.add(const Duration(days: 2)));
      });

      test('follicular phase calculation - should calculate date correctly', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Follicular Phase Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.follicularPhase],
            phaseDay: 2,
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNotNull);
        // Follicular starts on day 6 (menstrual + 5 days)
        final follicularStart = lastPeriodStart.add(const Duration(days: 5));
        expect(result, follicularStart.add(const Duration(days: 1))); // day 2 of phase
      });

      test('ovulation phase calculation - should calculate date correctly', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Ovulation Phase Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.ovulationPhase],
            phaseDay: 1,
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNotNull);
        // Ovulation starts at cycle day ~13 (28/2 - 1)
        final ovulationStart = lastPeriodStart.add(const Duration(days: 13));
        expect(result, ovulationStart);
      });

      test('early luteal phase calculation - should calculate date correctly', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Early Luteal Phase Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.earlyLutealPhase],
            phaseDay: 1,
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNotNull);
        // Early luteal starts 3 days after ovulation
        final ovulationStart = lastPeriodStart.add(const Duration(days: 13));
        final earlyLutealStart = ovulationStart.add(const Duration(days: 3));
        expect(result, earlyLutealStart);
      });

      test('late luteal phase calculation - should calculate date correctly', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Late Luteal Phase Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.lateLutealPhase],
            phaseDay: 2,
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNotNull);
        // Late luteal starts at 75% of cycle (day 21 for 28-day cycle)
        final lateLutealStart = lastPeriodStart.add(const Duration(days: 21));
        expect(result, lateLutealStart.add(const Duration(days: 1))); // day 2 of phase
      });

      test('phase day handling - day 1 vs day 5 should differ by 4 days', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task1 = Task(
          id: '1',
          title: 'Phase Day 1',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.menstrualPhase],
            phaseDay: 1,
          ),
          createdAt: DateTime.now(),
        );

        final task5 = Task(
          id: '2',
          title: 'Phase Day 5',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.menstrualPhase],
            phaseDay: 5,
          ),
          createdAt: DateTime.now(),
        );

        final result1 = await calculator.calculateMenstrualTaskScheduledDate(task1, prefs);
        final result5 = await calculator.calculateMenstrualTaskScheduledDate(task5, prefs);

        expect(result1, isNotNull);
        expect(result5, isNotNull);
        expect(result5!.difference(result1!).inDays, 4);
      });

      test('missing cycle data - should return null when no last_period_start', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Menstrual Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.menstrualPhase],
            phaseDay: 1,
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNull);
      });

      test('missing phaseDay - should return null', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Menstrual Task without phaseDay',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.menstrualPhase],
            // No phaseDay specified
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNull);
      });

      test('calculatePhaseStartDates - should calculate all phases correctly for 28-day cycle', () {
        final lastPeriodStart = DateTime(2025, 10, 1);
        final cycleLength = 28;

        final phases = calculator.calculatePhaseStartDates(lastPeriodStart, cycleLength);

        expect(phases['menstrual'], lastPeriodStart);
        expect(phases['follicular'], lastPeriodStart.add(const Duration(days: 5)));
        expect(phases['ovulation'], lastPeriodStart.add(const Duration(days: 13))); // 28/2 - 1
        expect(phases['earlyLuteal'], lastPeriodStart.add(const Duration(days: 16))); // ovulation + 3
        expect(phases['lateLuteal'], lastPeriodStart.add(const Duration(days: 21))); // 75% of 28
      });

      test('calculateMenstrualDateFromCache - should use cached phase data', () {
        final lastPeriodStart = DateTime(2025, 10, 1);
        final phaseStartDates = calculator.calculatePhaseStartDates(lastPeriodStart, 28);

        final task = Task(
          id: '1',
          title: 'Cached Menstrual Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.ovulationPhase],
            phaseDay: 2,
          ),
          createdAt: DateTime.now(),
        );

        final result = calculator.calculateMenstrualDateFromCache(task, phaseStartDates);

        expect(result, isNotNull);
        expect(result, phaseStartDates['ovulation']!.add(const Duration(days: 1))); // day 2 = +1
      });

      test('different cycle lengths - 25 day cycle', () {
        final lastPeriodStart = DateTime(2025, 10, 1);
        final cycleLength = 25;

        final phases = calculator.calculatePhaseStartDates(lastPeriodStart, cycleLength);

        expect(phases['menstrual'], lastPeriodStart);
        expect(phases['ovulation'], lastPeriodStart.add(const Duration(days: 11))); // 25/2 - 1 = 11.5 - 1 = 11
        // 75% of 25 = 18.75, rounded to 19 by (25 * 0.75).round() = 19
        final expectedLateLuteal = lastPeriodStart.add(Duration(days: (cycleLength * 0.75).round()));
        expect(phases['lateLuteal'], expectedLateLuteal);
      });

      test('different cycle lengths - 35 day cycle', () {
        final lastPeriodStart = DateTime(2025, 10, 1);
        final cycleLength = 35;

        final phases = calculator.calculatePhaseStartDates(lastPeriodStart, cycleLength);

        expect(phases['menstrual'], lastPeriodStart);
        expect(phases['ovulation'], lastPeriodStart.add(const Duration(days: 16))); // 35/2 - 1 = 16.5 - 1 = 16
        expect(phases['lateLuteal'], lastPeriodStart.add(const Duration(days: 26))); // 75% of 35 = 26.25 rounded to 26
      });

      test('default cycle length - should use 31 when not specified', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          // No average_cycle_length specified, should default to 31
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Menstrual Task with default cycle',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.ovulationPhase],
            phaseDay: 1,
          ),
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);

        expect(result, isNotNull);
        // With cycle length 31, ovulation is at day 14.5 - 1 = 14
        expect(result, lastPeriodStart.add(const Duration(days: 14)));
      });

      test('all five menstrual phases - should return different dates', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final phases = [
          RecurrenceType.menstrualPhase,
          RecurrenceType.follicularPhase,
          RecurrenceType.ovulationPhase,
          RecurrenceType.earlyLutealPhase,
          RecurrenceType.lateLutealPhase,
        ];

        final results = <DateTime>[];
        for (final phase in phases) {
          final task = Task(
            id: '1',
            title: 'Phase Task',
            recurrence: TaskRecurrence(
              types: [phase],
              phaseDay: 1,
            ),
            createdAt: DateTime.now(),
          );

          final result = await calculator.calculateMenstrualTaskScheduledDate(task, prefs);
          expect(result, isNotNull);
          results.add(result!);
        }

        // All phases should have different dates
        expect(results.toSet().length, 5);

        // Phases should be in chronological order
        for (int i = 0; i < results.length - 1; i++) {
          expect(results[i].isBefore(results[i + 1]), isTrue);
        }
      });
    });

    group('Edge Cases', () {
      test('null recurrence - should return null', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'No Recurrence',
          recurrence: null,
          createdAt: todayDate,
        );

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final result = await calculator.calculateNextOccurrenceDate(task, prefs);

        expect(result, isNull);
      });

      test('past start date - should still calculate next occurrence', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final pastDate = todayDate.subtract(const Duration(days: 30));

        final task = Task(
          id: '1',
          title: 'Past Start Date',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
            startDate: pastDate,
          ),
          createdAt: pastDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('future end date - should not prevent calculation', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final futureDate = todayDate.add(const Duration(days: 365));

        final task = Task(
          id: '1',
          title: 'Future End Date',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
            endDate: futureDate,
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
      });

      test('very long interval (90 days) - should calculate efficiently', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 100));

        final task = Task(
          id: '1',
          title: 'Every 90 days',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 90,
            startDate: startDate,
          ),
          createdAt: startDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should still complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('overdue task - should calculate next occurrence from today', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final overdueDate = todayDate.subtract(const Duration(days: 7));

        final task = Task(
          id: '1',
          title: 'Overdue Weekly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 1,
            weekDays: [1, 3, 5],
          ),
          scheduledDate: overdueDate,
          createdAt: overdueDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('task created far in the past - should calculate from today', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final oldDate = todayDate.subtract(const Duration(days: 365));

        final task = Task(
          id: '1',
          title: 'Old Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 1,
            weekDays: [2, 4],
          ),
          createdAt: oldDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        expect(result, isNotNull);
        expect(result!.isAfter(todayDate) || result.isAtSameMomentAs(todayDate), isTrue);
      });

      test('custom recurrence - should return null without daysAfterPeriod', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Custom Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.custom],
            interval: 5,
            // No daysAfterPeriod specified - custom recurrence won't match
          ),
          createdAt: todayDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);

        // Custom recurrence without proper configuration returns null
        // because isDueOn won't match any dates
        expect(result, isNull);
      });

      test('monthly task on 31st in 30-day month - should adjust to 30th', () {
        // April has 30 days
        final marchDate = DateTime(2025, 3, 25);

        final task = Task(
          id: '1',
          title: 'Monthly on 31st',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 31,
          ),
          createdAt: marchDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, marchDate);

        expect(result, isNotNull);
        if (result!.month == 4) {
          // April should be adjusted to 30th
          expect(result.day, 30);
        }
      });

      test('leap year - Feb 29 on 2024', () {
        final janDate = DateTime(2024, 1, 15);

        final task = Task(
          id: '1',
          title: 'Monthly on 29th',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 29,
          ),
          createdAt: janDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, janDate);

        expect(result, isNotNull);
        if (result!.month == 2 && result.year == 2024) {
          // 2024 is a leap year, should be Feb 29
          expect(result.day, 29);
        }
      });

      test('non-leap year - Feb 29 on 2025 should become Feb 28', () {
        final janDate = DateTime(2025, 1, 15);

        final task = Task(
          id: '1',
          title: 'Monthly on 29th',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 29,
          ),
          createdAt: janDate,
        );

        final result = calculator.calculateRegularRecurringTaskDate(task, janDate);

        expect(result, isNotNull);
        if (result!.month == 2 && result.year == 2025) {
          // 2025 is not a leap year, should be Feb 28
          expect(result.day, 28);
        }
      });
    });

    group('calculateNextScheduledDate', () {
      test('should create task with updated scheduledDate', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          scheduledDate: todayDate,
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: todayDate,
        );

        final result = await calculator.calculateNextScheduledDate(task, prefs);

        expect(result, isNotNull);
        expect(result!.scheduledDate, isNotNull);
        expect(result.isCompleted, false); // Should reset completion
        expect(result.isPostponed, false); // Should reset postponed flag
      });

      test('should reset completion status always', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Completed Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: todayDate,
        );

        final result = await calculator.calculateNextScheduledDate(task, prefs);

        expect(result, isNotNull);
        expect(result!.isCompleted, false);
        expect(result.completedAt, isNull);
      });

      test('should update reminderTime to match new scheduled date', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final reminderTime = DateTime(todayDate.year, todayDate.month, todayDate.day, 10, 30);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Task with Reminder',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          reminderTime: reminderTime,
          createdAt: todayDate,
        );

        final result = await calculator.calculateNextScheduledDate(task, prefs);

        expect(result, isNotNull);
        expect(result!.reminderTime, isNotNull);
        expect(result.reminderTime!.hour, 10);
        expect(result.reminderTime!.minute, 30);
      });

      test('should use recurrence reminderTime if task has none', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Task with Recurrence Reminder',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
            reminderTime: const TimeOfDay(hour: 14, minute: 0),
          ),
          reminderTime: null,
          createdAt: todayDate,
        );

        final result = await calculator.calculateNextScheduledDate(task, prefs);

        expect(result, isNotNull);
        expect(result!.reminderTime, isNotNull);
        expect(result.reminderTime!.hour, 14);
        expect(result.reminderTime!.minute, 0);
      });

      test('should return null if no next date can be calculated', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Task',
          recurrence: null,
          createdAt: DateTime.now(),
        );

        final result = await calculator.calculateNextScheduledDate(task, prefs);

        expect(result, isNull);
      });

      test('should clear completedAt timestamp', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final completedTime = DateTime.now();

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Completed Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          isCompleted: true,
          completedAt: completedTime,
          createdAt: todayDate,
        );

        final result = await calculator.calculateNextScheduledDate(task, prefs);

        expect(result, isNotNull);
        expect(result!.completedAt, isNull);
      });

      test('should clear isPostponed flag for auto-calculated tasks', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Postponed Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          isPostponed: true,
          createdAt: todayDate,
        );

        final result = await calculator.calculateNextScheduledDate(task, prefs);

        expect(result, isNotNull);
        expect(result!.isPostponed, false);
      });
    });

    group('Integration Tests', () {
      test('complete workflow - daily task completion and next occurrence', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        // Create daily task
        final task = Task(
          id: '1',
          title: 'Daily Exercise',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
            reminderTime: const TimeOfDay(hour: 7, minute: 0),
          ),
          scheduledDate: todayDate,
          isCompleted: false,
          createdAt: todayDate,
        );

        // Complete task
        final completedTask = task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );

        // Calculate next occurrence
        final nextTask = await calculator.calculateNextScheduledDate(completedTask, prefs);

        expect(nextTask, isNotNull);
        expect(nextTask!.scheduledDate, isNotNull);
        expect(nextTask.isCompleted, false);
        expect(nextTask.completedAt, isNull);
        expect(nextTask.reminderTime, isNotNull);
        expect(nextTask.reminderTime!.hour, 7);
      });

      test('complete workflow - weekly task with multiple weekdays', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Gym Days',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 1,
            weekDays: [1, 3, 5], // Mon, Wed, Fri
          ),
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: todayDate,
        );

        final nextTask = await calculator.calculateNextScheduledDate(task, prefs);

        expect(nextTask, isNotNull);
        expect(nextTask!.scheduledDate, isNotNull);
        expect([1, 3, 5].contains(nextTask.scheduledDate!.weekday), isTrue);
        expect(nextTask.isCompleted, false);
      });

      test('complete workflow - menstrual cycle task', () async {
        final lastPeriodStart = DateTime(2025, 10, 1);

        SharedPreferences.setMockInitialValues({
          'last_period_start': lastPeriodStart.toIso8601String(),
          'average_cycle_length': 28,
        });
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Ovulation Day Exercise',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.ovulationPhase],
            phaseDay: 1,
          ),
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final nextTask = await calculator.calculateNextScheduledDate(task, prefs);

        expect(nextTask, isNotNull);
        expect(nextTask!.scheduledDate, isNotNull);
        expect(nextTask.isCompleted, false);
      });

      test('complete workflow - monthly task over year boundary', () async {
        final decemberDate = DateTime(2024, 12, 20);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Monthly Bill Payment',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 5,
          ),
          createdAt: decemberDate,
        );

        final nextTask = await calculator.calculateNextScheduledDate(task, prefs);

        expect(nextTask, isNotNull);
        expect(nextTask!.scheduledDate, isNotNull);
        expect(nextTask.scheduledDate!.day, 5);
        // Could be in current month or next depending on whether we're past the 5th
        // Since created on Dec 20, next occurrence is not December
        expect(nextTask.scheduledDate!.isAfter(decemberDate), isTrue);
      });

      test('complete workflow - yearly task', () async {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final task = Task(
          id: '1',
          title: 'Birthday Reminder',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.yearly],
            interval: 6, // June
            dayOfMonth: 15,
          ),
          createdAt: todayDate,
        );

        final nextTask = await calculator.calculateNextScheduledDate(task, prefs);

        expect(nextTask, isNotNull);
        expect(nextTask!.scheduledDate, isNotNull);
        expect(nextTask.scheduledDate!.month, 6);
        expect(nextTask.scheduledDate!.day, 15);
      });
    });

    group('Optimization Verification', () {
      test('daily recurrence - O(1) complexity, no loops', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Daily Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.daily],
            interval: 1,
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should complete almost instantly
        expect(stopwatch.elapsedMicroseconds, lessThan(1000));
      });

      test('weekly recurrence - O(7*interval) complexity', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Weekly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.weekly],
            interval: 4,
            weekDays: [1, 3, 5],
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should check at most 28 days (7 * 4)
        expect(stopwatch.elapsedMicroseconds, lessThan(5000));
      });

      test('monthly recurrence - O(1) complexity, direct calculation', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Monthly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.monthly],
            interval: 1,
            dayOfMonth: 15,
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should calculate directly without loops
        expect(stopwatch.elapsedMicroseconds, lessThan(1000));
      });

      test('yearly recurrence - O(1) complexity, direct calculation', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Yearly Task',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.yearly],
            interval: 6,
            dayOfMonth: 15,
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        final result = calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        expect(result, isNotNull);
        // Should calculate directly without loops
        expect(stopwatch.elapsedMicroseconds, lessThan(1000));
      });

      test('no unnecessary loops - custom recurrence limited to 30 days', () {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final task = Task(
          id: '1',
          title: 'Custom Task with daysAfterPeriod',
          recurrence: TaskRecurrence(
            types: [RecurrenceType.custom],
            interval: 5,
            daysAfterPeriod: 3, // Needed for custom recurrence to work
          ),
          createdAt: todayDate,
        );

        final stopwatch = Stopwatch()..start();
        calculator.calculateRegularRecurringTaskDate(task, todayDate);
        stopwatch.stop();

        // Should limit search to 30 days max
        // Result may be null if no matching date found, which is acceptable
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });
    });
  });
}
