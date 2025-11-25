import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_settings_model.dart';
import 'energy_service.dart';
import 'energy_calculator.dart';

class EnergySettingsScreen extends StatefulWidget {
  const EnergySettingsScreen({super.key});

  @override
  State<EnergySettingsScreen> createState() => _EnergySettingsScreenState();
}

class _EnergySettingsScreenState extends State<EnergySettingsScreen> {
  late EnergySettings _settings;
  bool _isLoading = true;
  Map<String, dynamic>? _phaseInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await EnergyService.loadSettings();
    final phaseInfo = await EnergyCalculator.getCurrentPhaseInfo();
    if (mounted) {
      setState(() {
        _settings = settings;
        _phaseInfo = phaseInfo;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await EnergyService.saveSettings(_settings);
    // Re-initialize today's record with new settings
    await EnergyCalculator.initializeToday();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Energy Settings'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Phase Info Card
            if (_phaseInfo != null && _phaseInfo!['hasData'] == true) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.lightPink.withValues(alpha: 0.2),
                      AppColors.purple.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.lightPink.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: AppColors.lightPink,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Today's Flow Goal",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phase: ${_phaseInfo!['phase']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.greyText,
                                ),
                              ),
                              Text(
                                'Cycle Day: ${_phaseInfo!['cycleDay']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.greyText,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: 0.2),
                              borderRadius: AppStyles.borderRadiusMedium,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.track_changes_rounded,
                                  color: AppColors.purple,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_phaseInfo!['energyGoal']} pts',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Low Energy Peak Setting
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.nightlight_rounded,
                            color: AppColors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Low Energy Day Goal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Late luteal phase (before period)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_settings.minFlowGoal}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.purple,
                        inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.2),
                        thumbColor: AppColors.purple,
                        overlayColor: AppColors.purple.withValues(alpha: 0.2),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      ),
                      child: Slider(
                        value: _settings.minFlowGoal.toDouble(),
                        min: 1,
                        max: 15,
                        divisions: 14,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(minFlowGoal: value.round());
                          });
                          _saveSettings();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // High Energy Peak Setting
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            color: AppColors.coral,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'High Energy Day Goal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Ovulation phase (peak energy)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_settings.maxFlowGoal}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.coral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.coral,
                        inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.2),
                        thumbColor: AppColors.coral,
                        overlayColor: AppColors.coral.withValues(alpha: 0.2),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      ),
                      child: Slider(
                        value: _settings.maxFlowGoal.toDouble(),
                        min: 10,
                        max: 40,
                        divisions: 30,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(maxFlowGoal: value.round());
                          });
                          _saveSettings();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Energy Scale Preview
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Task Energy Scale',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEnergyLevelRow('-5', 'Most draining → 15 pts, -50% battery', AppColors.coral),
                    _buildEnergyLevelRow('-4', 'Very draining → 14 pts, -40% battery', AppColors.coral),
                    _buildEnergyLevelRow('-3', 'Draining → 13 pts, -30% battery', AppColors.orange),
                    _buildEnergyLevelRow('-2', 'Moderate drain → 12 pts, -20% battery', AppColors.orange),
                    _buildEnergyLevelRow('-1', 'Slight drain → 11 pts, -10% battery', AppColors.yellow),
                    _buildEnergyLevelRow('0', 'Neutral → 10 pts, no change', AppColors.greyText),
                    _buildEnergyLevelRow('+1', 'Slight charge → 9 pts, +10% battery', AppColors.yellow),
                    _buildEnergyLevelRow('+2', 'Moderate charge → 8 pts, +20% battery', AppColors.lightGreen),
                    _buildEnergyLevelRow('+3', 'Charging → 7 pts, +30% battery', AppColors.lightGreen),
                    _buildEnergyLevelRow('+4', 'Very charging → 6 pts, +40% battery', AppColors.successGreen),
                    _buildEnergyLevelRow('+5', 'Most charging → 5 pts, +50% battery', AppColors.successGreen),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // How It Works Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.waterBlue.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.waterBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.waterBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Understanding the System',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Task Energy
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.flash_on_rounded, color: AppColors.yellow, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Task Energy (-5 to +5)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'How draining or charging a task is. Set this when creating tasks.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.greyText,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Body Battery
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.battery_charging_full_rounded, color: AppColors.successGreen, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Body Battery (%)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your current energy level. Starts each morning based on how rested you feel. Goes down when you do draining tasks, goes up with charging tasks.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.greyText,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Flow Points
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.track_changes_rounded, color: AppColors.purple, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Flow Points',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your productivity score. Earned by completing tasks. Harder tasks earn MORE points! Daily goal adapts to your cycle phase.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.greyText,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyLevelRow(String level, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                level,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
