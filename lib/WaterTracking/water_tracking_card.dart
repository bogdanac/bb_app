import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/services.dart';

// WATER TRACKING CARD
class WaterTrackingCard extends StatefulWidget {
  final int waterIntake;
  final VoidCallback onWaterAdded;

  const WaterTrackingCard({
    super.key,
    required this.waterIntake,
    required this.onWaterAdded,
  });

  @override
  State<WaterTrackingCard> createState() => _WaterTrackingCardState();
}

class _WaterTrackingCardState extends State<WaterTrackingCard>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _buttonController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Progress bar animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Button scale animation controller
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));

    // Initialize progress animation with initial value
    const int goal = 1500;
    final double initialProgress = (widget.waterIntake / goal).clamp(0.0, 1.0);
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: initialProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    // Start the initial animation
    _progressController.forward();
  }

  @override
  void didUpdateWidget(WaterTrackingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waterIntake != widget.waterIntake) {
      _updateProgressAnimation();
    }
  }

  void _updateProgressAnimation() {
    const int goal = 1500;
    final double currentProgress = _progressAnimation.value;
    final double newProgress = (widget.waterIntake / goal).clamp(0.0, 1.0);

    _progressAnimation = Tween<double>(
      begin: currentProgress,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    _progressController.reset();
    _progressController.forward();
  }

  void _handleWaterAdded() async {
    // Strong haptic feedback
    await HapticFeedback.heavyImpact();

    // Button animation
    await _buttonController.forward();
    _buttonController.reverse();

    // Call the parent callback
    widget.onWaterAdded();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const int goal = 1500;

    // Hide card if water intake reaches or exceeds the goal
    if (widget.waterIntake >= goal) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.waterBlue.withValues(alpha: 0.2), // Water blue theme
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.water_drop_rounded,
                  color: AppColors.waterBlue, // Special water blue
                  size: 28,
                ),
                const SizedBox(width: 16),
                // Înlocuiește partea cu progress bar din WaterTrackingCard

                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress bar container - păstrează întotdeauna width-ul complet
                      Container(
                        height: 32,
                        width: double.infinity, // Forțează width complet
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                        child: AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _progressAnimation.value,
                                child: Container(
                                  height: 32, // Menține înălțimea
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16), // Ajustat pentru înălțimea de 32
                                    gradient: LinearGradient(
                                      colors: _progressAnimation.value > 0.9
                                          ? [AppColors.successGreen, AppColors.lightGreen] // Keep green for success
                                          : [AppColors.waterBlue, AppColors.waterBlue.withValues(alpha: 0.7)], // Water blue for progress
                                    ),
                                    boxShadow: _progressAnimation.value > 0.0
                                        ? [
                                      BoxShadow(
                                        color: AppColors.waterBlue.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Progress text overlay
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          const int goal = 1500;
                          final int remaining = (goal - widget.waterIntake).clamp(0, goal);

                          return Text(
                            remaining > 0
                                ? '${remaining}ml left'
                                : '🎉 Goal reached!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _progressAnimation.value > 0.5
                                  ? AppColors.white
                                  : AppColors.white54,
                              shadows: _progressAnimation.value > 0.5
                                  ? [
                                Shadow(
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                  color: AppColors.black.withValues(alpha: 0.3),
                                ),
                              ]
                                  : null,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: ElevatedButton(
                    onPressed: _handleWaterAdded,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.waterBlue,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(48, 24), // Larger button
                      padding: const EdgeInsets.all(4), // More padding
                    ),
                    child: const Text(
                      '+',
                      style: TextStyle(
                        fontSize: 24, // Larger plus sign
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}