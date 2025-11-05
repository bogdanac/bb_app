import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'food_tracking_service.dart';

class FoodTrackingGoalHistoryScreen extends StatefulWidget {
  const FoodTrackingGoalHistoryScreen({super.key});

  @override
  State<FoodTrackingGoalHistoryScreen> createState() => _FoodTrackingGoalHistoryScreenState();
}

class _FoodTrackingGoalHistoryScreenState extends State<FoodTrackingGoalHistoryScreen> {
  List<Map<String, dynamic>> _periodHistory = [];
  int _targetGoal = 80;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final periodHistory = await FoodTrackingService.getPeriodHistory();
    final targetGoal = await FoodTrackingService.getTargetGoal();
    setState(() {
      _periodHistory = periodHistory;
      _targetGoal = targetGoal;
      _isLoading = false;
    });
  }

  Map<String, List<Map<String, dynamic>>> _categorizeHistory() {
    final reached = <Map<String, dynamic>>[];
    final notReached = <Map<String, dynamic>>[];

    for (final period in _periodHistory) {
      final percentage = period['percentage'] as int;
      if (percentage >= _targetGoal) {
        reached.add(period);
      } else {
        notReached.add(period);
      }
    }

    return {'reached': reached, 'notReached': notReached};
  }

  Widget _buildPeriodTile(Map<String, dynamic> period, bool goalReached) {
    final percentage = period['percentage'] as int;
    final healthy = period['healthy'] as int;
    final processed = period['processed'] as int;
    final periodLabel = period['periodLabel'] as String;
    final frequency = period['frequency'] as String;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (goalReached) {
      statusColor = AppColors.successGreen;
      statusIcon = Icons.check_circle;
      statusLabel = 'Goal Reached';
    } else {
      statusColor = AppColors.orange;
      statusIcon = Icons.flag_outlined;
      statusLabel = 'Goal Not Reached';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.borderRadiusMedium,
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor.withValues(alpha: 0.2),
            border: Border.all(
              color: statusColor,
              width: 3,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$percentage%',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        title: Text(
          periodLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${frequency == "monthly" ? "Monthly" : "Weekly"} tracking period',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  size: 14,
                  color: AppColors.successGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  '$healthy healthy',
                  style: const TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.fastfood,
                  size: 14,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  '$processed processed',
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: AppStyles.borderRadiusSmall,
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categorized = _categorizeHistory();
    final reachedPeriods = categorized['reached']!;
    final notReachedPeriods = categorized['notReached']!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal History'),
        backgroundColor: AppColors.successGreen.withValues(alpha: 0.2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _periodHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: AppColors.white54,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No period history yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete your first tracking period to see history',
                        style: TextStyle(color: AppColors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    // Summary Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.successGreen.withValues(alpha: 0.3),
                            AppColors.lightGreen.withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppStyles.borderRadiusLarge,
                        border: Border.all(
                          color: AppColors.successGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.successGreen,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${reachedPeriods.length}/${_periodHistory.length} Periods',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Reached your $_targetGoal% goal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Goal Reached Section
                    if (reachedPeriods.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.successGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Goal Reached (${reachedPeriods.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...reachedPeriods.map((period) => _buildPeriodTile(period, true)),
                    ],

                    // Goal Not Reached Section
                    if (notReachedPeriods.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              color: AppColors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Goal Not Reached (${notReachedPeriods.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...notReachedPeriods.map((period) => _buildPeriodTile(period, false)),
                    ],
                  ],
                ),
    );
  }
}
