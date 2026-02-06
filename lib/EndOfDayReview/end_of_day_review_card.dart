import 'package:flutter/material.dart';
import 'end_of_day_review_data.dart';
import 'end_of_day_review_service.dart';
import 'end_of_day_review_screen.dart';
import '../Settings/app_customization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class EndOfDayReviewCard extends StatefulWidget {
  const EndOfDayReviewCard({super.key});

  @override
  State<EndOfDayReviewCard> createState() => _EndOfDayReviewCardState();
}

class _EndOfDayReviewCardState extends State<EndOfDayReviewCard> {
  EndOfDayReviewData? _reviewData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuickSummary();
  }

  Future<void> _loadQuickSummary() async {
    final reviewService = EndOfDayReviewService();
    final data = await reviewService.getTodayReview();
    if (mounted) {
      setState(() {
        _reviewData = data;
        _isLoading = false;
      });
    }
  }

  void _openFullReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EndOfDayReviewScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullReview,
      child: Container(
        decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.summarize_rounded, color: AppColors.purple, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Today\'s Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.grey300, size: 20),
                ],
              ),
            ),
            // Quick summary content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _isLoading
                  ? const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _buildQuickSummary(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSummary() {
    if (_reviewData == null || _reviewData!.isEmpty) {
      return Text(
        'No activity yet today. Tap to view details.',
        style: TextStyle(color: AppColors.greyText, fontSize: 13),
      );
    }

    // Get key metrics to display
    final metrics = _getKeyMetrics();

    if (metrics.isEmpty) {
      return Text(
        'Tap to see your daily summary.',
        style: TextStyle(color: AppColors.greyText, fontSize: 13),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: metrics.take(4).map((metric) => _buildMiniStat(metric)).toList(),
    );
  }

  List<_QuickMetric> _getKeyMetrics() {
    final metrics = <_QuickMetric>[];

    for (final summary in _reviewData!.moduleSummaries) {
      switch (summary.moduleKey) {
        case AppCustomizationService.moduleTasks:
          final helper = TasksSummaryHelper(summary);
          if (helper.completedCount > 0 || helper.pendingCount > 0) {
            metrics.add(_QuickMetric(
              value: '${helper.completedCount}',
              label: 'Tasks',
              icon: summary.icon,
              color: helper.completedCount > 0 ? AppColors.successGreen : AppColors.greyText,
            ));
          }
          break;

        case AppCustomizationService.moduleHabits:
          final helper = HabitsSummaryHelper(summary);
          if (helper.totalCount > 0) {
            metrics.add(_QuickMetric(
              value: '${helper.percentage}%',
              label: 'Habits',
              icon: summary.icon,
              color: helper.allCompleted ? AppColors.successGreen : AppColors.pastelGreen,
            ));
          }
          break;

        case AppCustomizationService.moduleEnergy:
          final helper = EnergySummaryHelper(summary);
          if (helper.flowPoints > 0 || helper.flowGoal > 0) {
            metrics.add(_QuickMetric(
              value: '${helper.flowPoints}',
              label: 'Flow',
              icon: summary.icon,
              color: helper.isGoalMet ? AppColors.successGreen : AppColors.coral,
            ));
          }
          break;

        case AppCustomizationService.moduleTimers:
          final helper = TimersSummaryHelper(summary);
          if (helper.hasActivity) {
            metrics.add(_QuickMetric(
              value: helper.formattedTime,
              label: 'Time',
              icon: summary.icon,
              color: AppColors.purple,
            ));
          }
          break;

        case AppCustomizationService.moduleWater:
          final helper = WaterSummaryHelper(summary);
          metrics.add(_QuickMetric(
            value: '${helper.percentage}%',
            label: 'Water',
            icon: summary.icon,
            color: helper.goalMet ? AppColors.successGreen : AppColors.waterBlue,
          ));
          break;

        case AppCustomizationService.moduleFood:
          final helper = FoodSummaryHelper(summary);
          if (helper.hasActivity) {
            metrics.add(_QuickMetric(
              value: '${helper.healthyPercentage}%',
              label: 'Food',
              icon: summary.icon,
              color: helper.goalMet ? AppColors.successGreen : AppColors.pastelGreen,
            ));
          }
          break;
      }
    }

    return metrics;
  }

  Widget _buildMiniStat(_QuickMetric metric) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(metric.icon, color: metric.color, size: 18),
        const SizedBox(height: 4),
        Text(
          metric.value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: metric.color,
          ),
        ),
        Text(
          metric.label,
          style: TextStyle(
            color: AppColors.greyText,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _QuickMetric {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  _QuickMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}
