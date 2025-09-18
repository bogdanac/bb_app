import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'habit_data_models.dart';
import 'habit_service.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.habit != null) {
      _nameController.text = widget.habit!.name;
      _isActive = widget.habit!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveHabit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a habit name')),
      );
      return;
    }

    final habit = Habit(
      id: widget.habit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      isActive: _isActive,
      createdAt: widget.habit?.createdAt,
      completedDates: widget.habit?.completedDates,
      currentCycle: widget.habit?.currentCycle ?? 1,
      isCompleted: widget.habit?.isCompleted ?? false,
    );

    widget.onSave(habit);
    Navigator.pop(context);
  }

  Future<void> _toggleDateCompletion(DateTime date) async {
    if (widget.habit != null) {
      await HabitService.toggleHabitCompletionOnDate(widget.habit!.id, date);
      setState(() {
        widget.habit!.toggleCompletionOnDate(date);
      });
    }
  }

  Widget _build21DayCalendar() {
    if (widget.habit == null) return const SizedBox.shrink();

    final habit = widget.habit!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate the current 21-day cycle start date
    // For cycle 1: start from creation date
    // For cycle 2+: start from (creation date + (cycle-1) * 21 days)
    final creationDate = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );
    final cycleStartDate = creationDate.add(Duration(days: (habit.currentCycle - 1) * 21));

    // Create 21 days starting from the cycle start date
    final days = List.generate(21, (index) => cycleStartDate.add(Duration(days: index)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '21-Day Progress Calendar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Current cycle ${habit.currentCycle} - Days ${(habit.currentCycle - 1) * 21 + 1} to ${habit.currentCycle * 21}. Tap to check/uncheck days.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 16),
            // Days of week header
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
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
            _buildCalendarGrid(days, today),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(List<DateTime> days, DateTime today) {
    // Group days into weeks (rows of 7)
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      final end = (i + 7 < days.length) ? i + 7 : days.length;
      weeks.add(days.sublist(i, end));
    }

    return Column(
      children: weeks.map((week) => _buildWeekRow(week, today)).toList(),
    );
  }

  Widget _buildWeekRow(List<DateTime> week, DateTime today) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: week.map((date) => _buildDayCell(date, today)).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today) {
    final isCompleted = widget.habit!.isCompletedOnDate(date);
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
        onTap: () => _toggleDateCompletion(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(8),
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
      ),
      body: Padding(
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
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                          SizedBox(height: 4),
                          Text(
                            'Only active habits appear on the home screen and can be tracked',
                            style: TextStyle(
                              color: AppColors.greyText,
                              fontSize: 14,
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
            const SizedBox(height: 24),
            if (widget.habit != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '21-Day Challenge',
                            style: TextStyle(
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
                      const SizedBox(height: 12),
                      Text(
                        '${widget.habit!.getCurrentCycleProgress()}/21 days completed',
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
                          label: const Text('Start Next 21-Day Cycle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _build21DayCalendar(),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  widget.habit == null ? 'Create Habit' : 'Update Habit',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

