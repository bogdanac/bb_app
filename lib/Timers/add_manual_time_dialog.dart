import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';

class AddManualTimeDialog extends StatefulWidget {
  final String activityId;
  final VoidCallback onAdded;

  const AddManualTimeDialog({
    super.key,
    required this.activityId,
    required this.onAdded,
  });

  @override
  State<AddManualTimeDialog> createState() => _AddManualTimeDialogState();
}

class _AddManualTimeDialogState extends State<AddManualTimeDialog> {
  int _hours = 0;
  int _minutes = 30;
  DateTime _date = DateTime.now();

  void _submit() {
    final totalMinutes = _hours * 60 + _minutes;
    if (totalMinutes == 0) return;

    final duration = Duration(minutes: totalMinutes);
    final session = TimerSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityId: widget.activityId,
      startTime: DateTime(_date.year, _date.month, _date.day, 12),
      endTime: DateTime(_date.year, _date.month, _date.day, 12)
          .add(duration),
      duration: duration,
      type: TimerSessionType.activity,
    );
    TimerService.addSession(session);
    widget.onAdded();
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.purple,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.day}/${_date.month}/${_date.year}';

    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      title: const Text('Add Manual Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: AppStyles.cardDecorationWithBorder(
                borderColor: AppColors.purple.withValues(alpha: 0.3),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: AppColors.purple, size: 18),
                  const SizedBox(width: 12),
                  Text(dateLabel, style: const TextStyle(fontSize: 15)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: AppColors.grey300),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Hours
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCounter(
                label: 'Hours',
                value: _hours,
                onDecrement: _hours > 0 ? () => setState(() => _hours--) : null,
                onIncrement:
                    _hours < 23 ? () => setState(() => _hours++) : null,
              ),
              const SizedBox(width: 24),
              _buildCounter(
                label: 'Minutes',
                value: _minutes,
                onDecrement:
                    _minutes > 0 ? () => setState(() => _minutes--) : null,
                onIncrement:
                    _minutes < 59 ? () => setState(() => _minutes++) : null,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: AppStyles.textButtonStyle(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_hours > 0 || _minutes > 0) ? _submit : null,
          style:
              AppStyles.elevatedButtonStyle(backgroundColor: AppColors.purple),
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildCounter({
    required String label,
    required int value,
    VoidCallback? onDecrement,
    VoidCallback? onIncrement,
  }) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: AppColors.grey200, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove_circle_outline),
              color: AppColors.purple,
              iconSize: 28,
            ),
            SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  '$value',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              onPressed: onIncrement,
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.purple,
              iconSize: 28,
            ),
          ],
        ),
      ],
    );
  }
}
