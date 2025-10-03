import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'habit_data_models.dart';
import 'habit_service.dart';

class HabitCard extends StatefulWidget {
  final VoidCallback onAllCompleted;

  const HabitCard({
    super.key,
    required this.onAllCompleted,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  List<Habit> _activeHabits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveHabits();
  }

  Future<void> _loadActiveHabits() async {
    _activeHabits = await HabitService.getActiveHabits();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _toggleHabit(Habit habit) async {
    final result = await HabitService.toggleHabitCompletion(habit.id);
    await _loadActiveHabits(); // Reload to get updated completion status

    // Check for cycle completion
    if (result['cycleCompleted'] == true && result['habit'] != null) {
      final completedHabit = result['habit'] as Habit;
      _showCycleCompletionDialog(completedHabit);
    }

    // Check if all habits are now completed
    final allCompleted = _activeHabits.every((h) => h.isCompletedToday());
    if (allCompleted) {
      widget.onAllCompleted();
    }
  }

  void _showCycleCompletionDialog(Habit habit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: AppColors.successGreen, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cycle Complete!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations! You\'ve completed a 21-day cycle for "${habit.name}".',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: AppColors.successGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '21 days completed! This is a major milestone in building lasting habits.',
                      style: TextStyle(
                        color: AppColors.successGreen.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to start a new 21-day cycle for this habit?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep Current Progress',
              style: TextStyle(color: AppColors.greyText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await HabitService.startNewCycle(habit.id);
              await _loadActiveHabits();

              // Show confirmation
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('New 21-day cycle started for "${habit.name}"!'),
                    backgroundColor: AppColors.successGreen,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start New Cycle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.dialogCardBackground,
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_activeHabits.isEmpty) {
      return const SizedBox.shrink(); // Don't show card if no active habits
    }

    final uncompletedHabits = _activeHabits.where((h) => !h.isCompletedToday()).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.homeCardBackground, // Home card background
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [


            // Habits list
            ...uncompletedHabits.map((habit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                  onTap: () => _toggleHabit(habit),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.homeCardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_box_outline_blank,
                          color: AppColors.orange.withValues(alpha: 0.8),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            habit.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (habit.getStreak() > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: AppColors.orange,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${habit.getStreak()}',
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
                  ),
                ),
            )),


            if (uncompletedHabits.isEmpty) ...[
              // All habits completed
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.celebration, color: AppColors.successGreen),
                    SizedBox(width: 8),
                    Text('All habits completed! 🎉'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}