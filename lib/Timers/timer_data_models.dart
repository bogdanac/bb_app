enum TimerSessionType { countdown, pomodoro, activity }

/// Energy mode for activities - affects battery per 25 min of work
enum ActivityEnergyMode {
  draining,   // -5% battery per 25 min
  neutral,    // 0% battery change (default)
  recharging, // +5% battery per 25 min
}

class Activity {
  final String id;
  final String name;
  final DateTime createdAt;
  final ActivityEnergyMode energyMode; // Affects battery: draining/neutral/recharging

  Activity({
    required this.id,
    required this.name,
    DateTime? createdAt,
    this.energyMode = ActivityEnergyMode.neutral,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'energyMode': energyMode.name,
      };

  static Activity fromJson(Map<String, dynamic> json) {
    // Handle migration from old energyLevel field
    ActivityEnergyMode mode = ActivityEnergyMode.neutral;
    if (json['energyMode'] != null) {
      mode = ActivityEnergyMode.values.firstWhere(
        (e) => e.name == json['energyMode'],
        orElse: () => ActivityEnergyMode.neutral,
      );
    } else if (json['energyLevel'] != null) {
      // Migrate from old int-based energyLevel
      final level = json['energyLevel'] as int;
      if (level > 0) {
        mode = ActivityEnergyMode.recharging;
      } else if (level < 0) {
        mode = ActivityEnergyMode.draining;
      }
    }
    return Activity(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      energyMode: mode,
    );
  }

  Activity copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    ActivityEnergyMode? energyMode,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      energyMode: energyMode ?? this.energyMode,
    );
  }

  /// Get battery change per 25 min based on energy mode
  int get batteryChangePer25Min {
    switch (energyMode) {
      case ActivityEnergyMode.draining:
        return -5;
      case ActivityEnergyMode.neutral:
        return 0;
      case ActivityEnergyMode.recharging:
        return 5;
    }
  }
}

class TimerSession {
  final String id;
  final String activityId;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final TimerSessionType type;

  TimerSession({
    required this.id,
    required this.activityId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'activityId': activityId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'type': type.name,
      };

  static TimerSession fromJson(Map<String, dynamic> json) {
    return TimerSession(
      id: json['id'],
      activityId: json['activityId'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      duration: Duration(seconds: json['durationSeconds']),
      type: TimerSessionType.values.byName(json['type']),
    );
  }
}
