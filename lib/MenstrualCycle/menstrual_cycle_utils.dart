import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menstrual_cycle_constants.dart';
import '../Fasting/scheduled_fastings_service.dart';

class MenstrualCycleUtils {
  static bool isCurrentlyOnPeriod(DateTime? lastPeriodStart, DateTime? lastPeriodEnd) {
    if (lastPeriodStart == null) return false;
    
    // If period has been manually ended, not currently on period
    if (lastPeriodEnd != null) return false;
    
    // Auto-end period after 7 days maximum
    final now = DateTime.now();
    final daysSinceStart = now.difference(lastPeriodStart).inDays;
    
    return daysSinceStart < 7;
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
    final nowDate = DateTime(now.year, now.month, now.day);

    // Alternative calculation method - more explicit
    final lastPeriodDateOnly = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    final daysSinceLastPeriod = nowDate.difference(lastPeriodDateOnly).inDays;
    final daysUntilPeriod = averageCycleLength - daysSinceLastPeriod;
    
    

    // Period expected today or overdue
    if (daysUntilPeriod < 0) {
      final daysOverdue = -daysUntilPeriod;
      return _getLatePeriodMessage(daysOverdue);
    } else if (daysUntilPeriod == 0) {
      return "Period expected today! 🩸";
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

    // Follicular phase (days 6-11) - rebirth, spring, renewal messages
    if (daysSinceStart >= 6 && daysSinceStart <= 11) {
      final follicularDay = daysSinceStart - 5; // Days 6-11 become 1-6 of follicular phase
      final messages = {
        1: "Day 1 of follicular phase - Fresh start, new energy 🌱",
        2: "Day 2 of follicular phase - Rising like spring 🌸",
        3: "Day 3 of follicular phase - Blossoming into your power 🌺",
        4: "Day 4 of follicular phase - Rebirth and renewal 🦋",
        5: "Day 5 of follicular phase - Full of vitality 🌟",
        6: "Day 6 of follicular phase - Ready to conquer 💪"
      };
      return messages[follicularDay] ?? "Day $follicularDay of follicular phase";
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
    if (lastPeriodStart != null) {
      final now = DateTime.now();
      final nextPeriodStart = lastPeriodStart.add(Duration(days: averageCycleLength));
      
      // Use same date calculation as getCycleInfo
      final nowDate = DateTime(now.year, now.month, now.day);
      final nextPeriodDate = DateTime(nextPeriodStart.year, nextPeriodStart.month, nextPeriodStart.day);
      final daysUntilPeriod = nextPeriodDate.difference(nowDate).inDays;
      
      // Check if period is late (only when actually late, not on expected day)
      if (daysUntilPeriod < 0) {
        final daysOverdue = -daysUntilPeriod;
        if (daysOverdue <= 3) {
          return AppColors.lightCoral; // Gentle color for early lateness
        } else if (daysOverdue <= 7) {
          return AppColors.coral; // Slightly more prominent for moderate lateness
        } else {
          return AppColors.orange; // More noticeable for extended lateness
        }
      }
    }
    
    final phase = getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);
    
    if (phase == MenstrualCycleConstants.menstrualPhase) return AppColors.lightRed;
    if (phase == MenstrualCycleConstants.follicularPhase) return AppColors.successGreen;
    if (phase == MenstrualCycleConstants.ovulationPhase) return AppColors.lightPink;
    if (phase == MenstrualCycleConstants.earlyLutealPhase) return AppColors.lightPurple;
    if (phase == MenstrualCycleConstants.lateLutealPhase) return AppColors.purple;
    
    return AppColors.coral;
  }

  static IconData getPhaseIcon(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) {
    if (lastPeriodStart != null) {
      final now = DateTime.now();
      final nextPeriodStart = lastPeriodStart.add(Duration(days: averageCycleLength));
      
      // Use same date calculation as getCycleInfo
      final nowDate = DateTime(now.year, now.month, now.day);
      final nextPeriodDate = DateTime(nextPeriodStart.year, nextPeriodStart.month, nextPeriodStart.day);
      final daysUntilPeriod = nextPeriodDate.difference(nowDate).inDays;
      
      // Check if period is late - use supportive icons (only when actually late, not on expected day)
      if (daysUntilPeriod < 0) {
        final daysOverdue = -daysUntilPeriod;
        if (daysOverdue <= 7) {
          return Icons.spa_rounded; // Gentle self-care icon for early-moderate lateness
        } else {
          return Icons.health_and_safety_rounded; // Health awareness icon for extended lateness
        }
      }
    }
    
    final phase = getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);

    if (phase == MenstrualCycleConstants.menstrualPhase) return Icons.water_drop_rounded;
    if (phase == MenstrualCycleConstants.follicularPhase) return Icons.energy_savings_leaf;
    if (phase == MenstrualCycleConstants.ovulationPhase) return Icons.favorite_rounded;
    if (phase == MenstrualCycleConstants.earlyLutealPhase || phase == MenstrualCycleConstants.lateLutealPhase) return Icons.nights_stay_rounded;

    return Icons.timeline_rounded;
  }


  static String getPhaseBasedPet(DateTime? lastPeriodStart, DateTime? lastPeriodEnd, int averageCycleLength) {
    final phase = getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);
    
    if (phase == MenstrualCycleConstants.menstrualPhase) return '🌙';
    if (phase == MenstrualCycleConstants.follicularPhase) return '🐰';
    if (phase == MenstrualCycleConstants.ovulationPhase) return '🌹';
    if (phase == MenstrualCycleConstants.earlyLutealPhase) return '🍃';
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

  // Get the current day within a specific menstrual phase (1-based indexing)
  static int getCurrentDayInPhase(DateTime? lastPeriodStart, int averageCycleLength, String targetPhase) {
    if (lastPeriodStart == null) return 0;

    final now = DateTime.now();
    final daysSinceStart = now.difference(lastPeriodStart).inDays + 1; // +1 because day 1 is period start
    final currentPhase = getPhaseFromCycleDays(daysSinceStart, averageCycleLength);

    if (currentPhase != targetPhase) return 0; // Not in the target phase

    // Calculate day within the specific phase
    if (targetPhase == MenstrualCycleConstants.menstrualPhase) {
      return daysSinceStart; // Days 1-5
    } else if (targetPhase == MenstrualCycleConstants.follicularPhase) {
      return daysSinceStart - 5; // Days 6-11 become 1-6
    } else if (targetPhase == MenstrualCycleConstants.ovulationPhase) {
      return daysSinceStart - 11; // Days 12-16 become 1-5
    } else if (targetPhase == MenstrualCycleConstants.earlyLutealPhase) {
      return daysSinceStart - 16; // Days 17-X become 1-Y
    } else if (targetPhase == MenstrualCycleConstants.lateLutealPhase) {
      final earlyLutealEnd = averageCycleLength - 7;
      return daysSinceStart - earlyLutealEnd; // Last 7 days become 1-7
    }

    return 0;
  }

  static String _getLatePeriodMessage(int daysOverdue) {
    if (daysOverdue == 1) {
      return "Period is 1 day late. This is completely normal, take care of yourself. 😌";
    } else if (daysOverdue <= 3) {
      return "Period is $daysOverdue days late. Don't worry, your body responds to many factors. Rest and stay hydrated! 🤗";
    } else if (daysOverdue <= 7) {
      return "Period is $daysOverdue days late. Cycles can vary, have you had any changes in stress, sleep, or routine lately? 💝";
    } else if (daysOverdue <= 14) {
      return "Period is $daysOverdue days late. While this can be normal, consider tracking any symptoms or changes 🌸";
    } else {
      return "Period is $daysOverdue days late. If you're concerned or experiencing other symptoms, it may be helpful to speak with a healthcare provider 💙";
    }
  }

  // FASTING WARNINGS
  static bool isDateInLateLutealPhase(DateTime date, DateTime? lastPeriodStart, int averageCycleLength) {
    if (lastPeriodStart == null) return false;

    // Calculate how many days since the last period start
    final daysSinceStart = date.difference(lastPeriodStart).inDays + 1;

    // Adjust for cycle length - late luteal is the last 7 days before next period
    final adjustedDays = daysSinceStart % averageCycleLength;
    if (adjustedDays == 0) return false; // Exactly on period start

    return adjustedDays > (averageCycleLength - 7);
  }

  static Future<bool> isFastingConflictWithLateLuteal(DateTime fastDate) async {
    final prefs = await SharedPreferences.getInstance();
    final lastStartStr = prefs.getString('last_period_start');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;

    if (lastStartStr == null) return false;

    final lastPeriodStart = DateTime.parse(lastStartStr);

    // First, check if the date is in late luteal phase
    final isInLateLuteal = isDateInLateLutealPhase(fastDate, lastPeriodStart, averageCycleLength);
    if (!isInLateLuteal) return false;

    // Second, check if there's actually a scheduled fast for this date
    final scheduledFastings = await ScheduledFastingsService.getScheduledFastings();
    final hasScheduledFast = scheduledFastings.any((fasting) =>
        fasting.isEnabled &&
        fasting.date.year == fastDate.year &&
        fasting.date.month == fastDate.month &&
        fasting.date.day == fastDate.day);

    // Only return true if BOTH conditions are met
    return hasScheduledFast;
  }
}