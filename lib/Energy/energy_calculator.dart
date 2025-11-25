import 'package:shared_preferences/shared_preferences.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import 'energy_settings_model.dart';
import 'energy_service.dart';

/// Calculator for daily flow goals and battery suggestions based on menstrual cycle phase
///
/// Flow goal calculation logic:
/// - Ovulation = peak high flow goal (maxFlowGoal)
/// - Last luteal phase day = peak low flow goal (minFlowGoal)
/// - Each day closer to ovulation increases goal
/// - Each day closer to late luteal decreases goal
///
/// Task energy levels (-5 to +5):
/// - Negative = draining tasks (earn more flow points)
/// - Positive = charging tasks (restore battery)
/// - Default is -1 (slightly draining)
class EnergyCalculator {
  /// Calculate today's flow goal based on menstrual phase
  static Future<int> calculateTodayGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await EnergyService.loadSettings();

    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    // If no menstrual data, return middle ground
    if (lastStartStr == null) {
      return (settings.minFlowGoal + settings.maxFlowGoal) ~/ 2;
    }

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final lastPeriodEnd = lastEndStr != null ? DateTime.parse(lastEndStr) : null;

    return calculateGoalForDate(
      date: DateTime.now(),
      lastPeriodStart: lastPeriodStart,
      lastPeriodEnd: lastPeriodEnd,
      averageCycleLength: averageCycleLength,
      settings: settings,
    );
  }

  /// Calculate suggested battery percentage based on menstrual phase (5-120%)
  static Future<int> calculateTodayBatterySuggestion() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await EnergyService.loadSettings();

    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    // If no menstrual data, return middle ground
    if (lastStartStr == null) {
      return (settings.minBattery + settings.maxBattery) ~/ 2;
    }

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final lastPeriodEnd = lastEndStr != null ? DateTime.parse(lastEndStr) : null;

    return calculateBatteryForDate(
      date: DateTime.now(),
      lastPeriodStart: lastPeriodStart,
      lastPeriodEnd: lastPeriodEnd,
      averageCycleLength: averageCycleLength,
      settings: settings,
    );
  }

  /// Calculate flow goal for a specific date
  static int calculateGoalForDate({
    required DateTime date,
    required DateTime lastPeriodStart,
    DateTime? lastPeriodEnd,
    required int averageCycleLength,
    required EnergySettings settings,
  }) {
    final daysSinceStart = date.difference(lastPeriodStart).inDays + 1;

    // Calculate position in cycle (0 = period start, ~14 = ovulation, ~28 = late luteal end)
    final cycleDay = daysSinceStart % averageCycleLength;
    if (cycleDay == 0) {
      // Exactly on period start day
      return _calculateFlowGoalForCycleDay(averageCycleLength, averageCycleLength, settings);
    }

    return _calculateFlowGoalForCycleDay(cycleDay, averageCycleLength, settings);
  }

  /// Calculate battery percentage for a specific date (5-120%)
  static int calculateBatteryForDate({
    required DateTime date,
    required DateTime lastPeriodStart,
    DateTime? lastPeriodEnd,
    required int averageCycleLength,
    required EnergySettings settings,
  }) {
    final daysSinceStart = date.difference(lastPeriodStart).inDays + 1;

    // Calculate position in cycle (0 = period start, ~14 = ovulation, ~28 = late luteal end)
    final cycleDay = daysSinceStart % averageCycleLength;
    if (cycleDay == 0) {
      // Exactly on period start day
      return _calculateBatteryForCycleDay(averageCycleLength, averageCycleLength, settings);
    }

    return _calculateBatteryForCycleDay(cycleDay, averageCycleLength, settings);
  }

  /// Calculate flow goal based on cycle day using linear interpolation
  static int _calculateFlowGoalForCycleDay(
    int cycleDay,
    int averageCycleLength,
    EnergySettings settings,
  ) {
    // Key points in the cycle:
    // - Day 1-5: Menstrual phase - moderate energy
    // - Day 6-11: Follicular phase - rising energy
    // - Day 12-16: Ovulation phase - peak energy (day 14 = ovulation)
    // - Day 17-21: Early luteal - declining energy
    // - Day 22-28: Late luteal - lowest energy (last day = lowest)

    const ovulationDay = 14; // Peak high energy
    final lastLutealDay = averageCycleLength; // Peak low energy
    final totalSpan = lastLutealDay - ovulationDay;

    // Flow goal range
    final flowRange = settings.maxFlowGoal - settings.minFlowGoal;

    if (cycleDay <= ovulationDay) {
      // Before or at ovulation: energy increases towards peak
      // Day 1 -> moderate, Day 14 -> peak
      final progressToOvulation = cycleDay / ovulationDay;
      final baseFlow = settings.minFlowGoal + (flowRange * 0.4); // Start at 40% of range
      final bonus = flowRange * 0.6 * progressToOvulation; // Add up to 60% more
      return (baseFlow + bonus).round().clamp(settings.minFlowGoal, settings.maxFlowGoal);
    } else {
      // After ovulation: energy decreases towards late luteal
      final progressToLutealEnd = (cycleDay - ovulationDay) / totalSpan;
      final flow = settings.maxFlowGoal - (flowRange * progressToLutealEnd);
      return flow.round().clamp(settings.minFlowGoal, settings.maxFlowGoal);
    }
  }

  /// Calculate battery percentage based on cycle day (5-120%)
  static int _calculateBatteryForCycleDay(
    int cycleDay,
    int averageCycleLength,
    EnergySettings settings,
  ) {
    // Same logic as flow goals, but for battery percentage
    const ovulationDay = 14; // Peak high battery
    final lastLutealDay = averageCycleLength; // Peak low battery
    final totalSpan = lastLutealDay - ovulationDay;

    // Battery range
    final batteryRange = settings.maxBattery - settings.minBattery;

    if (cycleDay <= ovulationDay) {
      // Before or at ovulation: battery increases towards peak
      final progressToOvulation = cycleDay / ovulationDay;
      final baseBattery = settings.minBattery + (batteryRange * 0.4); // Start at 40% of range
      final bonus = batteryRange * 0.6 * progressToOvulation; // Add up to 60% more
      return (baseBattery + bonus).round().clamp(settings.minBattery, settings.maxBattery);
    } else {
      // After ovulation: battery decreases towards late luteal
      final progressToLutealEnd = (cycleDay - ovulationDay) / totalSpan;
      final battery = settings.maxBattery - (batteryRange * progressToLutealEnd);
      return battery.round().clamp(settings.minBattery, settings.maxBattery);
    }
  }

  /// Get current phase info for display
  static Future<Map<String, dynamic>> getCurrentPhaseInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    if (lastStartStr == null) {
      return {
        'phase': 'Unknown',
        'cycleDay': 0,
        'energyGoal': 0,
        'hasData': false,
      };
    }

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final lastPeriodEnd = lastEndStr != null ? DateTime.parse(lastEndStr) : null;
    final now = DateTime.now();

    final daysSinceStart = now.difference(lastPeriodStart).inDays + 1;
    final phase = MenstrualCycleUtils.getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);
    final cycleDay = daysSinceStart % averageCycleLength;

    final settings = await EnergyService.loadSettings();
    final energyGoal = calculateGoalForDate(
      date: now,
      lastPeriodStart: lastPeriodStart,
      lastPeriodEnd: lastPeriodEnd,
      averageCycleLength: averageCycleLength,
      settings: settings,
    );

    return {
      'phase': phase,
      'cycleDay': cycleDay == 0 ? averageCycleLength : cycleDay,
      'energyGoal': energyGoal,
      'hasData': true,
    };
  }

  /// Initialize today's energy tracking with calculated goal and battery
  static Future<DailyEnergyRecord> initializeToday({int? startingBattery}) async {
    final phaseInfo = await getCurrentPhaseInfo();

    return EnergyService.initializeTodayRecord(
      startingBattery: startingBattery ?? await calculateTodayBatterySuggestion(),
      flowGoal: phaseInfo['energyGoal'] ?? 10,
      menstrualPhase: phaseInfo['phase'] ?? 'Unknown',
      cycleDayNumber: phaseInfo['cycleDay'] ?? 0,
    );
  }

  /// Get battery & flow summary for today
  static Future<Map<String, dynamic>> getTodaySummary() async {
    final record = await EnergyService.getTodayRecord();
    final phaseInfo = await getCurrentPhaseInfo();
    final settings = await EnergyService.loadSettings();

    if (record == null) {
      // Initialize if not exists
      final newRecord = await initializeToday();
      return {
        'startingBattery': newRecord.startingBattery,
        'currentBattery': newRecord.currentBattery,
        'batteryChange': 0,
        'flowPoints': 0,
        'flowGoal': newRecord.flowGoal,
        'flowPercentage': 0.0,
        'isGoalMet': false,
        'isPR': false,
        'phase': newRecord.menstrualPhase,
        'cycleDay': newRecord.cycleDayNumber,
        'completionLevel': EnergyCompletionLevel.low,
        'currentStreak': settings.currentStreak,
        'personalRecord': settings.personalRecord,
        'entries': [],
      };
    }

    // Update goal if phase changed
    if (record.flowGoal != phaseInfo['energyGoal']) {
      await EnergyService.initializeTodayRecord(
        flowGoal: phaseInfo['energyGoal'],
        menstrualPhase: phaseInfo['phase'],
        cycleDayNumber: phaseInfo['cycleDay'],
      );
    }

    return {
      'startingBattery': record.startingBattery,
      'currentBattery': record.currentBattery,
      'batteryChange': record.batteryChange,
      'flowPoints': record.flowPoints,
      'flowGoal': record.flowGoal,
      'flowPercentage': record.flowPercentage,
      'isGoalMet': record.isGoalMet,
      'isPR': record.isPR,
      'phase': record.menstrualPhase,
      'cycleDay': record.cycleDayNumber,
      'completionLevel': record.completionLevel,
      'currentStreak': settings.currentStreak,
      'personalRecord': settings.personalRecord,
      'entries': record.entries,
    };
  }
}
