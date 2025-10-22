import 'package:flutter/material.dart';
import 'Notifications/motion_alert_quick_setup.dart';
import 'Data/backup_screen.dart';
import 'Routines/widget_color_settings_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadWaterAmount();
    _loadWaterGoal();
    _loadFoodResetFrequency();
  }

  Future<void> _loadWaterAmount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterAmount = prefs.getInt('water_amount_per_tap') ?? 125;
    });
  }

  Future<void> _saveWaterAmount(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    // Save in the same format as other app settings (no flutter. prefix)
    await prefs.setInt('water_amount_per_tap', amount);

    // ALSO save with flutter. prefix for Android widget compatibility
    // This ensures the widget can read it regardless of SharedPreferences behavior
    await prefs.setInt('flutter.water_amount_per_tap', amount);

    setState(() {
      _waterAmount = amount;
    });
  }

  Future<void> _loadWaterGoal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterGoal = prefs.getInt('water_goal') ?? 1500;
    });
  }

  Future<void> _saveWaterGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', goal);

    // ALSO save with flutter. prefix for Android widget compatibility
    await prefs.setInt('flutter.water_goal', goal);

    setState(() {
      _waterGoal = goal;
    });
  }

  Future<void> _loadFoodResetFrequency() async {
    final frequency = await FoodTrackingService.getResetFrequency();
    setState(() {
      _foodResetFrequency = frequency;
    });
  }

  Future<void> _saveFoodResetFrequency(FoodTrackingResetFrequency frequency) async {
    await FoodTrackingService.setResetFrequency(frequency);
    setState(() {
      _foodResetFrequency = frequency;
    });
  }


  void _showWaterAmountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int tempAmount = _waterAmount;
        return AlertDialog(
          title: const Text('Water Amount per Tap'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current: ${_waterAmount}ml'),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: tempAmount.toString()),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (ml)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0 && parsed <= 1000) {
                    tempAmount = parsed;
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Range: 1-1000ml',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (tempAmount > 0 && tempAmount <= 1000) {
                  _saveWaterAmount(tempAmount);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showWaterGoalDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int tempGoal = _waterGoal;
        return AlertDialog(
          title: const Text('Daily Water Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current goal: ${_waterGoal}ml'),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: tempGoal.toString()),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Goal (ml)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0 && parsed <= 5000) {
                    tempGoal = parsed;
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Range: 1-5000ml',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (tempGoal > 0 && tempGoal <= 5000) {
                  _saveWaterGoal(tempGoal);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showFoodResetFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Food Tracking Reset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose when your food tracking counts should reset:'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Weekly (every Monday)'),
                subtitle: const Text('Counts reset at the start of each week'),
                leading: Icon(
                  _foodResetFrequency == FoodTrackingResetFrequency.weekly
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _foodResetFrequency == FoodTrackingResetFrequency.weekly
                      ? Theme.of(context).primaryColor
                      : null,
                ),
                onTap: () {
                  _saveFoodResetFrequency(FoodTrackingResetFrequency.weekly);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Monthly (1st of each month)'),
                subtitle: const Text('Counts reset at the start of each month'),
                leading: Icon(
                  _foodResetFrequency == FoodTrackingResetFrequency.monthly
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _foodResetFrequency == FoodTrackingResetFrequency.monthly
                      ? Theme.of(context).primaryColor
                      : null,
                ),
                onTap: () {
                  _saveFoodResetFrequency(FoodTrackingResetFrequency.monthly);
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
        title: const Text('Home Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

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
                                'Widget Color',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Customize your routine widget background color',
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

              // Water Tracking Settings Section (Combined)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: Column(
                  children: [
                    // Water Amount per Tap
                    InkWell(
                      onTap: _showWaterAmountDialog,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
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
                                    'Water Amount per Tap',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Currently: ${_waterAmount}ml per tap',
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
                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.normalCardBackground,
                      ),
                    ),
                    // Daily Water Goal
                    InkWell(
                      onTap: _showWaterGoalDialog,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
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
                                Icons.flag_rounded,
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
                                    'Daily Water Goal',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Currently: ${_waterGoal}ml per day',
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Food Tracking Reset Frequency Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.normalCardBackground,
                  ),
                ),
                child: InkWell(
                  onTap: _showFoodResetFrequencyDialog,
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
                                'Food Tracking Reset',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Currently: ${_foodResetFrequency == FoodTrackingResetFrequency.weekly ? 'Weekly' : 'Monthly'}',
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

            ],
          ),
        ),
    );
  }
}