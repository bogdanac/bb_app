import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'friend_data_models.dart';
import '../Services/firebase_backup_service.dart';
import '../shared/error_logger.dart';

class FriendService {
  static const String _friendsKey = 'circle_of_friends';

  /// Load all friends from SharedPreferences
  static Future<List<Friend>> loadFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final friendsJson = prefs.getStringList(_friendsKey) ?? [];

    if (friendsJson.isEmpty) {
      return [];
    }

    try {
      return friendsJson
          .map((json) => Friend.fromJson(jsonDecode(json)))
          .toList();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FriendService.loadFriends',
        error: 'Error loading friends: $e',
        stackTrace: stackTrace.toString(),
      );
      return [];
    }
  }

  /// Save friends to SharedPreferences
  static Future<void> saveFriends(List<Friend> friends) async {
    final prefs = await SharedPreferences.getInstance();
    final friendsJson = friends
        .map((friend) => jsonEncode(friend.toJson()))
        .toList();
    await prefs.setStringList(_friendsKey, friendsJson);

    // Backup to Firebase
    FirebaseBackupService.triggerBackup();
  }

  /// Add a new friend
  static Future<void> addFriend(Friend friend, List<Friend> friends) async {
    friends.add(friend);
    await saveFriends(friends);
  }

  /// Update an existing friend
  static Future<void> updateFriend(Friend updatedFriend, List<Friend> friends) async {
    final index = friends.indexWhere((f) => f.id == updatedFriend.id);
    if (index != -1) {
      friends[index] = updatedFriend;
      await saveFriends(friends);
    }
  }

  /// Delete a friend
  static Future<void> deleteFriend(String friendId, List<Friend> friends) async {
    friends.removeWhere((f) => f.id == friendId);
    await saveFriends(friends);
  }

  /// Reorder friends (for drag and drop)
  static Future<void> reorderFriends(int oldIndex, int newIndex, List<Friend> friends) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final friend = friends.removeAt(oldIndex);
    friends.insert(newIndex, friend);
    await saveFriends(friends);
  }

  /// Refresh all friends' battery levels based on decay
  static Future<void> refreshAllBatteries(List<Friend> friends) async {
    for (var friend in friends) {
      friend.refreshBattery();
    }
    await saveFriends(friends);
  }

  /// Update a friend's battery level manually
  static Future<void> updateFriendBattery(String friendId, double newBattery, List<Friend> friends) async {
    final friend = friends.firstWhere((f) => f.id == friendId);
    friend.updateBattery(newBattery);
    await saveFriends(friends);
  }
}
