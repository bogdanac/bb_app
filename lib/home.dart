import 'package:bb_app/MenstrualCycle/cycle_tracking_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:bb_app/Calendar/events_card.dart';
import 'package:bb_app/MenstrualCycle/menstrual_cycle_card.dart';
import 'package:bb_app/WaterTracking/water_tracking_card.dart';
import 'package:bb_app/Tasks/daily_tasks_card.dart';
import 'package:bb_app/Routines/morning_routine_card.dart';
import 'package:bb_app/Fasting/fasting_card.dart';
import 'package:bb_app/Habits/habit_card.dart';
import 'package:bb_app/Habits/habit_service.dart';
import 'package:bb_app/Notifications/notification_service.dart';
import 'package:bb_app/FoodTracking/food_tracking_card.dart';
import 'package:bb_app/home_settings_screen.dart';
import 'dart:async';
import 'package:flutter/services.dart';

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
  bool showHabitCard = false;
  bool _isLoading = true;
  bool _isDisposed = false;
  Timer? _waterSyncTimer;

  // Method channel for communicating with Android widget
  static const platform = MethodChannel('com.bb.bb_app/water_widget');

  // Add a key to force rebuild of MenstrualCycleCard
  Key _menstrualCycleKey = UniqueKey();

  // Key to access CalendarEventsCard for refresh
  final GlobalKey _calendarEventsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _startWaterSyncTimer();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _waterSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      await _loadWaterIntake();
      _checkFastingVisibility();
      _checkMorningRoutineVisibility();
      await _checkHabitCardVisibility();

      // Inițializează și programează notificările de apă
      await _initializeWaterNotifications();

      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing home data: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeWaterNotifications() async {
    final notificationService = NotificationService();

    // Programează notificările de apă pentru ziua curentă
    await notificationService.scheduleWaterReminders();

    // Verifică dacă trebuie să anuleze notificări pe baza progresului curent
    await notificationService.checkAndCancelWaterNotifications(waterIntake);
  }

  // Start periodic water sync timer (checks every 30 seconds)
  void _startWaterSyncTimer() {
    _waterSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isDisposed && mounted) {
        _loadWaterIntake();
      }
    });
  }

  // This method is called when the app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isDisposed && mounted && state == AppLifecycleState.resumed) {
      // Refresh water intake in case widget updated it
      _loadWaterIntake();
      // Refresh the menstrual cycle card when returning to the app
      _refreshMenstrualCycleData();
      // Force refresh of all home screen widgets including tasks
      setState(() {});
      debugPrint('App resumed - refreshed all home screen data');
    }
  }

  bool get _shouldShowWaterTracking {
    return waterIntake < 1500; // Changed to match the goal in WaterTrackingCard
  }

  Future<void> _loadWaterIntake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);

      // Check if it's after 2:00 AM and if we need to reset water data
      final lastResetDate = prefs.getString('last_water_reset_date');
      final shouldReset = _shouldResetWaterToday(now, lastResetDate);


      int intake;
      if (shouldReset) {
        // Reset for new day
        intake = 0;
        await prefs.setInt('water_$today', intake);
        await prefs.setString('last_water_reset_date', today);

        // Reprogramează notificările pentru ziua nouă
        final notificationService = NotificationService();
        await notificationService.rescheduleWaterNotificationsForTomorrow();

      } else {
        // Load data for current day - prioritize widget data
        int appIntake = prefs.getInt('water_$today') ?? 0;
        int widgetIntake = 0;

        // First try to get widget data using method channel
        try {
          final widgetIntakeFromChannel = await platform
              .invokeMethod('getWaterFromWidget', {'date': today});
          if (widgetIntakeFromChannel != null &&
              widgetIntakeFromChannel is int) {
            widgetIntake = widgetIntakeFromChannel;
          }
        } catch (e) {
          // Method channel failed, continue to SharedPreferences approach
        }

        // If method channel didn't work, try SharedPreferences with different approaches
        if (widgetIntake == 0) {
          // Try the flutter-prefixed key first (this is what the widget actually writes to)
          var widgetValue = prefs.get('flutter.water_$today');

          // If that doesn't work, try the regular key
          widgetValue ??= prefs.get('water_$today');

          if (widgetValue != null) {
            if (widgetValue is int) {
              widgetIntake = widgetValue;
            } else if (widgetValue is double) {
              widgetIntake = widgetValue.toInt();
            } else {
              // Try to parse as number
              widgetIntake = int.tryParse(widgetValue.toString()) ?? 0;
            }
          }
        }

        // Use the higher value (widget has priority since user might be using it)
        intake = widgetIntake > appIntake ? widgetIntake : appIntake;


        // Only sync if there's a significant difference to avoid constant writing
        if ((widgetIntake - appIntake).abs() > 0) {
          await prefs.setInt('water_$today', intake);
        }
      }


      if (!_isDisposed && mounted) {
        setState(() {
          waterIntake = intake;
        });
      }
    } catch (e) {
      debugPrint('Error loading water intake: $e');
    }
  }

  bool _shouldResetWaterToday(DateTime now, String? lastResetDate) {
    // If it's the first run and there's no reset date, check if there's existing data for today
    if (lastResetDate == null) {
      return false; // Don't reset on first run - load existing data if any
    }

    try {
      final today = DateFormat('yyyy-MM-dd').format(now);

      // If the last reset date is not today, we need to check if it's time to reset
      if (lastResetDate != today) {
        // Calculate the last 2 AM reset time for today
        final today2AM = DateTime(now.year, now.month, now.day, 2, 0);

        // If it's after 2 AM today and we haven't reset for today yet, reset
        if (now.isAfter(today2AM)) {
          return true;
        }
      }

      return false; // No reset needed
    } catch (e) {
      debugPrint('Error parsing last reset date: $e');
      return false; // In case of error, don't reset to preserve data
    }
  }

  void _checkFastingVisibility() async {
    final now = DateTime.now();
    final isFriday = now.weekday == 5;
    final is25th = now.day == 25;
    final prefs = await SharedPreferences.getInstance();

    bool shouldShow = false;

    // First, check if there's an active fast
    final isFasting = prefs.getBool('is_fasting') ?? false;
    final fastingStartTime = prefs.getString('current_fast_start');
    final fastingEndTime = prefs.getString('current_fast_end');

    bool hasActiveFast = false;
    if (isFasting && fastingStartTime != null && fastingEndTime != null) {
      final endTime = DateTime.parse(fastingEndTime);
      hasActiveFast = now.isBefore(endTime);
    }

    // Show the card if there's an active fast OR if there's a fast scheduled for today
    if (hasActiveFast) {
      shouldShow = true;
    } else if (isFriday || is25th) {
      // Check if there's a recommended fast for today
      shouldShow = _hasRecommendedFastForToday(now, isFriday, is25th);
    } else {
      shouldShow = false;
    }

    if (!_isDisposed && mounted) {
      setState(() {
        showFastingSection = shouldShow;
      });
    }
  }

  // Check if there's actually a recommended fast for today (more strict than fasting screen)
  bool _hasRecommendedFastForToday(DateTime now, bool isFriday, bool is25th) {
    // If today is the 25th, check if there was a recent Friday or upcoming Friday
    if (is25th) {
      final daysUntilFriday = (5 - now.weekday + 7) % 7;
      final daysSinceLastFriday =
          now.weekday >= 5 ? now.weekday - 5 : now.weekday + 2;

      // If Friday is close (within 6 days either way), do the longer fast on 25th
      if (daysSinceLastFriday <= 6 || daysUntilFriday <= 6) {
        return true; // Show fast on 25th
      }
      return true; // Always show on 25th
    }

    // If today is Friday, check if 25th is close
    if (isFriday) {
      final daysUntil25th = 25 - now.day;

      // If 25th is within 4-6 days, do the longer fast on Friday instead
      if (daysUntil25th >= 0 && daysUntil25th <= 6) {
        return true; // Show longer fast on Friday
      }

      // Check if 25th was recent (last month)
      if (now.day < 25) {
        // 25th is later this month, show normal Friday fast
        return true;
      } else {
        // Check if 25th was recent from last month
        final daysSince25thLastMonth = now.day - 25;
        if (daysSince25thLastMonth <= 6) {
          return false; // Don't show Friday fast if 25th was very recent
        }
        return true; // Show normal Friday fast
      }
    }

    return false;
  }

  // Callback for hiding fasting card for today
  void _onFastingHiddenForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setBool('fasting_hidden_$today', true);

    if (!_isDisposed && mounted) {
      setState(() {
        showFastingSection = false;
      });
    }
  }

  void _checkMorningRoutineVisibility() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // Clean up old hidden and completed flags (more than 2 days old)
    final allKeys = prefs.getKeys();
    final oldKeys = allKeys.where((key) =>
        (key.startsWith('morning_routine_hidden_') ||
            key.startsWith('morning_routine_completed_')) &&
        !key.endsWith(today));
    for (final key in oldKeys) {
      await prefs.remove(key);
    }

    final hiddenToday = prefs.getBool('morning_routine_hidden_$today') ?? false;
    final completedToday =
        prefs.getBool('morning_routine_completed_$today') ?? false;

    if (kDebugMode) {
      print(
          'Morning routine check - Hour: ${now.hour}, Hidden today: $hiddenToday, Completed today: $completedToday, Today: $today');
      print('Cleaned up ${oldKeys.length} old flags');
    }

    if (!_isDisposed && mounted) {
      setState(() {
        // Show only if: not hidden AND not completed today (allow routines 24/7)
        showMorningRoutine = !hiddenToday && !completedToday;
      });

      if (kDebugMode) {
        print('Morning routine visibility: $showMorningRoutine');
      }
    }
  }

  Future<void> _checkHabitCardVisibility() async {
    final hasUncompletedHabits = await HabitService.hasUncompletedHabitsToday();

    if (!_isDisposed && mounted) {
      setState(() {
        showHabitCard = hasUncompletedHabits;
      });
    }
  }

  void _onAllHabitsCompleted() {
    if (!_isDisposed && mounted) {
      setState(() {
        showHabitCard = false;
      });
    }
  }

  // Method to refresh menstrual cycle data
  void _refreshMenstrualCycleData() {
    if (!_isDisposed && mounted) {
      setState(() {
        _menstrualCycleKey = UniqueKey();
      });
    }
  }

  Future<void> _onRefresh() async {
    try {
      debugPrint('Manual refresh triggered - reloading all data');

      // Force refresh water intake with widget sync
      await _loadWaterIntake();

      // Refresh calendar events
      try {
        final calendarState = _calendarEventsKey.currentState as dynamic;
        if (calendarState != null) {
          await calendarState.refreshEvents();
        }
      } catch (e) {
        debugPrint('Error refreshing calendar events: $e');
      }

      // Check and update other sections
      _checkFastingVisibility();
      _checkMorningRoutineVisibility();
      await _checkHabitCardVisibility();
      _refreshMenstrualCycleData();

      // Show feedback that refresh completed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data refreshed'),
            duration: Duration(seconds: 1),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }

      debugPrint('Manual refresh completed successfully');
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Refresh failed: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _onWaterAdded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final oldIntake = waterIntake;
      final newIntake = waterIntake + 125;
      const int goal = 1500;

      if (!_isDisposed && mounted) {
        setState(() {
          waterIntake = newIntake;
        });
        // Save water data in both formats that widget checks
        await prefs.setInt('water_$today', newIntake);

        // Use the same underlying storage mechanism
        await prefs.setInt('water_$today', newIntake); // For app use
        // Save reset date
        await prefs.setString('last_water_reset_date', today);


        // Also sync with widget using method channel
        try {
          await platform.invokeMethod('syncWaterData', {
            'intake': newIntake,
            'date': today,
          });
        } catch (e) {
          // Widget sync failed, but continue with app functionality
        }

        // Show congratulations when goal is reached
        if (oldIntake < goal && newIntake >= goal && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Daily water goal achieved! Great job!'),
              backgroundColor: AppColors.successGreen,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Verifică și anulează notificările pe baza noului progres
        final notificationService = NotificationService();
        await notificationService.checkAndCancelWaterNotifications(newIntake);
      }
    } catch (e) {
      debugPrint('Error adding water: $e');
    }
  }

  void _onMorningRoutineCompleted() async {
    if (!_isDisposed && mounted) {
      // Save completion status for today
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setBool('morning_routine_completed_$today', true);

      setState(() {
        showMorningRoutine = false;
      });
    }
  }

  void _onMorningRoutineHiddenForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setBool('morning_routine_hidden_$today', true);

    if (kDebugMode) {
      print('Morning routine hidden for today: $today');
    }

    if (!_isDisposed && mounted) {
      setState(() {
        showMorningRoutine = false;
      });
    }
  }

  // Method to force show morning routine for debugging
  void _forceShowMorningRoutine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Clear the hidden and completed flags
      await prefs.remove('morning_routine_hidden_$today');
      await prefs.remove('morning_routine_completed_$today');

      if (!_isDisposed && mounted) {
        setState(() {
          showMorningRoutine = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _forceShowMorningRoutine: $e');
      }
    }

    if (kDebugMode) {
      print('Forced morning routine to show');
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('BBetter',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.pink),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('bbetter',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.transparent,
        actions: [
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.wb_sunny),
                onPressed: _forceShowMorningRoutine,
                tooltip: 'Force Show Morning Routine',
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8), // Even tighter overall padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Menstrual Cycle Card
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
              const SizedBox(height: 4), // Consistent spacing

              // Calendar Events Card
              CalendarEventsCard(key: _calendarEventsKey),
              const SizedBox(height: 4), // Consistent spacing

              // Water Tracking Section (conditional)
              if (_shouldShowWaterTracking) ...[
                WaterTrackingCard(
                  waterIntake: waterIntake,
                  onWaterAdded: _onWaterAdded,
                ),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Morning Routine Section (conditional)
              if (showMorningRoutine) ...[
                MorningRoutineCard(
                  onCompleted: _onMorningRoutineCompleted,
                  onHiddenForToday: _onMorningRoutineHiddenForToday,
                ),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Fasting Section (conditional)
              if (showFastingSection) ...[
                FastingCard(onHiddenForToday: _onFastingHiddenForToday),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Daily Tasks Section
              const DailyTasksCard(),
              const SizedBox(height: 4), // Consistent spacing

              // Habit Card Section (conditional - appears before water tracking)
              if (showHabitCard) ...[
                HabitCard(
                  onAllCompleted: _onAllHabitsCompleted,
                ),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Food Tracking Section
              const FoodTrackingCard(),
            ],
          ),
        ),
      ),
    );
  }
}
