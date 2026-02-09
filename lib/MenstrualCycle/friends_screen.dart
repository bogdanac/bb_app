import 'package:flutter/material.dart';
import 'package:bb_app/theme/app_colors.dart';
import 'package:bb_app/MenstrualCycle/friends_tab_screen.dart';

class FriendsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const FriendsScreen({super.key, this.onOpenDrawer});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // GlobalKeys for FriendsTabScreens to access their methods
  final GlobalKey<FriendsTabScreenState> _activeFriendsKey = GlobalKey<FriendsTabScreenState>();
  final GlobalKey<FriendsTabScreenState> _archivedFriendsKey = GlobalKey<FriendsTabScreenState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshBothTabs() {
    _activeFriendsKey.currentState?.refresh();
    _archivedFriendsKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
              )
            : null,
        title: const Text('Social'),
        backgroundColor: Colors.transparent,
        actions: [
          // Only show add button on Friends tab (not Archived)
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Friend',
              onPressed: () {
                _activeFriendsKey.currentState?.addFriend();
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.white,
              unselectedLabelColor: AppColors.successGreen.withValues(alpha: 0.7),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Social'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.archive_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Archived'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: TabBarView(
            controller: _tabController,
            children: [
              FriendsTabScreen(
                key: _activeFriendsKey,
                showArchived: false,
                onFriendArchiveChanged: _refreshBothTabs,
              ),
              FriendsTabScreen(
                key: _archivedFriendsKey,
                showArchived: true,
                onFriendArchiveChanged: _refreshBothTabs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
