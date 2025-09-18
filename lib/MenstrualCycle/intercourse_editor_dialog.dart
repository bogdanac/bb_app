import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'intercourse_data_model.dart';
import 'package:intl/intl.dart';

class IntercourseEditorDialog extends StatefulWidget {
  final DateTime date;
  final IntercourseRecord? existingRecord;

  const IntercourseEditorDialog({
    super.key,
    required this.date,
    this.existingRecord,
  });

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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRecord != null;
    
    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Intercourse' : 'Add Intercourse',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightPink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.lightPink.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppColors.pink,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, y').format(widget.date),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.pink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Orgasm toggle
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey700),
            ),
            child: SwitchListTile(
              title: const Text(
                'Orgasm',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _hadOrgasm ? 'Yes' : 'No',
                style: TextStyle(
                  color: _hadOrgasm ? AppColors.successGreen : AppColors.greyText,
                ),
              ),
              value: _hadOrgasm,
              onChanged: (value) {
                setState(() {
                  _hadOrgasm = value;
                });
              },
              activeThumbColor: AppColors.successGreen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Protection toggle
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey700),
            ),
            child: SwitchListTile(
              title: const Text(
                'Protection',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _wasProtected ? 'Protected' : 'Unprotected',
                style: TextStyle(
                  color: _wasProtected ? AppColors.successGreen : AppColors.error,
                ),
              ),
              value: _wasProtected,
              onChanged: (value) {
                setState(() {
                  _wasProtected = value;
                });
              },
              activeThumbColor: AppColors.successGreen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),
        ],
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final record = IntercourseRecord(
              id: widget.existingRecord?.id ?? IntercourseService.generateId(),
              date: widget.date,
              hadOrgasm: _hadOrgasm,
              wasProtected: _wasProtected,
            );
            Navigator.pop(context, record);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pink,
            foregroundColor: AppColors.white,
          ),
          child: Text(isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}