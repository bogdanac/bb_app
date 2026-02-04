import 'package:flutter/material.dart';
import 'package:bb_app/theme/app_colors.dart';
import 'package:bb_app/MenstrualCycle/friends_tab_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // GlobalKey for FriendsTabScreen to access its methods
  final GlobalKey<FriendsTabScreenState> _friendsTabKey = GlobalKey<FriendsTabScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Circle of Friends'),
        backgroundColor: AppColors.transparent,
      ),
      body: FriendsTabScreen(key: _friendsTabKey),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _friendsTabKey.currentState?.addFriend();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
