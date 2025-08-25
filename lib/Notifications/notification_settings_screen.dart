import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'motion_alert_settings_screen.dart';
import 'motion_alert_quick_setup.dart';
import '../Data/backup_screen.dart';

// NOTIFICATION SETTINGS SCREEN
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
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

            // Backup & Restore Card
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.backup_rounded,
                  color: AppColors.orange,
                  size: 28,
                ),
                title: const Text(
                  'Backup & Restore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Export/import all your app data safely',
                  style: TextStyle(color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BackupScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}