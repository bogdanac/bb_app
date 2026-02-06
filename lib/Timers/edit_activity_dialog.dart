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

  Widget _buildModeOption(ActivityEnergyMode mode) {
    final isSelected = _energyMode == mode;
    final color = _getModeColor(mode);

    return GestureDetector(
      onTap: () {
        setState(() {
          _energyMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: AppStyles.borderRadiusSmall,
          border: Border.all(
            color: isSelected ? color : AppColors.greyText.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getModeIcon(mode),
              color: isSelected ? color : AppColors.greyText,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getModeLabel(mode),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    _getModeDescription(mode),
                    style: TextStyle(
                      fontSize: 11,
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
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      title: const Text('Edit Activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: AppStyles.inputDecoration(
                hintText: 'Activity name',
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Text(
              'Energy Impact',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Per 25 min: earns 1 flow point',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyText.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            _buildModeOption(ActivityEnergyMode.recharging),
            const SizedBox(height: 8),
            _buildModeOption(ActivityEnergyMode.neutral),
            const SizedBox(height: 8),
            _buildModeOption(ActivityEnergyMode.draining),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: AppStyles.textButtonStyle(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: AppStyles.elevatedButtonStyle(backgroundColor: AppColors.purple),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
