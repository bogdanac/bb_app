import 'energy_settings_model.dart';

/// Calculator for Flow Points system - converts energy levels to productivity points
///
/// Flow Points Formula:
/// - 1 task = 1 flow point (regardless of energy level)
///
/// Battery Formula:
/// - Energy × 10% battery change
/// - So -5 drains 50%, +5 charges 50%
class FlowCalculator {
  /// Calculate flow points earned from an energy level (-5 to +5)
  /// Each completed task gives 1 flow point
  static int calculateFlowPoints(int energyLevel) {
    // 1 task = 1 flow point, regardless of energy level
    return 1;
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

  /// Check if a skip can be used for the streak based on skip mode
  static bool canUseStreakSkip({
    required DateTime? lastSkipDate,
    required DateTime? lastStreakDate,
    required DateTime today,
    SkipDayMode skipDayMode = SkipDayMode.weekly,
  }) {
    // Disabled mode - no skips allowed
    if (skipDayMode == SkipDayMode.disabled) return false;

    // Unlimited mode - always allow
    if (skipDayMode == SkipDayMode.unlimited) return true;

    // If no last skip, can always use one
    if (lastSkipDate == null) return true;

    final todayDate = DateTime(today.year, today.month, today.day);
    final lastSkip = DateTime(lastSkipDate.year, lastSkipDate.month, lastSkipDate.day);

    // Check if last skip was yesterday (no consecutive skips for all modes except unlimited)
    final yesterday = todayDate.subtract(const Duration(days: 1));
    if (lastSkip == yesterday) {
      return false; // Can't skip two days in a row
    }

    // Check based on mode
    switch (skipDayMode) {
      case SkipDayMode.weekly:
        // 1 skip per 7 days
        final weekAgo = todayDate.subtract(const Duration(days: 7));
        return !lastSkip.isAfter(weekAgo);

      case SkipDayMode.biweekly:
        // 1 skip per 14 days
        final twoWeeksAgo = todayDate.subtract(const Duration(days: 14));
        return !lastSkip.isAfter(twoWeeksAgo);

      case SkipDayMode.perCycle:
        // 1 skip per 28 days (menstrual cycle)
        final cycleAgo = todayDate.subtract(const Duration(days: 28));
        return !lastSkip.isAfter(cycleAgo);

      case SkipDayMode.unlimited:
      case SkipDayMode.disabled:
        return false; // Already handled above
    }
  }

  /// Get description for skip day mode
  static String getSkipModeDescription(SkipDayMode mode) {
    switch (mode) {
      case SkipDayMode.weekly:
        return '1 skip per week';
      case SkipDayMode.biweekly:
        return '1 skip every 2 weeks';
      case SkipDayMode.perCycle:
        return '1 skip per cycle (~28 days)';
      case SkipDayMode.unlimited:
        return 'Unlimited skips (no restrictions)';
      case SkipDayMode.disabled:
        return 'No skips allowed';
    }
  }

  /// Get days until next skip available
  static int? getDaysUntilNextSkip({
    required DateTime? lastSkipDate,
    required DateTime today,
    required SkipDayMode skipDayMode,
  }) {
    if (skipDayMode == SkipDayMode.disabled) return null;
    if (skipDayMode == SkipDayMode.unlimited) return 0;
    if (lastSkipDate == null) return 0;

    final todayDate = DateTime(today.year, today.month, today.day);
    final lastSkip = DateTime(lastSkipDate.year, lastSkipDate.month, lastSkipDate.day);

    int cooldownDays;
    switch (skipDayMode) {
      case SkipDayMode.weekly:
        cooldownDays = 7;
        break;
      case SkipDayMode.biweekly:
        cooldownDays = 14;
        break;
      case SkipDayMode.perCycle:
        cooldownDays = 28;
        break;
      case SkipDayMode.unlimited:
      case SkipDayMode.disabled:
        return 0;
    }

    final nextAvailable = lastSkip.add(Duration(days: cooldownDays));
    final daysRemaining = nextAvailable.difference(todayDate).inDays;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  /// Calculate streak with skip consideration at end of day
  /// Returns (newStreak, skipUsed, streakBroken)
  static ({int newStreak, bool skipUsed, bool streakBroken}) calculateStreakAtDayEnd({
    required bool goalMetToday,
    required int currentStreak,
    required DateTime? lastSkipDate,
    required DateTime today,
    SkipDayMode skipDayMode = SkipDayMode.weekly,
    bool autoUseSkip = true,
  }) {
    // If goal was met, streak continues
    if (goalMetToday) {
      return (newStreak: currentStreak, skipUsed: false, streakBroken: false);
    }

    // Goal not met - check if we can use a skip (only if auto-skip is enabled)
    if (autoUseSkip &&
        currentStreak > 0 &&
        canUseStreakSkip(
          lastSkipDate: lastSkipDate,
          lastStreakDate: null,
          today: today,
          skipDayMode: skipDayMode,
        )) {
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
