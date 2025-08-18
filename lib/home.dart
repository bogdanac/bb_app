import 'package:bb_app/MenstrualCycle/cycle_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:bb_app/Calendar/events_card.dart';
import 'package:bb_app/MenstrualCycle/menstrual_cycle_card.dart';
import 'package:bb_app/WaterTracking/water_tracking_card.dart';
import 'package:bb_app/Tasks/daily_tasks_card.dart';
import 'package:bb_app/Routines/morning_routine_card.dart';
import 'package:bb_app/Fasting/fasting_card.dart';

// HOME SCREEN
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int waterIntake = 0;
  bool showFastingSection = false;
  bool showMorningRoutine = true;

  // Add a key to force rebuild of MenstrualCycleCard
  Key _menstrualCycleKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWaterIntake();
    _checkFastingVisibility();
    _checkMorningRoutineVisibility();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // This method is called when the app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the menstrual cycle card when returning to the app
      setState(() {
        _menstrualCycleKey = UniqueKey();
      });
    }
  }

  bool get _shouldShowWaterTracking {
    return waterIntake <= 1750;
  }

  _loadWaterIntake() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      waterIntake = prefs.getInt('water_$today') ?? 0;
    });
  }

  _checkFastingVisibility() {
    final now = DateTime.now();
    final isSunday = now.weekday == 7;
    final is25th = now.day == 25;
    setState(() {
      showFastingSection = isSunday || is25th;
    });
  }

  _checkMorningRoutineVisibility() {
    final now = DateTime.now();
    setState(() {
      showMorningRoutine = now.hour < 12; // Show until noon
    });
  }

  // Method to refresh menstrual cycle data
  void _refreshMenstrualCycleData() {
    setState(() {
      _menstrualCycleKey = UniqueKey();
    });
  }

  // Method to navigate to cycle screen and refresh on return
  void _navigateToCycleScreen() async {
    // Navigate to your cycle screen here
    // final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CycleScreen()));

    // After returning from cycle screen, refresh the data
    _refreshMenstrualCycleData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BBetter', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh all data when user pulls down
          await _loadWaterIntake();
          _checkFastingVisibility();
          _checkMorningRoutineVisibility();
          _refreshMenstrualCycleData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Menstrual Cycle Section with key for rebuilding
              MenstrualCycleCard(
                key: _menstrualCycleKey,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CycleScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Water Tracking Section (conditional)
              if (_shouldShowWaterTracking) ...[
                WaterTrackingCard(
                  waterIntake: waterIntake,
                  onWaterAdded: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    setState(() {
                      waterIntake += 125;
                    });
                    await prefs.setInt('water_$today', waterIntake);
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Fasting Section (conditional)
              if (showFastingSection) ...[
                const FastingCard(),
                const SizedBox(height: 20),
              ],

              // Morning Routine Section (conditional)
              if (showMorningRoutine) ...[
                MorningRoutineCard(
                  onCompleted: () {
                    setState(() {
                      showMorningRoutine = false;
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Calendar Events Section
              const CalendarEventsCard(),
              const SizedBox(height: 20),

              // Daily Tasks Section
              const DailyTasksCard(),
            ],
          ),
        ),
      ),
    );
  }
}