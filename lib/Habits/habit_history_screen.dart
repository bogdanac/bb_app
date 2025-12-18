import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'habit_data_models.dart';

class HabitHistoryScreen extends StatefulWidget {
  final Habit habit;

  const HabitHistoryScreen({
    super.key,
    required this.habit,
  });

  @override
  State<HabitHistoryScreen> createState() => _HabitHistoryScreenState();
}

class _HabitHistoryScreenState extends State<HabitHistoryScreen> {
  CycleHistory? _selectedCycle;

  @override
  Widget build(BuildContext context) {
    final history = widget.habit.cycleHistory;
    final hasHistory = history.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.habit.name} History'),
        backgroundColor: Colors.transparent,
      ),
      body: hasHistory
          ? _buildHistoryContent(history)
          : _buildNoHistoryContent(),
    );
  }

  Widget _buildNoHistoryContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 80,
              color: AppColors.greyText.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Cycle History Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Complete your first ${widget.habit.duration.label} cycle to start building your history!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.greyText,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusMedium,
                border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up, color: AppColors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Current Cycle ${widget.habit.currentCycle}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.habit.getCurrentCycleProgress()}/${widget.habit.cycleDurationDays} days completed',
                    style: TextStyle(
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent(List<CycleHistory> history) {
    // Sort by cycle number descending (most recent first)
    final sortedHistory = List<CycleHistory>.from(history)
      ..sort((a, b) => b.cycleNumber.compareTo(a.cycleNumber));

    return Column(
      children: [
        // Summary card
        _buildSummaryCard(sortedHistory),
        // Cycle list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedHistory.length,
            itemBuilder: (context, index) {
              final cycle = sortedHistory[index];
              return _buildCycleCard(cycle);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<CycleHistory> history) {
    final totalCycles = history.length;
    final fullyCompletedCycles = history.where((c) => c.isFullyCompleted).length;
    final totalDaysCompleted = widget.habit.getTotalCompletedDaysAllCycles();
    final avgCompletionRate = widget.habit.averageCycleCompletionRate;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.orange.withValues(alpha: 0.2),
            AppColors.coral.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tracking since ${DateFormat('MMM d, yyyy').format(widget.habit.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.loop_rounded,
                value: '$totalCycles',
                label: 'Cycles',
              ),
              _buildStatItem(
                icon: Icons.check_circle_rounded,
                value: '$fullyCompletedCycles',
                label: 'Perfect',
                color: AppColors.successGreen,
              ),
              _buildStatItem(
                icon: Icons.calendar_today_rounded,
                value: '$totalDaysCompleted',
                label: 'Days',
              ),
              _buildStatItem(
                icon: Icons.percent_rounded,
                value: '${(avgCompletionRate * 100).toInt()}%',
                label: 'Avg Rate',
                color: avgCompletionRate >= 0.8 ? AppColors.successGreen : AppColors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color ?? AppColors.orange, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleCard(CycleHistory cycle) {
    final isExpanded = _selectedCycle == cycle;
    final isFullyCompleted = cycle.isFullyCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.borderRadiusMedium,
        side: BorderSide(
          color: isFullyCompleted
              ? AppColors.successGreen.withValues(alpha: 0.5)
              : AppColors.greyText.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCycle = isExpanded ? null : cycle;
          });
        },
        borderRadius: AppStyles.borderRadiusMedium,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.normalCardBackground,
            borderRadius: AppStyles.borderRadiusMedium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFullyCompleted
                          ? AppColors.successGreen.withValues(alpha: 0.2)
                          : AppColors.orange.withValues(alpha: 0.2),
                      borderRadius: AppStyles.borderRadiusSmall,
                    ),
                    child: Text(
                      'Cycle ${cycle.cycleNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFullyCompleted ? AppColors.successGreen : AppColors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isFullyCompleted)
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.successGreen,
                      size: 20,
                    ),
                  const Spacer(),
                  Text(
                    '${cycle.completedDays}/${cycle.targetDays}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isFullyCompleted ? AppColors.successGreen : AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.greyText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date range and completion rate
              Row(
                children: [
                  Icon(Icons.date_range_rounded, size: 14, color: AppColors.greyText),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('MMM d').format(cycle.startDate)} - ${DateFormat('MMM d, yyyy').format(cycle.endDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(cycle.completionRate * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _getCompletionColor(cycle.completionRate),
                    ),
                  ),
                ],
              ),
              // Progress bar
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: cycle.completionRate,
                  backgroundColor: AppColors.greyText.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getCompletionColor(cycle.completionRate),
                  ),
                  minHeight: 6,
                ),
              ),
              // Expanded details
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                // Calendar view of completed days
                _buildCycleCalendar(cycle),
                const SizedBox(height: 12),
                // Completion timestamp
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: AppColors.greyText),
                    const SizedBox(width: 4),
                    Text(
                      'Completed on ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(cycle.completedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCycleCalendar(CycleHistory cycle) {
    // Generate all days in the cycle
    final days = List.generate(
      cycle.targetDays,
      (index) => cycle.startDate.add(Duration(days: index)),
    );

    // Group into weeks
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      final end = (i + 7 < days.length) ? i + 7 : days.length;
      weeks.add(days.sublist(i, end));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Days Completed',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // Days of week header
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.greyText,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        ...weeks.map((week) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              ...week.map((date) {
                final dateString = DateFormat('yyyy-MM-dd').format(date);
                final isCompleted = cycle.completedDates.contains(dateString);

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.successGreen.withValues(alpha: 0.8)
                          : AppColors.greyText.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted ? Colors.white : AppColors.greyText,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Pad remaining cells if week is incomplete
              ...List.generate(7 - week.length, (index) => const Expanded(child: SizedBox())),
            ],
          ),
        )),
      ],
    );
  }

  Color _getCompletionColor(double rate) {
    if (rate >= 1.0) return AppColors.successGreen;
    if (rate >= 0.8) return AppColors.lightGreen;
    if (rate >= 0.5) return AppColors.yellow;
    return AppColors.orange;
  }
}
