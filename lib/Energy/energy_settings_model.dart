/// Skip day configuration modes
enum SkipDayMode {
  weekly,       // 1 skip per week (default)
  biweekly,     // 1 skip every 2 weeks
  perCycle,     // 1 skip per menstrual cycle (~28 days)
  unlimited,    // Unlimited skips (no restrictions)
  disabled,     // No skips allowed
}

/// Energy Settings Model - Stores user preferences for Body Battery & Flow tracking
class EnergySettings {
  // Battery Settings (percentage-based: 5%-120%)
  final int minBattery;    // Minimum battery % on late luteal phase (default: 5%)
  final int maxBattery;    // Maximum battery % on ovulation day (default: 120%)

  // Flow Settings (productivity points)
  final int minFlowGoal;   // Minimum flow goal on low-energy days (default: 5)
  final int maxFlowGoal;   // Maximum flow goal on high-energy days (default: 20)

  // Achievement Tracking
  final int currentStreak;   // Current days streak of meeting flow goals
  final int longestStreak;   // Longest streak ever achieved
  final int personalRecord;  // Personal best flow points in a single day

  // Streak Skip Tracking
  final DateTime? lastSkipDate;     // Last date a skip was used
  final DateTime? lastStreakDate;   // Last date that counted towards streak
  final SkipDayMode skipDayMode;    // How often skips are allowed
  final bool autoUseSkip;           // Automatically use skip when streak would break

  // Skip notification tracking
  final DateTime? pendingSkipNotification;  // Date when skip was auto-used, needs notification

  // Sleep schedule settings
  final int wakeHour;   // Hour user typically wakes up (0-23, default: 8)
  final int sleepHour;  // Hour user typically goes to sleep (0-23, default: 22)

  // UI settings
  final bool showMorningPrompt;  // Show morning battery prompt dialog (default: true)

  const EnergySettings({
    this.minBattery = 5,        // Default: 5% on low energy days
    this.maxBattery = 120,      // Default: 120% on high energy days
    this.minFlowGoal = 5,       // Default: 5 flow points minimum
    this.maxFlowGoal = 20,      // Default: 20 flow points maximum
    this.currentStreak = 0,     // Default: no streak
    this.longestStreak = 0,     // Default: no longest streak
    this.personalRecord = 0,    // Default: no PR yet
    this.lastSkipDate,
    this.lastStreakDate,
    this.skipDayMode = SkipDayMode.weekly,
    this.autoUseSkip = true,
    this.pendingSkipNotification,
    this.wakeHour = 8,
    this.sleepHour = 22,
    this.showMorningPrompt = true,
  });

  Map<String, dynamic> toJson() => {
    'minBattery': minBattery,
    'maxBattery': maxBattery,
    'minFlowGoal': minFlowGoal,
    'maxFlowGoal': maxFlowGoal,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'personalRecord': personalRecord,
    'lastSkipDate': lastSkipDate?.toIso8601String(),
    'lastStreakDate': lastStreakDate?.toIso8601String(),
    'skipDayMode': skipDayMode.name,
    'autoUseSkip': autoUseSkip,
    'pendingSkipNotification': pendingSkipNotification?.toIso8601String(),
    'wakeHour': wakeHour,
    'sleepHour': sleepHour,
    'showMorningPrompt': showMorningPrompt,
  };

  static EnergySettings fromJson(Map<String, dynamic> json) {
    // Handle migration from old field names
    final lowEnergyPeak = json['lowEnergyPeak'];
    final highEnergyPeak = json['highEnergyPeak'];
    final currentStreak = json['currentStreak'] ?? 0;

    // Parse skip day mode with fallback
    SkipDayMode skipMode = SkipDayMode.weekly;
    if (json['skipDayMode'] != null) {
      skipMode = SkipDayMode.values.firstWhere(
        (e) => e.name == json['skipDayMode'],
        orElse: () => SkipDayMode.weekly,
      );
    }

    return EnergySettings(
      minBattery: json['minBattery'] ?? lowEnergyPeak ?? 5,
      maxBattery: json['maxBattery'] ?? highEnergyPeak ?? 120,
      minFlowGoal: json['minFlowGoal'] ?? lowEnergyPeak ?? 5,
      maxFlowGoal: json['maxFlowGoal'] ?? highEnergyPeak ?? 20,
      currentStreak: currentStreak,
      // Migration: if no longestStreak, use currentStreak as baseline
      longestStreak: json['longestStreak'] ?? currentStreak,
      personalRecord: json['personalRecord'] ?? 0,
      lastSkipDate: json['lastSkipDate'] != null ? DateTime.parse(json['lastSkipDate']) : null,
      lastStreakDate: json['lastStreakDate'] != null ? DateTime.parse(json['lastStreakDate']) : null,
      skipDayMode: skipMode,
      autoUseSkip: json['autoUseSkip'] ?? true,
      pendingSkipNotification: json['pendingSkipNotification'] != null
          ? DateTime.parse(json['pendingSkipNotification'])
          : null,
      wakeHour: json['wakeHour'] ?? 8,
      sleepHour: json['sleepHour'] ?? 22,
      showMorningPrompt: json['showMorningPrompt'] ?? true,
    );
  }

  EnergySettings copyWith({
    int? minBattery,
    int? maxBattery,
    int? minFlowGoal,
    int? maxFlowGoal,
    int? currentStreak,
    int? longestStreak,
    int? personalRecord,
    DateTime? lastSkipDate,
    DateTime? lastStreakDate,
    SkipDayMode? skipDayMode,
    bool? autoUseSkip,
    DateTime? pendingSkipNotification,
    bool clearLastSkipDate = false,
    bool clearLastStreakDate = false,
    bool clearPendingSkipNotification = false,
    int? wakeHour,
    int? sleepHour,
    bool? showMorningPrompt,
  }) {
    return EnergySettings(
      minBattery: minBattery ?? this.minBattery,
      maxBattery: maxBattery ?? this.maxBattery,
      minFlowGoal: minFlowGoal ?? this.minFlowGoal,
      maxFlowGoal: maxFlowGoal ?? this.maxFlowGoal,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      personalRecord: personalRecord ?? this.personalRecord,
      lastSkipDate: clearLastSkipDate ? null : (lastSkipDate ?? this.lastSkipDate),
      lastStreakDate: clearLastStreakDate ? null : (lastStreakDate ?? this.lastStreakDate),
      skipDayMode: skipDayMode ?? this.skipDayMode,
      autoUseSkip: autoUseSkip ?? this.autoUseSkip,
      pendingSkipNotification: clearPendingSkipNotification
          ? null
          : (pendingSkipNotification ?? this.pendingSkipNotification),
      wakeHour: wakeHour ?? this.wakeHour,
      sleepHour: sleepHour ?? this.sleepHour,
      showMorningPrompt: showMorningPrompt ?? this.showMorningPrompt,
    );
  }

  /// Get the number of waking hours based on wake and sleep settings
  int get wakingHours {
    if (sleepHour > wakeHour) {
      return sleepHour - wakeHour;
    } else {
      // Handle overnight (e.g., wake at 22, sleep at 6)
      return (24 - wakeHour) + sleepHour;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnergySettings &&
          runtimeType == other.runtimeType &&
          minBattery == other.minBattery &&
          maxBattery == other.maxBattery &&
          minFlowGoal == other.minFlowGoal &&
          maxFlowGoal == other.maxFlowGoal &&
          currentStreak == other.currentStreak &&
          longestStreak == other.longestStreak &&
          personalRecord == other.personalRecord &&
          lastSkipDate == other.lastSkipDate &&
          lastStreakDate == other.lastStreakDate &&
          skipDayMode == other.skipDayMode &&
          autoUseSkip == other.autoUseSkip &&
          pendingSkipNotification == other.pendingSkipNotification &&
          wakeHour == other.wakeHour &&
          sleepHour == other.sleepHour &&
          showMorningPrompt == other.showMorningPrompt;

  @override
  int get hashCode =>
      minBattery.hashCode ^
      maxBattery.hashCode ^
      minFlowGoal.hashCode ^
      maxFlowGoal.hashCode ^
      currentStreak.hashCode ^
      longestStreak.hashCode ^
      personalRecord.hashCode ^
      lastSkipDate.hashCode ^
      lastStreakDate.hashCode ^
      skipDayMode.hashCode ^
      autoUseSkip.hashCode ^
      pendingSkipNotification.hashCode ^
      wakeHour.hashCode ^
      sleepHour.hashCode ^
      showMorningPrompt.hashCode;
}

/// Daily energy record for Body Battery & Flow tracking
class DailyEnergyRecord {
  final DateTime date;

  // Body Battery Metrics (percentage-based)
  final int startingBattery;  // Battery % at start of day (5-120%)
  final int currentBattery;   // Current battery % (can go negative or above 120%)

  // Flow Metrics (productivity points)
  final int flowPoints;       // Current flow points earned today
  final int flowGoal;         // Today's flow goal based on cycle phase
  final bool isGoalMet;       // Whether flow goal was achieved
  final bool isPR;            // Whether today set a new personal record

  // Legacy/Metadata
  final String menstrualPhase;
  final int cycleDayNumber;
  final List<EnergyConsumptionEntry> entries;

  const DailyEnergyRecord({
    required this.date,
    this.startingBattery = 100,
    required this.currentBattery,
    this.flowPoints = 0,
    required this.flowGoal,
    this.isGoalMet = false,
    this.isPR = false,
    required this.menstrualPhase,
    required this.cycleDayNumber,
    this.entries = const [],
  });

  // Battery percentage change from start
  int get batteryChange => currentBattery - startingBattery;

  // Flow progress percentage
  double get flowPercentage => flowGoal > 0 ? (flowPoints / flowGoal * 100).clamp(0, 200) : 0;

  double get completionPercentage => flowPercentage;

  EnergyCompletionLevel get completionLevel {
    final percentage = flowPercentage;
    if (percentage <= 50) return EnergyCompletionLevel.low;
    if (percentage <= 80) return EnergyCompletionLevel.moderate;
    if (percentage <= 100) return EnergyCompletionLevel.high;
    return EnergyCompletionLevel.over;
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'startingBattery': startingBattery,
    'currentBattery': currentBattery,
    'flowPoints': flowPoints,
    'flowGoal': flowGoal,
    'isGoalMet': isGoalMet,
    'isPR': isPR,
    'menstrualPhase': menstrualPhase,
    'cycleDayNumber': cycleDayNumber,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  static DailyEnergyRecord fromJson(Map<String, dynamic> json) {
    // Handle migration from old format

    return DailyEnergyRecord(
      date: DateTime.parse(json['date']),
      startingBattery: json['startingBattery'] ?? 100,
      currentBattery: json['currentBattery'] ?? json['startingBattery'] ?? 100,
      flowPoints: json['flowPoints'] ?? 0,
      flowGoal: json['flowGoal'] ?? json['energyGoal'] ?? 10,
      isGoalMet: json['isGoalMet'] ?? false,
      isPR: json['isPR'] ?? false,
      menstrualPhase: json['menstrualPhase'] ?? '',
      cycleDayNumber: json['cycleDayNumber'] ?? 0,
      entries: (json['entries'] as List<dynamic>?)
          ?.map((e) => EnergyConsumptionEntry.fromJson(e))
          .toList() ?? [],
    );
  }

  DailyEnergyRecord copyWith({
    DateTime? date,
    int? startingBattery,
    int? currentBattery,
    int? flowPoints,
    int? flowGoal,
    bool? isGoalMet,
    bool? isPR,
    String? menstrualPhase,
    int? cycleDayNumber,
    List<EnergyConsumptionEntry>? entries,
  }) {
    return DailyEnergyRecord(
      date: date ?? this.date,
      startingBattery: startingBattery ?? this.startingBattery,
      currentBattery: currentBattery ?? this.currentBattery,
      flowPoints: flowPoints ?? this.flowPoints,
      flowGoal: flowGoal ?? this.flowGoal,
      isGoalMet: isGoalMet ?? this.isGoalMet,
      isPR: isPR ?? this.isPR,
      menstrualPhase: menstrualPhase ?? this.menstrualPhase,
      cycleDayNumber: cycleDayNumber ?? this.cycleDayNumber,
      entries: entries ?? this.entries,
    );
  }
}

/// Individual energy consumption entry
class EnergyConsumptionEntry {
  final String id;
  final String title;
  final int energyLevel;
  final DateTime completedAt;
  final EnergySourceType sourceType;

  const EnergyConsumptionEntry({
    required this.id,
    required this.title,
    required this.energyLevel,
    required this.completedAt,
    required this.sourceType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'energyLevel': energyLevel,
    'completedAt': completedAt.toIso8601String(),
    'sourceType': sourceType.name,
  };

  static EnergyConsumptionEntry fromJson(Map<String, dynamic> json) => EnergyConsumptionEntry(
    id: json['id'],
    title: json['title'],
    energyLevel: json['energyLevel'],
    completedAt: DateTime.parse(json['completedAt']),
    sourceType: EnergySourceType.values.firstWhere(
      (e) => e.name == json['sourceType'],
      orElse: () => EnergySourceType.task,
    ),
  );
}

/// Types of energy consumption sources
enum EnergySourceType {
  task,
  routineStep,
}

/// Energy completion levels for color coding
enum EnergyCompletionLevel {
  low,      // Green - under 50% of goal
  moderate, // Yellow - 50-80% of goal
  high,     // Orange - 80-100% of goal
  over,     // Red - over 100% of goal
}
