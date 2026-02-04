import 'package:flutter/material.dart';
import '../Notifications/motion_alert_quick_setup.dart';
import '../WaterTracking/water_settings_screen.dart';
import '../FoodTracking/food_tracking_settings_screen.dart';
import '../Energy/energy_settings_screen.dart';
import '../FoodTracking/food_tracking_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeaturesSettingsScreen extends StatefulWidget {
  const FeaturesSettingsScreen({super.key});

  @override
  State<FeaturesSettingsScreen> createState() => _FeaturesSettingsScreenState();
}

class _FeaturesSettingsScreenState extends State<FeaturesSettingsScreen> {
  int _waterAmount = 125;
  int _waterGoal = 1500;
  FoodTrackingResetFrequency _foodResetFrequency = FoodTrackingResetFrequency.monthly;
  int _foodTargetGoal = 80;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = await FoodTrackingService.getResetFrequency();
    final targetGoal = await FoodTrackingService.getTargetGoal();
    if (mounted) {
      setState(() {
        _waterAmount = prefs.getInt('water_amount_per_tap') ?? 125;
        _waterGoal = prefs.getInt('water_goal') ?? 1500;
        _foodResetFrequency = frequency;
        _foodTargetGoal = targetGoal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Features Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Energy Tracking
                _buildSettingsCard(
                  context,
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.coral,
                  title: 'Energy Tracking',
                  subtitle: 'Configure daily energy goals based on cycle',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EnergySettingsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Water Tracking
                _buildSettingsCard(
                  context,
                  icon: Icons.water_drop_rounded,
                  iconColor: AppColors.waterBlue,
                  title: 'Water Tracking',
                  subtitle: 'Goal: ${_waterGoal}ml \u2022 Tap: ${_waterAmount}ml \u2022 Reminders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WaterSettingsScreen(),
                      ),
                    ).then((_) => _loadSettings());
                  },
                ),

                const SizedBox(height: 16),

                // Food Tracking
                _buildSettingsCard(
                  context,
                  icon: Icons.restaurant_rounded,
                  iconColor: AppColors.pastelGreen,
                  title: 'Food Tracking',
                  subtitle: 'Target: $_foodTargetGoal% \u2022 ${_foodResetFrequency == FoodTrackingResetFrequency.weekly ? 'Weekly' : 'Monthly'} reset',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FoodTrackingSettingsScreen(),
                      ),
                    ).then((_) => _loadSettings());
                  },
                ),

                const SizedBox(height: 16),

                // Motion Alert Setup
                _buildSettingsCard(
                  context,
                  icon: Icons.security_rounded,
                  iconColor: AppColors.yellow,
                  title: 'Motion Alert Setup',
                  subtitle: 'Quick setup: Night mode or 24/7 vacation mode',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MotionAlertQuickSetup(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: AppColors.normalCardBackground,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.borderRadiusLarge,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.greyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
