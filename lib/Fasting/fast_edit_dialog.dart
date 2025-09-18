import 'package:bb_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../shared/date_picker_utils.dart';

// FAST EDIT DIALOG
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fast Times', style: TextStyle(fontSize: 18),),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded, color: AppColors.successGreen,),
            title: const Text('Start Time'),
            subtitle: Text(DateFormat('MMM dd, yyyy HH:mm').format(_startTime)),
            onTap: () => _selectDateTime(true),
          ),
          ListTile(
            leading: const Icon(Icons.stop_rounded, color: AppColors.lightRed),
            title: const Text('End Time'),
            subtitle: Text(DateFormat('MMM dd, yyyy HH:mm').format(_endTime)),
            onTap: () => _selectDateTime(false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.greyText)),
        ),
        ElevatedButton(
          onPressed: _endTime.isAfter(_startTime)
              ? () {
            widget.onSave(_startTime, _endTime);
            Navigator.pop(context);
          }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}