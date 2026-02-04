import 'package:flutter/material.dart';
import 'package:bb_app/theme/app_colors.dart';
import 'package:bb_app/MenstrualCycle/friends_tab_screen.dart';

class FriendsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const FriendsScreen({super.key, this.onOpenDrawer});

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
        leading: widget.onOpenDrawer != null
            ? IconButton(icon: const Icon(Icons.menu_rounded), onPressed: widget.onOpenDrawer)
            : null,
        title: const Text('Circle of Friends'),
        backgroundColor: AppColors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FriendsTabScreen(key: _friendsTabKey),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _friendsTabKey.currentState?.addFriend();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
