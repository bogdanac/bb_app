import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Settings/app_customization_service.dart';
import 'shared/date_format_utils.dart';
import 'package:bb_app/Calendar/events_card.dart';
import 'package:bb_app/MenstrualCycle/menstrual_cycle_card.dart';
import 'package:bb_app/WaterTracking/water_tracking_card.dart';
import 'package:bb_app/WaterTracking/water_settings_model.dart';
import 'package:bb_app/WaterTracking/water_notification_service.dart';
import 'package:bb_app/Tasks/daily_tasks_card.dart';
import 'package:bb_app/Routines/routine_card.dart';
import 'package:bb_app/Routines/routine_service.dart';
import 'package:bb_app/Fasting/fasting_card.dart';
import 'package:bb_app/Fasting/fasting_utils.dart';
import 'package:bb_app/Habits/habit_card.dart';
import 'package:bb_app/Habits/habit_service.dart';
import 'shared/snackbar_utils.dart';
import 'shared/error_logger.dart';
import 'package:bb_app/Notifications/centralized_notification_manager.dart';
import 'package:bb_app/FoodTracking/food_tracking_card.dart';
import 'package:bb_app/Settings/settings_screen.dart';
import 'package:bb_app/Data/backup_service.dart';
import 'package:bb_app/shared/widget_update_service.dart';
import 'package:bb_app/Energy/battery_flow_home_card.dart';
import 'dart:async';
import 'package:flutter/services.dart';

// HOME SCREEN
class HomeScreen extends StatefulWidget {
  final void Function(int)? onNavigateToTab;
  final void Function(String moduleKey)? onNavigateToModule;
  final Future<void> Function()? onReloadSettings;
  final VoidCallback? onOpenDrawer;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.onNavigateToModule,
    this.onReloadSettings,
    this.onOpenDrawer,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int waterIntake = 0;
  int _waterGoal = 1500; // Default water goal
  bool showFastingSection = false;
  bool _isFastingInProgress = false;
  bool showRoutine = true;
  bool showHabitCard = false;
  bool _isDisposed = false;
  Timer? _waterSyncTimer;
  bool _backupOverdue = false;
  Map<String, bool> _cardVisibility = {};
  List<String> _cardOrder = [];

  // Method channel for communicating with Android widget
  static const platform = MethodChannel('com.bb.bb_app/water_widget');

  // Add a key to force rebuild of MenstrualCycleCard
  Key _menstrualCycleKey = UniqueKey();

  // Add a key to force rebuild of RoutineCard
  Key _routineCardKey = UniqueKey();

  // Key to access CalendarEventsCard for refresh
  final GlobalKey _calendarEventsKey = GlobalKey();

  // Key to access BatteryFlowHomeCard for refresh
  final GlobalKey<BatteryFlowHomeCardState> _batteryFlowCardKey = GlobalKey<BatteryFlowHomeCardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _checkBackupStatus();
    _startWaterSyncTimer();
    _loadCardSettings();
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
      // Non-critical: run in background without blocking
      ErrorLogger.uploadWidgetDebugLogs().catchError((e) {
        debugPrint('ERROR uploading widget debug logs: $e');
      });

      // Run independent operations in parallel for faster load
      await Future.wait([
        WidgetUpdateService.checkAndUpdateWidgetsOnNewDay(),
        _loadWaterIntake(),
        _loadWaterGoal(),
        _initializeWaterAmountSetting(),
      ]);

      // These update UI state - fire and forget (they call setState internally)
      _checkFastingVisibility();
      _checkRoutineVisibility();
      _checkHabitCardVisibility();

      // Non-critical: run in background without blocking UI
      _initializeWaterNotifications().catchError((e) {
        debugPrint('ERROR initializing water notifications: $e');
      });
    } catch (e) {
      debugPrint('ERROR initializing home data: $e');
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
    // Initialize the new water notification service
    await WaterNotificationService.initialize();
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
      // Check if it's a new day and update widgets
      WidgetUpdateService.checkAndUpdateWidgetsOnNewDay();

      // Refresh water intake in case widget updated it
      _loadWaterIntake();
      // Refresh the menstrual cycle card when returning to the app
      _refreshMenstrualCycleData();
      // Refresh backup status when returning to the app
      _checkBackupStatus();
      // Force refresh of all home screen widgets including tasks
      setState(() {
        _routineCardKey = UniqueKey(); // Force RoutineCard to reload from widget progress
      });
      debugPrint('App resumed - refreshed all home screen data');
    }
  }

  bool get _shouldShowWaterTracking {
    return waterIntake < _waterGoal; // Show card if water intake is below goal
  }

  Future<void> _loadWaterGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goal = prefs.getInt('water_goal') ?? 1500;
      if (mounted && !_isDisposed) {
        setState(() {
          _waterGoal = goal;
        });
      }
    } catch (e) {
      debugPrint('ERROR loading water goal: $e');
    }
  }

  Future<void> _loadWaterIntake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(now)).split('T')[0];

      // Check if it's after 2:00 AM and if we need to reset water data
      // Check both keys since widget uses flutter. prefix
      final lastResetDate = prefs.getString('flutter.last_water_reset_date') ??
                            prefs.getString('last_water_reset_date');
      final shouldReset = _shouldResetWaterToday(now, lastResetDate);


      int intake;
      if (shouldReset) {
        // Check if widget already has data for today before resetting
        int widgetIntake = 0;
        try {
          var widgetValue = prefs.get('flutter.water_$today');
          widgetValue ??= prefs.get('water_$today');
          if (widgetValue != null) {
            if (widgetValue is int) {
              widgetIntake = widgetValue;
            } else if (widgetValue is double) {
              widgetIntake = widgetValue.toInt();
            } else {
              widgetIntake = int.tryParse(widgetValue.toString()) ?? 0;
            }
          }
        } catch (e, stackTrace) {
          await ErrorLogger.logError(
            source: 'HomeScreen._loadWaterIntake.shouldReset',
            error: 'Error reading widget water data during reset: $e',
            stackTrace: stackTrace.toString(),
          );
        }

        // Use widget data if it exists, otherwise reset to 0
        intake = widgetIntake;
        await prefs.setInt('water_$today', intake);
        // Save to both keys to stay in sync with widget
        await prefs.setString('flutter.last_water_reset_date', today);
        await prefs.setString('last_water_reset_date', today);

        // Reprogramează notificările pentru ziua nouă (non-blocking)
        final notificationManager = CentralizedNotificationManager();
        // Don't await - let it run in background to avoid blocking UI
        notificationManager.forceRescheduleAll().catchError((e) {
          debugPrint('ERROR rescheduling notifications: $e');
        });

        // Reschedule water notifications for the new day
        WaterNotificationService.rescheduleForNewDay().catchError((e) {
          debugPrint('ERROR rescheduling water notifications: $e');
        });

      } else {
        // Load data for current day - SharedPreferences first (fast)
        int appIntake = prefs.getInt('water_$today') ?? 0;

        // Try flutter-prefixed key (widget writes here)
        var widgetValue = prefs.get('flutter.water_$today');
        widgetValue ??= prefs.get('water_$today');

        int widgetIntake = 0;
        if (widgetValue != null) {
          if (widgetValue is int) {
            widgetIntake = widgetValue;
          } else if (widgetValue is double) {
            widgetIntake = widgetValue.toInt();
          } else {
            widgetIntake = int.tryParse(widgetValue.toString()) ?? 0;
          }
        }

        // Use the higher value
        intake = widgetIntake > appIntake ? widgetIntake : appIntake;

        // Method channel sync in background (non-blocking) - only if no data found
        if (intake == 0) {
          platform.invokeMethod('getWaterFromWidget', {'date': today}).then((result) {
            if (result != null && result is int && result > 0 && mounted && !_isDisposed) {
              setState(() => waterIntake = result);
              prefs.setInt('water_$today', result);
            }
          }).catchError((e) {
            debugPrint('Method channel water sync failed: $e');
          });
        } else if ((widgetIntake - appIntake).abs() > 0) {
          prefs.setInt('water_$today', intake);
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
      final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(now)).split('T')[0];

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
    } else {
      // Check if there's actually a recommended fast for today
      final recommendedFast = await FastingUtils.getRecommendedFastType();
      shouldShow = recommendedFast.isNotEmpty;
    }

    if (!_isDisposed && mounted) {
      setState(() {
        showFastingSection = shouldShow;
      });
    }
  }

  // Callback for hiding fasting card for today
  void _onFastingHiddenForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];
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
    final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(now)).split('T')[0];

    // Clean up old completed flags (more than 2 days old)
    final allKeys = prefs.getKeys();
    final oldKeys = allKeys.where((key) =>
        key.startsWith('routine_completed_') &&
        !key.contains(today));
    for (final key in oldKeys) {
      await prefs.remove(key);
    }

    // Check if there are any routines scheduled for today that are not completed
    final routines = await RoutineService.loadRoutines();
    final effectiveDate = DateTime.now();
    final todayWeekday = effectiveDate.weekday;

    final activeRoutines = routines.where((routine) =>
      routine.activeDays.contains(todayWeekday)
    ).toList();

    bool hasUncompletedRoutine = false;
    for (var routine in activeRoutines) {
      final completedKey = 'routine_completed_${routine.id}_$today';
      final isCompleted = prefs.getBool(completedKey) ?? false;
      if (!isCompleted) {
        hasUncompletedRoutine = true;
        break;
      }
    }

    if (!_isDisposed && mounted) {
      setState(() {
        showRoutine = hasUncompletedRoutine;
      });
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
        SnackBarUtils.showSuccess(context, '✅ Data refreshed', duration: const Duration(seconds: 1));
      }

      debugPrint('Manual refresh completed successfully');
    } catch (e) {
      debugPrint('ERROR refreshing data: $e');
      if (mounted) {
        SnackBarUtils.showError(context, '❌ Refresh failed: $e', duration: const Duration(seconds: 2));
      }
    }
  }

  Future<void> _onWaterAdded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];

      // Load water settings
      final settings = await WaterSettings.load();
      final waterAmountPerTap = settings.amountPerTap;
      final goal = settings.dailyGoal;

      final oldIntake = waterIntake;
      final newIntake = waterIntake + waterAmountPerTap;

      if (!_isDisposed && mounted) {
        setState(() {
          waterIntake = newIntake;
        });
        // Save water data for app use
        await prefs.setInt('water_$today', newIntake);
        // Save reset date to both keys to stay in sync with widget
        await prefs.setString('flutter.last_water_reset_date', today);
        await prefs.setString('last_water_reset_date', today);

        // Update water notifications based on new intake
        await WaterNotificationService.checkAndUpdateNotifications(newIntake, settings);

        // Sync with widget using method channel and update widget display
        try {
          await platform.invokeMethod('syncWaterData', {
            'intake': newIntake,
            'date': today,
          });
          // Update the water widget to reflect the new value
          await platform.invokeMethod('updateWaterWidget');
        } catch (e, stackTrace) {
          await ErrorLogger.logError(
            source: 'HomeScreen._onWaterAdded.syncWidget',
            error: 'Failed to sync water data with widget: $e',
            stackTrace: stackTrace.toString(),
          );
        }

        // Show congratulations when goal is reached
        if (oldIntake < goal && newIntake >= goal && mounted) {
          SnackBarUtils.showSuccess(context, '🎉 Daily water goal achieved! Great job!');
        }
      }
    } catch (e) {
      debugPrint('ERROR adding water: $e');
    }
  }

  void _onRoutineCompleted() async {
    if (!_isDisposed && mounted) {
      // Save completion status for today
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];
      await prefs.setBool('routine_completed_$today', true);

      setState(() {
        showRoutine = false;
      });
    }
  }



  Future<void> _loadCardSettings() async {
    final cardStates = await AppCustomizationService.loadAllCardStates();
    final moduleStates = await AppCustomizationService.loadAllModuleStates();
    final cardOrder = await AppCustomizationService.loadCardOrder();

    // Compute effective visibility: card toggle AND module dependency
    final effectiveVisibility = <String, bool>{};
    for (final entry in cardStates.entries) {
      final moduleKey = AppCustomizationService.cardModuleDependency[entry.key];
      final moduleEnabled = moduleKey == null || (moduleStates[moduleKey] ?? true);
      effectiveVisibility[entry.key] = entry.value && moduleEnabled;
    }

    if (mounted) {
      setState(() {
        _cardVisibility = effectiveVisibility;
        _cardOrder = cardOrder;
      });
    }
  }

  bool _isCardVisible(String cardKey) {
    return _cardVisibility[cardKey] ?? true;
  }

  List<Widget> _buildOrderedCards() {
    // Map card keys to their widget builders
    final cardBuilders = <String, Widget? Function()>{
      AppCustomizationService.cardMenstrual: () {
        if (!_isCardVisible(AppCustomizationService.cardMenstrual)) return null;
        return MenstrualCycleCard(
          key: _menstrualCycleKey,
          onTap: () {
            widget.onNavigateToModule?.call(AppCustomizationService.moduleMenstrual);
          },
        );
      },
      AppCustomizationService.cardBatteryFlow: () {
        if (!_isCardVisible(AppCustomizationService.cardBatteryFlow)) return null;
        return BatteryFlowHomeCard(key: _batteryFlowCardKey);
      },
      AppCustomizationService.cardCalendar: () {
        if (!_isCardVisible(AppCustomizationService.cardCalendar)) return null;
        return CalendarEventsCard(key: _calendarEventsKey);
      },
      AppCustomizationService.cardFasting: () {
        if (!_isCardVisible(AppCustomizationService.cardFasting)) return null;
        if (!showFastingSection) return null;
        return FastingCard(
          onHiddenForToday: _onFastingHiddenForToday,
          onFastingStatusChanged: (bool isFasting) {
            setState(() {
              _isFastingInProgress = isFasting;
            });
          },
          onTap: () => widget.onNavigateToModule?.call(AppCustomizationService.moduleFasting),
        );
      },
      AppCustomizationService.cardFoodTracking: () {
        if (!_isCardVisible(AppCustomizationService.cardFoodTracking)) return null;
        if (_isFastingInProgress) return null;
        return const FoodTrackingCard();
      },
      AppCustomizationService.cardWaterTracking: () {
        if (!_isCardVisible(AppCustomizationService.cardWaterTracking)) return null;
        if (!_shouldShowWaterTracking) return null;
        return WaterTrackingCard(
          waterIntake: waterIntake,
          onWaterAdded: _onWaterAdded,
        );
      },
      AppCustomizationService.cardHabits: () {
        if (!_isCardVisible(AppCustomizationService.cardHabits)) return null;
        if (!showHabitCard) return null;
        return HabitCard(
          onAllCompleted: _onAllHabitsCompleted,
        );
      },
      AppCustomizationService.cardRoutines: () {
        if (!_isCardVisible(AppCustomizationService.cardRoutines)) return null;
        if (!showRoutine) return null;
        return RoutineCard(
          key: _routineCardKey,
          onCompleted: _onRoutineCompleted,
          onEnergyChanged: () {
            _batteryFlowCardKey.currentState?.refresh();
          },
        );
      },
      AppCustomizationService.cardDailyTasks: () {
        if (!_isCardVisible(AppCustomizationService.cardDailyTasks)) return null;
        return const DailyTasksCard();
      },
    };

    final widgets = <Widget>[];
    for (final cardKey in _cardOrder) {
      final builder = cardBuilders[cardKey];
      if (builder != null) {
        final widget = builder();
        if (widget != null) {
          widgets.add(widget);
          widgets.add(const SizedBox(height: 4));
        }
      }
    }

    // Remove trailing spacing
    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }

    return widgets;
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) async {
      // Reload card settings when returning from settings
      _loadCardSettings();
      // Reload main screen navigation settings (primary/secondary tabs)
      await widget.onReloadSettings?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                  SnackBarUtils.showLoading(context, 'Creating backup...');

                  try {
                    // Perform quick backup
                    final backupPath = await BackupService.exportToFile();

                    if (!context.mounted) return;

                    // Hide loading and show success
                    SnackBarUtils.hide(context);

                    if (backupPath != null) {
                      SnackBarUtils.showSuccess(context, '✅ Backup completed! Saved to: ${backupPath.split('/').last}', duration: const Duration(seconds: 4));
                    } else {
                      SnackBarUtils.showError(context, '❌ Backup failed - check storage permissions', duration: const Duration(seconds: 4));
                    }
                  } catch (e) {
                    if (!context.mounted) return;

                    // Hide loading and show error
                    SnackBarUtils.hide(context);
                    SnackBarUtils.showError(context, '❌ Backup failed: ${e.toString()}', duration: const Duration(seconds: 4));
                  }

                  // Refresh backup status
                  _checkBackupStatus();
                },
                tooltip: 'Quick Backup - Tap to backup your data now',
              ),
            ),
          // Menu button on mobile (opens drawer with secondary tabs + settings)
          if (widget.onOpenDrawer != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
              ),
            ),
          // Settings button on desktop (no drawer, direct access)
          if (widget.onOpenDrawer == null)
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8), // Even tighter overall padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildOrderedCards(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
