import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'habit_data_models.dart';
import 'habit_service.dart';
import 'habit_edit_screen.dart';
import 'habit_statistics_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<Habit> _habits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    _habits = await HabitService.loadHabits();
    setState(() {
      _isLoading = false;
    });
  }

  void _addHabit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitEditScreen(
          onSave: (habit) async {
            await HabitService.addHabit(habit);
            _loadHabits();
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
            _loadHabits();
          },
        ),
      ),
    );
  }

  Future<void> _deleteHabit(Habit habit) async {
    await HabitService.deleteHabit(habit.id);
    _loadHabits();

  }

  Future<void> _toggleHabitActive(Habit habit) async {
    habit.isActive = !habit.isActive;
    await HabitService.updateHabit(habit);
    _loadHabits();
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Habits'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
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
      body: _habits.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No habits yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Create your first habit to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header with instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tap to edit • Swipe left to delete • Toggle switch to activate',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Habits list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _habits.length,
                    itemBuilder: (context, index) {
                      final habit = _habits[index];
                      final isCompletedToday = habit.isCompletedToday();
                      final streak = habit.getStreak();
                      
                      return Dismissible(
                        key: ValueKey(habit.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.orange,
                                    size: 28,
                                  ),
                                  SizedBox(width: 12),
                                  Text('Delete Habit'),
                                ],
                              ),
                              content: Text('Are you sure you want to delete "${habit.name}"? This will permanently remove all tracking data.'),
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (direction) {
                          _deleteHabit(habit);
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.redPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _editHabit(habit),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              habit.name,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: habit.isActive ? null : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Cycle ${habit.currentCycle} • ${habit.getCurrentCycleProgress()}/21 days',
                                              style: TextStyle(
                                                color: habit.isActive ? AppColors.orange : Colors.grey[600],
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
                                            color: isCompletedToday ? AppColors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isCompletedToday ? AppColors.orange.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isCompletedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                                                color: isCompletedToday ? AppColors.orange : Colors.grey,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isCompletedToday ? 'Completed Today' : 'Not Done Today',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isCompletedToday ? AppColors.orange : Colors.grey,
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
                                              color: AppColors.orange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.orange.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.schedule,
                                                  color: AppColors.orange,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$streak day${streak == 1 ? '' : 's'}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.orange,
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
                    },
                  ),
                ),
              ],
            ),
    );
  }
}