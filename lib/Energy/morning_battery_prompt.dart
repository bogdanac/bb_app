import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_calculator.dart';
import 'energy_service.dart';
import 'energy_settings_model.dart';
import 'flow_calculator.dart';

/// Morning Battery Prompt - Dialog shown on first app open to set starting battery
class MorningBatteryPrompt extends StatefulWidget {
  const MorningBatteryPrompt({super.key});

  @override
  State<MorningBatteryPrompt> createState() => _MorningBatteryPromptState();

  /// Show the morning battery prompt
  static Future<void> show(BuildContext context) async {
    // Check if morning prompt is enabled
    final settings = await EnergyService.loadSettings();
    if (!settings.showMorningPrompt) {
      // Auto-initialize with suggested battery if prompt is disabled
      final today = await EnergyService.getTodayRecord();
      if (today == null) {
        await EnergyCalculator.initializeToday();
      }
      return;
    }

    // Check if already set today
    final today = await EnergyService.getTodayRecord();
    if (today != null) {
      // Already initialized today
      return;
    }

    if (!context.mounted) return;

    // Use rootNavigator to ensure dialog shows above all other routes
    // and can be dismissed properly regardless of nested navigators
    await showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) => const MorningBatteryPrompt(),
    );
  }
}

class _MorningBatteryPromptState extends State<MorningBatteryPrompt> {
  int? _suggestedBattery;
  late int _selectedBattery;
  bool _isLoading = true;
  String _phase = '';
  int _cycleDay = 0;
  EnergySettings _settings = const EnergySettings();

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    try {
      final settings = await EnergyService.loadSettings();
      final suggestion = await EnergyCalculator.calculateTodayBatterySuggestion();
      final phaseInfo = await EnergyCalculator.getCurrentPhaseInfo();

      // Adjust suggestion based on time of day
      // Battery decays ~3% per hour, so if it's later in the day, reduce suggestion
      final now = DateTime.now();
      final hourOfDay = now.hour;

      // Use wake hour from settings - if later, apply decay
      int adjustedSuggestion = suggestion;
      if (hourOfDay > settings.wakeHour) {
        final hoursLate = hourOfDay - settings.wakeHour;
        final decay = (hoursLate * 3).clamp(0, 50); // Max 50% decay, 3%/hr
        adjustedSuggestion = (suggestion - decay).clamp(settings.minBattery, settings.maxBattery);
      }

      setState(() {
        _settings = settings;
        _suggestedBattery = adjustedSuggestion;
        _selectedBattery = adjustedSuggestion;
        _phase = phaseInfo['phase'] ?? '';
        _cycleDay = phaseInfo['cycleDay'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _suggestedBattery = 100;
        _selectedBattery = 100;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirm() async {
    try {
      // Get flow goal
      final flowGoal = await EnergyCalculator.calculateTodayGoal();

      // Initialize today's record
      await EnergyService.initializeTodayRecord(
        startingBattery: _selectedBattery,
        flowGoal: flowGoal,
        menstrualPhase: _phase,
        cycleDayNumber: _cycleDay,
      );

      // Set decay start time:
      // - If before configured wake hour: start decay from NOW (woke up early)
      // - If after configured wake hour: start decay from wake hour (missed time already accounted in suggestion)
      final now = DateTime.now();
      final settings = await EnergyService.loadSettings();
      DateTime decayStartTime;
      if (now.hour < settings.wakeHour) {
        // Woke up early - start decay from now
        decayStartTime = now;
      } else {
        // After wake hour - start decay from configured wake time
        decayStartTime = DateTime(now.year, now.month, now.day, settings.wakeHour, 0);
      }
      await EnergyService.setDecayStartTime(decayStartTime);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // Handle error
      if (!mounted) return;
      Navigator.of(context).pop();
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
