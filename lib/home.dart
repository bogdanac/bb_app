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
import 'package:bb_app/Routines/routine_card.dart';
import 'package:bb_app/Fasting/fasting_card.dart';
import 'package:bb_app/Habits/habit_card.dart';
import 'package:bb_app/Habits/habit_service.dart';
import 'package:bb_app/Notifications/centralized_notification_manager.dart';
import 'package:bb_app/FoodTracking/food_tracking_card.dart';
import 'package:bb_app/home_settings_screen.dart';
import 'package:bb_app/Data/backup_service.dart';
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
  bool _isFastingInProgress = false;
  bool showRoutine = true;
  bool showHabitCard = false;
  bool _isLoading = true;
  bool _isDisposed = false;
  Timer? _waterSyncTimer;
  bool _backupOverdue = false;

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
    _checkBackupStatus();
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
      await _initializeWaterAmountSetting();
      _checkFastingVisibility();
      _checkRoutineVisibility();
      await _checkHabitCardVisibility();

      // Inițializează și programează notificările de apă
      await _initializeWaterNotifications();

      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR initializing home data: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeWaterAmountSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Initialize water amount setting if it doesn't exist
      if (!prefs.containsKey('water_amount_per_tap')) {
        debugPrint('Initializing water amount setting to default 125ml');
        await prefs.setInt('water_amount_per_tap', 125);
        // Also save with flutter. prefix for widget compatibility
        await prefs.setInt('flutter.water_amount_per_tap', 125);
      }
    } catch (e) {
      debugPrint('ERROR initializing water amount setting: $e');
    }
  }

  Future<void> _initializeWaterNotifications() async {
    final notificationManager = CentralizedNotificationManager();

    // Verifică dacă trebuie să anuleze notificări pe baza progresului curent
    await notificationManager.checkAndCancelWaterNotifications(waterIntake);
  }

  // Start periodic water sync timer (checks every 30 seconds)
  void _startWaterSyncTimer() {
    _waterSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isDisposed && mounted) {
        _loadWaterIntake();
      }
    });
  }

  Future<void> _checkBackupStatus() async {
    try {
      final backupStatus = await BackupService.getDetailedBackupStatus();
      if (mounted && !_isDisposed) {
        setState(() {
          _backupOverdue = backupStatus['any_overdue'] ?? false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR checking backup status: $e');
      }
      // Don't show warning icon for technical errors - only for actual overdue backups
      // User can still access backup screen via settings if needed
      if (mounted && !_isDisposed) {
        setState(() {
          _backupOverdue = false; // Don't show false alarms
        });
      }
    }
  }

  // This method is called when the app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isDisposed && mounted && state == AppLifecycleState.resumed) {
      // Refresh water intake in case widget updated it
      _loadWaterIntake();
      // Refresh the menstrual cycle card when returning to the app
      _refreshMenstrualCycleData();
      // Refresh backup status when returning to the app
      _checkBackupStatus();
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
        final notificationManager = CentralizedNotificationManager();
        await notificationManager.forceRescheduleAll();

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
      debugPrint('ERROR loading water intake: $e');
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
      debugPrint('ERROR parsing last reset date: $e');
      return false; // In case of error, don't reset to preserve data
    }
  }

  void _checkFastingVisibility() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final preferredDay = prefs.getInt('preferred_fasting_day') ?? 5; // Default to Friday
    final preferredMonthlyDay = prefs.getInt('preferred_monthly_fasting_day') ?? 25; // Default to 25th
    final isPreferredDay = now.weekday == preferredDay;
    final isPreferredMonthlyDay = now.day == preferredMonthlyDay;

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
    } else if (isPreferredDay || isPreferredMonthlyDay) {
      // Check if there's a recommended fast for today
      shouldShow = _hasRecommendedFastForToday(now, isPreferredDay, isPreferredMonthlyDay);
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
  bool _hasRecommendedFastForToday(DateTime now, bool isPreferredDay, bool isPreferredMonthlyDay) {
    // If today is the preferred monthly day, always show
    if (isPreferredMonthlyDay) {
      return true; // Always show on preferred monthly day
    }

    // If today is the preferred day, show normal weekly fast
    if (isPreferredDay) {
      return true; // Show normal preferred day fast
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

  void _checkRoutineVisibility() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // Clean up old hidden and completed flags (more than 2 days old)
    final allKeys = prefs.getKeys();
    final oldKeys = allKeys.where((key) =>
        (key.startsWith('routine_hidden_') ||
            key.startsWith('routine_completed_')) &&
        !key.endsWith(today));
    for (final key in oldKeys) {
      await prefs.remove(key);
    }

    final hiddenToday = prefs.getBool('routine_hidden_$today') ?? false;
    final completedToday =
        prefs.getBool('routine_completed_$today') ?? false;

    if (kDebugMode) {
      print(
          'Routine check - Hour: ${now.hour}, Hidden today: $hiddenToday, Completed today: $completedToday, Today: $today');
      print('Cleaned up ${oldKeys.length} old flags');
    }

    if (!_isDisposed && mounted) {
      setState(() {
        // Show only if: not hidden AND not completed today (allow routines 24/7)
        showRoutine = !hiddenToday && !completedToday;
      });

      if (kDebugMode) {
        print('Routine visibility: $showRoutine');
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
        debugPrint('ERROR refreshing calendar events: $e');
      }

      // Check and update other sections
      _checkFastingVisibility();
      _checkRoutineVisibility();
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
      debugPrint('ERROR refreshing data: $e');
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

      // Get customizable water amount
      final waterAmountPerTap = prefs.getInt('water_amount_per_tap') ?? 125;

      final oldIntake = waterIntake;
      final newIntake = waterIntake + waterAmountPerTap;
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
        final notificationManager = CentralizedNotificationManager();
        await notificationManager.checkAndCancelWaterNotifications(newIntake);
      }
    } catch (e) {
      debugPrint('ERROR adding water: $e');
    }
  }

  void _onRoutineCompleted() async {
    if (!_isDisposed && mounted) {
      // Save completion status for today
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setBool('routine_completed_$today', true);

      setState(() {
        showRoutine = false;
      });
    }
  }

  void _onRoutineHiddenForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setBool('routine_hidden_$today', true);

    if (kDebugMode) {
      print('Routine hidden for today: $today');
    }

    if (!_isDisposed && mounted) {
      setState(() {
        showRoutine = false;
      });
    }
  }

  // Method to force show routine for debugging
  void _forceShowRoutine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Clear the hidden and completed flags
      await prefs.remove('routine_hidden_$today');
      await prefs.remove('routine_completed_$today');

      if (!_isDisposed && mounted) {
        setState(() {
          showRoutine = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR in _forceShowRoutine: $e');
      }
    }

    if (kDebugMode) {
      print('Forced routine to show');
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
              style: TextStyle(fontWeight: FontWeight.w500)),
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
            style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: AppColors.transparent,
        actions: [
          if (_backupOverdue)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.backup_outlined, color: Colors.orange),
                onPressed: () async {
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Creating backup...'),
                        ],
                      ),
                      duration: Duration(seconds: 30),
                    ),
                  );

                  try {
                    // Perform quick backup
                    final backupPath = await BackupService.exportToFile();

                    if (!context.mounted) return;

                    // Hide loading and show success
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();

                    if (backupPath != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Backup completed! Saved to: ${backupPath.split('/').last}'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Backup failed - check storage permissions'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;

                    // Hide loading and show error
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Backup failed: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }

                  // Refresh backup status
                  _checkBackupStatus();
                },
                tooltip: 'Quick Backup - Tap to backup your data now',
              ),
            ),
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.wb_sunny),
                onPressed: _forceShowRoutine,
                tooltip: 'Force Show Routine',
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

              // Fasting Section (conditional)
              if (showFastingSection) ...[
                FastingCard(
                  onHiddenForToday: _onFastingHiddenForToday,
                  onFastingStatusChanged: (bool isFasting) {
                    setState(() {
                      _isFastingInProgress = isFasting;
                    });
                  },
                ),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Food Tracking Section (hidden during fasting)
              if (!_isFastingInProgress) ...[
                const FoodTrackingCard(),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Water Tracking Section (conditional)
              if (_shouldShowWaterTracking) ...[
                WaterTrackingCard(
                  waterIntake: waterIntake,
                  onWaterAdded: _onWaterAdded,
                ),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Habit Card Section (conditional)
              if (showHabitCard) ...[
                HabitCard(
                  onAllCompleted: _onAllHabitsCompleted,
                ),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Routine Section (conditional)
              if (showRoutine) ...[
                RoutineCard(
                  onCompleted: _onRoutineCompleted,
                  onHiddenForToday: _onRoutineHiddenForToday,
                ),
                const SizedBox(height: 4), // Consistent spacing
              ],

              // Daily Tasks Section
              const DailyTasksCard(),

            ],
          ),
        ),
      ),
    );
  }
}
