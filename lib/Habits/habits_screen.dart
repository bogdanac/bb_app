import 'package:bb_app/Habits/habit_edit_screen.dart';
import 'package:bb_app/Habits/habit_statistics_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:bb_app/Habits/habit_data_models.dart';
import 'package:bb_app/theme/app_colors.dart';
import 'package:bb_app/theme/app_styles.dart';
import 'package:bb_app/Habits/habit_service.dart';

class HabitsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const HabitsScreen({super.key, this.onOpenDrawer});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<Habit> _habits = [];
  bool _isLoading = true;

  // Hold state tracking
  bool _isHoldingForHabitDelete = false;
  String? _holdingHabitId;
  Timer? _habitHoldTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _habitHoldTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _habits = await HabitService.loadHabits();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startHabitHoldTimer(Habit habit) {
    // Cancel any existing timer to prevent duplicates
    _habitHoldTimer?.cancel();

    setState(() {
      _holdingHabitId = habit.id;
      _isHoldingForHabitDelete = true;
    });

    _habitHoldTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isHoldingForHabitDelete && _holdingHabitId == habit.id) {
        _deleteHabit(habit);
        _cancelHabitHoldTimer();
      }
    });
  }

  void _cancelHabitHoldTimer() {
    _habitHoldTimer?.cancel();
    _habitHoldTimer = null;
    if (mounted) {
      setState(() {
        _isHoldingForHabitDelete = false;
        _holdingHabitId = null;
      });
    }
  }

  void _addHabit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitEditScreen(
          onSave: (habit) async {
            await HabitService.addHabit(habit);
            _loadData();
          },
        ),
      ),
    );
  }

  void _editHabit(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitEditScreen(
          habit: habit,
          onSave: (updatedHabit) async {
            await HabitService.updateHabit(updatedHabit);
            _loadData();
          },
        ),
      ),
    );
  }

  Future<void> _deleteHabit(Habit habit) async {
    await HabitService.deleteHabit(habit.id);
    _loadData();
  }

  Future<void> _toggleHabitActive(Habit habit) async {
    habit.isActive = !habit.isActive;
    await HabitService.updateHabit(habit);
    _loadData();
  }

  void _viewStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitStatisticsScreen(habits: _habits),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawerLeading = widget.onOpenDrawer != null
        ? IconButton(icon: const Icon(Icons.menu_rounded), onPressed: widget.onOpenDrawer)
        : null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: drawerLeading,
          title: const Text('Habits'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: drawerLeading,
        title: const Text('Habits'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_habits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _viewStatistics,
                icon: const Icon(Icons.analytics_outlined),
                tooltip: 'Statistics',
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: _addHabit,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Habit',
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _buildHabitsContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitsContent() {
    if (_habits.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology_rounded, size: 64, color: AppColors.greyText),
                SizedBox(height: 16),
                Text(
                  'No habits yet',
                  style: TextStyle(fontSize: 18, color: AppColors.greyText),
                ),
                Text(
                  'Create your first habit to get started',
                  style: TextStyle(color: AppColors.greyText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Tap to edit • Swipe left to delete • Toggle switch to activate',
                  style: TextStyle(
                    color: AppColors.greyText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _habits.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final habit = _habits.removeAt(oldIndex);
                _habits.insert(newIndex, habit);
              });
              // Note: Habits don't have a specific save order method like routines
            },
            itemBuilder: (context, index) {
              final habit = _habits[index];
              return _buildHabitCard(habit, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHabitCard(Habit habit, int index) {
    final isCompletedToday = habit.isCompletedToday();
    final streak = habit.getStreak();

    return Dismissible(
      key: ValueKey(habit.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.7},
      confirmDismiss: (direction) async {
        return false; // Never auto-dismiss, require manual hold confirmation
      },
      onUpdate: (details) {
        final threshold = 0.7;
        final reachedThreshold = details.progress >= threshold;

        // When threshold reached, start hold detection
        if (reachedThreshold && _holdingHabitId != habit.id) {
          _startHabitHoldTimer(habit);
        } else if (!reachedThreshold && _holdingHabitId == habit.id) {
          _cancelHabitHoldTimer();
        }
      },
      onDismissed: (direction) {
        _deleteHabit(habit);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: (_isHoldingForHabitDelete && _holdingHabitId == habit.id)
              ? AppColors.deleteRed
              : AppColors.deleteRed.withValues(alpha: 0.8),
          borderRadius: AppStyles.borderRadiusMedium,
          boxShadow: (_isHoldingForHabitDelete && _holdingHabitId == habit.id) ? [
            BoxShadow(
              color: AppColors.deleteRed.withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 0,
            )
          ] : null,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              (_isHoldingForHabitDelete && _holdingHabitId == habit.id)
                  ? Icons.timer_rounded
                  : Icons.delete_rounded,
              color: AppColors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              (_isHoldingForHabitDelete && _holdingHabitId == habit.id)
                  ? 'Hold to Delete'
                  : 'Delete',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        key: ValueKey('habit_${habit.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppStyles.borderRadiusMedium,
        ),
        child: InkWell(
          onTap: () => _editHabit(habit),
          borderRadius: AppStyles.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.drag_handle_rounded, color: AppColors.greyText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: habit.isActive ? null : AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cycle ${habit.currentCycle} • ${habit.getCurrentCycleProgress()}/${habit.cycleDurationDays} days',
                            style: TextStyle(
                              color: habit.isActive ? AppColors.orange : AppColors.greyText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: habit.isActive,
                      onChanged: (value) => _toggleHabitActive(habit),
                      activeThumbColor: AppColors.orange,
                    ),
                  ],
                ),
                if (habit.isActive) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompletedToday ? AppColors.orange.withValues(alpha: 0.1) : AppColors.normalCardBackground,
                          borderRadius: AppStyles.borderRadiusMedium,
                          border: Border.all(
                            color: isCompletedToday ? AppColors.orange.withValues(alpha: 0.3) : AppColors.grey300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompletedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isCompletedToday ? AppColors.orange : AppColors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCompletedToday ? 'Completed Today' : 'Not Done Today',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isCompletedToday ? AppColors.orange : AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.normalCardBackground,
                            borderRadius: AppStyles.borderRadiusMedium,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                color: AppColors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$streak day${streak == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
