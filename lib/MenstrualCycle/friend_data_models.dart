import 'package:flutter/material.dart';

/// Type of meeting with a friend
enum MeetingType {
  intentional, // Planned meeting
  casual, // Casual encounter
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

  /// Get intentional meetings count
  int get intentionalMeetings =>
      meetings.where((m) => m.type == MeetingType.intentional).length;

  /// Get casual meetings count
  int get casualMeetings =>
      meetings.where((m) => m.type == MeetingType.casual).length;

  /// Get last meeting date
  DateTime? get lastMeetingDate {
    if (meetings.isEmpty) return null;
    meetings.sort((a, b) => b.date.compareTo(a.date));
    return meetings.first.date;
  }

  /// Add a meeting record
  void addMeeting(Meeting meeting) {
    meetings.add(meeting);
    updateBattery(1.0); // Recharge battery to 100%
  }

  /// Update battery level manually
  void updateBattery(double newBattery) {
    battery = newBattery.clamp(0.0, 1.0);
    lastUpdated = DateTime.now();
  }

  /// Refresh battery to current calculated value
  void refreshBattery() {
    battery = currentBattery;
    lastUpdated = DateTime.now();
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
    );
  }
}
