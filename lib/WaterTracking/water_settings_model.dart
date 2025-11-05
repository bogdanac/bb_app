import 'package:shared_preferences/shared_preferences.dart';

class WaterSettings {
  final int dailyGoal; // in ml
  final int amountPerTap; // in ml
  final int dayStartHour; // 0-23
  final int dayEndHour; // 0-23
  final bool notify20Enabled;
  final bool notify40Enabled;
  final bool notify60Enabled;
  final bool notify80Enabled;

  const WaterSettings({
    this.dailyGoal = 1500,
    this.amountPerTap = 125,
    this.dayStartHour = 9,
    this.dayEndHour = 22,
    this.notify20Enabled = true,
    this.notify40Enabled = true,
    this.notify60Enabled = true,
    this.notify80Enabled = true,
  });

  // Calculate threshold time for a given percentage
  DateTime getThresholdTime(int percentage) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day, dayStartHour);
    final dayEnd = DateTime(now.year, now.month, now.day, dayEndHour);

    final totalMinutes = dayEnd.difference(dayStart).inMinutes;
    final thresholdMinutes = (totalMinutes * percentage / 100).round();

    return dayStart.add(Duration(minutes: thresholdMinutes));
  }

  // Calculate threshold amount for a given percentage (rounded up to nearest 100)
  int getThresholdAmount(int percentage) {
    final rawAmount = (dailyGoal * percentage / 100);
    return ((rawAmount / 100).ceil() * 100).toInt();
  }

  // Check if notification is enabled for a threshold
  bool isNotificationEnabled(int percentage) {
    switch (percentage) {
      case 20:
        return notify20Enabled;
      case 40:
        return notify40Enabled;
      case 60:
        return notify60Enabled;
      case 80:
        return notify80Enabled;
      default:
        return false;
    }
  }

  WaterSettings copyWith({
    int? dailyGoal,
    int? amountPerTap,
    int? dayStartHour,
    int? dayEndHour,
    bool? notify20Enabled,
    bool? notify40Enabled,
    bool? notify60Enabled,
    bool? notify80Enabled,
  }) {
    return WaterSettings(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      amountPerTap: amountPerTap ?? this.amountPerTap,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      dayEndHour: dayEndHour ?? this.dayEndHour,
      notify20Enabled: notify20Enabled ?? this.notify20Enabled,
      notify40Enabled: notify40Enabled ?? this.notify40Enabled,
      notify60Enabled: notify60Enabled ?? this.notify60Enabled,
      notify80Enabled: notify80Enabled ?? this.notify80Enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyGoal': dailyGoal,
      'amountPerTap': amountPerTap,
      'dayStartHour': dayStartHour,
      'dayEndHour': dayEndHour,
      'notify20Enabled': notify20Enabled,
      'notify40Enabled': notify40Enabled,
      'notify60Enabled': notify60Enabled,
      'notify80Enabled': notify80Enabled,
    };
  }

  factory WaterSettings.fromMap(Map<String, dynamic> map) {
    return WaterSettings(
      dailyGoal: map['dailyGoal'] ?? 1500,
      amountPerTap: map['amountPerTap'] ?? 125,
      dayStartHour: map['dayStartHour'] ?? 9,
      dayEndHour: map['dayEndHour'] ?? 22,
      notify20Enabled: map['notify20Enabled'] ?? true,
      notify40Enabled: map['notify40Enabled'] ?? true,
      notify60Enabled: map['notify60Enabled'] ?? true,
      notify80Enabled: map['notify80Enabled'] ?? true,
    );
  }

  // Save to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', dailyGoal);
    await prefs.setInt('water_amount_per_tap', amountPerTap);
    await prefs.setInt('water_day_start_hour', dayStartHour);
    await prefs.setInt('water_day_end_hour', dayEndHour);
    await prefs.setBool('water_notify_20_enabled', notify20Enabled);
    await prefs.setBool('water_notify_40_enabled', notify40Enabled);
    await prefs.setBool('water_notify_60_enabled', notify60Enabled);
    await prefs.setBool('water_notify_80_enabled', notify80Enabled);
  }

  // Load from SharedPreferences
  static Future<WaterSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WaterSettings(
      dailyGoal: prefs.getInt('water_goal') ?? 1500,
      amountPerTap: prefs.getInt('water_amount_per_tap') ?? 125,
      dayStartHour: prefs.getInt('water_day_start_hour') ?? 9,
      dayEndHour: prefs.getInt('water_day_end_hour') ?? 22,
      notify20Enabled: prefs.getBool('water_notify_20_enabled') ?? true,
      notify40Enabled: prefs.getBool('water_notify_40_enabled') ?? true,
      notify60Enabled: prefs.getBool('water_notify_60_enabled') ?? true,
      notify80Enabled: prefs.getBool('water_notify_80_enabled') ?? true,
    );
  }
}
