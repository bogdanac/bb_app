import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'dart:math' as math;
import 'food_tracking_service.dart';
import 'food_tracking_data_models.dart';
import 'food_tracking_history_screen.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FoodTrackingCard extends StatefulWidget {
  const FoodTrackingCard({super.key});

  @override
  State<FoodTrackingCard> createState() => _FoodTrackingCardState();
}

class _FoodTrackingCardState extends State<FoodTrackingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  
  bool _isExpanded = false;
  int _healthyCount = 0;
  int _processedCount = 0;
  String _resetInfo = '';
  int _currentPhaseCalories = 0;
  int _targetGoal = 80;
  int _daysUntilReset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _loadCurrentPeriodCounts();
    _loadCalories();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Future<void> _loadCurrentPeriodCounts() async {
    final counts = await FoodTrackingService.getCurrentPeriodCounts();
    final resetInfo = await FoodTrackingService.getResetInfo();
    final targetGoal = await FoodTrackingService.getTargetGoal();
    final daysUntilReset = await FoodTrackingService.getDaysUntilReset();
    setState(() {
      _healthyCount = counts['healthy']!;
      _processedCount = counts['processed']!;
      _resetInfo = resetInfo;
      _targetGoal = targetGoal;
      _daysUntilReset = daysUntilReset;
    });
  }

  Future<void> _loadCalories() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load menstrual cycle data
    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;
    
    DateTime? lastPeriodStart;
    DateTime? lastPeriodEnd;
    if (lastStartStr != null) lastPeriodStart = DateTime.parse(lastStartStr);
    if (lastEndStr != null) lastPeriodEnd = DateTime.parse(lastEndStr);
    
    // Load current phase calories
    final calories = await MenstrualCycleUtils.getCurrentPhaseCalories(
      lastPeriodStart, 
      lastPeriodEnd, 
      averageCycleLength
    );
    
    if (mounted) {
      setState(() {
        _currentPhaseCalories = calories;
      });
    }
  }

  void _addHealthy() async {
    HapticFeedback.lightImpact();
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: FoodType.healthy,
      timestamp: DateTime.now(),
    );
    await FoodTrackingService.addEntry(entry);
    await _loadCurrentPeriodCounts();
  }

  void _addProcessed() async {
    HapticFeedback.lightImpact();
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: FoodType.processed,
      timestamp: DateTime.now(),
    );
    await FoodTrackingService.addEntry(entry);
    await _loadCurrentPeriodCounts();
  }

  void _showHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FoodTrackingHistoryScreen(),
      ),
    ).then((_) => _loadCurrentPeriodCounts());
  }

  double _getHealthyPercentage() {
    final total = _healthyCount + _processedCount;
    if (total == 0) return 0.0; // Show 0% when no data for the week
    return _healthyCount / total;
  }

  Color _getProgressColor() {
    final healthyPercentage = _getHealthyPercentage() * 100;
    if (healthyPercentage >= _targetGoal) return AppColors.lightGreen;
    if (healthyPercentage >= _targetGoal - 20) return AppColors.pastelGreen;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final healthyPercentage = _getHealthyPercentage() * 100;
    final total = _healthyCount + _processedCount;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusLarge,
          color: AppColors.homeCardBackground, // Home card background
        ),
        child: Column(
          children: [
            // Header row - always visible
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: AppStyles.borderRadiusLarge,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant,
                      color: AppColors.pastelGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            total == 0 
                              ? 'Food Tracking'
                              : '${healthyPercentage.round()}% healthy',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (_currentPhaseCalories > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pastelGreen.withValues(alpha: 0.25), // Golden yellow
                          borderRadius: AppStyles.borderRadiusMedium,
                          border: Border.all(
                            color: AppColors.pastelGreen.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$_currentPhaseCalories kcal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.pastelGreen,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _showHistory,
                      icon: const Icon(Icons.calendar_month_rounded),
                      tooltip: 'View History',
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(Icons.expand_more),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            // Expandable content
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    heightFactor: _expandAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: [
                    const Divider(color: AppColors.white24),
                    const SizedBox(height: 2),
                    // Action buttons with pie chart
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addHealthy,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Healthy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.pastelGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addProcessed,
                            icon: const Icon(Icons.remove, size: 16),
                            label: const Text('Processed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Pie chart on the right
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CustomPaint(
                            painter: FoodPieChartPainter(
                              healthyPercentage: _getHealthyPercentage(),
                              color: _getProgressColor(),
                              showText: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_daysUntilReset <= 3) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Target: $_targetGoal% healthy • $_resetInfo',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class FoodPieChartPainter extends CustomPainter {
  final double healthyPercentage;
  final Color color;
  final bool showText;

  FoodPieChartPainter({
    required this.healthyPercentage,
    required this.color,
    this.showText = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = AppColors.pastelGreen.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Healthy portion
    final healthyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final sweepAngle = 2 * math.pi * healthyPercentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      true,
      healthyPaint,
    );
    
    // Show percentage text in large chart
    if (showText) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(healthyPercentage * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}