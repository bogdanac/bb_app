import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'habit_data_models.dart';

class HabitStatisticsScreen extends StatefulWidget {
  final List<Habit> habits;

  const HabitStatisticsScreen({
    super.key,
    required this.habits,
  });

  @override
  State<HabitStatisticsScreen> createState() => _HabitStatisticsScreenState();
}

class _HabitStatisticsScreenState extends State<HabitStatisticsScreen> {
  List<HabitStatistics> _habitStats = [];
  int _selectedTimeRange = 7; // 7 days, 30 days, all time

  @override
  void initState() {
    super.initState();
    _calculateStatistics();
  }

  void _calculateStatistics() {
    _habitStats = widget.habits
        .where((habit) => habit.completedDates.isNotEmpty) // Only habits with data
        .map((habit) => HabitStatistics.fromHabit(habit))
        .toList();
    
    // Sort by current streak descending
    _habitStats.sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Statistics'),
        backgroundColor: Colors.transparent,
      ),
      body: _habitStats.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No habit data yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Start tracking your habits to see statistics',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Statistics Card
                  _buildOverallStatsCard(),
                  const SizedBox(height: 16),
                  
                  // Time Range Selector
                  _buildTimeRangeSelector(),
                  const SizedBox(height: 16),

                  // Individual Habit Statistics
                  const Text(
                    'Individual Habits',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  ..._habitStats.map((stats) => _buildHabitCard(stats)),
                ],
              ),
            ),
    );
  }

  Widget _buildOverallStatsCard() {
    final totalHabits = widget.habits.length;
    final activeHabits = widget.habits.where((h) => h.isActive).length;
    final totalCompletedToday = widget.habits.where((h) => h.isCompletedToday()).length;
    final avgCompletionRate = _habitStats.isNotEmpty
        ? _habitStats.map((s) => s.completionRateAll).reduce((a, b) => a + b) / _habitStats.length
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Habits',
                    value: totalHabits.toString(),
                    icon: Icons.psychology_rounded,
                    color: AppColors.yellow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Active Habits',
                    value: activeHabits.toString(),
                    icon: Icons.check_circle,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Completed Today',
                    value: '$totalCompletedToday/$activeHabits',
                    icon: Icons.today,
                    color: AppColors.yellow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Average Success',
                    value: '${(avgCompletionRate * 100).toInt()}%',
                    icon: Icons.trending_up,
                    color: AppColors.coral,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeRangeButton(
                    label: 'Last 7 Days',
                    value: 7,
                    isSelected: _selectedTimeRange == 7,
                    onTap: () => setState(() => _selectedTimeRange = 7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeRangeButton(
                    label: 'Last 30 Days',
                    value: 30,
                    isSelected: _selectedTimeRange == 30,
                    onTap: () => setState(() => _selectedTimeRange = 30),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeRangeButton(
                    label: 'All Time',
                    value: -1,
                    isSelected: _selectedTimeRange == -1,
                    onTap: () => setState(() => _selectedTimeRange = -1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(HabitStatistics stats) {
    final completionRate = _selectedTimeRange == -1
        ? stats.completionRateAll
        : _selectedTimeRange == 30
            ? stats.completionRateMonth
            : stats.completionRateWeek;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stats.habit.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCompletionRateColor(completionRate).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getCompletionRateColor(completionRate).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${(completionRate * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getCompletionRateColor(completionRate),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SmallStatCard(
                    title: 'Current Streak',
                    value: '${stats.currentStreak}',
                    unit: 'days',
                    color: AppColors.yellow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SmallStatCard(
                    title: 'Longest Streak',
                    value: stats.longestStreak.toString(),
                    unit: 'days',
                    color: AppColors.yellow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SmallStatCard(
                    title: 'Total Days',
                    value: '${stats.totalCompletedDays}',
                    unit: 'days',
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Progress bar for selected time range
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTimeRange == -1 
                          ? 'Overall Progress'
                          : 'Progress (Last $_selectedTimeRange days)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${(completionRate * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: completionRate,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(_getCompletionRateColor(completionRate)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCompletionRateColor(double rate) {
    if (rate >= 0.8) return AppColors.successGreen;
    if (rate >= 0.6) return AppColors.yellow;
    if (rate >= 0.4) return AppColors.yellow;
    return AppColors.lightCoral;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SmallStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color color;

  const _SmallStatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TimeRangeButton extends StatelessWidget {
  final String label;
  final int value;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeRangeButton({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.yellow.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.yellow.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.yellow : Colors.grey,
          ),
        ),
      ),
    );
  }
}