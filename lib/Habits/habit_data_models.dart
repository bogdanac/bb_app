import 'package:intl/intl.dart';

/// Duration options for habit cycles
enum HabitDuration {
  oneWeek(7, '1 Week'),
  threeWeeks(21, '21 Days'),
  threeMonths(90, '3 Months'),
  oneYear(365, '1 Year');

  final int days;
  final String label;
  const HabitDuration(this.days, this.label);

  static HabitDuration fromDays(int days) {
    return HabitDuration.values.firstWhere(
      (d) => d.days == days,
      orElse: () => HabitDuration.threeWeeks, // Default fallback
    );
  }
}

/// Represents a completed cycle in habit history
class CycleHistory {
  final int cycleNumber;
  final DateTime startDate;
  final DateTime endDate;
  final int targetDays;
  final int completedDays;
  final List<String> completedDates; // All dates completed in this cycle
  final DateTime completedAt; // When the cycle was marked as complete

  CycleHistory({
    required this.cycleNumber,
    required this.startDate,
    required this.endDate,
    required this.targetDays,
    required this.completedDays,
    required this.completedDates,
    required this.completedAt,
  });

  /// Get completion percentage for this cycle
  double get completionRate => targetDays > 0 ? completedDays / targetDays : 0.0;

  /// Check if cycle was fully completed (all days marked)
  bool get isFullyCompleted => completedDays >= targetDays;

  Map<String, dynamic> toJson() => {
    'cycleNumber': cycleNumber,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'targetDays': targetDays,
    'completedDays': completedDays,
    'completedDates': completedDates,
    'completedAt': completedAt.toIso8601String(),
  };

  static CycleHistory fromJson(Map<String, dynamic> json) {
    return CycleHistory(
      cycleNumber: json['cycleNumber'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      targetDays: json['targetDays'],
      completedDays: json['completedDays'],
      completedDates: List<String>.from(json['completedDates'] ?? []),
      completedAt: DateTime.parse(json['completedAt']),
    );
  }
}

// HABIT DATA MODELS
class Habit {
  final String id;
  String name;
  bool isActive;
  DateTime createdAt;
  DateTime startDate; // When the habit tracking should start (can be future date)
  int cycleDurationDays; // Duration of each cycle (7, 21, or 90 days)
  List<String> completedDates; // List of dates in 'yyyy-MM-dd' format
  int currentCycle; // Which cycle we're on
  bool isCompleted; // Has the habit cycle been fully completed
  List<CycleHistory> cycleHistory; // History of all completed cycles

  Habit({
    required this.id,
    required this.name,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? startDate,
    this.cycleDurationDays = 21, // Default to 21 days for backward compatibility
    List<String>? completedDates,
    this.currentCycle = 1,
    this.isCompleted = false,
    List<CycleHistory>? cycleHistory,
  }) : createdAt = createdAt ?? DateTime.now(),
       startDate = startDate ?? createdAt ?? DateTime.now(),
       completedDates = completedDates ?? [],
       cycleHistory = cycleHistory ?? [];

  /// Get the HabitDuration enum for this habit
  HabitDuration get duration => HabitDuration.fromDays(cycleDurationDays);

  /// Check if the habit has started (startDate <= today)
  bool hasStarted() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    return !startOnly.isAfter(todayOnly);
  }

  bool isCompletedToday() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return completedDates.contains(today);
  }

  void markCompleted() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (!completedDates.contains(today)) {
      completedDates.add(today);
    }
  }

  void markUncompleted() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    completedDates.remove(today);
  }

  bool isCompletedOnDate(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    return completedDates.contains(dateString);
  }

  void markCompletedOnDate(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    if (!completedDates.contains(dateString)) {
      completedDates.add(dateString);
    }
  }

  void markUncompletedOnDate(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    completedDates.remove(dateString);
  }

  void toggleCompletionOnDate(DateTime date) {
    if (isCompletedOnDate(date)) {
      markUncompletedOnDate(date);
    } else {
      markCompletedOnDate(date);
    }
  }

  int getCurrentCycleProgress() {
    if (completedDates.isEmpty) return 0;

    // Calculate cycle start based on startDate and current cycle
    final habitStart = DateTime(startDate.year, startDate.month, startDate.day);
    final cycleStartDate = habitStart.add(Duration(days: (currentCycle - 1) * cycleDurationDays));

    // Count completed days in current cycle window
    int progress = 0;
    for (int i = 0; i < cycleDurationDays; i++) {
      final checkDate = cycleStartDate.add(Duration(days: i));
      final checkDateString = DateFormat('yyyy-MM-dd').format(checkDate);
      if (completedDates.contains(checkDateString)) {
        progress++;
      }
    }

    return progress;
  }
  
  int getStreak() {
    if (completedDates.isEmpty) return 0;
    
    final today = DateTime.now();
    var currentDate = DateTime(today.year, today.month, today.day);
    var streak = 0;
    
    // Check if today is completed, if not start from yesterday
    final todayString = DateFormat('yyyy-MM-dd').format(currentDate);
    if (!completedDates.contains(todayString)) {
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    // Count consecutive completed days working backwards
    while (true) {
      final dateString = DateFormat('yyyy-MM-dd').format(currentDate);
      if (completedDates.contains(dateString)) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }
  
  bool canContinueToNextCycle() {
    return getCurrentCycleProgress() >= cycleDurationDays;
  }

  /// Save current cycle to history before moving to next
  void _saveCurrentCycleToHistory() {
    final habitStart = DateTime(startDate.year, startDate.month, startDate.day);
    final cycleStartDate = habitStart.add(Duration(days: (currentCycle - 1) * cycleDurationDays));
    final cycleEndDate = cycleStartDate.add(Duration(days: cycleDurationDays - 1));

    // Get completed dates for current cycle only
    final currentCycleCompletedDates = <String>[];
    for (int i = 0; i < cycleDurationDays; i++) {
      final checkDate = cycleStartDate.add(Duration(days: i));
      final checkDateString = DateFormat('yyyy-MM-dd').format(checkDate);
      if (completedDates.contains(checkDateString)) {
        currentCycleCompletedDates.add(checkDateString);
      }
    }

    final history = CycleHistory(
      cycleNumber: currentCycle,
      startDate: cycleStartDate,
      endDate: cycleEndDate,
      targetDays: cycleDurationDays,
      completedDays: currentCycleCompletedDates.length,
      completedDates: currentCycleCompletedDates,
      completedAt: DateTime.now(),
    );

    cycleHistory.add(history);
  }

  void continueToNextCycle() {
    // Save current cycle to history before moving on
    _saveCurrentCycleToHistory();

    currentCycle++;
    // Reset completion dates for new cycle
    completedDates.clear();
    isCompleted = false;
  }

  int getTotalCompletedDays() {
    return completedDates.length;
  }

  double getCompletionRate({int? lastNDays}) {
    if (lastNDays == null) {
      // Overall completion rate since creation
      final daysSinceCreation = DateTime.now().difference(createdAt).inDays + 1;
      return daysSinceCreation > 0 ? completedDates.length / daysSinceCreation : 0.0;
    } else {
      // Completion rate for last N days
      final today = DateTime.now();
      var count = 0;
      
      for (int i = 0; i < lastNDays; i++) {
        final date = today.subtract(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        if (completedDates.contains(dateString)) {
          count++;
        }
      }
      
      return count / lastNDays;
    }
  }

  /// Get total completed days across all cycles (including history)
  int getTotalCompletedDaysAllCycles() {
    int total = completedDates.length; // Current cycle
    for (final cycle in cycleHistory) {
      total += cycle.completedDays;
    }
    return total;
  }

  /// Get total number of completed cycles
  int get totalCompletedCycles => cycleHistory.length;

  /// Get average completion rate across all completed cycles
  double get averageCycleCompletionRate {
    if (cycleHistory.isEmpty) return 0.0;
    double totalRate = 0;
    for (final cycle in cycleHistory) {
      totalRate += cycle.completionRate;
    }
    return totalRate / cycleHistory.length;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'startDate': startDate.toIso8601String(),
    'cycleDurationDays': cycleDurationDays,
    'completedDates': completedDates,
    'currentCycle': currentCycle,
    'isCompleted': isCompleted,
    'cycleHistory': cycleHistory.map((c) => c.toJson()).toList(),
  };

  static Habit fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt']);
    return Habit(
      id: json['id'],
      name: json['name'],
      isActive: json['isActive'] ?? true,
      createdAt: createdAt,
      // For backward compatibility: use startDate if present, otherwise fall back to createdAt
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : createdAt,
      // For backward compatibility: default to 21 days if not present
      cycleDurationDays: json['cycleDurationDays'] ?? 21,
      completedDates: List<String>.from(json['completedDates'] ?? []),
      currentCycle: json['currentCycle'] ?? 1,
      isCompleted: json['isCompleted'] ?? false,
      cycleHistory: (json['cycleHistory'] as List<dynamic>?)
          ?.map((c) => CycleHistory.fromJson(c))
          .toList() ?? [],
    );
  }
}

class HabitStatistics {
  final Habit habit;
  final int currentStreak;
  final int longestStreak;
  final int totalCompletedDays;
  final double completionRateWeek;
  final double completionRateMonth;
  final double completionRateAll;
  final Map<String, int> monthlyStats; // 'yyyy-MM' -> completed days

  HabitStatistics({
    required this.habit,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompletedDays,
    required this.completionRateWeek,
    required this.completionRateMonth,
    required this.completionRateAll,
    required this.monthlyStats,
  });

  static HabitStatistics fromHabit(Habit habit) {
    final currentStreak = habit.getStreak();
    final totalCompletedDays = habit.getTotalCompletedDays();
    final completionRateWeek = habit.getCompletionRate(lastNDays: 7);
    final completionRateMonth = habit.getCompletionRate(lastNDays: 30);
    final completionRateAll = habit.getCompletionRate();

    // Calculate longest streak
    var longestStreak = 0;
    var currentStreakCount = 0;
    final sortedDates = List<String>.from(habit.completedDates)..sort();
    
    DateTime? previousDate;
    for (final dateString in sortedDates) {
      final date = DateTime.parse(dateString);
      
      if (previousDate == null || date.difference(previousDate).inDays == 1) {
        currentStreakCount++;
        longestStreak = longestStreak > currentStreakCount ? longestStreak : currentStreakCount;
      } else {
        currentStreakCount = 1;
      }
      
      previousDate = date;
    }

    // Calculate monthly stats
    final monthlyStats = <String, int>{};
    for (final dateString in habit.completedDates) {
      final date = DateTime.parse(dateString);
      final monthKey = DateFormat('yyyy-MM').format(date);
      monthlyStats[monthKey] = (monthlyStats[monthKey] ?? 0) + 1;
    }

    return HabitStatistics(
      habit: habit,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalCompletedDays: totalCompletedDays,
      completionRateWeek: completionRateWeek,
      completionRateMonth: completionRateMonth,
      completionRateAll: completionRateAll,
      monthlyStats: monthlyStats,
    );
  }
}