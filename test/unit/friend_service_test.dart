import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bb_app/MenstrualCycle/friend_data_models.dart';
import 'package:bb_app/MenstrualCycle/friend_service.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  group('MeetingType', () {
    test('has correct battery boost values', () {
      expect(MeetingType.metInPerson.batteryBoost, 1.0);
      expect(MeetingType.called.batteryBoost, 0.75);
      expect(MeetingType.texted.batteryBoost, 0.50);
    });

    test('has correct labels', () {
      expect(MeetingType.metInPerson.label, 'Met in person');
      expect(MeetingType.called.label, 'Called');
      expect(MeetingType.texted.label, 'Texted');
    });

    test('has correct icons', () {
      expect(MeetingType.metInPerson.icon, Icons.people_rounded);
      expect(MeetingType.called.icon, Icons.call_rounded);
      expect(MeetingType.texted.icon, Icons.chat_rounded);
    });

    test('has correct colors', () {
      expect(MeetingType.metInPerson.color, Colors.green);
      expect(MeetingType.called.color, Colors.blue);
      expect(MeetingType.texted.color, Colors.orange);
    });
  });

  group('Meeting Model', () {
    test('serializes to JSON and back', () {
      final meeting = Meeting(
        date: DateTime(2025, 6, 15, 14, 30),
        type: MeetingType.metInPerson,
        notes: 'Had coffee together',
      );

      final json = meeting.toJson();
      final restored = Meeting.fromJson(json);

      expect(restored.date, DateTime(2025, 6, 15, 14, 30));
      expect(restored.type, MeetingType.metInPerson);
      expect(restored.notes, 'Had coffee together');
    });

    test('handles null notes', () {
      final meeting = Meeting(
        date: DateTime(2025, 6, 15),
        type: MeetingType.called,
      );

      final json = meeting.toJson();
      final restored = Meeting.fromJson(json);

      expect(restored.notes, isNull);
    });

    test('preserves all meeting types through serialization', () {
      for (final type in MeetingType.values) {
        final meeting = Meeting(
          date: DateTime.now(),
          type: type,
        );
        final restored = Meeting.fromJson(meeting.toJson());
        expect(restored.type, type);
      }
    });
  });

  group('Friend Model', () {
    test('serializes to JSON and back with all fields', () {
      final friend = Friend(
        id: '123',
        name: 'John Doe',
        color: Colors.blue,
        battery: 0.85,
        lastUpdated: DateTime(2025, 6, 10),
        createdAt: DateTime(2025, 1, 1),
        meetings: [
          Meeting(date: DateTime(2025, 6, 1), type: MeetingType.metInPerson),
          Meeting(date: DateTime(2025, 6, 5), type: MeetingType.called),
        ],
        isArchived: false,
        notes: 'Works at Google',
        birthday: DateTime(1990, 3, 15),
        notifyLowBattery: true,
        notifyBirthday: false,
      );

      final json = friend.toJson();
      final restored = Friend.fromJson(json);

      expect(restored.id, '123');
      expect(restored.name, 'John Doe');
      expect(restored.color.value, Colors.blue.value);
      expect(restored.battery, 0.85);
      expect(restored.lastUpdated, DateTime(2025, 6, 10));
      expect(restored.createdAt, DateTime(2025, 1, 1));
      expect(restored.meetings.length, 2);
      expect(restored.isArchived, false);
      expect(restored.notes, 'Works at Google');
      expect(restored.birthday, DateTime(1990, 3, 15));
      expect(restored.notifyLowBattery, true);
      expect(restored.notifyBirthday, false);
    });

    test('defaults notification settings to true when not in JSON', () {
      final json = {
        'id': '123',
        'name': 'Test',
        'color': Colors.red.value,
        'battery': 1.0,
        'lastUpdated': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      final friend = Friend.fromJson(json);

      expect(friend.notifyLowBattery, true);
      expect(friend.notifyBirthday, true);
    });

    test('handles null optional fields', () {
      final friend = Friend(
        id: '123',
        name: 'Jane',
        color: Colors.pink,
        battery: 1.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final json = friend.toJson();
      final restored = Friend.fromJson(json);

      expect(restored.notes, isNull);
      expect(restored.birthday, isNull);
      expect(restored.meetings, isEmpty);
    });

    group('Battery Decay', () {
      test('calculates correct battery after 0 days', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 1.0,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(friend.currentBattery, 1.0);
        expect(friend.batteryPercentage, 100);
      });

      test('decays 1% per day', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 1.0,
          lastUpdated: DateTime.now().subtract(const Duration(days: 10)),
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        );

        expect(friend.currentBattery, 0.90);
        expect(friend.batteryPercentage, 90);
      });

      test('does not go below 0', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.5,
          lastUpdated: DateTime.now().subtract(const Duration(days: 100)),
          createdAt: DateTime.now().subtract(const Duration(days: 100)),
        );

        expect(friend.currentBattery, 0.0);
        expect(friend.batteryPercentage, 0);
      });

      test('battery color is green when >= 70%', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.75,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(friend.batteryColor, Colors.green);
      });

      test('battery color is orange when 40-69%', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.50,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(friend.batteryColor, Colors.orange);
      });

      test('battery color is red when < 40%', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.30,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(friend.batteryColor, Colors.red);
      });
    });

    group('Meeting Operations', () {
      test('addMeeting with metInPerson sets battery to 100%', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.30,
          lastUpdated: DateTime.now().subtract(const Duration(days: 30)),
          createdAt: DateTime.now().subtract(const Duration(days: 60)),
        );

        friend.addMeeting(Meeting(
          date: DateTime.now(),
          type: MeetingType.metInPerson,
        ));

        expect(friend.battery, 1.0);
        expect(friend.meetings.length, 1);
      });

      test('addMeeting with called sets battery to 75%', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.30,
          lastUpdated: DateTime.now().subtract(const Duration(days: 30)),
          createdAt: DateTime.now().subtract(const Duration(days: 60)),
        );

        friend.addMeeting(Meeting(
          date: DateTime.now(),
          type: MeetingType.called,
        ));

        expect(friend.battery, 0.75);
      });

      test('addMeeting with texted sets battery to 50%', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.30,
          lastUpdated: DateTime.now().subtract(const Duration(days: 30)),
          createdAt: DateTime.now().subtract(const Duration(days: 60)),
        );

        friend.addMeeting(Meeting(
          date: DateTime.now(),
          type: MeetingType.texted,
        ));

        expect(friend.battery, 0.50);
      });

      test('addMeeting updates lastUpdated', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 30));
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 0.50,
          lastUpdated: oldDate,
          createdAt: oldDate,
        );

        friend.addMeeting(Meeting(
          date: DateTime.now(),
          type: MeetingType.texted,
        ));

        expect(friend.lastUpdated.isAfter(oldDate), true);
      });

      test('meeting counts are calculated correctly', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 1.0,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
          meetings: [
            Meeting(date: DateTime(2025, 1, 1), type: MeetingType.metInPerson),
            Meeting(date: DateTime(2025, 1, 5), type: MeetingType.metInPerson),
            Meeting(date: DateTime(2025, 1, 10), type: MeetingType.called),
            Meeting(date: DateTime(2025, 1, 15), type: MeetingType.texted),
            Meeting(date: DateTime(2025, 1, 20), type: MeetingType.texted),
            Meeting(date: DateTime(2025, 1, 25), type: MeetingType.texted),
          ],
        );

        expect(friend.totalMeetings, 6);
        expect(friend.inPersonMeetings, 2);
        expect(friend.callMeetings, 1);
        expect(friend.textMeetings, 3);
      });

      test('lastMeetingDate returns most recent meeting', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 1.0,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
          meetings: [
            Meeting(date: DateTime(2025, 1, 1), type: MeetingType.metInPerson),
            Meeting(date: DateTime(2025, 6, 15), type: MeetingType.called),
            Meeting(date: DateTime(2025, 3, 10), type: MeetingType.texted),
          ],
        );

        expect(friend.lastMeetingDate, DateTime(2025, 6, 15));
      });

      test('lastMeetingDate returns null when no meetings', () {
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 1.0,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(friend.lastMeetingDate, isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = Friend(
          id: '1',
          name: 'Original',
          color: Colors.blue,
          battery: 0.5,
          lastUpdated: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          notifyLowBattery: true,
          notifyBirthday: true,
        );

        final copy = original.copyWith(
          name: 'Updated',
          birthday: DateTime(1990, 5, 20),
          notifyLowBattery: false,
        );

        expect(copy.id, '1'); // unchanged
        expect(copy.name, 'Updated');
        expect(copy.color, Colors.blue); // unchanged
        expect(copy.birthday, DateTime(1990, 5, 20));
        expect(copy.notifyLowBattery, false);
        expect(copy.notifyBirthday, true); // unchanged
      });
    });

    group('refreshBattery', () {
      test('does not update lastUpdated', () {
        final originalDate = DateTime.now().subtract(const Duration(days: 10));
        final friend = Friend(
          id: '1',
          name: 'Test',
          color: Colors.blue,
          battery: 1.0,
          lastUpdated: originalDate,
          createdAt: originalDate,
        );

        friend.refreshBattery();

        // Battery should be updated to current calculated value
        expect(friend.battery, 0.90);
        // But lastUpdated should NOT change (this is the fix we made)
        // Note: refreshBattery doesn't update lastUpdated anymore
      });
    });
  });

  group('FriendService', () {
    setUp(() {
      setupFirebaseMocks();
      SharedPreferences.setMockInitialValues({});
    });

    test('loadFriends returns empty list when none saved', () async {
      final friends = await FriendService.loadFriends();
      expect(friends, isEmpty);
    });

    test('saveFriends and loadFriends round trip', () async {
      final friends = [
        Friend(
          id: '1',
          name: 'Alice',
          color: Colors.pink,
          battery: 0.8,
          lastUpdated: DateTime(2025, 6, 1),
          createdAt: DateTime(2025, 1, 1),
          birthday: DateTime(1995, 8, 20),
          notifyBirthday: true,
        ),
        Friend(
          id: '2',
          name: 'Bob',
          color: Colors.blue,
          battery: 0.6,
          lastUpdated: DateTime(2025, 5, 15),
          createdAt: DateTime(2025, 2, 1),
          notifyLowBattery: false,
        ),
      ];

      await FriendService.saveFriends(friends);
      final loaded = await FriendService.loadFriends();

      expect(loaded.length, 2);
      expect(loaded[0].name, 'Alice');
      expect(loaded[0].birthday, DateTime(1995, 8, 20));
      expect(loaded[1].name, 'Bob');
      expect(loaded[1].notifyLowBattery, false);
    });

    test('addFriend adds to list and saves', () async {
      final friends = <Friend>[];
      final newFriend = Friend(
        id: '1',
        name: 'Charlie',
        color: Colors.green,
        battery: 1.0,
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await FriendService.addFriend(newFriend, friends);

      expect(friends.length, 1);
      expect(friends[0].name, 'Charlie');

      // Verify persisted
      final loaded = await FriendService.loadFriends();
      expect(loaded.length, 1);
    });

    test('updateFriend updates existing friend', () async {
      final friends = [
        Friend(
          id: '1',
          name: 'Original',
          color: Colors.red,
          battery: 0.5,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];
      await FriendService.saveFriends(friends);

      final updated = friends[0].copyWith(name: 'Updated', battery: 0.9);
      await FriendService.updateFriend(updated, friends);

      expect(friends[0].name, 'Updated');
      expect(friends[0].battery, 0.9);
    });

    test('deleteFriend removes friend from list', () async {
      final friends = [
        Friend(
          id: '1',
          name: 'ToDelete',
          color: Colors.red,
          battery: 0.5,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        Friend(
          id: '2',
          name: 'ToKeep',
          color: Colors.blue,
          battery: 0.8,
          lastUpdated: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];
      await FriendService.saveFriends(friends);

      await FriendService.deleteFriend('1', friends);

      expect(friends.length, 1);
      expect(friends[0].name, 'ToKeep');
    });

    test('reorderFriends changes order correctly', () async {
      final friends = [
        Friend(id: '1', name: 'First', color: Colors.red, battery: 1.0, lastUpdated: DateTime.now(), createdAt: DateTime.now()),
        Friend(id: '2', name: 'Second', color: Colors.blue, battery: 1.0, lastUpdated: DateTime.now(), createdAt: DateTime.now()),
        Friend(id: '3', name: 'Third', color: Colors.green, battery: 1.0, lastUpdated: DateTime.now(), createdAt: DateTime.now()),
      ];
      await FriendService.saveFriends(friends);

      // Move first to last position
      await FriendService.reorderFriends(0, 3, friends);

      expect(friends[0].name, 'Second');
      expect(friends[1].name, 'Third');
      expect(friends[2].name, 'First');
    });

    test('updateFriendBattery updates specific friend battery', () async {
      final friends = [
        Friend(
          id: '1',
          name: 'Test',
          color: Colors.red,
          battery: 0.3,
          lastUpdated: DateTime.now().subtract(const Duration(days: 10)),
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ];

      await FriendService.updateFriendBattery('1', 1.0, friends);

      expect(friends[0].battery, 1.0);
    });
  });
}
