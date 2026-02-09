import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../shared/date_format_utils.dart';

class FastEditDialog extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;
  final Function(DateTime, DateTime) onSave;

  const FastEditDialog({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.onSave,
  });

  /// Show as a full-screen page
  static Future<void> show(
    BuildContext context, {
    required DateTime startTime,
    required DateTime endTime,
    required Function(DateTime, DateTime) onSave,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FastEditDialog(
          startTime: startTime,
          endTime: endTime,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<FastEditDialog> createState() => _FastEditDialogState();
}

class _FastEditDialogState extends State<FastEditDialog> {
  late DateTime _startTime;
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _startTime = widget.startTime;
    _endTime = widget.endTime;
  }

  Future<void> _selectDateTime(bool isStart) async {
    final currentTime = isStart ? _startTime : _endTime;

    final newDateTime = await DatePickerUtils.showStyledDateTimePicker(
      context: context,
      initialDateTime: currentTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (newDateTime != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = newDateTime;
        } else {
          _endTime = newDateTime;
        }
      });
    }
  }

  void _submit() {
    widget.onSave(_startTime, _endTime);
    Navigator.pop(context);
  }

  bool get _canSave => _endTime.isAfter(_startTime);

  String get _durationText {
    final diff = _endTime.difference(_startTime);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: const Text('Edit Fast Times'),
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
            // Summary card at top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
              child: Column(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.yellow,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _canSave ? _durationText : 'Invalid',
                    style: TextStyle(
                      color: _canSave ? AppColors.yellow : AppColors.error,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _canSave ? 'Fast Duration' : 'End must be after start',
                    style: TextStyle(
                      color: _canSave ? AppColors.greyText : AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Start time picker
            _buildFieldContainer(
              icon: Icons.play_arrow_rounded,
              iconColor: AppColors.successGreen,
              label: 'Start Time',
              value: '${DateFormatUtils.formatLong(_startTime)}, ${DateFormatUtils.formatTime24(_startTime)}',
              onTap: () => _selectDateTime(true),
            ),
            const SizedBox(height: 16),

            // End time picker
            _buildFieldContainer(
              icon: Icons.stop_rounded,
              iconColor: AppColors.lightRed,
              label: 'End Time',
              value: '${DateFormatUtils.formatLong(_endTime)}, ${DateFormatUtils.formatTime24(_endTime)}',
              onTap: () => _selectDateTime(false),
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
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                      color: AppColors.greyText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.grey300, size: 20),
          ],
        ),
      ),
    );
  }
}
