import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_service.dart';
import 'energy_settings_model.dart';
import 'energy_calendar_screen.dart';
import 'energy_settings_screen.dart';
import 'flow_calculator.dart';
import 'morning_battery_prompt.dart';
import 'skip_day_notification.dart';

/// Battery & Flow Home Card - Expandable card matching food tracking style
class BatteryFlowHomeCard extends StatefulWidget {
  const BatteryFlowHomeCard({super.key});

  @override
  State<BatteryFlowHomeCard> createState() => BatteryFlowHomeCardState();
}

/// Public state class so external code can call refresh()
class BatteryFlowHomeCardState extends State<BatteryFlowHomeCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  bool _isExpanded = false;
  DailyEnergyRecord? _todayRecord;
  EnergySettings? _settings;
  bool _isLoading = true;
  DateTime? _lastLoadDate;
  Timer? _decayTimer;
  bool _canUseSkip = false;
  bool _isShowingMorningPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _loadData();
    _startDecayTimer();
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Start periodic timer to apply battery decay every 15 minutes
  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Check for new day (which also reloads data)
      _checkForNewDay();
    }
  }

  /// Check if it's a new day and show morning prompt if needed
  /// Also reloads data on every call to pick up widget changes
  Future<void> _checkForNewDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If it's a different day, check streak for all missed days
    if (_lastLoadDate != null && _lastLoadDate != today) {
      // Check streak for each day from _lastLoadDate up to yesterday
      final yesterday = today.subtract(const Duration(days: 1));
      var checkDate = _lastLoadDate!;

      // Iterate through all days that need to be checked (inclusive of yesterday)
      while (!checkDate.isAfter(yesterday)) {
        await EnergyService.checkStreakAtDayEnd(checkDate);
        checkDate = checkDate.add(const Duration(days: 1));
      }
    }

    // Always reload data - this will also show morning prompt if needed
    await _loadData();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  /// Public method to refresh the card data (called when energy changes externally)
  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Load all data in parallel for faster loading
    final results = await Future.wait([
      EnergyService.getTodayRecordWithDecay(forceReload: true),
      EnergyService.loadSettings(),
      EnergyService.canUseSkip(),
    ]);

    final record = results[0] as DailyEnergyRecord?;
    final settings = results[1] as EnergySettings;
    final canSkip = results[2] as bool;

    // Update UI first, then show prompt if needed (non-blocking)
    if (mounted) {
      setState(() {
        _todayRecord = record;
        _settings = settings;
        _canUseSkip = canSkip;
        _isLoading = false;
        _lastLoadDate = today;
      });
    }

    // Show morning prompt after UI is ready (if no record today)
    if (record == null && mounted && !_isShowingMorningPrompt) {
      // Use post-frame callback to ensure the widget tree is stable
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showMorningPromptSafely();
      });
    }

    // Check for pending notifications (shown after morning prompt)
    if (mounted && !_isShowingMorningPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          // First check for streak lost notification
          final shownLostNotification = await StreakLostNotification.checkAndShow(context);

          // Then check for skip notification (if streak wasn't lost)
          if (!shownLostNotification && mounted) {
            await SkipDayNotification.checkAndShow(context);
          }
        }
      });
    }
  }

  /// Safely show the morning prompt with proper guards
  Future<void> _showMorningPromptSafely() async {
    // Guard against multiple calls
    if (_isShowingMorningPrompt || !mounted) return;

    // Don't show morning prompt before 5am
    final now = DateTime.now();
    if (now.hour < 5) return;

    // Double-check we still need to show it
    final record = await EnergyService.getTodayRecord();
    if (record != null || !mounted) return;

    _isShowingMorningPrompt = true;
    try {
      await MorningBatteryPrompt.show(context);
    } finally {
      _isShowingMorningPrompt = false;
    }

    // Reload after prompt closes - the prompt now auto-initializes if closed with X
    if (mounted) {
      final newRecord = await EnergyService.getTodayRecordWithDecay();
      if (mounted) {
        setState(() {
          _todayRecord = newRecord;
        });
      }
    }
  }

  Future<void> _adjustBattery(int change) async {
    HapticFeedback.lightImpact();
    await EnergyService.adjustBattery(change);
    await _loadData();
  }

  Future<void> _addFlowPoints(int points) async {
    HapticFeedback.lightImpact();
    await EnergyService.addFlowPoints(points);
    await _loadData();
  }

  Future<void> _useSkipDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Skip Day?'),
        content: const Text(
          'This will preserve your streak if you don\'t meet today\'s goal.\n\n'
          'You can only use 1 skip per week, and not on consecutive days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
            ),
            child: const Text('Use Skip'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await EnergyService.useStreakSkip();
      if (success && mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skip day activated! Your streak is protected.'),
            backgroundColor: AppColors.orange,
          ),
        );
        await _loadData();
      }
    }
  }

  Color _getBatteryColor(int battery) {
    if (battery >= 80) return AppColors.successGreen;
    if (battery >= 50) return AppColors.yellow;
    if (battery >= 20) return AppColors.orange;
    if (battery >= 0) return AppColors.coral;
    return const Color(0xFFD32F2F);
  }

  IconData _getBatteryIcon(int battery) {
    if (battery >= 90) return Icons.battery_full_rounded;
    if (battery >= 60) return Icons.battery_5_bar_rounded;
    if (battery >= 30) return Icons.battery_3_bar_rounded;
    if (battery >= 10) return Icons.battery_1_bar_rounded;
    return Icons.battery_0_bar_rounded;
  }

  void _showAdjustBatteryDialog() {
    if (_todayRecord == null) return;

    int newBattery = _todayRecord!.currentBattery;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Adjust Battery',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$newBattery%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _getBatteryColor(newBattery),
                  ),
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _getBatteryColor(newBattery),
                    inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.3),
                    thumbColor: _getBatteryColor(newBattery),
                    overlayColor: _getBatteryColor(newBattery).withValues(alpha: 0.3),
                    trackHeight: 8,
                  ),
                  child: Slider(
                    value: newBattery.toDouble(),
                    min: -50,
                    max: 150,
                    divisions: 200,
                    label: '$newBattery%',
                    onChanged: (value) {
                      setDialogState(() {
                        newBattery = value.round();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final change = newBattery - _todayRecord!.currentBattery;
                          await _adjustBattery(change);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppStyles.borderRadiusLarge,
            color: AppColors.homeCardBackground,
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    // Handle case when no record exists
    if (_todayRecord == null || _settings == null) {
      final now = DateTime.now();
      // Before 5am - show "night mode" card
      if (now.hour < 5) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppStyles.borderRadiusLarge,
              color: AppColors.homeCardBackground,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.nightlight_rounded,
                  color: AppColors.purple,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Get some rest! Your energy will reset after 5am.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // After 5am but no record - this shouldn't happen normally
      // but show a tap-to-start card just in case
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
        child: InkWell(
          onTap: () async {
            await _showMorningPromptSafely();
          },
          borderRadius: AppStyles.borderRadiusLarge,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppStyles.borderRadiusLarge,
              color: AppColors.homeCardBackground,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.battery_charging_full_rounded,
                  color: AppColors.successGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap to set your starting energy for today',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final battery = _todayRecord!.currentBattery;
    final flowPoints = _todayRecord!.flowPoints;
    final flowGoal = _todayRecord!.flowGoal;
    final streak = _settings!.currentStreak;
    final batteryColor = _getBatteryColor(battery);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusLarge,
          color: AppColors.homeCardBackground,
        ),
        child: Column(
          children: [
            // Header row - always visible
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: AppStyles.borderRadiusLarge,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    // Battery icon
                    Icon(
                      _getBatteryIcon(battery),
                      color: batteryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    // Battery percentage and flow info
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '$battery%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: batteryColor,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Flow icon - target/bullseye for productivity goals
                          Icon(
                            Icons.track_changes_rounded,
                            color: _todayRecord!.isGoalMet ? AppColors.successGreen : AppColors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$flowPoints/$flowGoal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _todayRecord!.isGoalMet ? AppColors.successGreen : Colors.white,
                            ),
                          ),
                          // Streak with fire icon
                          if (streak > 0) ...[
                            const SizedBox(width: 20),
                            Icon(
                              Icons.whatshot_rounded,
                              color: AppColors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$streak',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Flow points progress bar
                    SizedBox(
                      width: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (flowPoints / flowGoal).clamp(0.0, 1.0),
                          backgroundColor: AppColors.greyText.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            _todayRecord!.isGoalMet ? AppColors.successGreen : AppColors.purple,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(Icons.expand_more),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            // Expandable content
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    heightFactor: _expandAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: [
                    const Divider(color: AppColors.white24),
                    const SizedBox(height: 8),
                    // Quick action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _adjustBattery(-10),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.coral.withValues(alpha: 0.2),
                              foregroundColor: AppColors.coral,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: const Text('−10%', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _adjustBattery(10),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen.withValues(alpha: 0.2),
                              foregroundColor: AppColors.successGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: const Text('+10%', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Adjust battery dialog button
                        IconButton(
                          onPressed: _showAdjustBatteryDialog,
                          icon: const Icon(Icons.tune_rounded),
                          tooltip: 'Adjust Battery',
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.greyText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addFlowPoints(1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple.withValues(alpha: 0.2),
                              foregroundColor: AppColors.purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: const Text('+1pt', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addFlowPoints(2),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple.withValues(alpha: 0.2),
                              foregroundColor: AppColors.purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: const Text('+2pts', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // History and Settings row
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EnergyCalendarScreen(),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: AppColors.greyText,
                            ),
                            label: Text(
                              'History',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.greyText,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EnergySettingsScreen(),
                                ),
                              );
                              // Reload data after settings change
                              _loadData();
                            },
                            icon: Icon(
                              Icons.settings_rounded,
                              size: 16,
                              color: AppColors.greyText,
                            ),
                            label: Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.greyText,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Warning for low battery
                    if (FlowCalculator.isBatteryCritical(battery)) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: AppColors.coral,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Low battery! Prioritize rest.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.coral,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Skip day button - show when goal not met, streak > 0, and skip available
                    if (!_todayRecord!.isGoalMet && streak > 0 && _canUseSkip) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _useSkipDay,
                        icon: Icon(
                          Icons.shield_rounded,
                          size: 16,
                          color: AppColors.orange,
                        ),
                        label: Text(
                          'Skip day available',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.orange,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.orange,
                          side: BorderSide(
                            color: AppColors.orange,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppStyles.borderRadiusMedium,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
