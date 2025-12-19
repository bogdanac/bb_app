import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Notifications/centralized_notification_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  bool _menstrualTrackingEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadModuleSettings();
  }

  Future<void> _loadModuleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _menstrualTrackingEnabled = prefs.getBool('menstrual_tracking_enabled') ?? true;
    });
  }

  Future<void> _setMenstrualTrackingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('menstrual_tracking_enabled', enabled);
    setState(() {
      _menstrualTrackingEnabled = enabled;
    });

    // Reschedule notifications to apply the change
    final notificationManager = CentralizedNotificationManager();
    await notificationManager.forceRescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Modules'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menstrual Tracking Card
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
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
                        Icons.favorite_rounded,
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
                            'Menstrual Tracking',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Cycle predictions, phase-based tasks & notifications',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _menstrualTrackingEnabled,
                      activeThumbColor: AppColors.lightPink,
                      onChanged: (value) => _setMenstrualTrackingEnabled(value),
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
}
