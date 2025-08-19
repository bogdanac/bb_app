import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  _selectDateTime(bool isStart) async {
    final currentTime = isStart ? _startTime : _endTime;

    final date = await showDatePicker(
      context: context,
      initialDate: currentTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentTime),
      );

      if (time != null) {
        final newDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isStart) {
            _startTime = newDateTime;
          } else {
            _endTime = newDateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fast Times'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Start Time'),
            subtitle: Text(DateFormat('MMM dd, yyyy HH:mm').format(_startTime)),
            onTap: () => _selectDateTime(true),
          ),
          ListTile(
            leading: const Icon(Icons.stop_rounded),
            title: const Text('End Time'),
            subtitle: Text(DateFormat('MMM dd, yyyy HH:mm').format(_endTime)),
            onTap: () => _selectDateTime(false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _endTime.isAfter(_startTime)
              ? () {
            widget.onSave(_startTime, _endTime);
            Navigator.pop(context);
          }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}