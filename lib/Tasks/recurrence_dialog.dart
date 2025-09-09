import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'tasks_data_models.dart';
import '../theme/app_colors.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';

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
  List<int> _selectedWeekDays = [];
  int? _dayOfMonth;
  bool _isLastDayOfMonth = false;
  DateTime? _endDate;
  int? _phaseDay; // Selected day within a menstrual phase
  bool _usePhaseDaySelector = false; // Whether to use specific day selection

  final List<String> _weekDayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRecurrence != null) {
      final recurrence = widget.initialRecurrence!;
      _selectedTypes = List.from(recurrence.types);
      _primaryType = recurrence.types.isNotEmpty
          ? recurrence.types.first
          : RecurrenceType.daily;
      _interval = recurrence.interval;
      _selectedWeekDays = List.from(recurrence.weekDays);
      _dayOfMonth = recurrence.dayOfMonth;
      _isLastDayOfMonth = recurrence.isLastDayOfMonth;
      _endDate = recurrence.endDate;
      _phaseDay = recurrence.phaseDay;
      _usePhaseDaySelector = recurrence.phaseDay != null;
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
      appBar: AppBar(
        title: const Text('Repeat Task'),
        backgroundColor: AppColors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
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
                    // Quick options section
                    const Text(
                      'Quick Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick preset buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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

                    // Menstrual cycle options
                    const Text(
                      'Menstrual Cycle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                    const SizedBox(height: 8),
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

                    // Phase Day Selector for menstrual phases
                    if (_hasSelectedMenstrualPhase()) ...[
                      const SizedBox(height: 16),
                      _buildPhaseDaySelector(),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Custom section - only show if primary type is not a menstrual phase
                    if (!_isMenstrualPhase(_primaryType)) ...[
                      const Text(
                        'Custom Repeat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Recurrence Type Selection - only show if primary type is not a menstrual phase
                    if (!_isMenstrualPhase(_primaryType))
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Repeat every:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: _interval.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
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
                                  flex: 2,
                                  child:
                                      DropdownButtonFormField<RecurrenceType>(
                                    initialValue: _displayedSelectedType,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                    ),
                                    items: _allowedDropdownTypes.map((type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child:
                                            Text(_getRecurrenceTypeName(type)),
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
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Weekly specific options
                    if (_selectedTypes.contains(RecurrenceType.weekly)) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Repeat on days:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(7, (index) {
                                final dayNumber = index + 1;
                                final isSelected =
                                    _selectedWeekDays.contains(dayNumber);

                                return FilterChip(
                                  label: Text(
                                    _weekDayNames[index].substring(0, 3),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white : null,
                                    ),
                                  ),
                                  selected: isSelected,
                                  backgroundColor: Colors.transparent,
                                  selectedColor: AppColors.coral,
                                  checkmarkColor: Colors.white,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.coral
                                        : Colors.grey.withValues(alpha: 0.5),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWeekDays.add(dayNumber);
                                      } else {
                                        _selectedWeekDays.remove(dayNumber);
                                        // If all weekdays are deselected, keep at least Monday
                                        if (_selectedWeekDays.isEmpty) {
                                          _selectedWeekDays.add(1); // Monday
                                        }
                                      }
                                      _selectedWeekDays.sort();
                                    });
                                  },
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Yearly specific options
                    if (_selectedTypes.contains(RecurrenceType.yearly)) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                AppColors.successGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Repeat on:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('Month: '),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue:
                                        _interval <= 12 ? _interval : 1,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                    ),
                                    items: List.generate(12, (index) {
                                      final monthNames = [
                                        'Jan',
                                        'Feb',
                                        'Mar',
                                        'Apr',
                                        'May',
                                        'Jun',
                                        'Jul',
                                        'Aug',
                                        'Sep',
                                        'Oct',
                                        'Nov',
                                        'Dec'
                                      ];
                                      return DropdownMenuItem(
                                        value: index + 1,
                                        child: Text(monthNames[index]),
                                      );
                                    }),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _interval =
                                              value; // For yearly, interval represents the month
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Day: '),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    initialValue:
                                        _dayOfMonth?.toString() ?? '1',
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                    ),
                                    onChanged: (value) {
                                      final intValue = int.tryParse(value);
                                      if (intValue != null &&
                                          intValue >= 1 &&
                                          intValue <= 31) {
                                        setState(() {
                                          _dayOfMonth = intValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Monthly specific options
                    if (_selectedTypes.contains(RecurrenceType.monthly)) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.purple.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Repeat on:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),

                            // Specific day option
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: !_isLastDayOfMonth
                                    ? AppColors.purple.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !_isLastDayOfMonth
                                      ? AppColors.purple.withValues(alpha: 0.3)
                                      : Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isLastDayOfMonth = false;
                                    _dayOfMonth ??= DateTime.now().day;
                                  });
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
                                          color: !_isLastDayOfMonth
                                              ? AppColors.purple
                                              : Colors.grey,
                                          width: 2,
                                        ),
                                        color: !_isLastDayOfMonth
                                            ? AppColors.purple
                                            : Colors.transparent,
                                      ),
                                      child: !_isLastDayOfMonth
                                          ? const Icon(
                                              Icons.circle,
                                              size: 12,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const Text('Day '),
                                    SizedBox(
                                      width: 60,
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
                                          isDense: true,
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
                                    const Text(' of each month'),
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
                                    ? AppColors.purple.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isLastDayOfMonth
                                      ? AppColors.purple.withValues(alpha: 0.3)
                                      : Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isLastDayOfMonth = true;
                                    _dayOfMonth = null;
                                  });
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
                                              ? AppColors.purple
                                              : Colors.grey,
                                          width: 2,
                                        ),
                                        color: _isLastDayOfMonth
                                            ? AppColors.purple
                                            : Colors.transparent,
                                      ),
                                      child: _isLastDayOfMonth
                                          ? const Icon(
                                              Icons.circle,
                                              size: 12,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const Text('Last day of each month'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // End Date Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Date (Optional)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _selectEndDate,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _endDate != null
                                          ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                          : 'Tap to set end date',
                                      style: TextStyle(
                                        color: _endDate != null
                                            ? null
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  if (_endDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          size: 18),
                                      onPressed: () =>
                                          setState(() => _endDate = null),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: Colors.grey[600],
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
                          interval: _interval,
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
                          endDate: _endDate,
                          phaseDay: _hasSelectedMenstrualPhase() &&
                                  _usePhaseDaySelector
                              ? _phaseDay
                              : null,
                        );
                        Navigator.pop(context, recurrence);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Repeat',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
      {List<int>? weekdays, String? customDescription}) {
    final isSelected = _selectedTypes.contains(type) ||
        (customDescription != null &&
            customDescription == '3 days after period ends' &&
            _selectedTypes.contains(RecurrenceType.custom) &&
            _interval == -1);

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
            // If it was a custom type, also remove the special custom option
            if (customDescription == '3 days after period ends') {
              _selectedTypes.remove(RecurrenceType.custom);
            }
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
                // Default to weekdays when "Weekly" is selected without specific days
                _selectedWeekDays = [
                  1,
                  2,
                  3,
                  4,
                  5
                ]; // Mon-Fri (most common for weekly tasks)
              }
            }

            // Special handling for "3 days after period" custom recurrence
            if (customDescription == '3 days after period ends') {
              _selectedTypes.remove(type);
              _selectedTypes.add(RecurrenceType.custom);
              _primaryType = RecurrenceType.custom;
              _interval = -1; // Special marker for "3 days after period"
            } else {
              _interval = interval;
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.coral
                : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    } catch (e) {
      if (kDebugMode) {
        print('Error validating recurrence: $e');
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

  void _selectEndDate() async {
    final date = await showDatePicker(
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
        color: AppColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.coral.withValues(alpha: 0.2),
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
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'Optional',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              const Text('Specific day within phase'),
            ],
          ),
          if (_usePhaseDaySelector) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Cycle Day $currentCycleDay',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
}
