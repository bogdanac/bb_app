import 'package:flutter/material.dart';

/// Type of interaction with a friend
enum MeetingType {
  metInPerson, // Met face to face - full recharge
  called, // Phone/video call - 75% recharge
  texted, // Text/message - 50% recharge
}

extension MeetingTypeExtension on MeetingType {
  String get label {
    switch (this) {
      case MeetingType.metInPerson:
        return 'Met in person';
      case MeetingType.called:
        return 'Called';
      case MeetingType.texted:
        return 'Texted';
    }
  }

  IconData get icon {
    switch (this) {
      case MeetingType.metInPerson:
        return Icons.people_rounded;
      case MeetingType.called:
        return Icons.call_rounded;
      case MeetingType.texted:
        return Icons.chat_rounded;
    }
  }

  /// Battery effect for this meeting type:
  /// metInPerson → sets battery to 1.0 (full recharge)
  /// called / texted → amount ADDED to current battery
  double get batteryBoost {
    switch (this) {
      case MeetingType.metInPerson:
        return 1.0; // Full recharge to 100%
      case MeetingType.called:
        return 0.25; // +25% added to current battery
      case MeetingType.texted:
        return 0.10; // +10% added to current battery
    }
  }

  Color get color {
    switch (this) {
      case MeetingType.metInPerson:
        return Colors.green;
      case MeetingType.called:
        return Colors.blue;
      case MeetingType.texted:
        return Colors.orange;
    }
  }
}

/// Represents a meeting record with a friend
class Meeting {
  final DateTime date;
  final MeetingType type;
  final String? notes;

  Meeting({
    required this.date,
    required this.type,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.index,
      'notes': notes,
    };
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      date: DateTime.parse(json['date'] as String),
      type: MeetingType.values[json['type'] as int],
      notes: json['notes'] as String?,
    );
  }
}

/// Represents a friend with friendship battery tracking
class Friend {
  final String id;
  String name;
  Color color;
  double battery; // 0.0 to 1.0 (0% to 100%)
  DateTime lastUpdated;
  DateTime createdAt;
  List<Meeting> meetings;
  bool isArchived;
  String? notes; // Personal notes about the friend
  DateTime? birthday; // Optional birthday for reminders
  bool notifyLowBattery; // Notify when battery drops below threshold
  bool notifyBirthday; // Notify before birthday

  Friend({
    required this.id,
    required this.name,
    required this.color,
    required this.battery,
    required this.lastUpdated,
    required this.createdAt,
    List<Meeting>? meetings,
    this.isArchived = false,
    this.notes,
    this.birthday,
    this.notifyLowBattery = true,
    this.notifyBirthday = true,
  }) : meetings = meetings ?? [];

  /// Calculate current battery level based on daily decay
  double get currentBattery {
    final now = DateTime.now();
    final daysSinceUpdate = now.difference(lastUpdated).inDays;

    // Decrease 1% per day
    final decayedBattery = battery - (daysSinceUpdate * 0.01);

    // Clamp between 0 and 1
    return decayedBattery.clamp(0.0, 1.0);
  }

  /// Get battery percentage as integer
  int get batteryPercentage => (currentBattery * 100).round();

  /// Get color based on battery level
  Color get batteryColor {
    final current = currentBattery;
    if (current >= 0.7) {
      return Colors.green;
    } else if (current >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Get total number of meetings
  int get totalMeetings => meetings.length;

  /// Get in-person meetings count
  int get inPersonMeetings =>
      meetings.where((m) => m.type == MeetingType.metInPerson).length;

  /// Get call meetings count
  int get callMeetings =>
      meetings.where((m) => m.type == MeetingType.called).length;

  /// Get text meetings count
  int get textMeetings =>
      meetings.where((m) => m.type == MeetingType.texted).length;

  /// Get the most recent meeting date of ANY type
  DateTime? get lastMeetingDate {
    if (meetings.isEmpty) return null;
    meetings.sort((a, b) => b.date.compareTo(a.date));
    return meetings.first.date;
  }

  /// Get the most recent IN-PERSON meeting date (used for "Last seen" display)
  DateTime? get lastSeenInPersonDate {
    final inPerson = meetings.where((m) => m.type == MeetingType.metInPerson).toList();
    if (inPerson.isEmpty) return null;
    inPerson.sort((a, b) => b.date.compareTo(a.date));
    return inPerson.first.date;
  }

  /// Add a meeting record and update battery accordingly:
  /// - metInPerson → full recharge (100%), decay restarts from meeting date
  /// - called / texted → add boost to current battery, decay restarts from interaction date
  void addMeeting(Meeting meeting) {
    meetings.add(meeting);
    if (meeting.type == MeetingType.metInPerson) {
      battery = 1.0;
      lastUpdated = meeting.date;
    } else {
      // Compute current decayed battery, then add the boost
      battery = (currentBattery + meeting.type.batteryBoost).clamp(0.0, 1.0);
      lastUpdated = meeting.date;
    }
  }

  /// Update battery level manually (e.g. from slider)
  void updateBattery(double newBattery) {
    battery = newBattery.clamp(0.0, 1.0);
    lastUpdated = DateTime.now();
  }

  /// Refresh battery to current calculated value (does not update lastUpdated)
  void refreshBattery() {
    battery = currentBattery;
    // Note: do NOT update lastUpdated here - it should only change when user presses heart button
  }

  /// Archive this friend
  void archive() {
    isArchived = true;
  }

  /// Unarchive this friend
  void unarchive() {
    isArchived = false;
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'battery': battery,
      'lastUpdated': lastUpdated.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'meetings': meetings.map((m) => m.toJson()).toList(),
      'isArchived': isArchived,
      'notes': notes,
      'birthday': birthday?.toIso8601String(),
      'notifyLowBattery': notifyLowBattery,
      'notifyBirthday': notifyBirthday,
    };
  }

  /// Create from JSON
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      battery: (json['battery'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      meetings: (json['meetings'] as List<dynamic>?)
              ?.map((m) => Meeting.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      isArchived: json['isArchived'] as bool? ?? false,
      notes: json['notes'] as String?,
      birthday: json['birthday'] != null ? DateTime.parse(json['birthday'] as String) : null,
      notifyLowBattery: json['notifyLowBattery'] as bool? ?? true,
      notifyBirthday: json['notifyBirthday'] as bool? ?? true,
    );
  }

  /// Create a copy with optional modifications
  Friend copyWith({
    String? id,
    String? name,
    Color? color,
    double? battery,
    DateTime? lastUpdated,
    DateTime? createdAt,
    List<Meeting>? meetings,
    bool? isArchived,
    String? notes,
    DateTime? birthday,
    bool? notifyLowBattery,
    bool? notifyBirthday,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      battery: battery ?? this.battery,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
      meetings: meetings ?? this.meetings,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      birthday: birthday ?? this.birthday,
      notifyLowBattery: notifyLowBattery ?? this.notifyLowBattery,
      notifyBirthday: notifyBirthday ?? this.notifyBirthday,
    );
  }
}
