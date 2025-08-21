import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import '../theme/app_colors.dart';
import 'motion_alert_settings_screen.dart';
import 'motion_alert_quick_setup.dart';

// NOTIFICATION SETTINGS SCREEN
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isEnabled = true;
  int _hour = 8;
  int _minute = 0;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    final isEnabled = await _notificationService.isMorningNotificationEnabled();
    final time = await _notificationService.getMorningNotificationTime();

    setState(() {
      _isEnabled = isEnabled;
      _hour = time['hour']!;
      _minute = time['minute']!;
    });
  }

  _updateNotificationTime() async {
    if (_isEnabled) {
      await _notificationService.scheduleMorningNotification(_hour, _minute);
    } else {
      await _notificationService.cancelMorningNotification();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEnabled
              ? 'Morning notification set for ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}'
              : 'Morning notifications disabled',
        ),
        backgroundColor: _isEnabled ? AppColors.successGreen : Colors.grey, // Green for enabled
      ),
    );
  }

  _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );

    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
      await _updateNotificationTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Morning Routine Reminder',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get a daily reminder to start your morning routine',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Enable/Disable switch
                    SwitchListTile(
                      title: const Text('Enable notifications'),
                      value: _isEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _isEnabled = value;
                        });
                        await _updateNotificationTime();
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),

                    if (_isEnabled) ...[
                      const Divider(),

                      // Time picker
                      ListTile(
                        leading: const Icon(Icons.access_time_rounded),
                        title: const Text('Notification time'),
                        subtitle: Text(
                          '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        trailing: const Icon(Icons.edit_rounded),
                        onTap: _selectTime,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Motion Alert Quick Setup Card
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.security_rounded,
                  color: AppColors.coral,
                  size: 28,
                ),
                title: const Text(
                  'Motion Alert Setup',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Quick setup: Night mode or 24/7 vacation mode',
                  style: TextStyle(color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MotionAlertQuickSetup(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Instructions card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.purple, // Purple for info
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Setup Instructions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Notifications are currently simulated in debug mode\n'
                          '• To enable real notifications, add these dependencies to pubspec.yaml:\n'
                          '  - flutter_local_notifications: ^17.0.0\n'
                          '  - timezone: ^0.9.0\n'
                          '• Uncomment the implementation code in NotificationService\n'
                          '• Request notification permissions on first app launch',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
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