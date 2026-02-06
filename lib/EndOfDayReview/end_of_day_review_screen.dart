import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'end_of_day_review_data.dart';
import 'end_of_day_review_service.dart';
import '../Settings/app_customization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class EndOfDayReviewScreen extends StatefulWidget {
  const EndOfDayReviewScreen({super.key});

  @override
  State<EndOfDayReviewScreen> createState() => _EndOfDayReviewScreenState();
}

class _EndOfDayReviewScreenState extends State<EndOfDayReviewScreen> {
  EndOfDayReviewData? _reviewData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    setState(() => _isLoading = true);
    final reviewService = EndOfDayReviewService();
    final data = await reviewService.getTodayReview();
    if (mounted) {
      setState(() {
        _reviewData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Summary'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReview,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_reviewData == null || _reviewData!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.summarize_rounded, size: 64, color: AppColors.grey300),
            const SizedBox(height: 16),
            Text(
              'No activity recorded today',
              style: TextStyle(color: AppColors.greyText, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete some tasks, habits, or track your activities\nto see your daily summary here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey300, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          ..._reviewData!.moduleSummaries.map(_buildModuleCard),
          const SizedBox(height: 24),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: AppColors.yellow, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMMEEEEd().format(now),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        color: AppColors.greyText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! Here\'s your day so far.';
    if (hour < 17) return 'Good afternoon! Here\'s your progress today.';
    return 'Good evening! Here\'s how your day went.';
  }

  Widget _buildModuleCard(ModuleSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
      child: _buildModuleContent(summary),
    );
  }

  Widget _buildModuleContent(ModuleSummary summary) {
    switch (summary.moduleKey) {
      case AppCustomizationService.moduleWater:
        return _buildWaterContent(summary);
      case AppCustomizationService.moduleFood:
        return _buildFoodContent(summary);
      case AppCustomizationService.moduleTasks:
        return _buildTasksContent(summary);
      case AppCustomizationService.moduleHabits:
        return _buildHabitsContent(summary);
      case AppCustomizationService.moduleEnergy:
        return _buildEnergyContent(summary);
      case AppCustomizationService.moduleTimers:
        return _buildTimersContent(summary);
      case AppCustomizationService.moduleFasting:
        return _buildFastingContent(summary);
      case AppCustomizationService.moduleMenstrual:
        return _buildMenstrualContent(summary);
      case AppCustomizationService.moduleRoutines:
        return _buildRoutinesContent(summary);
      default:
        return _buildGenericContent(summary);
    }
  }

  Widget _buildModuleHeader(ModuleSummary summary, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(summary.icon, color: summary.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary.moduleName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildWaterContent(ModuleSummary summary) {
    final helper = WaterSummaryHelper(summary);
    final goalMet = helper.goalMet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          summary,
          trailing: goalMet
              ? Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    helper.formattedIntake,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: goalMet ? AppColors.successGreen : AppColors.waterBlue,
                    ),
                  ),
                  Text(
                    ' / ${helper.goal}ml',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (helper.percentage / 100).clamp(0.0, 1.0),
                backgroundColor: AppColors.grey700,
                valueColor: AlwaysStoppedAnimation(goalMet ? AppColors.successGreen : AppColors.waterBlue),
              ),
              const SizedBox(height: 4),
              Text(
                goalMet ? 'Goal reached!' : '${helper.percentage}% of daily goal',
                style: TextStyle(color: AppColors.greyText, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodContent(ModuleSummary summary) {
    final helper = FoodSummaryHelper(summary);

    if (!helper.hasActivity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModuleHeader(summary),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'No food tracked today',
              style: TextStyle(color: AppColors.greyText, fontSize: 14),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          summary,
          trailing: helper.goalMet
              ? Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  '${helper.healthyCount}',
                  'Healthy',
                  AppColors.pastelGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  '${helper.processedCount}',
                  'Processed',
                  AppColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  '${helper.healthyPercentage}%',
                  'Healthy ratio',
                  helper.goalMet ? AppColors.successGreen : AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksContent(ModuleSummary summary) {
    final helper = TasksSummaryHelper(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(summary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${helper.completedCount}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: helper.hasActivity ? AppColors.successGreen : AppColors.greyText,
                    ),
                  ),
                  Text(
                    ' tasks completed',
                    style: TextStyle(fontSize: 16, color: AppColors.greyText),
                  ),
                ],
              ),
              if (helper.pendingCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${helper.pendingCount} still pending',
                  style: TextStyle(color: AppColors.orange, fontSize: 13),
                ),
              ],
              if (helper.completedTitles.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...helper.completedTitles.map((title) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_rounded, color: AppColors.successGreen, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(color: AppColors.grey100, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHabitsContent(ModuleSummary summary) {
    final helper = HabitsSummaryHelper(summary);

    if (helper.totalCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModuleHeader(summary),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'No active habits',
              style: TextStyle(color: AppColors.greyText, fontSize: 14),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          summary,
          trailing: helper.allCompleted
              ? Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${helper.completedCount}/${helper.totalCount}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: helper.allCompleted ? AppColors.successGreen : AppColors.pastelGreen,
                    ),
                  ),
                  Text(
                    ' habits',
                    style: TextStyle(fontSize: 16, color: AppColors.greyText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: helper.percentage / 100,
                backgroundColor: AppColors.grey700,
                valueColor: AlwaysStoppedAnimation(helper.allCompleted ? AppColors.successGreen : AppColors.pastelGreen),
              ),
              const SizedBox(height: 4),
              Text(
                helper.allCompleted ? 'All habits completed!' : '${helper.percentage}% completed',
                style: TextStyle(color: AppColors.greyText, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnergyContent(ModuleSummary summary) {
    final helper = EnergySummaryHelper(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          summary,
          trailing: helper.isGoalMet
              ? Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  '${helper.flowPoints}',
                  'Flow points',
                  helper.isGoalMet ? AppColors.successGreen : AppColors.coral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  '${helper.currentBattery}%',
                  'Battery',
                  _getBatteryColor(helper.currentBattery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  helper.isGoalMet ? 'Yes!' : 'Not yet',
                  'Goal met',
                  helper.isGoalMet ? AppColors.successGreen : AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getBatteryColor(int battery) {
    if (battery >= 70) return AppColors.successGreen;
    if (battery >= 40) return AppColors.yellow;
    return AppColors.orange;
  }

  Widget _buildTimersContent(ModuleSummary summary) {
    final helper = TimersSummaryHelper(summary);

    if (!helper.hasActivity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModuleHeader(summary),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'No activities tracked today',
              style: TextStyle(color: AppColors.greyText, fontSize: 14),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(summary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    helper.formattedTime,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
                    ),
                  ),
                  Text(
                    ' total',
                    style: TextStyle(fontSize: 16, color: AppColors.greyText),
                  ),
                ],
              ),
              if (helper.activityBreakdown.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...helper.activityBreakdown.entries.take(4).map((entry) {
                  final hours = entry.value ~/ 60;
                  final minutes = entry.value % 60;
                  final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: AppColors.purple, size: 8),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(color: AppColors.grey100, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(color: AppColors.greyText, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFastingContent(ModuleSummary summary) {
    final helper = FastingSummaryHelper(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          summary,
          trailing: helper.completedFastToday
              ? Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            helper.fastingStatus,
            style: TextStyle(
              fontSize: 15,
              color: helper.hasActivity ? AppColors.yellow : AppColors.greyText,
              fontWeight: helper.hasActivity ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenstrualContent(ModuleSummary summary) {
    final helper = MenstrualSummaryHelper(summary);

    if (!helper.hasData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModuleHeader(summary),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'No cycle data available',
              style: TextStyle(color: AppColors.greyText, fontSize: 14),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(summary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  'Day ${helper.cycleDay}',
                  'Cycle day',
                  AppColors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildStatBox(
                  helper.currentPhase,
                  'Current phase',
                  AppColors.lightCoral,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutinesContent(ModuleSummary summary) {
    final helper = RoutinesSummaryHelper(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(summary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${helper.completedCount}/${helper.totalCount}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: helper.hasActivity ? AppColors.orange : AppColors.greyText,
                    ),
                  ),
                  Text(
                    ' routines',
                    style: TextStyle(fontSize: 16, color: AppColors.greyText),
                  ),
                ],
              ),
              if (helper.completedNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...helper.completedNames.map((name) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_rounded, color: AppColors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(color: AppColors.grey100, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenericContent(ModuleSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(summary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            summary.data.toString(),
            style: TextStyle(color: AppColors.greyText, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.grey700.withValues(alpha: 0.5),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppColors.greyText, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_reviewData == null) return const SizedBox.shrink();
    return Center(
      child: Text(
        'Last updated: ${DateFormat.Hm().format(_reviewData!.generatedAt)}',
        style: TextStyle(color: AppColors.grey300, fontSize: 12),
      ),
    );
  }
}
