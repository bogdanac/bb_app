import 'package:flutter_test/flutter_test.dart';
import 'package:bb_app/Energy/flow_calculator.dart';

void main() {
  group('Streak Skip Logic', () {
    group('canUseStreakSkip', () {
      test('returns true if never used a skip before', () {
        final result = FlowCalculator.canUseStreakSkip(
          lastSkipDate: null,
          lastStreakDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result, true);
      });

      test('returns false if skip was used yesterday (no consecutive skips)', () {
        final result = FlowCalculator.canUseStreakSkip(
          lastSkipDate: DateTime(2025, 1, 14), // yesterday
          lastStreakDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result, false);
      });

      test('returns false if skip was used 3 days ago (within 7 days)', () {
        final result = FlowCalculator.canUseStreakSkip(
          lastSkipDate: DateTime(2025, 1, 12), // 3 days ago
          lastStreakDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result, false);
      });

      test('returns true if skip was used exactly 7 days ago (7 days cooldown passed)', () {
        final result = FlowCalculator.canUseStreakSkip(
          lastSkipDate: DateTime(2025, 1, 8), // exactly 7 days ago
          lastStreakDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result, true); // 7 days have passed, skip available again
      });

      test('returns false if skip was used 6 days ago (within 7 day cooldown)', () {
        final result = FlowCalculator.canUseStreakSkip(
          lastSkipDate: DateTime(2025, 1, 9), // 6 days ago
          lastStreakDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result, false);
      });

      test('returns true if skip was used 8 days ago (more than 7 days)', () {
        final result = FlowCalculator.canUseStreakSkip(
          lastSkipDate: DateTime(2025, 1, 7), // 8 days ago
          lastStreakDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result, true);
      });

      test('returns true if skip was used 30 days ago', () {
        final result = FlowCalculator.canUseStreakSkip(
          lastSkipDate: DateTime(2024, 12, 16), // 30 days ago
          lastStreakDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result, true);
      });
    });

    group('calculateStreakAtDayEnd', () {
      test('streak continues if goal was met', () {
        final result = FlowCalculator.calculateStreakAtDayEnd(
          goalMetToday: true,
          currentStreak: 5,
          lastSkipDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result.newStreak, 5);
        expect(result.skipUsed, false);
        expect(result.streakBroken, false);
      });

      test('uses skip if goal not met and skip available', () {
        final result = FlowCalculator.calculateStreakAtDayEnd(
          goalMetToday: false,
          currentStreak: 5,
          lastSkipDate: null, // never used, so available
          today: DateTime(2025, 1, 15),
        );
        expect(result.newStreak, 5); // streak preserved
        expect(result.skipUsed, true);
        expect(result.streakBroken, false);
      });

      test('streak breaks if goal not met and no skip available (used recently)', () {
        final result = FlowCalculator.calculateStreakAtDayEnd(
          goalMetToday: false,
          currentStreak: 5,
          lastSkipDate: DateTime(2025, 1, 12), // 3 days ago, not available
          today: DateTime(2025, 1, 15),
        );
        expect(result.newStreak, 0); // streak broken
        expect(result.skipUsed, false);
        expect(result.streakBroken, true);
      });

      test('streak breaks if goal not met and skip was used yesterday', () {
        final result = FlowCalculator.calculateStreakAtDayEnd(
          goalMetToday: false,
          currentStreak: 10,
          lastSkipDate: DateTime(2025, 1, 14), // yesterday
          today: DateTime(2025, 1, 15),
        );
        expect(result.newStreak, 0); // streak broken, can't use consecutive skips
        expect(result.skipUsed, false);
        expect(result.streakBroken, true);
      });

      test('no streak break if streak was already 0', () {
        final result = FlowCalculator.calculateStreakAtDayEnd(
          goalMetToday: false,
          currentStreak: 0,
          lastSkipDate: null,
          today: DateTime(2025, 1, 15),
        );
        expect(result.newStreak, 0);
        expect(result.skipUsed, false);
        expect(result.streakBroken, false); // nothing to break
      });
    });

    group('updateStreak', () {
      test('increments streak when goal met and had streak yesterday', () {
        final result = FlowCalculator.updateStreak(
          goalMetToday: true,
          goalMetYesterday: true,
          currentStreak: 5,
        );
        expect(result, 6);
      });

      test('starts new streak when goal met but no previous streak', () {
        final result = FlowCalculator.updateStreak(
          goalMetToday: true,
          goalMetYesterday: false,
          currentStreak: 0,
        );
        expect(result, 1);
      });

      test('continues streak when goal met even if yesterday not met but had streak', () {
        final result = FlowCalculator.updateStreak(
          goalMetToday: true,
          goalMetYesterday: false,
          currentStreak: 3, // had existing streak
        );
        expect(result, 4);
      });

      test('does not change streak when goal not met (break happens at day end)', () {
        final result = FlowCalculator.updateStreak(
          goalMetToday: false,
          goalMetYesterday: true,
          currentStreak: 5,
        );
        expect(result, 5); // unchanged, break handled separately
      });
    });

    group('Longest Streak Logic', () {
      test('longest streak should be tracked separately from current', () {
        // This is more of a documentation test - the actual logic is in EnergyService
        // When current streak exceeds longest, longest should be updated

        int currentStreak = 0;
        int longestStreak = 5;

        // Simulate meeting goal for 6 days
        for (int i = 0; i < 6; i++) {
          currentStreak = FlowCalculator.updateStreak(
            goalMetToday: true,
            goalMetYesterday: i > 0,
            currentStreak: currentStreak,
          );
          if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
          }
        }

        expect(currentStreak, 6);
        expect(longestStreak, 6); // updated because current exceeded it
      });

      test('longest streak preserved when current streak breaks', () {
        int currentStreak = 10;
        int longestStreak = 10;

        // Simulate streak breaking
        final result = FlowCalculator.calculateStreakAtDayEnd(
          goalMetToday: false,
          currentStreak: currentStreak,
          lastSkipDate: DateTime(2025, 1, 14), // skip not available
          today: DateTime(2025, 1, 15),
        );

        currentStreak = result.newStreak;
        // longest should NOT change when streak breaks

        expect(currentStreak, 0);
        expect(longestStreak, 10); // preserved
      });
    });
  });
}
