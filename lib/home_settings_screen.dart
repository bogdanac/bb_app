import 'package:flutter/material.dart';
import 'Notifications/motion_alert_quick_setup.dart';
import 'Data/backup_screen.dart';
import 'Routines/widget_color_settings_screen.dart';
import 'WaterTracking/water_settings_screen.dart';
import 'FoodTracking/food_tracking_settings_screen.dart';
import 'Energy/energy_settings_screen.dart';
import 'Settings/modules_screen.dart';
import 'shared/error_logs_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'FoodTracking/food_tracking_service.dart';

class HomeSettingsScreen extends StatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  State<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends State<HomeSettingsScreen> {
  int _waterAmount = 125; // Default water amount
  int _waterGoal = 1500; // Default water goal
  FoodTrackingResetFrequency _foodResetFrequency = FoodTrackingResetFrequency.monthly;
  int _foodTargetGoal = 80;

  @override
  void initState() {
    super.initState();
    _loadWaterAmount();
    _loadWaterGoal();
    _loadFoodSettings();
  }

  Future<void> _loadWaterAmount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterAmount = prefs.getInt('water_amount_per_tap') ?? 125;
    });
  }


  Future<void> _loadWaterGoal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterGoal = prefs.getInt('water_goal') ?? 1500;
    });
  }

  Future<void> _loadFoodSettings() async {
    final frequency = await FoodTrackingService.getResetFrequency();
    final targetGoal = await FoodTrackingService.getTargetGoal();
    setState(() {
      _foodResetFrequency = frequency;
      _foodTargetGoal = targetGoal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Modules Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ModulesScreen(),
                      ),
                    );
                  },
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lightPink.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.toggle_on_rounded,
                            color: AppColors.lightPink,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Modules',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Enable or disable app features',
                                style: TextStyle(
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

              // Energy Settings Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EnergySettingsScreen(),
                      ),
                    );
                  },
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.bolt_rounded,
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
                                'Energy Tracking',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configure daily energy goals based on cycle',
                                style: TextStyle(
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

              // Water Tracking Settings Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WaterSettingsScreen(),
                      ),
                    );
                  },
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.waterBlue.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.water_drop_rounded,
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
                                'Water Tracking',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Goal: ${_waterGoal}ml • Tap: ${_waterAmount}ml • Reminders',
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

              // Food Tracking Settings Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FoodTrackingSettingsScreen(),
                      ),
                    ).then((_) => _loadFoodSettings());
                  },
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
                            Icons.restaurant_rounded,
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
                                'Food Tracking',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Target: $_foodTargetGoal% • ${_foodResetFrequency == FoodTrackingResetFrequency.weekly ? 'Weekly' : 'Monthly'} reset',
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

              // Backup & Restore Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupScreen(),
                      ),
                    );
                  },
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.backup_rounded,
                            color: AppColors.successGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup & Restore',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Export/import all your app data safely',
                                style: TextStyle(
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

              // Widget Color Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WidgetColorSettingsScreen(),
                      ),
                    );
                  },
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
                            Icons.palette_rounded,
                            color: AppColors.coral,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Widget Colors',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Customize widget backgrounds',
                                style: TextStyle(
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

              // Motion Alert Setup Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MotionAlertQuickSetup(),
                      ),
                    );
                  },
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.yellow.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            color: AppColors.yellow,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Motion Alert Setup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Quick setup: Night mode or 24/7 vacation mode',
                                style: TextStyle(
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

              // Error Logs Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ErrorLogsScreen(),
                      ),
                    );
                  },
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusSmall,
                          ),
                          child: const Icon(
                            Icons.bug_report_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Error Logs',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'View app error logs for debugging',
                                style: TextStyle(
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
              ),

            ],
          ),
        ),
    );
  }
}