import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_settings_model.dart';
import 'energy_service.dart';
import 'energy_calculator.dart';
import 'flow_calculator.dart';
import 'skip_day_notification.dart';

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

            // Battery Settings Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Battery Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyText,
                ),
              ),
            ),

            // Lowest Battery Setting (Luteal)
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
                            Icons.battery_1_bar_rounded,
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
                                'Lowest Battery',
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
                          '${_settings.minBattery}%',
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
                        value: _settings.minBattery.toDouble(),
                        min: 5,
                        max: 50,
                        divisions: 9,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(minBattery: value.round());
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

            // Highest Battery Setting (Ovulation)
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
                            Icons.battery_full_rounded,
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
                                'Highest Battery',
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
                          '${_settings.maxBattery}%',
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
                        value: _settings.maxBattery.toDouble(),
                        min: 80,
                        max: 150,
                        divisions: 14,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(maxBattery: value.round());
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

            // Wake/Sleep Hours Card
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
                            color: AppColors.waterBlue.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.schedule_rounded,
                            color: AppColors.waterBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Waking Hours',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Battery drains ~3%/hr (${_settings.wakingHours} waking hours)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(
                            label: 'Wake up',
                            icon: Icons.wb_sunny_rounded,
                            color: AppColors.yellow,
                            hour: _settings.wakeHour,
                            minute: _settings.wakeMinute,
                            onChanged: (hour, minute) {
                              setState(() {
                                _settings = _settings.copyWith(
                                  wakeHour: hour,
                                  wakeMinute: minute,
                                );
                              });
                              _saveSettings();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePicker(
                            label: 'Sleep',
                            icon: Icons.nightlight_rounded,
                            color: AppColors.purple,
                            hour: _settings.sleepHour,
                            minute: _settings.sleepMinute,
                            onChanged: (hour, minute) {
                              setState(() {
                                _settings = _settings.copyWith(
                                  sleepHour: hour,
                                  sleepMinute: minute,
                                );
                              });
                              _saveSettings();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Morning Prompt Toggle
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.1),
                        borderRadius: AppStyles.borderRadiusSmall,
                      ),
                      child: Icon(
                        Icons.wb_twilight_rounded,
                        color: AppColors.yellow,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Morning Prompt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    'Ask how charged you feel each morning',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
                value: _settings.showMorningPrompt,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(showMorningPrompt: value);
                  });
                  _saveSettings();
                },
                activeTrackColor: AppColors.yellow.withValues(alpha: 0.5),
                activeThumbColor: AppColors.yellow,
              ),
            ),

            const SizedBox(height: 12),

            // Timer Energy Tracking Toggle
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.1),
                        borderRadius: AppStyles.borderRadiusSmall,
                      ),
                      child: Icon(
                        Icons.timer_rounded,
                        color: AppColors.purple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Timer Energy Tracking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.help_outline_rounded,
                        color: AppColors.greyText,
                        size: 20,
                      ),
                      onPressed: () => _showTimerEnergyHelpDialog(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    'Timer sessions affect battery & flow points',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
                value: _settings.trackTimerEnergy,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(trackTimerEnergy: value);
                  });
                  _saveSettings();
                },
                activeTrackColor: AppColors.purple.withValues(alpha: 0.5),
                activeThumbColor: AppColors.purple,
              ),
            ),

            const SizedBox(height: 16),

            // Flow Points Settings Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Flow Points Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyText,
                ),
              ),
            ),

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

            // Skip Day Settings Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Streak Skip Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyText,
                ),
              ),
            ),

            // Skip Day Settings Card
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: InkWell(
                onTap: () async {
                  final newSettings = await SkipDaySettingsDialog.show(context, _settings);
                  if (newSettings != null) {
                    setState(() {
                      _settings = newSettings;
                    });
                    _saveSettings();
                  }
                },
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusSmall,
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: AppColors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Skip Day Frequency',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              FlowCalculator.getSkipModeDescription(_settings.skipDayMode),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.orange,
                              ),
                            ),
                            if (_settings.autoUseSkip && _settings.skipDayMode != SkipDayMode.disabled)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Auto-use enabled',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.greyText,
                                  ),
                                ),
                              ),
                          ],
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
                    _buildEnergyLevelRow('-5', 'Most draining → 1 pt, -25% battery', AppColors.coral),
                    _buildEnergyLevelRow('-4', 'Very draining → 1 pt, -20% battery', AppColors.coral),
                    _buildEnergyLevelRow('-3', 'Draining → 1 pt, -15% battery', AppColors.orange),
                    _buildEnergyLevelRow('-2', 'Moderate drain → 1 pt, -10% battery', AppColors.orange),
                    _buildEnergyLevelRow('-1', 'Slight drain → 1 pt, -5% battery', AppColors.yellow),
                    _buildEnergyLevelRow('0', 'Neutral → 1 pt, no change', AppColors.greyText),
                    _buildEnergyLevelRow('+1', 'Slight charge → 1 pt, +5% battery', AppColors.yellow),
                    _buildEnergyLevelRow('+2', 'Moderate charge → 1 pt, +10% battery', AppColors.lightGreen),
                    _buildEnergyLevelRow('+3', 'Charging → 1 pt, +15% battery', AppColors.lightGreen),
                    _buildEnergyLevelRow('+4', 'Very charging → 1 pt, +20% battery', AppColors.successGreen),
                    _buildEnergyLevelRow('+5', 'Most charging → 1 pt, +25% battery', AppColors.successGreen),
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
                                'Your energy level. Tasks: energy × 5% change. Timer sessions: ±5% per 25 min (based on activity type).',
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
                                'Your productivity score. Tasks: 1 pt each. Timer sessions: 1 pt per 25 min. Daily goal adapts to your cycle phase.',
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

  void _showTimerEnergyHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: Row(
          children: [
            Icon(Icons.timer_rounded, color: AppColors.purple),
            const SizedBox(width: 8),
            const Text('Timer Energy Tracking'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When enabled, timer sessions contribute to your daily energy tracking.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.greyText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                icon: Icons.track_changes_rounded,
                color: AppColors.purple,
                title: 'Flow Points',
                description: 'Earn 1 flow point for every 25 minutes of focused work.',
              ),
              const SizedBox(height: 12),
              _buildHelpSection(
                icon: Icons.battery_charging_full_rounded,
                color: AppColors.successGreen,
                title: 'Battery Impact',
                description: 'Activities can be set as:\n'
                    '• Recharging: +5% battery per 25 min\n'
                    '• Neutral: No battery change\n'
                    '• Draining: -5% battery per 25 min',
              ),
              const SizedBox(height: 12),
              _buildHelpSection(
                icon: Icons.edit_rounded,
                color: AppColors.waterBlue,
                title: 'Setting Activity Type',
                description: 'Long-press an activity in the Timers tab to edit its energy mode.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.1),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: AppColors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Example: 50 min of a draining activity = 2 flow points and -10% battery',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.purple,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: AppStyles.textButtonStyle(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
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
    );
  }

  Widget _buildTimePicker({
    required String label,
    required IconData icon,
    required Color color,
    required int hour,
    required int minute,
    required void Function(int hour, int minute) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
        );
        if (time != null) {
          onChanged(time.hour, time.minute);
        }
      },
      borderRadius: AppStyles.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppStyles.borderRadiusSmall,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.greyText,
                  ),
                ),
                Text(
                  '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
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
