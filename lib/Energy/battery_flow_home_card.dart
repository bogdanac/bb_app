import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_service.dart';
import 'energy_settings_model.dart';
import 'energy_settings_screen.dart';
import 'flow_calculator.dart';
import 'morning_battery_prompt.dart';

/// Battery & Flow Home Card - Expandable card matching food tracking style
class BatteryFlowHomeCard extends StatefulWidget {
  const BatteryFlowHomeCard({super.key});

  @override
  State<BatteryFlowHomeCard> createState() => _BatteryFlowHomeCardState();
}

class _BatteryFlowHomeCardState extends State<BatteryFlowHomeCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  bool _isExpanded = false;
  DailyEnergyRecord? _todayRecord;
  EnergySettings? _settings;
  bool _isLoading = true;
  DateTime? _lastLoadDate;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _checkForNewDay();
    }
  }

  /// Check if it's a new day and show morning prompt if needed
  Future<void> _checkForNewDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If we haven't loaded yet or it's a different day, check for morning prompt
    if (_lastLoadDate == null || _lastLoadDate != today) {
      final record = await EnergyService.getTodayRecord();
      if (record == null && mounted) {
        // It's a new day with no record - show morning prompt
        await MorningBatteryPrompt.show(context);
      }
      // Reload data (whether we showed prompt or not)
      await _loadData();
    }
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

  Future<void> _loadData() async {
    // Use getTodayRecordWithDecay to apply automatic battery decay
    final record = await EnergyService.getTodayRecordWithDecay();
    final settings = await EnergyService.loadSettings();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If no record today, show morning prompt
    if (record == null && mounted) {
      await MorningBatteryPrompt.show(context);
      // Reload after prompt (with decay)
      final newRecord = await EnergyService.getTodayRecordWithDecay();
      if (mounted) {
        setState(() {
          _todayRecord = newRecord;
          _settings = settings;
          _isLoading = false;
          _lastLoadDate = today;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _todayRecord = record;
        _settings = settings;
        _isLoading = false;
        _lastLoadDate = today;
      });
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

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EnergySettingsScreen()),
    ).then((_) => _loadData());
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

    // Don't show card if no data
    if (_todayRecord == null || _settings == null) {
      return const SizedBox.shrink();
    }

    final battery = _todayRecord!.currentBattery;
    final flowPoints = _todayRecord!.flowPoints;
    final flowGoal = _todayRecord!.flowGoal;
    final streak = _settings!.currentStreak;
    final batteryColor = _getBatteryColor(battery);
    final batteryChange = _todayRecord!.batteryChange;

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
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
                child: Row(
                  children: [
                    // Battery icon
                    Icon(
                      _getBatteryIcon(battery),
                      color: batteryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
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
                          const SizedBox(width: 12),
                          Icon(
                            Icons.whatshot_rounded,
                            color: _todayRecord!.isGoalMet ? AppColors.successGreen : AppColors.coral,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$flowPoints/$flowGoal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _todayRecord!.isGoalMet ? AppColors.successGreen : Colors.white,
                            ),
                          ),
                          if (streak > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '🔥$streak',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Progress bar
                    SizedBox(
                      width: 60,
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
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      tooltip: 'Settings',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
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
                    const SizedBox(height: 2),
                    // Battery change indicator
                    if (batteryChange != 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Today: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.greyText,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: batteryChange > 0
                                    ? AppColors.successGreen.withValues(alpha: 0.2)
                                    : AppColors.coral.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${batteryChange > 0 ? '+' : ''}$batteryChange%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: batteryChange > 0
                                      ? AppColors.successGreen
                                      : AppColors.coral,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showAdjustBatteryDialog,
                          icon: const Icon(Icons.tune_rounded),
                          tooltip: 'Adjust Battery',
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.purple,
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
