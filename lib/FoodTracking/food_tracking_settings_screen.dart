import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'food_tracking_service.dart';

class FoodTrackingSettingsScreen extends StatefulWidget {
  const FoodTrackingSettingsScreen({super.key});

  @override
  State<FoodTrackingSettingsScreen> createState() => _FoodTrackingSettingsScreenState();
}

class _FoodTrackingSettingsScreenState extends State<FoodTrackingSettingsScreen> {
  FoodTrackingResetFrequency _resetFrequency = FoodTrackingResetFrequency.monthly;
  int _targetGoal = 80;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final frequency = await FoodTrackingService.getResetFrequency();
    final targetGoal = await FoodTrackingService.getTargetGoal();
    setState(() {
      _resetFrequency = frequency;
      _targetGoal = targetGoal;
    });
  }

  Future<void> _saveResetFrequency(FoodTrackingResetFrequency frequency) async {
    await FoodTrackingService.setResetFrequency(frequency);
    setState(() {
      _resetFrequency = frequency;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset frequency updated to ${frequency == FoodTrackingResetFrequency.weekly ? 'Weekly' : 'Monthly'}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveTargetGoal(int percentage) async {
    await FoodTrackingService.setTargetGoal(percentage);
    setState(() {
      _targetGoal = percentage;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target goal updated to $percentage%'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showResetFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Frequency'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose when your food tracking counts should reset:'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Weekly'),
                subtitle: const Text('Resets every Monday'),
                leading: Icon(
                  _resetFrequency == FoodTrackingResetFrequency.weekly
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _resetFrequency == FoodTrackingResetFrequency.weekly
                      ? AppColors.pastelGreen
                      : null,
                ),
                onTap: () {
                  _saveResetFrequency(FoodTrackingResetFrequency.weekly);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Monthly'),
                subtitle: const Text('Resets on the 1st of each month'),
                leading: Icon(
                  _resetFrequency == FoodTrackingResetFrequency.monthly
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _resetFrequency == FoodTrackingResetFrequency.monthly
                      ? AppColors.pastelGreen
                      : null,
                ),
                onTap: () {
                  _saveResetFrequency(FoodTrackingResetFrequency.monthly);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showTargetGoalDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Target Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select your target percentage for healthy food:'),
              const SizedBox(height: 16),
              for (int percentage in [70, 75, 80, 85, 90, 95])
                ListTile(
                  title: Text('$percentage%'),
                  leading: Icon(
                    _targetGoal == percentage
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _targetGoal == percentage
                        ? AppColors.pastelGreen
                        : null,
                  ),
                  onTap: () {
                    _saveTargetGoal(percentage);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Tracking Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reset Frequency Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: InkWell(
                onTap: _showResetFrequencyDialog,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.pastelGreen.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusSmall,
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.pastelGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reset Frequency',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _resetFrequency == FoodTrackingResetFrequency.weekly
                                  ? 'Weekly (every Monday)'
                                  : 'Monthly (1st of each month)',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
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

            // Target Goal Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: InkWell(
                onTap: _showTargetGoalDialog,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusSmall,
                        ),
                        child: Icon(
                          Icons.track_changes_rounded,
                          color: AppColors.lightGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Target Goal',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Currently: $_targetGoal% healthy',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
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

            const SizedBox(height: 24),

            // Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.pastelGreen.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.pastelGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.pastelGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About Food Tracking',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Track your healthy vs processed food intake. '
                          'Your progress resets based on the frequency you choose. '
                          'When there are 3 days or less until reset, you\'ll see a reminder on the home card.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.white.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
