import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'flow_calculator.dart';

/// Celebration Dialogs for Body Battery & Flow achievements
class EnergyCelebrations {
  /// Show celebration when flow goal is met
  static Future<void> showGoalMetCelebration(
    BuildContext context,
    int flowPoints,
    int flowGoal,
  ) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.successGreen,
                      AppColors.successGreen.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Goal Achieved!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'You reached $flowPoints flow points today!',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.greyText,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show celebration for new personal record
  static Future<void> showPersonalRecordCelebration(
    BuildContext context,
    int newRecord,
    int oldRecord,
  ) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star burst animation concept
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.purple,
                          AppColors.purple.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.purple,
                    ),
                    child: const Icon(
                      Icons.military_tech_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'New Personal Record!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.greyText,
                  ),
                  children: [
                    const TextSpan(text: 'You smashed your previous record of '),
                    TextSpan(
                      text: '$oldRecord',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const TextSpan(text: ' with '),
                    TextSpan(
                      text: '$newRecord flow points',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.purple,
                      ),
                    ),
                    const TextSpan(text: '!'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                  child: const Text(
                    'Amazing!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show celebration for streak milestones
  static Future<void> showStreakMilestoneCelebration(
    BuildContext context,
    int streak,
  ) async {
    if (!context.mounted) return;

    final milestone = FlowCalculator.getStreakMilestone(streak);
    if (milestone == null) return;

    String title;
    String message;
    if (streak >= 100) {
      title = 'Legendary Streak!';
      message = '100 days of consistent excellence!';
    } else if (streak >= 50) {
      title = 'Incredible Streak!';
      message = '50 days of crushing your goals!';
    } else if (streak >= 30) {
      title = 'Amazing Streak!';
      message = '30 days of unstoppable progress!';
    } else if (streak >= 14) {
      title = 'Two Week Streak!';
      message = 'You\'re building an incredible habit!';
    } else if (streak >= 7) {
      title = 'One Week Streak!';
      message = 'Keep up the great work!';
    } else {
      title = 'Streak Started!';
      message = 'You\'re on a roll!';
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fire icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.orange,
                      AppColors.coral,
                    ],
                  ),
                ),
                child: const Text(
                  '🔥',
                  style: TextStyle(fontSize: 64),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.greyText,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$streak Days',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orange,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                  child: const Text(
                    'Keep Going!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show warning for low battery
  static Future<void> showLowBatteryWarning(
    BuildContext context,
    int battery,
  ) async {
    if (!context.mounted) return;
    if (!FlowCalculator.isBatteryCritical(battery)) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.coral.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.battery_alert_rounded,
                  size: 64,
                  color: AppColors.coral,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Low Battery Warning',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                FlowCalculator.getBatterySuggestion(battery),
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.greyText,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '$battery%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coral,
                      ),
                    ),
                    Text(
                      'Current Battery',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                  child: const Text(
                    'Take a Break',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
