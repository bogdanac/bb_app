import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_service.dart';
import 'energy_settings_model.dart';
import 'flow_calculator.dart';
import 'morning_battery_prompt.dart';

/// Battery & Flow Home Card - Shows current battery %, flow points, streak, and quick actions
class BatteryFlowHomeCard extends StatefulWidget {
  const BatteryFlowHomeCard({super.key});

  @override
  State<BatteryFlowHomeCard> createState() => _BatteryFlowHomeCardState();
}

class _BatteryFlowHomeCardState extends State<BatteryFlowHomeCard> {
  DailyEnergyRecord? _todayRecord;
  EnergySettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final record = await EnergyService.getTodayRecord();
    final settings = await EnergyService.loadSettings();

    // If no record today, show morning prompt
    if (record == null && mounted) {
      await MorningBatteryPrompt.show(context);
      // Reload after prompt
      final newRecord = await EnergyService.getTodayRecord();
      setState(() {
        _todayRecord = newRecord;
        _settings = settings;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _todayRecord = record;
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _adjustBattery(int change) async {
    await EnergyService.adjustBattery(change);
    await _loadData();
  }

  Future<void> _addFlowPoints(int points) async {
    await EnergyService.addFlowPoints(points);
    await _loadData();
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

  Color _getBatteryColor(int battery) {
    if (battery >= 80) return AppColors.successGreen;
    if (battery >= 50) return AppColors.yellow;
    if (battery >= 20) return AppColors.orange;
    if (battery >= 0) return AppColors.coral;
    return const Color(0xFFD32F2F); // Dark red for critical
  }

  IconData _getBatteryIcon(int battery) {
    if (battery >= 90) return Icons.battery_full_rounded;
    if (battery >= 60) return Icons.battery_5_bar_rounded;
    if (battery >= 30) return Icons.battery_3_bar_rounded;
    if (battery >= 10) return Icons.battery_1_bar_rounded;
    return Icons.battery_0_bar_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.normalCardBackground,
          borderRadius: AppStyles.borderRadiusLarge,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_todayRecord == null || _settings == null) {
      return const SizedBox.shrink();
    }

    final battery = _todayRecord!.currentBattery;
    final flowPoints = _todayRecord!.flowPoints;
    final flowGoal = _todayRecord!.flowGoal;
    final streak = _settings!.currentStreak;
    final pr = _settings!.personalRecord;
    final batteryChange = _todayRecord!.batteryChange;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getBatteryColor(battery).withValues(alpha: 0.2),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: _getBatteryColor(battery).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                _getBatteryIcon(battery),
                color: _getBatteryColor(battery),
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Body Battery & Flow',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Battery gauge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$battery%',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _getBatteryColor(battery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (batteryChange != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                    const SizedBox(height: 4),
                    Text(
                      'Battery Level',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),

              // Flow points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.whatshot_rounded,
                        color: AppColors.coral,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$flowPoints/$flowGoal',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _todayRecord!.isGoalMet
                              ? AppColors.successGreen
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flow Points',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                    ),
                  ),
                  if (pr > 0)
                    Text(
                      'PR: $pr',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.purple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (flowPoints / flowGoal).clamp(0.0, 1.0),
              backgroundColor: AppColors.greyText.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                _todayRecord!.isGoalMet
                    ? AppColors.successGreen
                    : AppColors.purple,
              ),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 16),

          // Streak
          if (streak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🔥',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$streak day${streak > 1 ? 's' : ''} streak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Quick action buttons
          Row(
            children: [
              _QuickButton(
                label: '−10%',
                onPressed: () => _adjustBattery(-10),
                color: AppColors.coral,
              ),
              const SizedBox(width: 8),
              _QuickButton(
                label: '+10%',
                onPressed: () => _adjustBattery(10),
                color: AppColors.successGreen,
              ),
              const SizedBox(width: 8),
              _QuickButton(
                label: '+1pt',
                onPressed: () => _addFlowPoints(1),
                color: AppColors.purple,
              ),
              const SizedBox(width: 8),
              _QuickButton(
                label: '+2pts',
                onPressed: () => _addFlowPoints(2),
                color: AppColors.purple,
              ),
              const Spacer(),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Low battery! Prioritize rest and recharging activities.',
                      style: TextStyle(
                        fontSize: 13,
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
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _QuickButton({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
