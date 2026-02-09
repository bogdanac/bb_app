import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'intercourse_data_model.dart';
import '../shared/date_format_utils.dart';

class IntercourseEditorDialog extends StatefulWidget {
  final DateTime date;
  final IntercourseRecord? existingRecord;

  const IntercourseEditorDialog({
    super.key,
    required this.date,
    this.existingRecord,
  });

  /// Show as a full-screen page
  static Future<dynamic> show(
    BuildContext context, {
    required DateTime date,
    IntercourseRecord? existingRecord,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntercourseEditorDialog(
          date: date,
          existingRecord: existingRecord,
        ),
      ),
    );
  }

  @override
  State<IntercourseEditorDialog> createState() => _IntercourseEditorDialogState();
}

class _IntercourseEditorDialogState extends State<IntercourseEditorDialog> {
  late bool _hadOrgasm;
  late bool _wasProtected;

  @override
  void initState() {
    super.initState();
    _hadOrgasm = widget.existingRecord?.hadOrgasm ?? false;
    _wasProtected = widget.existingRecord?.wasProtected ?? false;
  }

  void _submit() {
    final record = IntercourseRecord(
      id: widget.existingRecord?.id ?? IntercourseService.generateId(),
      date: widget.date,
      hadOrgasm: _hadOrgasm,
      wasProtected: _wasProtected,
    );
    Navigator.pop(context, record);
  }

  void _delete() {
    Navigator.pop(context, 'delete');
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRecord != null;

    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Intercourse' : 'Add Intercourse'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _submit,
              icon: Icon(
                Icons.check_rounded,
                color: AppColors.successGreen,
              ),
              label: Text(
                isEditing ? 'Update' : 'Save',
                style: TextStyle(
                  color: AppColors.successGreen,
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
            // Date card at top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: AppColors.pink,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormatUtils.formatLong(widget.date),
                    style: TextStyle(
                      color: AppColors.pink,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Orgasm toggle
            _buildToggleField(
              icon: Icons.favorite_border_rounded,
              iconColor: AppColors.lightPink,
              label: 'Orgasm',
              subtitle: _hadOrgasm ? 'Yes' : 'No',
              subtitleColor: _hadOrgasm ? AppColors.successGreen : AppColors.greyText,
              value: _hadOrgasm,
              onChanged: (value) => setState(() => _hadOrgasm = value),
            ),
            const SizedBox(height: 16),

            // Protection toggle
            _buildToggleField(
              icon: Icons.shield_rounded,
              iconColor: AppColors.waterBlue,
              label: 'Protection',
              subtitle: _wasProtected ? 'Protected' : 'Unprotected',
              subtitleColor: _wasProtected ? AppColors.successGreen : AppColors.error,
              value: _wasProtected,
              onChanged: (value) => setState(() => _wasProtected = value),
            ),

            // Delete button for editing
            if (isEditing) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: Icon(Icons.delete_rounded, color: AppColors.error),
                  label: Text(
                    'Delete Record',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required Color subtitleColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.successGreen,
          ),
        ],
      ),
    );
  }
}
