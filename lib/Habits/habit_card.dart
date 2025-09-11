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
    await HabitService.toggleHabitCompletion(habit.id);
    await _loadActiveHabits(); // Reload to get updated completion status
    
    // Check if all habits are now completed
    final allCompleted = _activeHabits.every((h) => h.isCompletedToday());
    if (allCompleted) {
      widget.onAllCompleted();
    }
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
            color: AppColors.orange.withValues(alpha: 0.2),
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
    final completedCount = _activeHabits.length - uncompletedHabits.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.orange.withValues(alpha: 0.15),
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
                      color: AppColors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked,
                          color: AppColors.orange,
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
                                    fontWeight: FontWeight.bold,
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

            // Completed habits (if any)
            if (completedCount > 0) ...[
              const SizedBox(height: 8),
              ...(_activeHabits.where((h) => h.isCompletedToday()).map((habit) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                    onTap: () => _toggleHabit(habit),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              habit.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
            ],

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