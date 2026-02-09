import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../Settings/app_customization_service.dart';
import 'habit_data_models.dart';
import 'habit_service.dart';
import 'habit_history_screen.dart';
import '../shared/snackbar_utils.dart';

class HabitEditScreen extends StatefulWidget {
  final Habit? habit;
  final Function(Habit) onSave;

  const HabitEditScreen({
    super.key,
    this.habit,
    required this.onSave,
  });

  @override
  State<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends State<HabitEditScreen> {
  final _nameController = TextEditingController();
  bool _isActive = true;
  late DateTime _startDate;
  late HabitDuration _duration;

  // For calendar preview (used when creating new habit or editing without progress)
  final int _previewCurrentCycle = 1;

  // For monthly calendar navigation (long cycles)
  DateTime _currentViewMonth = DateTime.now();

  // First day of week setting
  int _firstDayOfWeek = 1; // 1 = Monday, 7 = Sunday

  @override
  void initState() {
    super.initState();
    if (widget.habit != null) {
      _nameController.text = widget.habit!.name;
      _isActive = widget.habit!.isActive;
      _startDate = widget.habit!.startDate;
      _duration = widget.habit!.duration;
    } else {
      _startDate = DateTime.now();
      _duration = HabitDuration.threeWeeks; // Default to 21 days
    }
    _loadFirstDayOfWeek();
  }

  Future<void> _loadFirstDayOfWeek() async {
    final firstDay = await AppCustomizationService.getCalendarFirstDayOfWeek();
    if (mounted) {
      setState(() {
        _firstDayOfWeek = firstDay;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveHabit() {
    if (_nameController.text.trim().isEmpty) {
      SnackBarUtils.showInfo(context, 'Please enter a habit name');
      return;
    }

    final habit = Habit(
      id: widget.habit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      isActive: _isActive,
      createdAt: widget.habit?.createdAt,
      startDate: _startDate,
      cycleDurationDays: _duration.days,
      completedDates: widget.habit?.completedDates,
      currentCycle: widget.habit?.currentCycle ?? 1,
      isCompleted: widget.habit?.isCompleted ?? false,
      cycleHistory: widget.habit?.cycleHistory, // Preserve cycle history
    );

    widget.onSave(habit);
    Navigator.pop(context);
  }

  void _openHistory() {
    if (widget.habit != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HabitHistoryScreen(habit: widget.habit!),
        ),
      );
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _toggleDateCompletion(DateTime date) async {
    if (widget.habit != null) {
      await HabitService.toggleHabitCompletionOnDate(widget.habit!.id, date);
      setState(() {
        widget.habit!.toggleCompletionOnDate(date);
      });
    }
  }

  Future<void> _showRestartCycleDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restart_alt, color: AppColors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Restart Cycle?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to restart the current ${widget.habit!.duration.label} cycle for "${widget.habit!.name}"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusSmall,
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'This will:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Clear all progress in the current cycle'),
                  Text('• Reset to day 1 of ${widget.habit!.cycleDurationDays}'),
                  const Text('• Keep the same cycle number'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restart Cycle'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _restartCurrentCycle();
    }
  }

  Future<void> _restartCurrentCycle() async {
    if (widget.habit != null) {
      // Restart cycle without saving to history
      final now = DateTime.now();
      final newStartDate = DateTime(now.year, now.month, now.day);
      widget.habit!.restartCurrentCycle(newStartDate);
      _startDate = newStartDate;

      // Save the updated habit
      await HabitService.updateHabit(widget.habit!);

      setState(() {
        // Trigger UI refresh
      });

      if (mounted) {
        SnackBarUtils.showWarning(context, 'Cycle restarted for "${widget.habit!.name}"! Starting fresh from day 1.');
      }
    }
  }

  Future<void> _showContinueToNextCycleDialog() async {
    final nextCycle = widget.habit!.currentCycle + 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.arrow_forward, color: AppColors.successGreen, size: 28),
            const SizedBox(width: 8),
            Text('Continue to Cycle $nextCycle?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start cycle $nextCycle for "${widget.habit!.name}"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusSmall,
                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: AppColors.successGreen, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'This will:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('• Start cycle $nextCycle'),
                  const Text('• Clear current progress'),
                  Text('• Begin a fresh ${widget.habit!.duration.label} challenge'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('Start Cycle $nextCycle'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _continueToNextCycle();
    }
  }

  Future<void> _continueToNextCycle() async {
    if (widget.habit != null) {
      // Use the existing method from habit data model
      widget.habit!.continueToNextCycle();

      // Save the updated habit
      await HabitService.updateHabit(widget.habit!);

      setState(() {
        // Trigger UI refresh
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Started cycle ${widget.habit!.currentCycle} for "${widget.habit!.name}"! Let\'s build this habit! 🎯');
      }
    }
  }

  Widget _buildCycleCalendar({bool isPreview = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Use local state for preview, or habit data for existing habits
    final int duration;
    final DateTime cycleStartDate;
    final int currentCycle;

    if (isPreview || widget.habit == null) {
      // Preview mode: use local state values
      duration = _duration.days;
      cycleStartDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
      currentCycle = _previewCurrentCycle;
    } else {
      // Existing habit with progress: use habit data
      final habit = widget.habit!;
      duration = habit.cycleDurationDays;
      final habitStartDate = DateTime(
        habit.startDate.year,
        habit.startDate.month,
        habit.startDate.day,
      );
      cycleStartDate = habitStartDate.add(Duration(days: (habit.currentCycle - 1) * duration));
      currentCycle = habit.currentCycle;
    }

    final cycleEndDate = cycleStartDate.add(Duration(days: duration - 1));

    // For long cycles (30+ days), use monthly view with navigation
    final useMontlyView = duration >= 30;

    if (useMontlyView) {
      return _buildMonthlyCalendar(
        cycleStartDate: cycleStartDate,
        cycleEndDate: cycleEndDate,
        duration: duration,
        currentCycle: currentCycle,
        today: today,
        isPreview: isPreview,
      );
    }

    // Short cycles: show all days at once
    final days = List.generate(duration, (index) => cycleStartDate.add(Duration(days: index)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_duration.label} ${isPreview ? "Preview" : "Progress"} Calendar',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPreview
                  ? 'Preview of your ${_duration.days}-day cycle starting ${DateFormat('MMM d').format(_startDate)}'
                  : 'Cycle $currentCycle - Days ${(currentCycle - 1) * duration + 1} to ${currentCycle * duration}. Tap to check/uncheck days.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 12),
            // Days of week header
            Row(
              children: (_firstDayOfWeek == 1
                      ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      : ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.greyText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Calendar grid
            _buildCalendarGrid(days, today, isPreview: isPreview),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCalendar({
    required DateTime cycleStartDate,
    required DateTime cycleEndDate,
    required int duration,
    required int currentCycle,
    required DateTime today,
    required bool isPreview,
  }) {
    // Ensure current view month is within the cycle range
    final firstMonth = DateTime(cycleStartDate.year, cycleStartDate.month, 1);
    final lastMonth = DateTime(cycleEndDate.year, cycleEndDate.month, 1);

    if (_currentViewMonth.isBefore(firstMonth)) {
      _currentViewMonth = firstMonth;
    } else if (_currentViewMonth.isAfter(lastMonth)) {
      _currentViewMonth = lastMonth;
    }

    final viewMonth = DateTime(_currentViewMonth.year, _currentViewMonth.month, 1);

    // Get days in this month that are within the cycle
    final daysInMonth = DateUtils.getDaysInMonth(viewMonth.year, viewMonth.month);
    final monthStart = DateTime(viewMonth.year, viewMonth.month, 1);

    // Filter to only show days within the cycle
    final List<DateTime> cycleDaysInMonth = [];
    for (int i = 0; i < daysInMonth; i++) {
      final day = monthStart.add(Duration(days: i));
      if (!day.isBefore(cycleStartDate) && !day.isAfter(cycleEndDate)) {
        cycleDaysInMonth.add(day);
      }
    }

    // Calculate progress for this month
    int completedInMonth = 0;
    if (!isPreview && widget.habit != null) {
      for (final day in cycleDaysInMonth) {
        if (widget.habit!.isCompletedOnDate(day)) {
          completedInMonth++;
        }
      }
    }

    // Build calendar grid for the full month (with empty slots for alignment)
    // Calculate offset based on first day of week setting
    final int firstDayWeekday;
    if (_firstDayOfWeek == 1) {
      // Monday first: Monday=0, Tuesday=1, ..., Sunday=6
      firstDayWeekday = (monthStart.weekday - 1) % 7;
    } else {
      // Sunday first: Sunday=0, Monday=1, ..., Saturday=6
      firstDayWeekday = monthStart.weekday % 7;
    }
    final allDays = <DateTime?>[];

    // Add empty slots for days before the month starts
    for (int i = 0; i < firstDayWeekday; i++) {
      allDays.add(null);
    }

    // Add all days of the month
    for (int i = 0; i < daysInMonth; i++) {
      allDays.add(monthStart.add(Duration(days: i)));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title
            Text(
              '${_duration.label} ${isPreview ? "Preview" : "Progress"} Calendar',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPreview
                  ? 'Preview: ${DateFormat('MMM d, yyyy').format(cycleStartDate)} - ${DateFormat('MMM d, yyyy').format(cycleEndDate)}'
                  : 'Cycle $currentCycle. Tap days to check/uncheck.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 12),

            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: viewMonth.isAfter(firstMonth) ? AppColors.orange : AppColors.greyText.withValues(alpha: 0.3),
                  ),
                  onPressed: viewMonth.isAfter(firstMonth)
                      ? () {
                          setState(() {
                            _currentViewMonth = DateTime(viewMonth.year, viewMonth.month - 1, 1);
                          });
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(viewMonth),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isPreview && cycleDaysInMonth.isNotEmpty)
                      Text(
                        '$completedInMonth/${cycleDaysInMonth.length} days',
                        style: TextStyle(
                          fontSize: 12,
                          color: completedInMonth == cycleDaysInMonth.length
                              ? AppColors.successGreen
                              : AppColors.greyText,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: viewMonth.isBefore(lastMonth) ? AppColors.orange : AppColors.greyText.withValues(alpha: 0.3),
                  ),
                  onPressed: viewMonth.isBefore(lastMonth)
                      ? () {
                          setState(() {
                            _currentViewMonth = DateTime(viewMonth.year, viewMonth.month + 1, 1);
                          });
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Days of week header
            Row(
              children: (_firstDayOfWeek == 1
                      ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      : ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.greyText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),

            // Calendar grid
            _buildMonthlyCalendarGrid(
              allDays: allDays,
              cycleStartDate: cycleStartDate,
              cycleEndDate: cycleEndDate,
              today: today,
              isPreview: isPreview,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCalendarGrid({
    required List<DateTime?> allDays,
    required DateTime cycleStartDate,
    required DateTime cycleEndDate,
    required DateTime today,
    required bool isPreview,
  }) {
    // Group into weeks
    final weeks = <List<DateTime?>>[];
    for (int i = 0; i < allDays.length; i += 7) {
      final end = (i + 7 < allDays.length) ? i + 7 : allDays.length;
      final week = allDays.sublist(i, end);
      // Pad last week with nulls if needed
      while (week.length < 7) {
        week.add(null);
      }
      weeks.add(week);
    }

    return Column(
      children: weeks.map((week) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: week.map((date) {
              if (date == null) {
                return const Expanded(child: SizedBox(height: 36));
              }

              // Check if this day is within the cycle
              final isInCycle = !date.isBefore(cycleStartDate) && !date.isAfter(cycleEndDate);

              if (!isInCycle) {
                // Day outside cycle - show greyed out
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    height: 36,
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: _buildDayCell(date, today, isPreview: isPreview),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(List<DateTime> days, DateTime today, {bool isPreview = false}) {
    // Group days into weeks (rows of 7)
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      final end = (i + 7 < days.length) ? i + 7 : days.length;
      weeks.add(days.sublist(i, end));
    }

    return Column(
      children: weeks.map((week) => _buildWeekRow(week, today, isPreview: isPreview)).toList(),
    );
  }

  Widget _buildWeekRow(List<DateTime> week, DateTime today, {bool isPreview = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: week.map((date) => _buildDayCell(date, today, isPreview: isPreview)).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today, {bool isPreview = false}) {
    final isCompleted = !isPreview && widget.habit != null && widget.habit!.isCompletedOnDate(date);
    final isToday = date.day == today.day &&
                   date.month == today.month &&
                   date.year == today.year;
    final isPast = date.isBefore(today);
    date.isAfter(today);

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (isCompleted) {
      backgroundColor = AppColors.orange.withValues(alpha: 0.2);
      borderColor = AppColors.orange;
      textColor = AppColors.orange;
    } else if (isToday) {
      backgroundColor = AppColors.white.withValues(alpha: 0.1);
      borderColor = AppColors.white;
      textColor = AppColors.white;
    } else if (isPast) {
      backgroundColor = AppColors.transparent;
      borderColor = AppColors.greyText.withValues(alpha: 0.3);
      textColor = AppColors.greyText;
    } else {
      backgroundColor = AppColors.transparent;
      borderColor = AppColors.white.withValues(alpha: 0.3);
      textColor = AppColors.white.withValues(alpha: 0.7);
    }

    return Expanded(
      child: GestureDetector(
        onTap: isPreview ? null : () => _toggleDateCompletion(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: AppStyles.borderRadiusSmall,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (isCompleted)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.orange,
                    size: 12,
                  ),
                ),
              if (isToday && !isCompleted)
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit == null ? 'Add Habit' : 'Edit Habit'),
        backgroundColor: Colors.transparent,
        actions: [
          // History button - only show for existing habits
          if (widget.habit != null)
            IconButton(
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded),
              tooltip: 'View Cycle History',
              color: widget.habit!.cycleHistory.isNotEmpty
                  ? AppColors.orange
                  : AppColors.greyText,
            ),
          TextButton.icon(
            onPressed: _saveHabit,
            icon: const Icon(Icons.check, color: AppColors.orange),
            label: Text(
              widget.habit == null ? 'Create' : 'Save',
              style: const TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                hintText: 'e.g., Drink 8 glasses of water',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Habit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Only active habits appear on the home screen',
                            style: TextStyle(
                              color: AppColors.greyText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                      activeThumbColor: AppColors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Start Date picker
            Card(
              child: InkWell(
                onTap: _selectStartDate,
                borderRadius: AppStyles.borderRadiusMedium,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Date',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _startDate.isAfter(DateTime.now())
                                  ? 'Tracking starts on this date'
                                  : 'Tracking started on this date',
                              style: const TextStyle(
                                color: AppColors.greyText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusSmall,
                          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.orange, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMM d, yyyy').format(_startDate),
                              style: const TextStyle(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Duration picker (only for new habits or if habit has no progress)
            if (widget.habit == null || widget.habit!.completedDates.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Challenge Duration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'How long should each cycle be?',
                        style: TextStyle(
                          color: AppColors.greyText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: HabitDuration.values.map((duration) {
                          final isSelected = _duration == duration;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _duration = duration;
                                  });
                                },
                                borderRadius: AppStyles.borderRadiusSmall,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.orange.withValues(alpha: 0.2)
                                        : AppColors.transparent,
                                    borderRadius: AppStyles.borderRadiusSmall,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.orange
                                          : AppColors.greyText.withValues(alpha: 0.3),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        duration.label,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.orange : AppColors.white,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${duration.days} days',
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.orange.withValues(alpha: 0.8)
                                              : AppColors.greyText,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Calendar preview for new habits only
            if (widget.habit == null)
              _buildCycleCalendar(isPreview: true),
            // Progress section for existing habits (even with no progress yet)
            if (widget.habit != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${widget.habit!.duration.label} Challenge',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Cycle ${widget.habit!.currentCycle}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.greyText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.habit!.getCurrentCycleProgress()}/${widget.habit!.cycleDurationDays} days completed',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (widget.habit!.canContinueToNextCycle())
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              widget.habit!.continueToNextCycle();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text('Start Next ${widget.habit!.duration.label} Cycle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showRestartCycleDialog(),
                              icon: const Icon(Icons.restart_alt, size: 18),
                              label: const Text('Restart Cycle'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.orange,
                                side: BorderSide(color: AppColors.orange),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showContinueToNextCycleDialog(),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: Text('Cycle ${widget.habit!.currentCycle + 1}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.successGreen,
                                side: BorderSide(color: AppColors.successGreen),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildCycleCalendar(),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

