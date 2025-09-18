import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class IntercourseRecord {
  final String id;
  final DateTime date;
  final bool hadOrgasm;
  final bool wasProtected;

  IntercourseRecord({
    required this.id,
    required this.date,
    required this.hadOrgasm,
    required this.wasProtected,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'hadOrgasm': hadOrgasm,
      'wasProtected': wasProtected,
    };
  }

  factory IntercourseRecord.fromJson(Map<String, dynamic> json) {
    return IntercourseRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      hadOrgasm: json['hadOrgasm'],
      wasProtected: json['wasProtected'],
    );
  }
}

class IntercourseService {
  static const String _storageKey = 'intercourse_records';

  static Future<List<IntercourseRecord>> loadIntercourseRecords() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Handle potential type mismatch - data might be stored as String instead of List<String>
    List<String> recordsJson;
    try {
      recordsJson = prefs.getStringList(_storageKey) ?? [];
    } catch (e) {
      // If getStringList fails, try to get as String and clear corrupted data
      if (kDebugMode) {
        print('Warning: Intercourse data type mismatch, clearing corrupted data');
      }
      await prefs.remove(_storageKey);
      recordsJson = [];
    }
    
    return recordsJson.map((jsonString) {
      final json = jsonDecode(jsonString);
      return IntercourseRecord.fromJson(json);
    }).toList();
  }

  static Future<void> saveIntercourseRecords(List<IntercourseRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList(_storageKey, recordsJson);
  }

  static Future<void> addIntercourseRecord(IntercourseRecord record) async {
    final records = await loadIntercourseRecords();
    records.add(record);
    records.sort((a, b) => a.date.compareTo(b.date));
    await saveIntercourseRecords(records);
  }

  static Future<void> updateIntercourseRecord(IntercourseRecord updatedRecord) async {
    final records = await loadIntercourseRecords();
    final index = records.indexWhere((record) => record.id == updatedRecord.id);
    if (index != -1) {
      records[index] = updatedRecord;
      records.sort((a, b) => a.date.compareTo(b.date));
      await saveIntercourseRecords(records);
    }
  }

  static Future<void> deleteIntercourseRecord(String id) async {
    final records = await loadIntercourseRecords();
    records.removeWhere((record) => record.id == id);
    await saveIntercourseRecords(records);
  }

  static Future<List<IntercourseRecord>> getIntercourseForDate(DateTime date) async {
    final records = await loadIntercourseRecords();
    return records.where((record) {
      return record.date.year == date.year &&
          record.date.month == date.month &&
          record.date.day == date.day;
    }).toList();
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}