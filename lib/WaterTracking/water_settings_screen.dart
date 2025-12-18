import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/time_picker_utils.dart';
import 'water_settings_model.dart';
import 'water_notification_service.dart';

class WaterSettingsScreen extends StatefulWidget {
  const WaterSettingsScreen({super.key});

  @override
  State<WaterSettingsScreen> createState() => _WaterSettingsScreenState();
}

class _WaterSettingsScreenState extends State<WaterSettingsScreen> {
  late WaterSettings _settings;
  bool _isLoading = true;

  final TextEditingController _dailyGoalController = TextEditingController();
  final TextEditingController _amountPerTapController = TextEditingController();
  final TextEditingController _dayStartController = TextEditingController();
  final TextEditingController _dayEndController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await WaterSettings.load();
    setState(() {
      _settings = settings;
      _dailyGoalController.text = settings.dailyGoal.toString();
      _amountPerTapController.text = settings.amountPerTap.toString();
      _dayStartController.text = settings.dayStartHour.toString();
      _dayEndController.text = settings.dayEndHour.toString();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _settings.save();

    // Reschedule notifications with new settings
    await WaterNotificationService.scheduleNotifications(_settings);

    // Check current intake and cancel notifications for thresholds already met
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final currentIntake = prefs.getInt('water_$today') ?? 0;
    if (currentIntake > 0) {
      await WaterNotificationService.checkAndUpdateNotifications(currentIntake, _settings);
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Water settings saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _updateDailyGoal(String value) {
    final goal = int.tryParse(value);
    if (goal != null && goal >= 500 && goal <= 5000) {
      setState(() {
        _settings = _settings.copyWith(dailyGoal: goal);
      });
    }
  }

  void _updateAmountPerTap(String value) {
    final amount = int.tryParse(value);
    if (amount != null && amount >= 50 && amount <= 1000) {
      setState(() {
        _settings = _settings.copyWith(amountPerTap: amount);
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await TimePickerUtils.showStyledTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: isStartTime ? _settings.dayStartHour : _settings.dayEndHour,
        minute: 0,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          if (picked.hour < _settings.dayEndHour) {
            _settings = _settings.copyWith(dayStartHour: picked.hour);
          }
        } else {
          if (picked.hour > _settings.dayStartHour) {
            _settings = _settings.copyWith(dayEndHour: picked.hour);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _dailyGoalController.dispose();
    _amountPerTapController.dispose();
    _dayStartController.dispose();
    _dayEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        color: AppColors.appBackground,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Main Settings Card
            _buildSectionCard(
              title: 'Water Tracking',
              icon: Icons.water_drop_rounded,
              iconColor: AppColors.waterBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dailyGoalController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Daily Goal (ml)',
                            hintText: '1500',
                            suffix: const Text('ml'),
                            border: OutlineInputBorder(
                              borderRadius: AppStyles.borderRadiusMedium,
                            ),
                          ),
                          onChanged: _updateDailyGoal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _amountPerTapController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Per Tap (ml)',
                            hintText: '125',
                            suffix: const Text('ml'),
                            border: OutlineInputBorder(
                              borderRadius: AppStyles.borderRadiusMedium,
                            ),
                          ),
                          onChanged: _updateAmountPerTap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, true),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Day Starts',
                              border: OutlineInputBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                            ),
                            child: Text(
                              '${_settings.dayStartHour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, false),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Day Ends',
                              border: OutlineInputBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                            ),
                            child: Text(
                              '${_settings.dayEndHour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_settings.dailyGoal / _settings.amountPerTap).ceil()} taps to goal • ${_settings.dayEndHour - _settings.dayStartHour}h active day',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.white54,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notification Thresholds Section
            _buildSectionCard(
              title: 'Reminder Thresholds',
              icon: Icons.notifications_active_rounded,
              iconColor: AppColors.lightPink,
              child: Column(
                children: [
                  _buildThresholdToggle(20),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildThresholdToggle(40),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildThresholdToggle(60),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildThresholdToggle(80),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.waterBlue,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                ),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.borderRadiusLarge,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusLarge,
          color: AppColors.homeCardBackground,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdToggle(int percentage) {
    final amount = _settings.getThresholdAmount(percentage);
    final time = _settings.getThresholdTime(percentage);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final isEnabled = _settings.isNotificationEnabled(percentage);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$percentage% Reminder',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$amount ml by $timeStr',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.white54,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isEnabled,
          activeThumbColor: AppColors.waterBlue,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            setState(() {
              switch (percentage) {
                case 20:
                  _settings = _settings.copyWith(notify20Enabled: value);
                  break;
                case 40:
                  _settings = _settings.copyWith(notify40Enabled: value);
                  break;
                case 60:
                  _settings = _settings.copyWith(notify60Enabled: value);
                  break;
                case 80:
                  _settings = _settings.copyWith(notify80Enabled: value);
                  break;
              }
            });
          },
        ),
      ],
    );
  }
}
