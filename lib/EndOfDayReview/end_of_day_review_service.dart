import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'end_of_day_review_data.dart';
import '../Settings/app_customization_service.dart';
import '../Tasks/task_service.dart';
import '../Habits/habit_service.dart';
import '../Energy/energy_service.dart';
import '../Timers/timer_service.dart';
import '../Routines/routine_service.dart';
import '../Chores/chore_service.dart';
import '../FoodTracking/food_tracking_service.dart';
import '../FoodTracking/food_tracking_data_models.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import '../theme/app_colors.dart';
import '../shared/error_logger.dart';

/// Service for gathering end of day review data from all active modules.
/// Always fetches live data - no caching.
class EndOfDayReviewService {
  static final EndOfDayReviewService _instance = EndOfDayReviewService._internal();
  factory EndOfDayReviewService() => _instance;
  EndOfDayReviewService._internal();

  /// Get review data for today - ALWAYS LIVE (no caching)
  Future<EndOfDayReviewData> getTodayReview() async {
    try {
      final enabledModules = await _getEnabledModules();
      final summaries = <ModuleSummary>[];

      // Include Water and Food if their modules are enabled
      if (enabledModules.contains(AppCustomizationService.moduleWater)) {
        final waterSummary = await _getWaterSummary();
        summaries.add(waterSummary);
      }

      if (enabledModules.contains(AppCustomizationService.moduleFood)) {
        final foodSummary = await _getFoodSummary();
        summaries.add(foodSummary);
      }

      // Add module-specific summaries based on enabled state
      for (final moduleKey in enabledModules) {
        final summary = await _getModuleSummary(moduleKey);
        if (summary != null) {
          summaries.add(summary);
        }
      }

      return EndOfDayReviewData(
        date: DateTime.now(),
        moduleSummaries: summaries,
        generatedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EndOfDayReviewService.getTodayReview',
        error: 'Error getting today\'s review: $e',
        stackTrace: stackTrace.toString(),
      );
      return EndOfDayReviewData(
        date: DateTime.now(),
        moduleSummaries: [],
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Check if it's currently evening (default: 6 PM onwards)
  Future<bool> isEveningTime() async {
    final prefs = await SharedPreferences.getInstance();
    final eveningStartHour = prefs.getInt('end_of_day_review_evening_start') ?? 18;
    final now = DateTime.now();
    return now.hour >= eveningStartHour;
  }

  /// Get list of enabled module keys
  Future<List<String>> _getEnabledModules() async {
    final states = await AppCustomizationService.loadAllModuleStates();
    return states.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  /// Get summary for a specific module
  Future<ModuleSummary?> _getModuleSummary(String moduleKey) async {
    try {
      switch (moduleKey) {
        case AppCustomizationService.moduleTasks:
          return await _getTasksSummary();
        case AppCustomizationService.moduleHabits:
          return await _getHabitsSummary();
        case AppCustomizationService.moduleEnergy:
          return await _getEnergySummary();
        case AppCustomizationService.moduleTimers:
          return await _getTimersSummary();
        case AppCustomizationService.moduleFasting:
          return await _getFastingSummary();
        case AppCustomizationService.moduleMenstrual:
          return await _getMenstrualSummary();
        case AppCustomizationService.moduleRoutines:
          return await _getRoutinesSummary();
        case AppCustomizationService.moduleChores:
          return await _getChoresSummary();
        default:
          return null;
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'EndOfDayReviewService._getModuleSummary',
        error: 'Error getting summary for $moduleKey: $e',
        stackTrace: stackTrace.toString(),
      );
      return null;
    }
  }

  /// Get tasks summary for today
  Future<ModuleSummary> _getTasksSummary() async {
    final taskService = TaskService();
    final tasks = await taskService.loadTasks();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final completedToday = tasks.where((t) =>
        t.isCompleted &&
        t.completedAt != null &&
        t.completedAt!.isAfter(todayStart) &&
        t.completedAt!.isBefore(todayEnd)).toList();

    final pending = tasks.where((t) => !t.isCompleted).length;

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleTasks,
      moduleName: 'Tasks',
      icon: Icons.task_alt_rounded,
      color: AppColors.coral,
      data: {
        'completedCount': completedToday.length,
        'pendingCount': pending,
        'completedTitles': completedToday.take(5).map((t) => t.title).toList(),
      },
    );
  }

  /// Get habits summary for today
  Future<ModuleSummary> _getHabitsSummary() async {
    final habits = await HabitService.getActiveHabits();
    final completedCount = habits.where((h) => h.isCompletedToday()).length;

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleHabits,
      moduleName: 'Habits',
      icon: Icons.track_changes_rounded,
      color: AppColors.pastelGreen,
      data: {
        'completedCount': completedCount,
        'totalCount': habits.length,
        'percentage': habits.isNotEmpty
            ? (completedCount / habits.length * 100).round()
            : 0,
      },
    );
  }

  /// Get energy/flow summary for today
  Future<ModuleSummary> _getEnergySummary() async {
    final summary = await EnergyService.getTodaySummary();

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleEnergy,
      moduleName: 'Energy',
      icon: Icons.bolt_rounded,
      color: AppColors.coral,
      data: summary,
    );
  }

  /// Get timers/activities summary for today
  Future<ModuleSummary> _getTimersSummary() async {
    final today = DateTime.now();
    final sessions = await TimerService.loadSessions();
    final activities = await TimerService.loadActivities();

    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todaySessions = sessions.where((s) =>
        s.startTime.isAfter(todayStart) &&
        s.startTime.isBefore(todayEnd)).toList();

    // Calculate total time and breakdown by activity
    int totalMinutes = 0;
    final activityBreakdown = <String, int>{};

    for (final session in todaySessions) {
      final minutes = session.duration.inMinutes;
      totalMinutes += minutes;

      // Find activity name
      final activity = activities.where((a) => a.id == session.activityId).firstOrNull;
      final activityName = activity?.name ?? 'Unknown';

      activityBreakdown[activityName] = (activityBreakdown[activityName] ?? 0) + minutes;
    }

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleTimers,
      moduleName: 'Activities',
      icon: Icons.timer_rounded,
      color: AppColors.purple,
      data: {
        'totalMinutes': totalMinutes,
        'activityCount': activityBreakdown.length,
        'activityBreakdown': activityBreakdown,
      },
    );
  }

  /// Get fasting summary for today
  Future<ModuleSummary> _getFastingSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check for active fast
    final activeJson = prefs.getString('active_fast');
    bool isCurrentlyFasting = false;
    String currentFastType = '';
    int elapsedMinutes = 0;

    if (activeJson != null) {
      try {
        final parts = activeJson.split('|');
        if (parts.length >= 2) {
          final startTime = DateTime.parse(parts[0]);
          currentFastType = parts[1];
          elapsedMinutes = now.difference(startTime).inMinutes;
          isCurrentlyFasting = true;
        }
      } catch (_) {}
    }

    // Check for completed fast today
    bool completedFastToday = false;
    List<String> historyStr = [];
    try {
      historyStr = prefs.getStringList('fasting_history') ?? [];
    } catch (_) {}

    for (final item in historyStr) {
      try {
        final parts = item.split('|');
        if (parts.length >= 3) {
          final endTime = DateTime.parse(parts[1]);
          if (endTime.year == today.year &&
              endTime.month == today.month &&
              endTime.day == today.day) {
            completedFastToday = true;
            break;
          }
        }
      } catch (_) {}
    }

    String status = 'No fasting today';
    if (isCurrentlyFasting) {
      final hours = elapsedMinutes ~/ 60;
      final mins = elapsedMinutes % 60;
      status = 'Fasting: ${hours}h ${mins}m elapsed';
    } else if (completedFastToday) {
      status = 'Completed a fast today';
    }

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleFasting,
      moduleName: 'Fasting',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.yellow,
      data: {
        'isCurrentlyFasting': isCurrentlyFasting,
        'currentFastType': currentFastType,
        'elapsedMinutes': elapsedMinutes,
        'completedFastToday': completedFastToday,
        'status': status,
      },
    );
  }

  /// Get menstrual cycle summary for today
  Future<ModuleSummary> _getMenstrualSummary() async {
    final prefs = await SharedPreferences.getInstance();

    final lastPeriodStr = prefs.getString('last_period_start');
    final lastPeriodEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    DateTime? lastPeriodStart;
    DateTime? lastPeriodEnd;

    if (lastPeriodStr != null) {
      try {
        lastPeriodStart = DateTime.parse(lastPeriodStr);
      } catch (_) {}
    }
    if (lastPeriodEndStr != null) {
      try {
        lastPeriodEnd = DateTime.parse(lastPeriodEndStr);
      } catch (_) {}
    }

    final currentPhase = MenstrualCycleUtils.getCyclePhase(
      lastPeriodStart,
      lastPeriodEnd,
      averageCycleLength,
    );

    int cycleDay = 0;
    int daysUntilPeriod = 0;
    bool isPeriodDay = false;

    if (lastPeriodStart != null) {
      final now = DateTime.now();
      final daysSinceStart = now.difference(lastPeriodStart).inDays;
      cycleDay = daysSinceStart + 1; // Day 1 is period start
      daysUntilPeriod = averageCycleLength - daysSinceStart;
      isPeriodDay = MenstrualCycleUtils.isCurrentlyOnPeriod(lastPeriodStart, lastPeriodEnd);
    }

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleMenstrual,
      moduleName: 'Cycle',
      icon: Icons.local_florist_rounded,
      color: AppColors.red,
      data: {
        'currentPhase': currentPhase,
        'cycleDay': cycleDay,
        'daysUntilPeriod': daysUntilPeriod,
        'isPeriodDay': isPeriodDay,
      },
    );
  }

  /// Get routines summary for today
  Future<ModuleSummary> _getRoutinesSummary() async {
    final routines = await RoutineService.loadRoutines();
    final today = RoutineService.getEffectiveDate();
    final prefs = await SharedPreferences.getInstance();

    int completedCount = 0;
    final completedNames = <String>[];

    for (final routine in routines) {
      // Check if routine was completed today via SharedPreferences
      final completedKey = 'routine_completed_${routine.id}_$today';
      final isCompletedToday = prefs.getBool(completedKey) ?? false;
      if (isCompletedToday) {
        completedCount++;
        completedNames.add(routine.title);
      }
    }

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleRoutines,
      moduleName: 'Routines',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.orange,
      data: {
        'completedCount': completedCount,
        'totalCount': routines.length,
        'completedNames': completedNames.take(5).toList(),
      },
    );
  }

  /// Get water summary for today
  Future<ModuleSummary> _getWaterSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'water_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final intake = prefs.getInt(todayKey) ?? 0;
    final goal = prefs.getInt('water_goal') ?? 1500;

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleWater,
      moduleName: 'Water',
      icon: Icons.water_drop_rounded,
      color: AppColors.waterBlue,
      data: {
        'intake': intake,
        'goal': goal,
        'goalMet': intake >= goal,
        'percentage': goal > 0 ? (intake / goal * 100).round().clamp(0, 200) : 0,
      },
    );
  }

  /// Get food tracking summary for today
  Future<ModuleSummary> _getFoodSummary() async {
    final today = DateTime.now();
    final entries = await FoodTrackingService.getEntriesForDay(today);

    int healthy = 0;
    int processed = 0;

    for (final entry in entries) {
      if (entry.type == FoodType.healthy) {
        healthy++;
      } else {
        processed++;
      }
    }

    final total = healthy + processed;
    final targetGoal = await FoodTrackingService.getTargetGoal();

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleFood,
      moduleName: 'Food',
      icon: Icons.restaurant_rounded,
      color: AppColors.pastelGreen,
      data: {
        'healthyCount': healthy,
        'processedCount': processed,
        'healthyPercentage': total > 0 ? (healthy / total * 100).round() : 0,
        'targetPercentage': targetGoal,
        'goalMet': total > 0 && (healthy / total * 100).round() >= targetGoal,
      },
    );
  }

  /// Get chores summary for today
  Future<ModuleSummary> _getChoresSummary() async {
    final chores = await ChoreService.loadChores();
    final stats = await ChoreService.getStats();

    // Count chores completed today
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    int completedToday = 0;
    for (final chore in chores) {
      if (chore.lastCompleted.isAfter(todayStart) &&
          chore.lastCompleted.isBefore(todayEnd)) {
        completedToday++;
      }
    }

    return ModuleSummary(
      moduleKey: AppCustomizationService.moduleChores,
      moduleName: 'Chores',
      icon: Icons.cleaning_services_rounded,
      color: AppColors.waterBlue,
      data: {
        'totalChores': stats['totalChores'],
        'avgCondition': stats['avgCondition'],
        'completedToday': completedToday,
        'overdueCount': stats['overdueCount'],
        'criticalCount': stats['criticalCount'],
      },
    );
  }
}
