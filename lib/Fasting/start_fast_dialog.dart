import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../shared/date_format_utils.dart';

class StartFastDialog extends StatefulWidget {
  final int defaultHours;
  final DateTime? initialStartTime;

  const StartFastDialog({
    super.key,
    this.defaultHours = 18,
    this.initialStartTime,
  });

  /// Show as a full-screen page
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    int defaultHours = 18,
    DateTime? initialStartTime,
  }) {
    return Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => StartFastDialog(
          defaultHours: defaultHours,
          initialStartTime: initialStartTime,
        ),
      ),
    );
  }

  @override
  State<StartFastDialog> createState() => _StartFastDialogState();
}

class _StartFastDialogState extends State<StartFastDialog> {
  late int _selectedHours;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _selectedHours = widget.defaultHours;
    _startTime = widget.initialStartTime ?? DateTime.now();
  }

  DateTime get _estimatedEndTime => _startTime.add(Duration(hours: _selectedHours));

  void _submit() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, {
      'hours': _selectedHours,
      'startTime': _startTime,
      'endTime': _estimatedEndTime,
    });
  }

  Future<void> _selectStartDateTime() async {
    final newDateTime = await DatePickerUtils.showStyledDateTimePicker(
      context: context,
      initialDateTime: _startTime,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );

    if (newDateTime == null || !mounted) return;

    // Validate: start time cannot be in the future
    if (newDateTime.isAfter(DateTime.now())) {
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
      _startTime = newDateTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: const Text('Start a Fast'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _submit,
              icon: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.yellow,
              ),
              label: Text(
                'Start',
                style: TextStyle(
                  color: AppColors.yellow,
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
                    '${_selectedHours}h fast',
                    style: TextStyle(
                      color: AppColors.yellow,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ends ${DateFormatUtils.formatShort(_estimatedEndTime)} at ${DateFormatUtils.formatTime24(_estimatedEndTime)}',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Duration picker
            _buildFieldContainer(
              icon: Icons.timer_outlined,
              iconColor: AppColors.yellow,
              label: 'Duration',
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Hours stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _selectedHours > 1
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedHours--);
                              }
                            : null,
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          color: _selectedHours > 1 ? AppColors.yellow : AppColors.grey300,
                        ),
                        iconSize: 36,
                      ),
                      SizedBox(
                        width: 100,
                        child: Center(
                          child: Text(
                            '$_selectedHours',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.yellow,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _selectedHours < 72
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedHours++);
                              }
                            : null,
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          color: _selectedHours < 72 ? AppColors.yellow : AppColors.grey300,
                        ),
                        iconSize: 36,
                      ),
                    ],
                  ),
                  Text(
                    'hours',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick presets
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildPresetChip('12h', 12),
                      _buildPresetChip('16h', 16),
                      _buildPresetChip('18h', 18),
                      _buildPresetChip('20h', 20),
                      _buildPresetChip('24h', 24),
                      _buildPresetChip('36h', 36),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Start time picker
            _buildFieldContainer(
              icon: Icons.play_arrow_rounded,
              iconColor: AppColors.successGreen,
              label: 'Start Time',
              value: '${DateFormatUtils.formatLong(_startTime)}, ${DateFormatUtils.formatTime24(_startTime)}',
              onTap: _selectStartDateTime,
            ),
            const SizedBox(height: 16),

            // Estimated end time (read-only)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusMedium,
                border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.flag_rounded, color: AppColors.yellow, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated End',
                          style: TextStyle(
                            color: AppColors.greyText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormatUtils.formatLong(_estimatedEndTime)}, ${DateFormatUtils.formatTime24(_estimatedEndTime)}',
                          style: TextStyle(
                            color: AppColors.yellow,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildPresetChip(String label, int hours) {
    final isSelected = _selectedHours == hours;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.dialogBackground : AppColors.greyText,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: isSelected ? AppColors.yellow : AppColors.grey800,
      side: BorderSide(
        color: isSelected ? AppColors.yellow : AppColors.grey700,
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedHours = hours);
      },
    );
  }
}
