import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'energy_service.dart';
import 'energy_settings_model.dart';
import 'flow_calculator.dart';

/// Skip Day Notification - Dialog shown when a skip was auto-used to save streak
class SkipDayNotification extends StatelessWidget {
  final DateTime skipDate;
  final int currentStreak;

  const SkipDayNotification({
    super.key,
    required this.skipDate,
    required this.currentStreak,
  });

  /// Check and show skip notification if needed
  /// Returns true if notification was shown
  static Future<bool> checkAndShow(BuildContext context) async {
    final skipDate = await EnergyService.checkAndClearSkipNotification();
    if (skipDate == null) return false;

    final settings = await EnergyService.loadSettings();

    if (!context.mounted) return false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SkipDayNotification(
        skipDate: skipDate,
        currentStreak: settings.currentStreak,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d');
    final formattedDate = dateFormat.format(skipDate);

    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_rounded,
                color: AppColors.orange,
                size: 48,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            const Text(
              'Streak Protected!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              'A skip day was automatically used on $formattedDate to protect your streak.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.greyText,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Streak display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusMedium,
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.whatshot_rounded,
                    color: AppColors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$currentStreak day streak',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Info text
            Text(
              "You didn't meet your flow goal, but your skip day kept your streak alive!",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.greyText,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppStyles.borderRadiusMedium,
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

/// Skip Day Settings Dialog - Configure skip day behavior
class SkipDaySettingsDialog extends StatefulWidget {
  final EnergySettings settings;

  const SkipDaySettingsDialog({
    super.key,
    required this.settings,
  });

  static Future<EnergySettings?> show(
    BuildContext context,
    EnergySettings settings,
  ) async {
    return showDialog<EnergySettings>(
      context: context,
      builder: (context) => SkipDaySettingsDialog(settings: settings),
    );
  }

  @override
  State<SkipDaySettingsDialog> createState() => _SkipDaySettingsDialogState();
}

class _SkipDaySettingsDialogState extends State<SkipDaySettingsDialog> {
  late SkipDayMode _selectedMode;
  late bool _autoUseSkip;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.settings.skipDayMode;
    _autoUseSkip = widget.settings.autoUseSkip;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.skip_next_rounded,
                  color: AppColors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Skip Day Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Skip days protect your streak when you miss your flow goal.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),

            const SizedBox(height: 24),

            // Skip frequency
            const Text(
              'Skip Frequency',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            ...SkipDayMode.values.map((mode) => _buildModeOption(mode)),

            const SizedBox(height: 20),

            // Auto-use toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusMedium,
                border: Border.all(
                  color: AppColors.normalCardBackground,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-use skip days',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automatically use a skip when your streak would break',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoUseSkip,
                    onChanged: _selectedMode == SkipDayMode.disabled
                        ? null
                        : (value) {
                            setState(() {
                              _autoUseSkip = value;
                            });
                          },
                    activeTrackColor: AppColors.orange,
                    activeThumbColor: Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final newSettings = widget.settings.copyWith(
                        skipDayMode: _selectedMode,
                        autoUseSkip: _autoUseSkip,
                      );
                      Navigator.of(context).pop(newSettings);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(SkipDayMode mode) {
    final isSelected = _selectedMode == mode;
    final description = FlowCalculator.getSkipModeDescription(mode);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          // Disable auto-use if skips are disabled
          if (mode == SkipDayMode.disabled) {
            _autoUseSkip = false;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.orange.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: AppStyles.borderRadiusSmall,
          border: Border.all(
            color: isSelected
                ? AppColors.orange
                : AppColors.greyText.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.orange : AppColors.greyText,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? AppColors.orange : null,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
