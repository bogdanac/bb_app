import 'package:flutter/material.dart';
import 'tasks_data_models.dart';
import '../theme/app_colors.dart';

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
  RecurrenceType _selectedType = RecurrenceType.daily;
  int _interval = 1;
  List<int> _selectedWeekDays = [];
  int? _dayOfMonth;
  bool _isLastDayOfMonth = false;
  DateTime? _endDate;

  final List<String> _weekDayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRecurrence != null) {
      final recurrence = widget.initialRecurrence!;
      _selectedType = recurrence.type;
      _interval = recurrence.interval;
      _selectedWeekDays = List.from(recurrence.weekDays);
      _dayOfMonth = recurrence.dayOfMonth;
      _isLastDayOfMonth = recurrence.isLastDayOfMonth;
      _endDate = recurrence.endDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  color: AppColors.coral,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Repeat Task',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 24),
            
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
                        _buildQuickOption('Daily', RecurrenceType.daily, 1, Icons.today_rounded),
                        _buildQuickOption('Weekly', RecurrenceType.weekly, 1, Icons.date_range_rounded),
                        _buildQuickOption('Monthly', RecurrenceType.monthly, 1, Icons.calendar_month_rounded),
                        _buildQuickOption('Weekdays', RecurrenceType.weekly, 1, Icons.work_rounded, weekdays: [1,2,3,4,5]),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Custom section
                    const Text(
                      'Custom Repeat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Recurrence Type Selection
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
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                child: DropdownButtonFormField<RecurrenceType>(
                                  initialValue: _selectedType,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: RecurrenceType.values.where((type) => type != RecurrenceType.custom).map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(_getRecurrenceTypeName(type)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedType = value;
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
                    if (_selectedType == RecurrenceType.weekly) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.orange.withValues(alpha: 0.2),
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
                                final isSelected = _selectedWeekDays.contains(dayNumber);
                
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
                                  selectedColor: AppColors.orange,
                                  checkmarkColor: Colors.white,
                                  side: BorderSide(
                                    color: isSelected ? AppColors.orange : Colors.grey.withValues(alpha: 0.5),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWeekDays.add(dayNumber);
                                      } else {
                                        _selectedWeekDays.remove(dayNumber);
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
                    
                    // Monthly specific options
                    if (_selectedType == RecurrenceType.monthly) ...[
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
                                          color: !_isLastDayOfMonth ? AppColors.purple : Colors.grey,
                                          width: 2,
                                        ),
                                        color: !_isLastDayOfMonth ? AppColors.purple : Colors.transparent,
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
                                        initialValue: _dayOfMonth?.toString() ?? DateTime.now().day.toString(),
                                        keyboardType: TextInputType.number,
                                        enabled: !_isLastDayOfMonth,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          isDense: true,
                                        ),
                                        onChanged: (value) {
                                          final intValue = int.tryParse(value);
                                          if (intValue != null && intValue >= 1 && intValue <= 31) {
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
                                          color: _isLastDayOfMonth ? AppColors.purple : Colors.grey,
                                          width: 2,
                                        ),
                                        color: _isLastDayOfMonth ? AppColors.purple : Colors.transparent,
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
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
                                        color: _endDate != null ? null : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  if (_endDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () => setState(() => _endDate = null),
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
            
            // Action buttons
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.initialRecurrence != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, null),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                if (widget.initialRecurrence != null) const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: _isValidRecurrence() ? () {
                      final recurrence = TaskRecurrence(
                        type: _selectedType,
                        interval: _interval,
                        weekDays: _selectedType == RecurrenceType.weekly ? _selectedWeekDays : [],
                        dayOfMonth: _selectedType == RecurrenceType.monthly && !_isLastDayOfMonth
                            ? _dayOfMonth : null,
                        isLastDayOfMonth: _selectedType == RecurrenceType.monthly && _isLastDayOfMonth,
                        endDate: _endDate,
                      );
                      Navigator.pop(context, recurrence);
                    } : null,
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption(String label, RecurrenceType type, int interval, IconData icon, {List<int>? weekdays}) {
    final isSelected = _selectedType == type && _interval == interval && 
        (weekdays == null || _selectedWeekDays.length == weekdays.length && 
         weekdays.every((day) => _selectedWeekDays.contains(day)));
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
          _interval = interval;
          if (weekdays != null) {
            _selectedWeekDays = List.from(weekdays);
          } else {
            _selectedWeekDays.clear();
          }
          _dayOfMonth = null;
          _isLastDayOfMonth = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.grey.withValues(alpha: 0.3),
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
    if (_selectedType == RecurrenceType.weekly && _selectedWeekDays.isEmpty) {
      return false;
    }
    if (_selectedType == RecurrenceType.monthly && !_isLastDayOfMonth && _dayOfMonth == null) {
      return false;
    }
    return _interval > 0;
  }

  String _getRecurrenceTypeName(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return _interval == 1 ? 'Day' : 'Days';
      case RecurrenceType.weekly:
        return _interval == 1 ? 'Week' : 'Weeks';
      case RecurrenceType.monthly:
        return _interval == 1 ? 'Month' : 'Months';
      case RecurrenceType.custom:
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
}