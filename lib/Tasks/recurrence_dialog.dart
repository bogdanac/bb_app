import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'tasks_data_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';
import '../shared/time_picker_utils.dart';
import '../shared/date_picker_utils.dart';

class RecurrenceDialog extends StatefulWidget {
  final TaskRecurrence? initialRecurrence;

  const RecurrenceDialog({
    super.key,
    this.initialRecurrence,
  });

  @override
  State<RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<RecurrenceDialog> {
  List<RecurrenceType> _selectedTypes = []; // Support multiple selections
  RecurrenceType _primaryType =
      RecurrenceType.daily; // For settings like interval
  int _interval = 1;
  int _monthOfYear = 1; // For yearly recurrence: which month (1-12)
  List<int> _selectedWeekDays = [];
  int? _dayOfMonth;
  bool _isLastDayOfMonth = false;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _phaseDay; // Selected day within a menstrual phase
  bool _usePhaseDaySelector = false; // Whether to use specific day selection
  TimeOfDay? _reminderTime; // Reminder time for recurring tasks


  @override
  void initState() {
    super.initState();
    if (widget.initialRecurrence != null) {
      final recurrence = widget.initialRecurrence!;
      _selectedTypes = List.from(recurrence.types);
      _primaryType = recurrence.types.isNotEmpty
          ? recurrence.types.first
          : RecurrenceType.daily;
      // For yearly recurrence, interval stores the month
      if (recurrence.types.contains(RecurrenceType.yearly)) {
        _monthOfYear = recurrence.interval;
        _interval = 1; // Default to every 1 year
      } else {
        _interval = recurrence.interval;
      }
      _selectedWeekDays = List.from(recurrence.weekDays);
      _dayOfMonth = recurrence.dayOfMonth;
      _isLastDayOfMonth = recurrence.isLastDayOfMonth;
      _startDate = recurrence.startDate;
      _endDate = recurrence.endDate;
      _phaseDay = recurrence.phaseDay;
      _usePhaseDaySelector = recurrence.phaseDay != null;
      _reminderTime = recurrence.reminderTime;
    }
  }

  // Get allowed types for dropdown to prevent the dropdown error
  List<RecurrenceType> get _allowedDropdownTypes {
    return RecurrenceType.values
        .where((type) =>
            type != RecurrenceType.custom &&
            // Exclude menstrual phases from dropdown as they have quick options
            type != RecurrenceType.menstrualPhase &&
            type != RecurrenceType.follicularPhase &&
            type != RecurrenceType.ovulationPhase &&
            type != RecurrenceType.earlyLutealPhase &&
            type != RecurrenceType.lateLutealPhase &&
            type != RecurrenceType.menstrualStartDay &&
            type != RecurrenceType.ovulationPeakDay)
        .toList();
  }

  // Check if current primary type should be shown in dropdown
  RecurrenceType get _displayedSelectedType {
    if (_allowedDropdownTypes.contains(_primaryType)) {
      return _primaryType;
    }
    // If selected type is not in allowed dropdown types, default to daily
    return RecurrenceType.daily;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: const Text('Repeat Task'),
        backgroundColor: AppColors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, widget.initialRecurrence),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick preset buttons
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickOption('Daily', RecurrenceType.daily, 1,
                            Icons.today_rounded),
                        _buildQuickOption('Weekly', RecurrenceType.weekly, 1,
                            Icons.date_range_rounded),
                        _buildQuickOption('Monthly', RecurrenceType.monthly, 1,
                            Icons.calendar_month_rounded),
                        _buildQuickOption('Yearly', RecurrenceType.yearly, 1,
                            Icons.event_rounded),
                      ],
                    ),

                    const SizedBox(height: 16),


                    // Recurrence Type Selection - only show if a daily/weekly/monthly type is selected (not yearly)
                    if (_selectedTypes.isNotEmpty && !_isMenstrualPhase(_primaryType) && !_selectedTypes.contains(RecurrenceType.yearly))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.dialogBackground.withValues(alpha: 0.08),
                          borderRadius: AppStyles.borderRadiusLarge,
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Repeat every:',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: AppColors.greyText),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 50,
                              height: 30,
                              child: TextFormField(
                                initialValue: _interval.toString(),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: AppStyles.borderRadiusSmall,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 0),
                                  isDense: false,
                                  hintText: '1',
                                ),
                                onChanged: (value) {
                                  final intValue = int.tryParse(value);
                                  if (intValue != null && intValue > 0) {
                                    setState(() {
                                      _interval = intValue;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<RecurrenceType>(
                                initialValue: _displayedSelectedType,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: AppStyles.borderRadiusSmall,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                  isDense: true,
                                ),
                                items: _allowedDropdownTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      _getRecurrenceTypeName(type),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _primaryType = value;
                                      // Update selected types if this basic type is being changed
                                      _selectedTypes = [value];
                                      // Reset values when type changes
                                      _selectedWeekDays.clear();
                                      _dayOfMonth = null;
                                      _isLastDayOfMonth = false;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),

                    // Weekly specific options - show right after repeat every
                    if (_selectedTypes.contains(RecurrenceType.weekly)) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dialogBackground.withValues(alpha: 0.08),
                          borderRadius: AppStyles.borderRadiusLarge,
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Repeat on days:',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: AppColors.greyText),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(7, (index) {
                                final dayNumber = index + 1;
                                final isSelected = _selectedWeekDays.contains(dayNumber);
                                return FilterChip(
                                  label: Text(_getDayName(dayNumber)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWeekDays.add(dayNumber);
                                      } else {
                                        _selectedWeekDays.remove(dayNumber);
                                      }
                                    });
                                  },
                                  backgroundColor: Colors.transparent,
                                  selectedColor: AppColors.coral.withValues(alpha: 0.2),
                                  checkmarkColor: AppColors.coral,
                                  side: BorderSide(
                                    color: isSelected ? AppColors.coral : AppColors.greyText,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Monthly specific options - show right after weekly
                    if (_selectedTypes.contains(RecurrenceType.monthly)) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dialogBackground.withValues(alpha: 0.08),
                          borderRadius: AppStyles.borderRadiusLarge,
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Monthly Options:',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: AppColors.greyText),
                            ),
                            const SizedBox(height: 8),
                            // Specific day option
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isLastDayOfMonth
                                    ? AppColors.coral.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: AppStyles.borderRadiusSmall,
                                border: Border.all(
                                  color: !_isLastDayOfMonth
                                      ? AppColors.coral.withValues(alpha: 0.1)
                                      : AppColors.greyText,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isLastDayOfMonth = false;
                                    _dayOfMonth = _dayOfMonth ?? DateTime.now().day;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: !_isLastDayOfMonth
                                              ? AppColors.coral
                                              : AppColors.greyText,
                                          width: 2,
                                        ),
                                        color: !_isLastDayOfMonth
                                            ? AppColors.coral
                                            : Colors.transparent,
                                      ),
                                      child: !_isLastDayOfMonth
                                          ? const Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    SizedBox(
                                      width: 50,
                                      height: 30,
                                      child: TextFormField(
                                        initialValue: _dayOfMonth?.toString() ??
                                            DateTime.now().day.toString(),
                                        keyboardType: TextInputType.number,
                                        enabled: !_isLastDayOfMonth,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                                ),
                                        onChanged: (value) {
                                          final intValue = int.tryParse(value);
                                          if (intValue != null &&
                                              intValue >= 1 &&
                                              intValue <= 31) {
                                            setState(() {
                                              _dayOfMonth = intValue;
                                              _isLastDayOfMonth = false;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('of each month', style: TextStyle(color: AppColors.greyText)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Last day option
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isLastDayOfMonth
                                    ? AppColors.coral.withValues(alpha: 0.3)
                                    : Colors.transparent,
                                borderRadius: AppStyles.borderRadiusSmall,
                                border: Border.all(
                                  color: _isLastDayOfMonth
                                      ? AppColors.coral.withValues(alpha: 0.3)
                                      : AppColors.greyText,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _isLastDayOfMonth = true);
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _isLastDayOfMonth
                                              ? AppColors.coral
                                              : AppColors.greyText,
                                          width: 2,
                                        ),
                                        color: _isLastDayOfMonth
                                            ? AppColors.coral
                                            : Colors.transparent,
                                      ),
                                      child: _isLastDayOfMonth
                                          ? const Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const Text('Last day of each month', style: TextStyle(color: AppColors.greyText)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Yearly specific options - show right after monthly
                    if (_selectedTypes.contains(RecurrenceType.yearly)) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dialogBackground.withValues(alpha: 0.08),
                          borderRadius: AppStyles.borderRadiusLarge,
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yearly Options:',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: AppColors.greyText),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Month: ', style: TextStyle(color: AppColors.greyText)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _monthOfYear,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: AppStyles.borderRadiusSmall,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      isDense: true,
                                    ),
                                    items: List.generate(12, (index) {
                                      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                                         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                      return DropdownMenuItem(
                                        value: index + 1,
                                        child: Text(monthNames[index]),
                                      );
                                    }),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _monthOfYear = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 24),
                                const Text('Day: ', style: TextStyle(color: AppColors.greyText)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 50,
                                  height: 30,
                                  child: TextFormField(
                                    initialValue: _dayOfMonth?.toString() ?? '1',
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: AppStyles.borderRadiusSmall,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                      isDense: false,
                                    ),
                                    onChanged: (value) {
                                      final intValue = int.tryParse(value);
                                      if (intValue != null && intValue >= 1 && intValue <= 31) {
                                        setState(() {
                                          _dayOfMonth = intValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickOption(
                            MenstrualCycleConstants.menstrualPhaseShort,
                            RecurrenceType.menstrualPhase,
                            1,
                            Icons.water_drop_rounded),
                        _buildQuickOption(
                            MenstrualCycleConstants.follicularPhaseShort,
                            RecurrenceType.follicularPhase,
                            1,
                            Icons.energy_savings_leaf),
                        _buildQuickOption(
                            MenstrualCycleConstants.ovulationPhaseShort,
                            RecurrenceType.ovulationPhase,
                            1,
                            Icons.favorite_rounded),
                        _buildQuickOption(
                            MenstrualCycleConstants.earlyLutealPhaseShort,
                            RecurrenceType.earlyLutealPhase,
                            1,
                            Icons.nights_stay_rounded),
                        _buildQuickOption(
                            MenstrualCycleConstants.lateLutealPhaseShort,
                            RecurrenceType.lateLutealPhase,
                            1,
                            Icons.nights_stay_rounded),
                      ],
                    ),

                    // Phase Day Selector for menstrual phases - show right after menstrual phases selection
                    if (_hasSelectedMenstrualPhase()) ...[
                      const SizedBox(height: 8),
                      _buildPhaseDaySelector(),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Reminder Time Section (only show if recurrence is selected)
                    if (_selectedTypes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.dialogBackground.withValues(alpha: 0.08),
                          borderRadius: AppStyles.borderRadiusLarge,
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Set a reminder:',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: AppColors.greyText),
                            ),
                            const SizedBox(width: 16),
                            InkWell(
                              onTap: _selectReminderTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: AppStyles.borderRadiusSmall,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: _reminderTime != null 
                                          ? AppColors.coral 
                                          : AppColors.greyText,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _reminderTime != null
                                          ? _reminderTime!.format(context)
                                          : 'Set time',
                                      style: TextStyle(
                                        color: _reminderTime != null
                                            ? AppColors.coral
                                            : AppColors.greyText,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_reminderTime != null) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => setState(() => _reminderTime = null),
                                        child: Icon(
                                          Icons.clear_rounded,
                                          size: 18,
                                          color: AppColors.greyText,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Start Date and End Date Section (same row)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.dialogBackground.withValues(alpha: 0.08),
                        borderRadius: AppStyles.borderRadiusMedium,
                        border: Border.all(
                          color: AppColors.coral.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Start Date',
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: AppColors.greyText),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: _selectStartDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: AppStyles.borderRadiusSmall,
                                          color: Colors.white.withValues(alpha: 0.05),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.blue[600],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _startDate != null
                                                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                                    : 'Starts today',
                                                style: TextStyle(
                                                  color: _startDate != null
                                                      ? null
                                                      : AppColors.greyText,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (_startDate != null)
                                              GestureDetector(
                                                onTap: () => setState(() => _startDate = null),
                                                child: Icon(
                                                  Icons.clear_rounded,
                                                  size: 16,
                                                  color: AppColors.greyText,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'End Date',
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: AppColors.greyText),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: _selectEndDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: AppStyles.borderRadiusSmall,
                                          color: Colors.white.withValues(alpha: 0.05),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              color: AppColors.greyText,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _endDate != null
                                                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                                    : 'Set end date',
                                                style: TextStyle(
                                                  color: _endDate != null
                                                      ? null
                                                      : AppColors.greyText,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (_endDate != null)
                                              GestureDetector(
                                                onTap: () => setState(() => _endDate = null),
                                                child: Icon(
                                                  Icons.clear_rounded,
                                                  size: 16,
                                                  color: AppColors.greyText,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () =>
                    Navigator.pop(context, widget.initialRecurrence),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isValidRecurrence()
                    ? () {
                        final recurrence = TaskRecurrence(
                          types: _selectedTypes,
                          // For yearly, interval stores the month; otherwise it's the repeat frequency
                          interval: _selectedTypes.contains(RecurrenceType.yearly)
                              ? _monthOfYear
                              : _interval,
                          weekDays:
                              _selectedTypes.contains(RecurrenceType.weekly)
                                  ? _selectedWeekDays
                                  : [],
                          dayOfMonth: (_selectedTypes
                                          .contains(RecurrenceType.monthly) &&
                                      !_isLastDayOfMonth) ||
                                  _selectedTypes.contains(RecurrenceType.yearly)
                              ? _dayOfMonth
                              : null,
                          isLastDayOfMonth:
                              _selectedTypes.contains(RecurrenceType.monthly) &&
                                  _isLastDayOfMonth,
                          startDate: _startDate,
                          endDate: _endDate,
                          phaseDay: _hasSelectedMenstrualPhase() &&
                                  _usePhaseDaySelector
                              ? _phaseDay
                              : null,
                          reminderTime: _reminderTime,
                        );
                        Navigator.pop(context, recurrence);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppStyles.borderRadiusMedium,
                  ),
                ),
                child: const Text(
                  'Save Repeat',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption(
      String label, RecurrenceType type, int interval, IconData icon,
      {List<int>? weekdays}) {
    final isSelected = _selectedTypes.contains(type);

    return InkWell(
      onTap: () {
        setState(() {
          // Define conflicting schedule types
          final scheduleTypes = [
            RecurrenceType.daily,
            RecurrenceType.weekly,
            RecurrenceType.monthly,
            RecurrenceType.yearly
          ];
          final isScheduleType = scheduleTypes.contains(type);

          // Toggle selection - if already selected, remove it; if not selected, add it
          if (isSelected) {
            _selectedTypes.remove(type);
          } else {
            // If this is a schedule type, remove other conflicting schedule types
            if (isScheduleType) {
              _selectedTypes.removeWhere(
                  (selectedType) => scheduleTypes.contains(selectedType));
            }

            _selectedTypes.add(type);
            _primaryType = type; // Set as primary for configuration

            // Configure settings for the primary type
            if (type == RecurrenceType.weekly) {
              if (weekdays != null) {
                _selectedWeekDays = List.from(weekdays);
              } else {
                _selectedWeekDays = []; // Don't preselect any days
              }
            } else if (type == RecurrenceType.monthly) {
              // Set default day of month to current day if not already set
              _dayOfMonth ??= DateTime.now().day;
            } else if (type == RecurrenceType.yearly) {
              // Set default day and month for yearly
              _dayOfMonth ??= DateTime.now().day;
              _monthOfYear = DateTime.now().month;
            }

            _interval = interval;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral : Colors.transparent,
          borderRadius: AppStyles.borderRadiusLarge,
          border: Border.all(
            color: isSelected
                ? AppColors.coral
                : AppColors.greyText,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.greyText,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidRecurrence() {
    try {
      if (_selectedTypes.isEmpty) {
        return false;
      }

      // Check each selected type for validity
      for (final type in _selectedTypes) {
        if (type == RecurrenceType.weekly && _selectedWeekDays.isEmpty) {
          return false;
        }
        if (type == RecurrenceType.monthly &&
            !_isLastDayOfMonth &&
            _dayOfMonth == null) {
          return false;
        }
        if (type == RecurrenceType.yearly && _dayOfMonth == null) {
          return false;
        }
      }

      // Menstrual phase recurrences are always valid (no additional parameters needed)
      final menstrualTypes = [
        RecurrenceType.menstrualPhase,
        RecurrenceType.follicularPhase,
        RecurrenceType.ovulationPhase,
        RecurrenceType.earlyLutealPhase,
        RecurrenceType.lateLutealPhase,
        RecurrenceType.menstrualStartDay,
        RecurrenceType.ovulationPeakDay
      ];

      if (_selectedTypes.any((type) => menstrualTypes.contains(type))) {
        return true;
      }

      return _interval > 0;
    } catch (e, stackTrace) {
      // Note: This is a UI method, synchronous context
      // Log to console - detailed logging happens in service layer
      if (kDebugMode) {
        print('ERROR validating recurrence: $e');
      }
      return false;
    }
  }

  String _getRecurrenceTypeName(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return _interval == 1 ? 'Day' : 'Days';
      case RecurrenceType.weekly:
        return _interval == 1 ? 'Week' : 'Weeks';
      case RecurrenceType.monthly:
        return _interval == 1 ? 'Month' : 'Months';
      case RecurrenceType.yearly:
        return _interval == 1 ? 'Year' : 'Years';
      case RecurrenceType.custom:
        return 'Custom';
      default:
        return 'Custom';
    }
  }

  void _selectStartDate() async {
    final date = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow past dates
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  void _selectEndDate() async {
    final date = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  void _selectReminderTime() async {
    final time = await TimePickerUtils.showStyledTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _reminderTime = time;
      });
    }
  }

  /// Check if the selected type is a menstrual phase
  bool _isMenstrualPhase(RecurrenceType type) {
    return [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase,
      RecurrenceType.menstrualStartDay,
      RecurrenceType.ovulationPeakDay
    ].contains(type);
  }

  bool _hasSelectedMenstrualPhase() {
    final menstrualTypes = [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase,
    ];
    return _selectedTypes.any((type) => menstrualTypes.contains(type));
  }

  Widget _buildPhaseDaySelector() {
    if (!_hasSelectedMenstrualPhase()) return const SizedBox.shrink();

    // Get the selected menstrual phase to determine day range
    final selectedPhase = _selectedTypes.firstWhere(
      (type) => [
        RecurrenceType.menstrualPhase,
        RecurrenceType.follicularPhase,
        RecurrenceType.ovulationPhase,
        RecurrenceType.earlyLutealPhase,
        RecurrenceType.lateLutealPhase,
      ].contains(type),
      orElse: () => RecurrenceType.menstrualPhase,
    );

    // Define actual cycle day ranges for each phase (30-day cycle)
    int minCycleDay, maxCycleDay;
    String phaseTitle;

    switch (selectedPhase) {
      case RecurrenceType.menstrualPhase:
        minCycleDay = 1;
        maxCycleDay = 5;
        phaseTitle = 'Menstrual Phase';
        break;
      case RecurrenceType.follicularPhase:
        minCycleDay = 6;
        maxCycleDay = 11;
        phaseTitle = 'Follicular Phase';
        break;
      case RecurrenceType.ovulationPhase:
        minCycleDay = 12;
        maxCycleDay = 16;
        phaseTitle = 'Ovulation Phase';
        break;
      case RecurrenceType.earlyLutealPhase:
        minCycleDay = 17;
        maxCycleDay = 23;
        phaseTitle = 'Early Luteal Phase';
        break;
      case RecurrenceType.lateLutealPhase:
        minCycleDay = 24;
        maxCycleDay = 30;
        phaseTitle = 'Late Luteal Phase';
        break;
      default:
        minCycleDay = 1;
        maxCycleDay = 5;
        phaseTitle = 'Phase';
    }

    // Convert stored phaseDay (1-based within phase) to actual cycle day for display
    int currentCycleDay;
    if (_phaseDay == null) {
      currentCycleDay = minCycleDay; // Default to first day of phase
      _phaseDay = 1; // Store as relative day 1
    } else {
      currentCycleDay = minCycleDay + _phaseDay! - 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dialogBackground.withValues(alpha: 0.08),
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: AppColors.coral.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Select Day within $phaseTitle',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: AppColors.greyText,
                ),
              ),
              const Spacer(),
              Text(
                'Optional',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _usePhaseDaySelector,
                activeColor: AppColors.coral,
                onChanged: (value) {
                  setState(() {
                    _usePhaseDaySelector = value ?? false;
                    if (!_usePhaseDaySelector) {
                      _phaseDay = null;
                    } else {
                      _phaseDay = 1; // Default to first day of phase
                    }
                  });
                },
              ),
              const Text('Specific day within phase', style: TextStyle(color: AppColors.greyText)),
            ],
          ),
          if (_usePhaseDaySelector) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Cycle Day $currentCycleDay',
                  style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.greyText),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: currentCycleDay.toDouble(),
                    min: minCycleDay.toDouble(),
                    max: maxCycleDay.toDouble(),
                    divisions: maxCycleDay - minCycleDay,
                    activeColor: AppColors.coral,
                    onChanged: (value) {
                      setState(() {
                        final selectedCycleDay = value.round();
                        // Convert back to relative day within the phase
                        _phaseDay = selectedCycleDay - minCycleDay + 1;
                      });
                    },
                  ),
                ),
              ],
            )
          ],
        ],
      ),
    );
  }

  String _getDayName(int dayNumber) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayNames[dayNumber - 1];
  }
}
