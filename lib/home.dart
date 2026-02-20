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
import 'package:bb_app/Habits/habit_data_models.dart';
import 'theme/app_styles.dart';
import 'shared/snackbar_utils.dart';
import 'shared/error_logger.dart';
import 'package:bb_app/Notifications/centralized_notification_manager.dart';
import 'package:bb_app/FoodTracking/food_tracking_card.dart';
import 'package:bb_app/Settings/settings_screen.dart';
import 'package:bb_app/Data/backup_service.dart';
import 'package:bb_app/shared/widget_update_service.dart';
import 'package:bb_app/Energy/battery_flow_home_card.dart';
import 'package:bb_app/Timers/activities_card.dart';
import 'package:bb_app/Timers/productivity_card.dart';
import 'package:bb_app/EndOfDayReview/end_of_day_review_card.dart';
import 'package:bb_app/Chores/chores_card.dart';
import 'package:bb_app/EndOfDayReview/end_of_day_review_screen.dart';
import 'package:bb_app/shared/collapsible_card_wrapper.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bb_app/Services/realtime_sync_service.dart';

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
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// Public method to refresh card settings from outside
  Future<void> refreshCardSettings() async {
    await _loadCardSettings();
  }

  /// Refresh data-driven cards (called when switching back to Home tab)
  void refreshCards() {
    _choresCardKey.currentState?.refresh();
    _activitiesCardKey.currentState?.refresh();
  }

  int waterIntake = 0;
  int _waterGoal = 1500; // Default water goal
  bool showFastingSection = false;
  bool _isFastingInProgress = false;
  bool showRoutine = true;
  bool showHabitCard = false;
  bool _isDisposed = false;
  Timer? _waterSyncTimer;
  bool _backupOverdue = false;
  bool _autoBackupTriggered = false; // Track if auto-backup was already triggered for this session
  Map<String, bool> _cardVisibility = {};
  List<String> _cardOrder = [];
  bool _productivityScheduledNow = false;
  bool _productivityHiddenTemporarily = false;
  bool _isEveningTime = false;
  bool _endOfDayReviewEnabled = false;
  Set<String> _cardsHiddenForToday = {}; // Cards swiped away for today
  double? _expandedTasksHeight; // Calculated height to fill remaining space
  Key _dailyTasksKey = UniqueKey(); // Force rebuild of DailyTasksCard on sync

  // Method channel for communicating with Android widget
  static const platform = MethodChannel('com.bb.bb_app/water_widget');

  // Add a key to force rebuild of MenstrualCycleCard
  Key _menstrualCycleKey = UniqueKey();

  // Add a key to force rebuild of RoutineCard
  final Key _routineCardKey = UniqueKey();

  // Key to access CalendarEventsCard for refresh
  final GlobalKey _calendarEventsKey = GlobalKey();

  // Key to access BatteryFlowHomeCard for refresh
  final GlobalKey<BatteryFlowHomeCardState> _batteryFlowCardKey = GlobalKey<BatteryFlowHomeCardState>();

  // Key to access EndOfDayReviewCard for refresh when tasks change
  final GlobalKey<EndOfDayReviewCardState> _endOfDayReviewCardKey = GlobalKey<EndOfDayReviewCardState>();

  // Keys to access ChoresCard and ActivitiesCard for refresh when returning to Home
  final GlobalKey<ChoresCardState> _choresCardKey = GlobalKey<ChoresCardState>();
  final GlobalKey<ActivitiesCardState> _activitiesCardKey = GlobalKey<ActivitiesCardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _checkBackupStatus();
    _startWaterSyncTimer();
    _loadCardSettings();
    // Listen for remote sync events (e.g., phone edited a task while web was open)
    RealtimeSyncService().addSyncEventListener(_onRemoteSyncEvent);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _waterSyncTimer?.cancel();
    RealtimeSyncService().removeSyncEventListener(_onRemoteSyncEvent);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when remote data changes arrive (e.g., phone synced new tasks)
  void _onRemoteSyncEvent() {
    if (!_isDisposed && mounted) {
      setState(() {
        // Force rebuild DailyTasksCard with fresh data
        _dailyTasksKey = UniqueKey();
      });
      debugPrint('HomeScreen: Remote sync detected — refreshing cards');
    }
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
      _checkHabitCycleCompletions();
      _checkHabitsWithMissedDays();

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
        final wasOverdue = _backupOverdue;
        final isNowOverdue = backupStatus['any_overdue'] ?? false;

        setState(() {
          _backupOverdue = isNowOverdue;
        });

        // Auto-backup and share when overdue is detected (only once per session)
        if (isNowOverdue && !wasOverdue && !_autoBackupTriggered) {
          _autoBackupTriggered = true;
          _performAutoBackupAndShare();
        }
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

  /// Automatically create a backup and open the share panel
  Future<void> _performAutoBackupAndShare() async {
    if (!mounted) return;

    // Show loading indicator
    SnackBarUtils.showLoading(context, 'Creating automatic backup...');

    try {
      // Perform backup
      final backupPath = await BackupService.exportToFile();

      if (!mounted) return;

      // Hide loading
      SnackBarUtils.hide(context);

      if (backupPath != null) {
        // Show success message briefly
        SnackBarUtils.showSuccess(
          context,
          '✅ Backup created! Opening share panel...',
          duration: const Duration(seconds: 2),
        );

        // Wait a moment for snackbar to show, then open share panel
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        await _shareBackupFile(backupPath);

        // Refresh backup status after sharing
        _checkBackupStatus();
      } else {
        SnackBarUtils.showError(
          context,
          '❌ Auto-backup failed - check storage permissions',
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.hide(context);
      SnackBarUtils.showError(
        context,
        '❌ Auto-backup failed: ${e.toString()}',
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Share a backup file using the system share panel
  Future<void> _shareBackupFile(String filePath) async {
    try {
      final originalFile = File(filePath);
      if (!await originalFile.exists()) {
        if (mounted) {
          SnackBarUtils.showError(context, '❌ Backup file not found for sharing');
        }
        return;
      }

      // Create a temporary copy for sharing to prevent file system issues
      final fileName = filePath.split(Platform.pathSeparator).last;
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}${Platform.pathSeparator}share_$fileName');

      // Copy the file to temp location
      await originalFile.copy(tempFile.path);

      final now = DateTime.now();
      final dateTime = '${DateFormatUtils.formatLong(now)}, ${DateFormatUtils.formatTime24(now)}';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'BBetter App Backup - $dateTime',
          subject: 'BBetter Backup File - $dateTime',
        ),
      );

      // Update cloud share timestamp
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_cloud_share', now.toIso8601String());
      } catch (e) {
        debugPrint('Could not update cloud share timestamp: $e');
      }

      // Clean up temp file after a delay
      Future.delayed(const Duration(seconds: 10), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('Could not clean up temp file: $e');
        }
      });

    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '❌ Error sharing backup: $e');
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
      // Refresh tasks — on web this is critical to pick up changes from phone
      // while this tab was in the background
      setState(() {
        _dailyTasksKey = UniqueKey();
      });
      // Note: RoutineCard handles its own refresh via WidgetsBindingObserver._refreshRoutine()
      // Do NOT reassign _routineCardKey here - it destroys and rebuilds the card, showing a loading spinner
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
      // Note: Flutter's SharedPreferences adds "flutter." prefix internally
      // So getString('last_water_reset_date') looks for 'flutter.last_water_reset_date'
      // The widget saves to both prefixed and non-prefixed keys for compatibility
      final lastResetDate = prefs.getString('last_water_reset_date');
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
        // Save reset date (Flutter adds "flutter." prefix internally)
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

  Future<void> _checkFastingVisibility() async {
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
  Future<void> _onFastingHiddenForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];
    await prefs.setBool('fasting_hidden_$today', true);

    if (!_isDisposed && mounted) {
      setState(() {
        showFastingSection = false;
      });
    }
  }

  Future<void> _checkRoutineVisibility() async {
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

  /// Check for habits with completed cycles and prompt user to start new cycles
  Future<void> _checkHabitCycleCompletions() async {
    try {
      final habitsWithCompletedCycles = await HabitService.getHabitsWithCompletedCycles();

      if (habitsWithCompletedCycles.isEmpty) return;

      // Show dialog for each habit with completed cycle (one at a time)
      for (final habit in habitsWithCompletedCycles) {
        if (!mounted || _isDisposed) break;

        // Check if we've already prompted for this habit today
        final prefs = await SharedPreferences.getInstance();
        final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];
        final promptKey = 'habit_cycle_prompt_${habit.id}_$today';

        if (prefs.getBool(promptKey) == true) continue;

        // Mark as prompted for today
        await prefs.setBool(promptKey, true);

        // Show the dialog
        await _showCycleCompletionPrompt(habit);
      }
    } catch (e) {
      debugPrint('ERROR checking habit cycle completions: $e');
    }
  }

  /// Check for habits with 2+ consecutive missed days and prompt user
  Future<void> _checkHabitsWithMissedDays() async {
    try {
      final habitsWithMissedDays = await HabitService.getHabitsWithConsecutiveMissedDays(minMissedDays: 2);

      if (habitsWithMissedDays.isEmpty) return;

      // Show dialog for each habit (one at a time)
      for (final habit in habitsWithMissedDays) {
        if (!mounted || _isDisposed) break;

        // Check if we've already prompted for this habit today
        final prefs = await SharedPreferences.getInstance();
        final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];
        final promptKey = 'habit_missed_prompt_${habit.id}_$today';

        if (prefs.getBool(promptKey) == true) continue;

        // Mark as prompted for today
        await prefs.setBool(promptKey, true);

        // Show the dialog
        await _showMissedDaysPrompt(habit);
      }
    } catch (e) {
      debugPrint('ERROR checking habits with missed days: $e');
    }
  }

  Future<void> _showMissedDaysPrompt(Habit habit) async {
    if (!mounted) return;

    final missedDays = habit.getConsecutiveMissedDays();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.favorite_border, color: AppColors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hey, checking in! 💭',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I noticed "${habit.name}" hasn\'t been marked for $missedDays day${missedDays == 1 ? '' : 's'}. Life happens, and that\'s okay! 🌱',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'What would you like to do?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            // Option 1: Fresh Start
            _buildOptionCard(
              icon: Icons.refresh_rounded,
              color: AppColors.successGreen,
              title: 'Fresh Start',
              description: 'Reset and begin a new cycle from today',
              onTap: () async {
                final habitId = habit.id;
                final habitName = habit.name;
                Navigator.pop(dialogContext);
                await HabitService.restartHabitCycle(habitId);
                await _checkHabitCardVisibility();
                if (mounted) {
                  SnackBarUtils.showSuccess(context, '🌟 Fresh start for "$habitName"! You\'ve got this!');
                }
              },
            ),
            const SizedBox(height: 8),
            // Option 2: Grace Period
            _buildOptionCard(
              icon: Icons.spa_rounded,
              color: Colors.blue,
              title: 'Grace Period',
              description: 'Grant yourself kindness - keep your streak alive',
              onTap: () async {
                final habitId = habit.id;
                final habitName = habit.name;
                Navigator.pop(dialogContext);
                await HabitService.grantForgivenessForHabit(habitId, missedDays);
                await _checkHabitCardVisibility();
                if (mounted) {
                  SnackBarUtils.showSuccess(context, '💚 Grace granted for "$habitName". Be kind to yourself!');
                }
              },
            ),
            const SizedBox(height: 8),
            // Option 3: Take a Break
            _buildOptionCard(
              icon: Icons.pause_circle_outline_rounded,
              color: AppColors.greyText,
              title: 'Take a Break',
              description: 'Pause this habit for now - you can reactivate anytime',
              onTap: () async {
                final habitId = habit.id;
                final habitName = habit.name;
                Navigator.pop(dialogContext);
                await HabitService.deactivateHabit(habitId);
                await _checkHabitCardVisibility();
                if (mounted) {
                  SnackBarUtils.showInfo(context, '⏸️ "$habitName" paused. It\'ll be waiting when you\'re ready!');
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Keep Going',
              style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppStyles.borderRadiusSmall,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _showCycleCompletionPrompt(Habit habit) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: AppColors.successGreen, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cycle Complete!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations! You\'ve completed a ${habit.duration.label} cycle for "${habit.name}".',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusSmall,
                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: AppColors.successGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${habit.getCurrentCycleProgress()} days completed! This is a major milestone in building lasting habits.',
                      style: TextStyle(
                        color: AppColors.successGreen.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to start a new ${habit.duration.label} cycle for this habit?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Current Progress',
              style: TextStyle(color: AppColors.greyText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final habitName = habit.name;
              final durationLabel = habit.duration.label;
              Navigator.pop(context);
              await HabitService.startNewCycle(habit.id);
              await _checkHabitCardVisibility();

              if (mounted) {
                SnackBarUtils.showSuccess(context, 'New $durationLabel cycle started for "$habitName"!');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start New Cycle'),
          ),
        ],
      ),
    );
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

  void _onChoreCompleted() {
    // Chores card handles its own refresh, but trigger setState to update if needed
    if (!_isDisposed && mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCardSettings() async {
    final cardStates = await AppCustomizationService.loadAllCardStates();
    final moduleStates = await AppCustomizationService.loadAllModuleStates();
    final cardOrder = await AppCustomizationService.loadCardOrder();
    final productivityScheduled = await AppCustomizationService.isProductivityCardScheduledNow();
    final isEvening = await AppCustomizationService.isEveningTime();
    final reviewEnabled = await AppCustomizationService.isEndOfDayReviewEnabled();

    // Check if productivity card was hidden today (persists until next day)
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];
    final productivityHidden = prefs.getBool('productivity_hidden_$today') ?? false;

    // Load cards that were swiped away for today
    final hiddenCardsJson = prefs.getStringList('cards_hidden_$today') ?? [];
    final hiddenCards = hiddenCardsJson.toSet();

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
        _productivityScheduledNow = productivityScheduled;
        _productivityHiddenTemporarily = productivityHidden;
        _isEveningTime = isEvening;
        _endOfDayReviewEnabled = reviewEnabled;
        _cardsHiddenForToday = hiddenCards;
      });
    }
  }

  bool _isCardVisible(String cardKey) {
    return _cardVisibility[cardKey] ?? true;
  }

  /// Hide a card for today (when user swipes it away)
  Future<void> _hideCardForToday(String cardKey) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];

    // Add to hidden set
    _cardsHiddenForToday.add(cardKey);

    // Persist to SharedPreferences
    await prefs.setStringList('cards_hidden_$today', _cardsHiddenForToday.toList());

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  /// Check if a card is hidden for today
  bool _isCardHiddenForToday(String cardKey) {
    return _cardsHiddenForToday.contains(cardKey);
  }

  /// Show in-app alert when timer completes (especially useful on desktop)
  void _onTimerComplete(String title, String message, bool isBreak) {
    if (!mounted) return;

    // Show a prominent snackbar with the completion message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isBreak ? Icons.coffee_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isBreak ? AppColors.pastelGreen : AppColors.purple,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
        return DailyTasksCard(
          key: _dailyTasksKey,
          height: _expandedTasksHeight,
          onTasksChanged: () {
            // Refresh EndOfDayReviewCard when tasks change
            _endOfDayReviewCardKey.currentState?.refresh();
          },
        );
      },
      AppCustomizationService.cardChores: () {
        if (!_isCardVisible(AppCustomizationService.cardChores)) return null;
        return ChoresCard(
          key: _choresCardKey,
          onTap: () => widget.onNavigateToModule?.call(AppCustomizationService.moduleChores),
          onChoreCompleted: _onChoreCompleted,
        );
      },
      AppCustomizationService.cardActivities: () {
        if (!_isCardVisible(AppCustomizationService.cardActivities)) return null;
        return ActivitiesCard(
          key: _activitiesCardKey,
          onNavigateToTimers: () => widget.onNavigateToModule?.call(AppCustomizationService.moduleTimers),
        );
      },
      AppCustomizationService.cardProductivity: () {
        if (!_isCardVisible(AppCustomizationService.cardProductivity)) return null;
        // On mobile, respect schedule and temporary hide
        if (!_productivityScheduledNow || _productivityHiddenTemporarily) return null;
        return ProductivityCard(
          onNavigateToTimers: () => widget.onNavigateToModule?.call(AppCustomizationService.moduleTimers),
          onHideTemporarily: () async {
            // Persist hide until next day
            final prefs = await SharedPreferences.getInstance();
            final today = DateFormatUtils.formatISO(DateFormatUtils.stripTime(DateTime.now())).split('T')[0];
            await prefs.setBool('productivity_hidden_$today', true);
            if (mounted && !_isDisposed) {
              setState(() => _productivityHiddenTemporarily = true);
            }
          },
          onTimerComplete: _onTimerComplete,
        );
      },
      AppCustomizationService.cardEndOfDayReview: () {
        if (!_isCardVisible(AppCustomizationService.cardEndOfDayReview)) return null;
        // Only show during evening time and if feature is enabled
        if (!_isEveningTime || !_endOfDayReviewEnabled) return null;
        return EndOfDayReviewCard(key: _endOfDayReviewCardKey);
      },
    };

    final widgets = <Widget>[];
    for (final cardKey in _cardOrder) {
      // Skip cards hidden for today
      if (_isCardHiddenForToday(cardKey)) continue;

      final builder = cardBuilders[cardKey];
      if (builder != null) {
        final builtWidget = builder();
        if (builtWidget != null) {
          // ProductivityCard has its own hide button and interactive tabs —
          // skip Dismissible to avoid gesture conflicts
          if (cardKey == AppCustomizationService.cardProductivity) {
            widgets.add(builtWidget);
          } else {
            // Wrap with Dismissible for swipe-to-hide
            widgets.add(
              Dismissible(
                key: ValueKey('dismissible_$cardKey'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.2),
                    borderRadius: AppStyles.borderRadiusLarge,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Hidden for today',
                        style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.visibility_off_rounded, color: AppColors.coral),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  HapticFeedback.lightImpact();
                  return true;
                },
                onDismissed: (direction) {
                  _hideCardForToday(cardKey);
                  SnackBarUtils.showSuccess(
                    context,
                    'Card hidden for today',
                    duration: const Duration(seconds: 2),
                  );
                },
                child: builtWidget,
              ),
            );
          }
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
      await _loadCardSettings();
      // Reload main screen navigation settings (primary/secondary tabs)
      await widget.onReloadSettings?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Menu button on left (mobile only)
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
              )
            : null,
        title: const Text('bbetter',
            style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: AppColors.transparent,
        actions: [
          // End of day review button (visible during evening only)
          if (_isEveningTime && _endOfDayReviewEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Icon(Icons.summarize_rounded, color: AppColors.purple),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EndOfDayReviewScreen(),
                    ),
                  );
                },
                tooltip: 'Today\'s Summary',
              ),
            ),
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
        child: _buildResponsiveBody(context),
      ),
    );
  }

  Widget _buildResponsiveBody(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    if (isDesktop) {
      return _buildDesktopDashboard();
    }
    return _buildMobileSingleColumn();
  }

  Widget _buildMobileSingleColumn() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        final cards = _buildOrderedCards();
        // Count non-task cards (each ~100-150px estimated + 8px spacing)
        final otherCardCount = cards.where((w) => w is! SizedBox).length - 1; // -1 for tasks card
        final estimatedOtherHeight = otherCardCount * 140.0;
        final availableForTasks = viewportHeight - estimatedOtherHeight - 32; // padding
        final tasksHeight = availableForTasks > 320 ? availableForTasks : null;

        // Store for card builders to use
        _expandedTasksHeight = tasksHeight;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildOrderedCards(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Track drag state for desktop reordering
  String? _draggedCardKey;

  Widget _buildDesktopDashboard() {
    _expandedTasksHeight = null; // Desktop uses default height
    final cards = _buildAllCardsForDesktopWithKeys();

    // Cards that should be double-width on desktop
    const doubleWidthCards = {
      AppCustomizationService.cardCalendar,
      AppCustomizationService.cardDailyTasks,
    };

    const singleWidth = 380.0;
    const doubleWidth = 772.0; // 380 * 2 + 12 (spacing)

    // Get card metadata for collapsible wrappers
    final cardInfoMap = {
      for (final info in AppCustomizationService.allCards) info.key: info
    };

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((entry) {
          final cardKey = entry.$1;
          final cardWidget = entry.$2;
          final isDoubleWidth = doubleWidthCards.contains(cardKey);
          final cardInfo = cardInfoMap[cardKey];
          final cardWidth = isDoubleWidth ? doubleWidth : singleWidth;

          Widget wrappedCard = cardWidget;

          // Wrap with collapsible wrapper if we have card info
          if (cardInfo != null) {
            wrappedCard = CollapsibleCardWrapper(
              cardKey: cardKey,
              title: cardInfo.label,
              icon: cardInfo.icon,
              iconColor: cardInfo.color,
              child: cardWidget,
            );
          }

          // Wrap with drag-and-drop support
          return _buildDraggableCard(
            cardKey: cardKey,
            width: cardWidth,
            child: wrappedCard,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDraggableCard({
    required String cardKey,
    required double width,
    required Widget child,
  }) {
    final isDragging = _draggedCardKey == cardKey;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != cardKey,
      onAcceptWithDetails: (details) async {
        final draggedKey = details.data;
        final targetKey = cardKey;

        // Reorder the cards
        final newOrder = List<String>.from(_cardOrder);
        final draggedIndex = newOrder.indexOf(draggedKey);
        final targetIndex = newOrder.indexOf(targetKey);

        if (draggedIndex != -1 && targetIndex != -1) {
          newOrder.removeAt(draggedIndex);
          newOrder.insert(targetIndex, draggedKey);

          // Save new order
          await AppCustomizationService.saveCardOrder(newOrder);

          if (mounted) {
            setState(() {
              _cardOrder = newOrder;
              _draggedCardKey = null;
            });
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Insertion indicator line shown above the target card
            if (isTarget)
              Container(
                width: width,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            LongPressDraggable<String>(
              data: cardKey,
              delay: const Duration(milliseconds: 150),
              onDragStarted: () {
                HapticFeedback.mediumImpact();
                setState(() => _draggedCardKey = cardKey);
              },
              onDragEnd: (_) {
                setState(() => _draggedCardKey = null);
              },
              feedback: Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width, maxHeight: 200),
                    child: Opacity(
                      opacity: 0.85,
                      child: child,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: SizedBox(width: width, height: 60, child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.normalCardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.purple.withValues(alpha: 0.3), width: 1),
                  ),
                )),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: width,
                transform: isDragging
                    ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
                    : Matrix4.identity(),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build ALL cards for desktop with their keys for variable width support
  /// Respects card visibility toggles from settings
  List<(String, Widget)> _buildAllCardsForDesktopWithKeys() {
    final cardBuilders = <String, Widget? Function()>{
      AppCustomizationService.cardProductivity: () {
        if (!_isCardVisible(AppCustomizationService.cardProductivity)) return null;
        return ProductivityCard(
          onNavigateToTimers: () => widget.onNavigateToModule?.call(AppCustomizationService.moduleTimers),
          onTimerComplete: _onTimerComplete,
        );
      },
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
        return DailyTasksCard(
          key: _dailyTasksKey,
          height: _expandedTasksHeight,
          onTasksChanged: () {
            // Refresh EndOfDayReviewCard when tasks change
            _endOfDayReviewCardKey.currentState?.refresh();
          },
        );
      },
      AppCustomizationService.cardChores: () {
        if (!_isCardVisible(AppCustomizationService.cardChores)) return null;
        return ChoresCard(
          key: _choresCardKey,
          onTap: () => widget.onNavigateToModule?.call(AppCustomizationService.moduleChores),
          onChoreCompleted: _onChoreCompleted,
        );
      },
      AppCustomizationService.cardActivities: () {
        if (!_isCardVisible(AppCustomizationService.cardActivities)) return null;
        return ActivitiesCard(
          key: _activitiesCardKey,
          onNavigateToTimers: () => widget.onNavigateToModule?.call(AppCustomizationService.moduleTimers),
        );
      },
      AppCustomizationService.cardEndOfDayReview: () {
        if (!_isCardVisible(AppCustomizationService.cardEndOfDayReview)) return null;
        // On desktop, show during evening if enabled (same logic as mobile)
        if (!_isEveningTime || !_endOfDayReviewEnabled) return null;
        return EndOfDayReviewCard(key: _endOfDayReviewCardKey);
      },
    };

    final result = <(String, Widget)>[];
    for (final cardKey in _cardOrder) {
      // Skip cards hidden for today (also applies to desktop)
      if (_isCardHiddenForToday(cardKey)) continue;

      final builder = cardBuilders[cardKey];
      if (builder != null) {
        final builtWidget = builder();
        if (builtWidget != null) {
          result.add((cardKey, builtWidget));
        }
      }
    }
    return result;
  }
}
