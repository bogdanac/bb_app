import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'timer_data_models.dart';

class EditActivityDialog extends StatefulWidget {
  final Activity activity;
  final Function(Activity) onSave;

  const EditActivityDialog({
    super.key,
    required this.activity,
    required this.onSave,
  });

  /// Show as a full-screen page
  static Future<void> show(
    BuildContext context, {
    required Activity activity,
    required Function(Activity) onSave,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditActivityDialog(
          activity: activity,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  late TextEditingController _nameController;
  late ActivityEnergyMode _energyMode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activity.name);
    _energyMode = widget.activity.energyMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final updatedActivity = widget.activity.copyWith(
      name: name,
      energyMode: _energyMode,
    );
    widget.onSave(updatedActivity);
    Navigator.pop(context);
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  Color _getModeColor(ActivityEnergyMode mode) {
    switch (mode) {
      case ActivityEnergyMode.draining:
        return AppColors.coral;
      case ActivityEnergyMode.neutral:
        return AppColors.greyText;
      case ActivityEnergyMode.recharging:
        return AppColors.successGreen;
    }
  }

  IconData _getModeIcon(ActivityEnergyMode mode) {
    switch (mode) {
      case ActivityEnergyMode.draining:
        return Icons.battery_2_bar_rounded;
      case ActivityEnergyMode.neutral:
        return Icons.battery_4_bar_rounded;
      case ActivityEnergyMode.recharging:
        return Icons.battery_charging_full_rounded;
    }
  }

  String _getModeLabel(ActivityEnergyMode mode) {
    switch (mode) {
      case ActivityEnergyMode.draining:
        return 'Draining';
      case ActivityEnergyMode.neutral:
        return 'Neutral';
      case ActivityEnergyMode.recharging:
        return 'Recharging';
    }
  }

  String _getModeDescription(ActivityEnergyMode mode) {
    switch (mode) {
      case ActivityEnergyMode.draining:
        return '-5% battery per 25 min';
      case ActivityEnergyMode.neutral:
        return 'No battery change';
      case ActivityEnergyMode.recharging:
        return '+5% battery per 25 min';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: const Text('Edit Activity'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _canSave ? _submit : null,
              icon: Icon(
                Icons.check_rounded,
                color: _canSave ? AppColors.successGreen : AppColors.grey300,
              ),
              label: Text(
                'Save',
                style: TextStyle(
                  color: _canSave ? AppColors.successGreen : AppColors.grey300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview card at top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getModeColor(_energyMode).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getModeIcon(_energyMode),
                      color: _getModeColor(_energyMode),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text.isEmpty ? 'Activity Name' : _nameController.text,
                    style: TextStyle(
                      color: _nameController.text.isEmpty ? AppColors.grey300 : AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getModeDescription(_energyMode),
                    style: TextStyle(
                      color: _getModeColor(_energyMode),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            _buildFieldContainer(
              icon: Icons.label_rounded,
              iconColor: AppColors.purple,
              label: 'Activity Name',
              child: TextField(
                controller: _nameController,
                decoration: AppStyles.inputDecoration(
                  hintText: 'e.g., Piano Learning',
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 16),

            // Energy impact section
            _buildFieldContainer(
              icon: Icons.bolt_rounded,
              iconColor: AppColors.yellow,
              label: 'Energy Impact',
              subtitle: 'Per 25 min: earns 1 flow point',
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildModeOption(ActivityEnergyMode.recharging),
                  const SizedBox(height: 8),
                  _buildModeOption(ActivityEnergyMode.neutral),
                  const SizedBox(height: 8),
                  _buildModeOption(ActivityEnergyMode.draining),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldContainer({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.greyText.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildModeOption(ActivityEnergyMode mode) {
    final isSelected = _energyMode == mode;
    final color = _getModeColor(mode);

    return GestureDetector(
      onTap: () => setState(() => _energyMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: AppStyles.borderRadiusMedium,
          border: Border.all(
            color: isSelected ? color : AppColors.grey700,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getModeIcon(mode),
              color: isSelected ? color : AppColors.greyText,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getModeLabel(mode),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? color : AppColors.white,
                    ),
                  ),
                  Text(
                    _getModeDescription(mode),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: color,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
