import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../shared/date_format_utils.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';

class AddManualTimeDialog extends StatefulWidget {
  final String activityId;
  final VoidCallback onAdded;
  final DateTime? initialDate;

  const AddManualTimeDialog({
    super.key,
    required this.activityId,
    required this.onAdded,
    this.initialDate,
  });

  /// Show as a full-screen page (matching task editor style)
  static Future<bool?> show(
    BuildContext context, {
    required String activityId,
    required VoidCallback onAdded,
    DateTime? initialDate,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddManualTimeDialog(
          activityId: activityId,
          onAdded: onAdded,
          initialDate: initialDate,
        ),
      ),
    );
  }

  @override
  State<AddManualTimeDialog> createState() => _AddManualTimeDialogState();
}

class _AddManualTimeDialogState extends State<AddManualTimeDialog> {
  int _hours = 0;
  int _minutes = 30;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
  }

  void _submit() {
    final totalMinutes = _hours * 60 + _minutes;
    if (totalMinutes == 0) return;

    final duration = Duration(minutes: totalMinutes);
    final session = TimerSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityId: widget.activityId,
      startTime: DateTime(_date.year, _date.month, _date.day, 12),
      endTime: DateTime(_date.year, _date.month, _date.day, 12).add(duration),
      duration: duration,
      type: TimerSessionType.activity,
    );
    TimerService.addSession(session);
    widget.onAdded();
    Navigator.pop(context, true); // Return true to indicate success
  }

  Future<void> _pickDate() async {
    final picked = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _hours * 60 + _minutes;
    final formattedDuration = _hours > 0
        ? '${_hours}h ${_minutes}m'
        : '${_minutes}m';

    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: const Text('Add Manual Time'),
        backgroundColor: Colors.transparent,
        actions: [
          // Save button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: totalMinutes > 0 ? _submit : null,
              icon: Icon(
                Icons.check_rounded,
                color: totalMinutes > 0 ? AppColors.successGreen : AppColors.grey300,
              ),
              label: Text(
                'Save',
                style: TextStyle(
                  color: totalMinutes > 0 ? AppColors.successGreen : AppColors.grey300,
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
                    Icons.timer_outlined,
                    color: AppColors.purple,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formattedDuration,
                    style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'on ${DateFormatUtils.formatFullDate(_date)}',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date picker
            _buildFieldContainer(
              icon: Icons.calendar_today_rounded,
              iconColor: AppColors.purple,
              label: 'Date',
              value: DateFormatUtils.formatFullDate(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // Hours field
            _buildFieldContainer(
              icon: Icons.hourglass_top_rounded,
              iconColor: AppColors.coral,
              label: 'Hours',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _hours > 0 ? () => setState(() => _hours--) : null,
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      color: _hours > 0 ? AppColors.coral : AppColors.grey300,
                    ),
                    iconSize: 32,
                  ),
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        '$_hours',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _hours < 23 ? () => setState(() => _hours++) : null,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: _hours < 23 ? AppColors.coral : AppColors.grey300,
                    ),
                    iconSize: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Minutes slider
            _buildFieldContainer(
              icon: Icons.timelapse_rounded,
              iconColor: AppColors.pastelGreen,
              label: 'Minutes',
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text('0', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.pastelGreen,
                              inactiveTrackColor: AppColors.grey700,
                              thumbColor: AppColors.pastelGreen,
                              overlayColor: AppColors.pastelGreen.withValues(alpha: 0.2),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                            ),
                            child: Slider(
                              value: _minutes.toDouble(),
                              min: 0,
                              max: 60,
                              divisions: 60,
                              onChanged: (value) {
                                setState(() => _minutes = value.round());
                              },
                            ),
                          ),
                        ),
                        Text('60', style: TextStyle(color: AppColors.grey300, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_minutes min',
                    style: TextStyle(
                      color: AppColors.pastelGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Quick preset buttons
            Text(
              'Quick presets',
              style: TextStyle(
                color: AppColors.greyText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('15m', 0, 15),
                _buildPresetChip('30m', 0, 30),
                _buildPresetChip('45m', 0, 45),
                _buildPresetChip('1h', 1, 0),
                _buildPresetChip('1.5h', 1, 30),
                _buildPresetChip('2h', 2, 0),
              ],
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
    String? value,
    Widget? child,
    VoidCallback? onTap,
  }) {
    final content = Container(
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
              Text(
                label,
                style: TextStyle(
                  color: AppColors.greyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (value != null) ...[
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: AppColors.grey300, size: 20),
              ],
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  Widget _buildPresetChip(String label, int hours, int minutes) {
    final isSelected = _hours == hours && _minutes == minutes;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.white : AppColors.greyText,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: isSelected ? AppColors.purple : AppColors.grey800,
      side: BorderSide(
        color: isSelected ? AppColors.purple : AppColors.grey700,
      ),
      onPressed: () {
        setState(() {
          _hours = hours;
          _minutes = minutes;
        });
      },
    );
  }
}
