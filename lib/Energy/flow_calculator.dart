import 'energy_settings_model.dart';

/// Calculator for Flow Points system - converts energy levels to productivity points
///
/// Flow Points Formula:
/// - Draining tasks (negative energy): -5=10pts, -4=8pts, -3=6pts, -2=4pts, -1=2pts
/// - Neutral tasks: 0=1pt
/// - Charging tasks (positive energy): +1=2pts, +2=3pts, +3=4pts, +4=5pts, +5=6pts
///
/// Battery Formula:
/// - Energy × 10% battery change
/// - So -5 drains 50%, +5 charges 50%
class FlowCalculator {
  /// Calculate flow points earned from an energy level (-5 to +5)
  static int calculateFlowPoints(int energyLevel) {
    // Clamp energy level to valid range
    final energy = energyLevel.clamp(-5, 5);

    // Flow points formula:
    // Draining tasks (negative): absolute value * 2
    // -5 → 10, -4 → 8, -3 → 6, -2 → 4, -1 → 2
    // Neutral: 0 → 1
    // Charging tasks (positive): value + 1
    // +1 → 2, +2 → 3, +3 → 4, +4 → 5, +5 → 6

    if (energy < 0) {
      // Draining tasks: |energy| * 2
      return energy.abs() * 2;
    } else if (energy == 0) {
      // Neutral tasks: 1 point
      return 1;
    } else {
      // Charging tasks: energy + 1
      return energy + 1;
    }
  }

  /// Calculate battery change percentage from energy level (-5 to +5)
  static int calculateBatteryChange(int energyLevel) {
    // Clamp energy level to valid range
    final energy = energyLevel.clamp(-5, 5);

    // Simple formula: energy × 10%
    // -5 → -50% (drains 50%)
    // 0 → 0% (neutral)
    // +5 → +50% (charges 50%)
    return energy * 10;
  }

  /// Calculate flow points from multiple energy entries
  static int calculateTotalFlowPoints(List<EnergyConsumptionEntry> entries) {
    if (entries.isEmpty) return 0;

    int total = 0;
    for (final entry in entries) {
      total += calculateFlowPoints(entry.energyLevel);
    }
    return total;
  }

  /// Calculate battery change from multiple energy entries
  static int calculateTotalBatteryChange(List<EnergyConsumptionEntry> entries) {
    if (entries.isEmpty) return 0;

    int total = 0;
    for (final entry in entries) {
      total += calculateBatteryChange(entry.energyLevel);
    }
    return total;
  }

  /// Check if flow goal is met
  static bool isFlowGoalMet(int flowPoints, int flowGoal) {
    return flowPoints >= flowGoal;
  }

  /// Check if today's flow is a personal record
  static bool isPersonalRecord(int flowPoints, int currentPR) {
    return flowPoints > currentPR;
  }

  /// Update streak based on goal achievement
  /// Returns new streak count
  /// Note: This is called when goal is MET - streak only breaks at end of day check
  static int updateStreak({
    required bool goalMetToday,
    required bool goalMetYesterday,
    required int currentStreak,
  }) {
    if (!goalMetToday) {
      // Goal not met today - don't increment (but don't break here - that's done at day end)
      return currentStreak;
    }

    if (goalMetYesterday || currentStreak > 0) {
      // Continue or extend streak
      return currentStreak + 1;
    }

    // First day of new streak
    return 1;
  }

  /// Check if a skip can be used for the streak
  /// Rules: 1 skip allowed per week, no consecutive skips
  static bool canUseStreakSkip({
    required DateTime? lastSkipDate,
    required DateTime? lastStreakDate,
    required DateTime today,
  }) {
    // If no last skip, can always use one
    if (lastSkipDate == null) return true;

    final todayDate = DateTime(today.year, today.month, today.day);
    final lastSkip = DateTime(lastSkipDate.year, lastSkipDate.month, lastSkipDate.day);

    // Check if last skip was yesterday (no consecutive skips)
    final yesterday = todayDate.subtract(const Duration(days: 1));
    if (lastSkip == yesterday) {
      return false; // Can't skip two days in a row
    }

    // Check if a skip was used in the last 7 days
    final weekAgo = todayDate.subtract(const Duration(days: 7));
    if (lastSkip.isAfter(weekAgo)) {
      return false; // Already used skip this week
    }

    return true;
  }

  /// Calculate streak with skip consideration at end of day
  /// Returns (newStreak, skipUsed, streakBroken)
  static ({int newStreak, bool skipUsed, bool streakBroken}) calculateStreakAtDayEnd({
    required bool goalMetToday,
    required int currentStreak,
    required DateTime? lastSkipDate,
    required DateTime today,
  }) {
    // If goal was met, streak continues
    if (goalMetToday) {
      return (newStreak: currentStreak, skipUsed: false, streakBroken: false);
    }

    // Goal not met - check if we can use a skip
    if (currentStreak > 0 && canUseStreakSkip(lastSkipDate: lastSkipDate, lastStreakDate: null, today: today)) {
      // Use a skip to preserve streak
      return (newStreak: currentStreak, skipUsed: true, streakBroken: false);
    }

    // No skip available or no streak to preserve - streak breaks
    return (newStreak: 0, skipUsed: false, streakBroken: currentStreak > 0);
  }

  /// Get streak milestone for celebration (returns milestone value or null)
  static int? getStreakMilestone(int streak) {
    const milestones = [3, 7, 14, 30, 50, 100];
    if (milestones.contains(streak)) {
      return streak;
    }
    return null;
  }

  /// Get flow description for energy level
  static String getFlowDescription(int energyLevel) {
    final points = calculateFlowPoints(energyLevel);
    final batteryChange = calculateBatteryChange(energyLevel);

    if (batteryChange < 0) {
      return 'Drains ${batteryChange.abs()}%, Earns $points pts';
    } else if (batteryChange > 0) {
      return 'Charges $batteryChange%, Earns $points pts';
    } else {
      return 'Neutral, Earns $points pts';
    }
  }

  /// Get color for battery level (for UI)
  static String getBatteryColor(int battery) {
    if (battery >= 80) return 'green';
    if (battery >= 50) return 'yellow';
    if (battery >= 20) return 'orange';
    if (battery >= 0) return 'red';
    return 'critical'; // Below 0%
  }

  /// Check if battery is critically low (warning threshold)
  static bool isBatteryCritical(int battery) {
    return battery < 20;
  }

  /// Get suggested action based on battery level
  static String getBatterySuggestion(int battery) {
    if (battery < 0) {
      return 'Critical! Take a break and recharge immediately';
    } else if (battery < 20) {
      return 'Low battery - prioritize recharging activities';
    } else if (battery < 50) {
      return 'Moderate energy - balance work with rest';
    } else if (battery < 80) {
      return 'Good energy - you can tackle challenging tasks';
    } else if (battery <= 120) {
      return 'High energy - great time for difficult work!';
    } else {
      return 'Excellent! You\'re fully charged and ready!';
    }
  }

  /// Validate energy level is in valid range
  static bool isValidEnergyLevel(int energyLevel) {
    return energyLevel >= -5 && energyLevel <= 5;
  }

  /// Validate battery level (allow negative and above 120%)
  static bool isValidBatteryLevel(int battery) {
    // Allow any integer - battery can go negative or above 120%
    return true;
  }

  /// Calculate recommended flow goal based on cycle phase and battery
  static int calculateRecommendedFlowGoal({
    required int minFlowGoal,
    required int maxFlowGoal,
    required double cyclePhaseMultiplier, // 0.0 to 1.0
  }) {
    // Linear interpolation between min and max based on cycle phase
    final range = maxFlowGoal - minFlowGoal;
    final goal = minFlowGoal + (range * cyclePhaseMultiplier);
    return goal.round().clamp(minFlowGoal, maxFlowGoal);
  }
}
