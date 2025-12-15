import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class StartFastDialog extends StatefulWidget {
  final int defaultHours;
  final DateTime? initialStartTime;

  const StartFastDialog({
    super.key,
    this.defaultHours = 18,
    this.initialStartTime,
  });

  @override
  State<StartFastDialog> createState() => _StartFastDialogState();
}

class _StartFastDialogState extends State<StartFastDialog> {
  late int _selectedHours;
  late DateTime _startTime;
  late FixedExtentScrollController _hoursController;

  @override
  void initState() {
    super.initState();
    _selectedHours = widget.defaultHours;
    _startTime = widget.initialStartTime ?? DateTime.now();
    _hoursController = FixedExtentScrollController(
      initialItem: _selectedHours - 1, // Hours start from 1
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  DateTime get _estimatedEndTime => _startTime.add(Duration(hours: _selectedHours));

  String _formatDateTime(DateTime dt) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dayNames[dt.weekday - 1]}, ${monthNames[dt.month - 1]} ${dt.day} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartDateTime() async {
    // First pick date
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.yellow,
              onPrimary: Colors.black,
              surface: AppColors.dialogBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.dialogBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    // Then pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.yellow,
              onPrimary: Colors.black,
              surface: AppColors.dialogBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.dialogBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null || !mounted) return;

    final newStartTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Validate: start time cannot be in the future
    if (newStartTime.isAfter(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start time cannot be in the future'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _startTime = newStartTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialogBackground,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, color: AppColors.yellow, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Start a Fast',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Hours Picker Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dialogCardBackground,
                borderRadius: AppStyles.borderRadiusMedium,
                border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Scrollable Hours Picker
                  SizedBox(
                    height: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hours wheel
                        SizedBox(
                          width: 80,
                          child: ListWheelScrollView.useDelegate(
                            controller: _hoursController,
                            itemExtent: 50,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.5,
                            perspective: 0.003,
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedHours = index + 1; // Hours 1-72
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 72, // 1 to 72 hours
                              builder: (context, index) {
                                final hours = index + 1;
                                final isSelected = hours == _selectedHours;
                                return Center(
                                  child: Text(
                                    '$hours',
                                    style: TextStyle(
                                      fontSize: isSelected ? 32 : 22,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? AppColors.yellow : AppColors.greyText,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // "hours" label
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            'hours',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Start Time Section
            InkWell(
              onTap: _selectStartDateTime,
              borderRadius: AppStyles.borderRadiusMedium,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.dialogCardBackground,
                  borderRadius: AppStyles.borderRadiusMedium,
                  border: Border.all(color: AppColors.greyText.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline, color: AppColors.successGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(_startTime),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_rounded, color: AppColors.greyText, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Estimated End Time Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusMedium,
                border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, color: AppColors.yellow, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated End',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.greyText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(_estimatedEndTime),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.yellow,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.greyText,
                      side: const BorderSide(color: AppColors.greyText),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context, {
                        'hours': _selectedHours,
                        'startTime': _startTime,
                        'endTime': _estimatedEndTime,
                      });
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Fast', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
