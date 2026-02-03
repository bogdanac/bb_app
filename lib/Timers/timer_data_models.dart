enum TimerSessionType { countdown, pomodoro, activity }

class Activity {
  final String id;
  final String name;
  final DateTime createdAt;

  Activity({
    required this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  static Activity fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
    );
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
