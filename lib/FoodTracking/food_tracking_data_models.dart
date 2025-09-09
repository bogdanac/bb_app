import 'dart:convert';

enum FoodType { healthy, processed }

class FoodEntry {
  final String id;
  final FoodType type;
  final DateTime timestamp;
  final String? note;

  FoodEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'note': note,
    };
  }

  static FoodEntry fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'],
      type: FoodType.values.firstWhere((e) => e.name == json['type']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      note: json['note'],
    );
  }

  String toJsonString() => jsonEncode(toJson());
  
  static FoodEntry fromJsonString(String jsonString) => 
      fromJson(jsonDecode(jsonString));
}