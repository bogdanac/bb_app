import 'package:flutter/material.dart';
import '../Data/backup_screen.dart';
import '../Routines/widget_color_settings_screen.dart';
import 'modules_screen.dart';
import 'home_cards_screen.dart';
import 'primary_tabs_screen.dart';
import '../shared/error_logs_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
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
                // App Features
                _buildSettingsCard(
                  context,
                  icon: Icons.toggle_on_rounded,
                  iconColor: AppColors.lightPink,
                  title: 'App Features',
                  subtitle: 'Enable or disable app features',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ModulesScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Home Page Cards
                _buildSettingsCard(
                  context,
                  icon: Icons.dashboard_customize_rounded,
                  iconColor: AppColors.pink,
                  title: 'Home Page Cards',
                  subtitle: 'Choose which cards appear on Home',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeCardsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Primary Tabs
                _buildSettingsCard(
                  context,
                  icon: Icons.reorder_rounded,
                  iconColor: AppColors.purple,
                  title: 'Primary Tabs',
                  subtitle: 'Choose which modules appear on bottom nav',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrimaryTabsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Widget Colors
                _buildSettingsCard(
                  context,
                  icon: Icons.palette_rounded,
                  iconColor: AppColors.coral,
                  title: 'Widget Colors',
                  subtitle: 'Customize widget backgrounds',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WidgetColorSettingsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Backup & Restore
                _buildSettingsCard(
                  context,
                  icon: Icons.backup_rounded,
                  iconColor: AppColors.successGreen,
                  title: 'Backup & Restore',
                  subtitle: 'Export/import all your app data safely',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Error Logs
                _buildSettingsCard(
                  context,
                  icon: Icons.bug_report_rounded,
                  iconColor: AppColors.error,
                  title: 'Error Logs',
                  subtitle: 'View app error logs for debugging',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ErrorLogsScreen(),
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
