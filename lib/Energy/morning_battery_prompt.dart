import 'package:flutter/material.dart';
import '../Settings/app_customization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_calculator.dart';
import 'energy_service.dart';
import 'energy_settings_model.dart';
import 'flow_calculator.dart';

/// Pre-loaded data for morning battery prompt to avoid lag
class MorningPromptData {
  final EnergySettings settings;
  final int suggestedBattery;
  final String phase;
  final int cycleDay;
  final int flowGoal;

  const MorningPromptData({
    required this.settings,
    required this.suggestedBattery,
    required this.phase,
    required this.cycleDay,
    required this.flowGoal,
  });
}

/// Morning Battery Prompt - Dialog shown on first app open to set starting battery
class MorningBatteryPrompt extends StatefulWidget {
  final MorningPromptData? preloadedData;

  const MorningBatteryPrompt({super.key, this.preloadedData});

  @override
  State<MorningBatteryPrompt> createState() => _MorningBatteryPromptState();

  /// Show the morning battery prompt
  /// Returns true if a record was initialized, false otherwise
  static Future<bool> show(BuildContext context) async {
    // Only show if energy module is enabled
    final energyEnabled = await AppCustomizationService.isModuleEnabled(
      AppCustomizationService.moduleEnergy,
    );
    if (!energyEnabled) return false;

    final now = DateTime.now();

    // Only show morning prompt between 5am and 11am
    if (now.hour < 5 || now.hour >= 11) {
      // Outside morning window - auto-initialize without prompt
      final today = await EnergyService.getTodayRecord();
      if (today == null) {
        await EnergyCalculator.initializeToday();
        return true;
      }
      return false;
    }

    // Check if morning prompt is enabled
    final settings = await EnergyService.loadSettings();
    if (!settings.showMorningPrompt) {
      // Auto-initialize with suggested battery if prompt is disabled
      final today = await EnergyService.getTodayRecord();
      if (today == null) {
        await EnergyCalculator.initializeToday();
        return true;
      }
      return false;
    }

    // Check if already set today
    final today = await EnergyService.getTodayRecord();
    if (today != null) {
      // Already initialized today
      return false;
    }

    // Pre-load all data before showing dialog to prevent lag
    final suggestion = await EnergyCalculator.calculateTodayBatterySuggestion();
    final phaseInfo = await EnergyCalculator.getCurrentPhaseInfo();
    final flowGoal = await EnergyCalculator.calculateTodayGoal();

    // Calculate wake time in minutes since midnight
    final wakeTimeMinutes = settings.wakeHour * 60 + settings.wakeMinute;
    final currentTimeMinutes = now.hour * 60 + now.minute;

    // Apply decay for time passed since wake time
    int adjustedSuggestion = suggestion;
    if (currentTimeMinutes > wakeTimeMinutes) {
      final minutesLate = currentTimeMinutes - wakeTimeMinutes;
      final hoursLate = minutesLate / 60.0;
      final decay = (hoursLate * 3).round().clamp(0, 50); // Max 50% decay, 3%/hr
      adjustedSuggestion = (suggestion - decay).clamp(settings.minBattery, settings.maxBattery);
    }

    final preloadedData = MorningPromptData(
      settings: settings,
      suggestedBattery: adjustedSuggestion,
      phase: phaseInfo['phase'] ?? '',
      cycleDay: phaseInfo['cycleDay'] ?? 0,
      flowGoal: flowGoal,
    );

    if (!context.mounted) return false;

    // Use rootNavigator to ensure dialog shows above all other routes
    // and can be dismissed properly regardless of nested navigators
    final wasConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) => MorningBatteryPrompt(preloadedData: preloadedData),
    );

    // If dialog was dismissed (closed with X or barrier tap), auto-initialize
    if (wasConfirmed != true) {
      final stillNoRecord = await EnergyService.getTodayRecord();
      if (stillNoRecord == null) {
        await EnergyCalculator.initializeToday();
        return true;
      }
    }

    return wasConfirmed == true;
  }
}

class _MorningBatteryPromptState extends State<MorningBatteryPrompt> {
  int? _suggestedBattery;
  late int _selectedBattery;
  bool _isLoading = true;
  String _phase = '';
  int _cycleDay = 0;
  int _flowGoal = 10;
  EnergySettings _settings = const EnergySettings();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Use preloaded data if available (no async needed - instant UI)
    if (widget.preloadedData != null) {
      final data = widget.preloadedData!;
      _settings = data.settings;
      _suggestedBattery = data.suggestedBattery;
      _selectedBattery = data.suggestedBattery;
      _phase = data.phase;
      _cycleDay = data.cycleDay;
      _flowGoal = data.flowGoal;
      _isLoading = false;
    } else {
      // Fallback to loading (shouldn't happen with new flow)
      _loadSuggestionFallback();
    }
  }

  Future<void> _loadSuggestionFallback() async {
    try {
      final settings = await EnergyService.loadSettings();
      final suggestion = await EnergyCalculator.calculateTodayBatterySuggestion();
      final phaseInfo = await EnergyCalculator.getCurrentPhaseInfo();
      final flowGoal = await EnergyCalculator.calculateTodayGoal();

      // Adjust suggestion based on time of day
      final now = DateTime.now();
      final wakeTimeMinutes = settings.wakeHour * 60 + settings.wakeMinute;
      final currentTimeMinutes = now.hour * 60 + now.minute;

      int adjustedSuggestion = suggestion;
      if (currentTimeMinutes > wakeTimeMinutes) {
        final minutesLate = currentTimeMinutes - wakeTimeMinutes;
        final hoursLate = minutesLate / 60.0;
        final decay = (hoursLate * 3).round().clamp(0, 50);
        adjustedSuggestion = (suggestion - decay).clamp(settings.minBattery, settings.maxBattery);
      }

      if (!mounted) return;
      setState(() {
        _settings = settings;
        _suggestedBattery = adjustedSuggestion;
        _selectedBattery = adjustedSuggestion;
        _phase = phaseInfo['phase'] ?? '';
        _cycleDay = phaseInfo['cycleDay'] ?? 0;
        _flowGoal = flowGoal;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestedBattery = 100;
        _selectedBattery = 100;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirm() async {
    try {
      // Initialize today's record using preloaded data
      await EnergyService.initializeTodayRecord(
        startingBattery: _selectedBattery,
        flowGoal: _flowGoal,
        menstrualPhase: _phase,
        cycleDayNumber: _cycleDay,
      );

      // Set decay start time:
      // - If before configured wake time: start decay from NOW (woke up early)
      // - If after configured wake time: start decay from NOW (decay already accounted in suggestion)
      final now = DateTime.now();

      // Calculate wake time in minutes since midnight
      final wakeTimeMinutes = _settings.wakeHour * 60 + _settings.wakeMinute;
      final currentTimeMinutes = now.hour * 60 + now.minute;

      DateTime decayStartTime;
      if (currentTimeMinutes < wakeTimeMinutes) {
        // Woke up early - start decay from now
        decayStartTime = now;
      } else {
        // After wake time - start decay from now since suggestion already includes decay
        decayStartTime = now;
      }
      await EnergyService.setDecayStartTime(decayStartTime);

      if (!mounted) return;
      Navigator.of(context).pop(true); // Return true to indicate confirmed
    } catch (e) {
      // Handle error
      if (!mounted) return;
      Navigator.of(context).pop(false);
    }
  }

  Color _getBatteryColor(int battery) {
    if (battery >= 80) return AppColors.successGreen;
    if (battery >= 50) return AppColors.yellow;
    if (battery >= 20) return AppColors.orange;
    return AppColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Calculating your energy...'),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.battery_charging_full_rounded,
                  color: _getBatteryColor(_selectedBattery),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateTime.now().hour < 12 ? 'Good Morning!' : 'Set Your Battery',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.greyText,
                  ),
                  tooltip: 'Skip for now',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Subtitle
            Text(
              'How charged is your body battery today?',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.greyText,
              ),
            ),

            const SizedBox(height: 24),

            // Phase info
            if (_phase.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightPink.withValues(alpha: 0.2),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: AppColors.lightPink,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_phase - Day $_cycleDay',
                      style: TextStyle(
                        color: AppColors.lightPink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Battery display
            Center(
              child: Column(
                children: [
                  Text(
                    '$_selectedBattery%',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: _getBatteryColor(_selectedBattery),
                    ),
                  ),
                  Text(
                    FlowCalculator.getBatterySuggestion(_selectedBattery),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _getBatteryColor(_selectedBattery),
                inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.3),
                thumbColor: _getBatteryColor(_selectedBattery),
                overlayColor: _getBatteryColor(_selectedBattery).withValues(alpha: 0.3),
                trackHeight: 8,
              ),
              child: Slider(
                value: _selectedBattery.toDouble().clamp(
                  _settings.minBattery.toDouble(),
                  _settings.maxBattery.toDouble(),
                ),
                min: _settings.minBattery.toDouble(),
                max: _settings.maxBattery.toDouble(),
                divisions: (_settings.maxBattery - _settings.minBattery).clamp(1, 200),
                label: '$_selectedBattery%',
                onChanged: (value) {
                  setState(() {
                    _selectedBattery = value.round();
                  });
                },
              ),
            ),

            // Suggested battery hint
            if (_suggestedBattery != null && _suggestedBattery != _selectedBattery)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedBattery = _suggestedBattery!;
                    });
                  },
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                  label: Text('Use suggested: $_suggestedBattery%'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getBatteryColor(_selectedBattery),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppStyles.borderRadiusMedium,
                  ),
                ),
                child: const Text(
                  'Start My Day',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
