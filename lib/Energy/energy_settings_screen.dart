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
                            "Today's Energy",
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
                              color: AppColors.coral.withValues(alpha: 0.2),
                              borderRadius: AppStyles.borderRadiusMedium,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: AppColors.coral,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_phaseInfo!['energyGoal']}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.coral,
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
              const SizedBox(height: 24),
            ],

            // Info Section
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
                          'How Energy Goals Work',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your daily energy goal adjusts based on your menstrual cycle phase:\n\n'
                      '- Ovulation: Peak energy (highest goal)\n'
                      '- Late Luteal: Low energy (lowest goal)\n'
                      '- Other phases: Gradually transitions between peaks\n\n'
                      'Energy represents both time and task difficulty:\n'
                      '1 = Quick/easy (~5 min)\n'
                      '5 = Hard/long (significant effort)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.greyText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

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
                          '${_settings.lowEnergyPeak}',
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
                        value: _settings.lowEnergyPeak.toDouble(),
                        min: 1,
                        max: 15,
                        divisions: 14,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(lowEnergyPeak: value.round());
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
                          '${_settings.highEnergyPeak}',
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
                        value: _settings.highEnergyPeak.toDouble(),
                        min: 10,
                        max: 40,
                        divisions: 30,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(highEnergyPeak: value.round());
                          });
                          _saveSettings();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

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
                      'Energy Level Guide',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEnergyLevelRow(1, 'Quick task (~5 min)', AppColors.successGreen),
                    _buildEnergyLevelRow(2, 'Short task (~15 min)', AppColors.lightGreen),
                    _buildEnergyLevelRow(3, 'Medium task (~30 min)', AppColors.yellow),
                    _buildEnergyLevelRow(4, 'Long task (~1 hour)', AppColors.orange),
                    _buildEnergyLevelRow(5, 'Major task (significant effort)', AppColors.coral),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyLevelRow(int level, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
