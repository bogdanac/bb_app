import 'package:intl/intl.dart';

// HABIT DATA MODELS
class Habit {
  final String id;
  String name;
  bool isActive;
  DateTime createdAt;
  List<String> completedDates; // List of dates in 'yyyy-MM-dd' format
  int currentCycle; // Which 21-day cycle we're on
  bool isCompleted; // Has the habit been fully completed (21 days)

  Habit({
    required this.id,
    required this.name,
    this.isActive = true,
    DateTime? createdAt,
    List<String>? completedDates,
    this.currentCycle = 1,
    this.isCompleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       completedDates = completedDates ?? [];

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
    
    // Get the start date of current cycle (21 days ago from the most recent completion)
    final sortedDates = List<String>.from(completedDates)..sort();
    final latestDate = DateTime.parse(sortedDates.last);
    final cycleStartDate = latestDate.subtract(const Duration(days: 20)); // 21 days total
    
    // Count completed days in current 21-day cycle
    int progress = 0;
    for (int i = 0; i < 21; i++) {
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
    return getCurrentCycleProgress() >= 21;
  }
  
  void continueToNextCycle() {
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'completedDates': completedDates,
    'currentCycle': currentCycle,
    'isCompleted': isCompleted,
  };

  static Habit fromJson(Map<String, dynamic> json) => Habit(
    id: json['id'],
    name: json['name'],
    isActive: json['isActive'] ?? true,
    createdAt: DateTime.parse(json['createdAt']),
    completedDates: List<String>.from(json['completedDates'] ?? []),
    currentCycle: json['currentCycle'] ?? 1,
    isCompleted: json['isCompleted'] ?? false,
  );
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