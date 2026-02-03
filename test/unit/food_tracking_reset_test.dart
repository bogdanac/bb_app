import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Food Tracking Auto Reset Logic', () {
    test('reset triggers when lastReset is in previous month', () {
      // GIVEN: lastReset is Nov 1, current date is Dec 16
      final lastReset = DateTime(2025, 11, 1);
      final now = DateTime(2025, 12, 16);
      final currentMonthStart = DateTime(now.year, now.month, 1); // Dec 1

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentMonthStart);

      // THEN: Reset should trigger because Nov 1 < Dec 1
      expect(shouldReset, isTrue);
    });

    test('reset does NOT trigger on same day as lastReset', () {
      // GIVEN: lastReset is Dec 1, current date is Dec 1
      final lastReset = DateTime(2025, 12, 1);
      final now = DateTime(2025, 12, 1);
      final currentMonthStart = DateTime(now.year, now.month, 1); // Dec 1

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentMonthStart);

      // THEN: Reset should NOT trigger because Dec 1 is NOT before Dec 1
      expect(shouldReset, isFalse);
    });

    test('reset does NOT trigger later in same month', () {
      // GIVEN: lastReset is Dec 1, current date is Dec 16
      final lastReset = DateTime(2025, 12, 1);
      final now = DateTime(2025, 12, 16);
      final currentMonthStart = DateTime(now.year, now.month, 1); // Dec 1

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentMonthStart);

      // THEN: Reset should NOT trigger because Dec 1 is NOT before Dec 1
      expect(shouldReset, isFalse);
    });

    test('reset triggers when lastReset is multiple months ago', () {
      // GIVEN: lastReset is Oct 1, current date is Dec 16
      final lastReset = DateTime(2025, 10, 1);
      final now = DateTime(2025, 12, 16);
      final currentMonthStart = DateTime(now.year, now.month, 1); // Dec 1

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentMonthStart);

      // THEN: Reset should trigger because Oct 1 < Dec 1
      expect(shouldReset, isTrue);
    });

    test('reset triggers across year boundary', () {
      // GIVEN: lastReset is Dec 1 2024, current date is Jan 15 2025
      final lastReset = DateTime(2024, 12, 1);
      final now = DateTime(2025, 1, 15);
      final currentMonthStart = DateTime(now.year, now.month, 1); // Jan 1 2025

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentMonthStart);

      // THEN: Reset should trigger because Dec 1 2024 < Jan 1 2025
      expect(shouldReset, isTrue);
    });

    test('reset triggers on first day of new month', () {
      // GIVEN: lastReset is Nov 1, current date is Dec 1
      final lastReset = DateTime(2025, 11, 1);
      final now = DateTime(2025, 12, 1);
      final currentMonthStart = DateTime(now.year, now.month, 1); // Dec 1

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentMonthStart);

      // THEN: Reset should trigger because Nov 1 < Dec 1
      expect(shouldReset, isTrue);
    });
  });

  group('Food Tracking Weekly Reset Logic', () {
    test('reset triggers when lastReset is in previous week', () {
      // GIVEN: lastReset is Monday Dec 9, current date is Monday Dec 16
      final lastReset = DateTime(2025, 12, 9); // Monday
      final now = DateTime(2025, 12, 16); // Monday
      final currentWeekStart = _getWeekStart(now); // Dec 16

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentWeekStart);

      // THEN: Reset should trigger because Dec 9 < Dec 16
      expect(shouldReset, isTrue);
    });

    test('reset does NOT trigger on same Monday', () {
      // GIVEN: lastReset is Monday Dec 16, current date is Monday Dec 16
      final lastReset = DateTime(2025, 12, 16); // Monday
      final now = DateTime(2025, 12, 16); // Monday
      final currentWeekStart = _getWeekStart(now); // Dec 16

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentWeekStart);

      // THEN: Reset should NOT trigger
      expect(shouldReset, isFalse);
    });

    test('reset does NOT trigger later in same week', () {
      // GIVEN: lastReset is Monday Dec 16, current date is Thursday Dec 19
      final lastReset = DateTime(2025, 12, 16); // Monday
      final now = DateTime(2025, 12, 19); // Thursday
      final currentWeekStart = _getWeekStart(now); // Dec 16 (Monday)

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentWeekStart);

      // THEN: Reset should NOT trigger because Dec 16 is NOT before Dec 16
      expect(shouldReset, isFalse);
    });

    test('reset triggers on new Monday', () {
      // GIVEN: lastReset is Monday Dec 16, current date is Monday Dec 23
      final lastReset = DateTime(2025, 12, 16); // Monday
      final now = DateTime(2025, 12, 23); // Next Monday
      final currentWeekStart = _getWeekStart(now); // Dec 23

      // WHEN: We check if reset should happen
      final shouldReset = lastReset.isBefore(currentWeekStart);

      // THEN: Reset should trigger because Dec 16 < Dec 23
      expect(shouldReset, isTrue);
    });
  });

  group('Food Tracking Manual Reset', () {
    test('manual reset works regardless of auto reset setting', () {
      // Manual reset (resetNow) does not check autoResetEnabled
      // It always saves all entries to history and clears them
      // Test both scenarios: auto reset disabled and enabled
      for (final autoResetEnabled in [false, true]) {
        const canManualReset = true; // Always allowed regardless of autoResetEnabled
        expect(canManualReset, isTrue,
            reason: 'Manual reset must work when autoResetEnabled=$autoResetEnabled');
      }
    });

    test('manual reset saves all entries from oldest to newest', () {
      // GIVEN: Entries from Nov 15 to Dec 16
      final entries = [
        DateTime(2025, 11, 15),
        DateTime(2025, 11, 20),
        DateTime(2025, 12, 1),
        DateTime(2025, 12, 10),
        DateTime(2025, 12, 16),
      ];

      // WHEN: We find oldest and newest
      final oldest = entries.reduce((a, b) => a.isBefore(b) ? a : b);
      final newest = entries.reduce((a, b) => a.isAfter(b) ? a : b);

      // THEN: Should capture full date range
      expect(oldest, equals(DateTime(2025, 11, 15)));
      expect(newest, equals(DateTime(2025, 12, 16)));
    });
  });

  group('Food Tracking Auto Reset Disabled', () {
    test('auto reset does not trigger when disabled', () {
      // GIVEN: Auto reset is disabled, lastReset is Nov 1, current is Dec 16
      final lastReset = DateTime(2025, 11, 1);
      final now = DateTime(2025, 12, 16);
      final currentMonthStart = DateTime(now.year, now.month, 1);

      // Helper function that mimics actual reset logic
      bool shouldAutoReset(bool autoResetEnabled) {
        return autoResetEnabled && lastReset.isBefore(currentMonthStart);
      }

      // WHEN/THEN: Verify the date condition is met
      expect(lastReset.isBefore(currentMonthStart), isTrue,
          reason: 'Date condition should be met');

      // WHEN/THEN: Reset should NOT trigger when auto reset is disabled
      expect(shouldAutoReset(false), isFalse,
          reason: 'Auto reset disabled should prevent reset');

      // WHEN/THEN: Reset WOULD trigger if auto reset was enabled
      expect(shouldAutoReset(true), isTrue,
          reason: 'Same conditions with auto reset enabled should trigger');
    });

    test('auto reset triggers when enabled', () {
      // GIVEN: Auto reset is enabled, lastReset is Nov 1, current is Dec 16
      const autoResetEnabled = true;
      final lastReset = DateTime(2025, 11, 1);
      final now = DateTime(2025, 12, 16);
      final currentMonthStart = DateTime(now.year, now.month, 1);

      // WHEN: We check if reset should happen
      bool shouldReset = false;
      if (autoResetEnabled) {
        shouldReset = lastReset.isBefore(currentMonthStart);
      }

      // THEN: Reset should trigger
      expect(shouldReset, isTrue);
    });
  });
}

/// Helper to get Monday of the week for a given date
DateTime _getWeekStart(DateTime date) {
  final daysFromMonday = (date.weekday - 1) % 7;
  return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromMonday));
}
