import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// WATER TRACKING CARD
class WaterTrackingCard extends StatefulWidget {
  final int waterIntake;
  final VoidCallback onWaterAdded;

  const WaterTrackingCard({
    Key? key,
    required this.waterIntake,
    required this.onWaterAdded,
  }) : super(key: key);

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
    const int goal = 1800;
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
    const int goal = 1800;
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
    const int goal = 1750;
    const int hideThreshold = 1750;

    // Hide card if water intake is over 1700ml
    if (widget.waterIntake > hideThreshold) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.3),
              Colors.blue.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Water Tracking',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${widget.waterIntake}ml',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: ElevatedButton(
                    onPressed: _handleWaterAdded,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
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
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.red.withOpacity(0.3),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: _progressAnimation.value > 0.9
                                    ? [Colors.green, Colors.lightGreen]
                                    : [Colors.blue, Colors.lightBlue],
                              ),
                              boxShadow: _progressAnimation.value > 0.0
                                  ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}