import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menstrual_cycle_constants.dart';

class MenstrualCycleUtils {
  static bool isCurrentlyOnPeriod(DateTime? lastPeriodStart, DateTime? lastPeriodEnd) {
    return lastPeriodStart != null && lastPeriodEnd == null;
  }

  static String getCyclePhase(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) {
    if (lastPeriodStart == null) return "No data available";

    final now = DateTime.now();
    final daysSinceStart = now.difference(lastPeriodStart).inDays + 1; // +1 because day 1 is period start

    // Use the simplified phase system that considers days 1-5 as Menstrual Phase
    return getPhaseFromCycleDays(daysSinceStart, averageCycleLength);
  }

  static String getPhaseFromCycleDays(int cycleDays, int averageCycleLength) {
    if (cycleDays <= 5) {
      return MenstrualCycleConstants.menstrualPhase;
    } else if (cycleDays <= 11) {
      return MenstrualCycleConstants.follicularPhase;
    } else if (cycleDays <= 16) {
      return MenstrualCycleConstants.ovulationPhase;
    } else if (cycleDays <= (averageCycleLength - 7)) {
      return MenstrualCycleConstants.earlyLutealPhase;
    } else {
      return MenstrualCycleConstants.lateLutealPhase;
    }
  }

  static String getCycleInfo(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) {
    if (lastPeriodStart == null) return "Track your first period to begin";

    final now = DateTime.now();
    final nextPeriodStart = lastPeriodStart.add(Duration(days: averageCycleLength));
    final daysUntilPeriod = nextPeriodStart.difference(now).inDays;

    // Period expected today or overdue
    if (daysUntilPeriod <= 0) {
      if (daysUntilPeriod == 0) {
        return "Period expected today! 🩸";
      } else {
        final daysOverdue = -daysUntilPeriod;
        return "Period is $daysOverdue days overdue";
      }
    }

    // Pre-period warnings (1-5 days) with personalized messages
    if (daysUntilPeriod <= 5) {
      final messages = {
        1: "Period expected tomorrow! Take care of yourself 💝",
        2: "Period in 2 days. Rest and stay comfortable 🛋️",
        3: "Period in 3 days. Listen to your body 🤗",
        4: "Period in 4 days. Symptoms may begin, be gentle with yourself 😌",
        5: "Period in 5 days. Stay hydrated and rest well 💧"
      };
      return messages[daysUntilPeriod] ?? "$daysUntilPeriod days until period";
    }

    // Current period info
    if (isCurrentlyOnPeriod(lastPeriodStart, lastPeriodEnd)) {
      final currentDay = now.difference(lastPeriodStart).inDays + 1;
      return "Day $currentDay of period";
    }

    // Cycle day info with ovulation focus
    final daysSinceStart = now.difference(lastPeriodStart).inDays + 1;

    if (daysSinceStart <= 11) {
      return "Back in the game";
    } else if (daysSinceStart <= 16) {
      final ovulationDay = 14;
      final daysToOvulation = ovulationDay - daysSinceStart;

      if (daysToOvulation == 0) {
        return "Ovulation day! 🥚";
      } else if (daysToOvulation == 1) {
        return "Ovulation tomorrow";
      } else if (daysToOvulation == -1) {
        return "Ovulation was yesterday";
      } else if (daysSinceStart >= 12 && daysSinceStart <= 16) {
        return "Ovulation window";
      } else {
        return "Ovulation window";
      }
    } else {
      if (daysUntilPeriod <= 3) {
        return "$daysUntilPeriod days until next period";
      }
      return "Totul e în regulă în mine și în lume.";
    }
  }

  static Color getPhaseColor(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) {
    final phase = getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);
    
    if (phase == MenstrualCycleConstants.menstrualPhase) return AppColors.lightRed;
    if (phase == MenstrualCycleConstants.follicularPhase) return AppColors.successGreen;
    if (phase == MenstrualCycleConstants.ovulationPhase) return AppColors.lightPink;
    if (phase == MenstrualCycleConstants.earlyLutealPhase) return AppColors.lightPurple;
    if (phase == MenstrualCycleConstants.lateLutealPhase) return AppColors.purple;
    
    return AppColors.coral;
  }

  static IconData getPhaseIcon(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) {
    final phase = getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);

    if (phase == MenstrualCycleConstants.menstrualPhase) return Icons.water_drop_rounded;
    if (phase == MenstrualCycleConstants.follicularPhase) return Icons.energy_savings_leaf;
    if (phase == MenstrualCycleConstants.ovulationPhase) return Icons.favorite_rounded;
    if (phase == MenstrualCycleConstants.earlyLutealPhase || phase == MenstrualCycleConstants.lateLutealPhase) return Icons.nights_stay_rounded;

    return Icons.timeline_rounded;
  }


  static String getPhaseBasedPet(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) {
    final phase = getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);
    
    if (phase == MenstrualCycleConstants.menstrualPhase) return '🐾';
    if (phase == MenstrualCycleConstants.follicularPhase) return '😸';
    if (phase == MenstrualCycleConstants.ovulationPhase) return '🦋';
    if (phase == MenstrualCycleConstants.earlyLutealPhase) return '🐰';
    if (phase == MenstrualCycleConstants.lateLutealPhase) return '🐻';
    
    return '😸';
  }

  // CALORIE MANAGEMENT
  static Future<int> getPhaseCalories(String phase) async {
    final prefs = await SharedPreferences.getInstance();
    
    final defaultCalories = MenstrualCycleConstants.defaultPhaseCalories;

    final key = 'calories_${phase.replaceAll(' ', '_').toLowerCase()}';
    return prefs.getInt(key) ?? defaultCalories[phase] ?? 2000;
  }

  static Future<void> setPhaseCalories(String phase, int calories) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'calories_${phase.replaceAll(' ', '_').toLowerCase()}';
    await prefs.setInt(key, calories);
  }

  static Future<int> getCurrentPhaseCalories(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) async {
    final phase = getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);
    return await getPhaseCalories(phase);
  }

  static List<String> getAllPhases() {
    return MenstrualCycleConstants.allPhases;
  }
}