import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'menstrual_cycle_utils.dart';
import 'menstrual_cycle_constants.dart';
import '../shared/snackbar_utils.dart';

class CycleCalorieSettingsScreen extends StatefulWidget {
  const CycleCalorieSettingsScreen({super.key});

  @override
  State<CycleCalorieSettingsScreen> createState() => _CycleCalorieSettingsScreenState();
}

class _CycleCalorieSettingsScreenState extends State<CycleCalorieSettingsScreen> {
  Map<String, int> phaseCalories = {};
  Map<String, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    _loadCalories();
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCalories() async {
    try {
      final phases = MenstrualCycleUtils.getAllPhases();
      
      for (final phase in phases) {
        final calories = await MenstrualCycleUtils.getPhaseCalories(phase);
        phaseCalories[phase] = calories;
        controllers[phase] = TextEditingController(text: calories.toString());
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      // If loading fails, set defaults
      final phases = MenstrualCycleUtils.getAllPhases();
      for (final phase in phases) {
        phaseCalories[phase] = 2000; // Safe default
        controllers[phase] = TextEditingController(text: '2000');
      }
      
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveCalories() async {
    try {
      for (final phase in phaseCalories.keys) {
        final controller = controllers[phase];
        if (controller != null) {
          final caloriesText = controller.text;
          final calories = int.tryParse(caloriesText) ?? phaseCalories[phase] ?? 2000;
          
          // Validate calories range (1000-4000)
          final validCalories = calories.clamp(1000, 4000);
          
          await MenstrualCycleUtils.setPhaseCalories(phase, validCalories);
          phaseCalories[phase] = validCalories;
          controller.text = validCalories.toString();
        }
      }
      
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Calorie settings saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error saving settings: $e');
      }
    }
  }

  Color _getPhaseColor(String phase) {
    if (phase == MenstrualCycleConstants.menstrualPhase) return AppColors.error;
    if (phase == MenstrualCycleConstants.follicularPhase) return AppColors.successGreen;
    if (phase == MenstrualCycleConstants.ovulationPhase) return AppColors.lightPink;
    if (phase == MenstrualCycleConstants.earlyLutealPhase) return AppColors.lightPurple;
    if (phase == MenstrualCycleConstants.lateLutealPhase) return AppColors.purple;
    return AppColors.coral;
  }

  IconData _getPhaseIcon(String phase) {
    if (phase == MenstrualCycleConstants.menstrualPhase) return Icons.water_drop_rounded;
    if (phase == MenstrualCycleConstants.follicularPhase) return Icons.energy_savings_leaf;
    if (phase == MenstrualCycleConstants.ovulationPhase) return Icons.favorite_rounded;
    if (phase == MenstrualCycleConstants.earlyLutealPhase || phase == MenstrualCycleConstants.lateLutealPhase) return Icons.nights_stay_rounded;
    return Icons.timeline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase Calorie Settings'),
        backgroundColor: AppColors.transparent,
        actions: [
          IconButton(
            onPressed: _saveCalories,
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: phaseCalories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set custom calorie targets for each menstrual cycle phase',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...MenstrualCycleUtils.getAllPhases().map((phase) => 
                    _buildPhaseCalorieCard(phase)
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: AppStyles.borderRadiusMedium,
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.info, size: 20),
                            const SizedBox(width: 8),
                            const Text('Tips', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Menstruation: Lower calories due to fatigue\n'
                          '• Follicular: Higher energy, moderate calories\n'
                          '• Ovulation: Peak energy, highest calories\n'
                          '• Luteal: Cravings may increase, adjust accordingly',
                          style: TextStyle(fontSize: 14, color: AppColors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPhaseCalorieCard(String phase) {
    final color = _getPhaseColor(phase);
    final icon = _getPhaseIcon(phase);
    final controller = controllers[phase];
    
    if (controller == null) {
      return const SizedBox.shrink(); // Return empty if controller not ready
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusMedium,
          color: color.withValues(alpha: 0.1),
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
                    phase,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recommended calorie intake',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                decoration: InputDecoration(
                  suffixText: 'kcal',
                  suffixStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.white60,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppStyles.borderRadiusSmall,
                    borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppStyles.borderRadiusSmall,
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    final calories = int.tryParse(value);
                    if (calories != null && calories >= 1000 && calories <= 4000) {
                      phaseCalories[phase] = calories;
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}