import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class MenstrualCycleCard extends StatefulWidget {
  final VoidCallback? onTap;

  const MenstrualCycleCard({
    Key? key,
    this.onTap,
  }) : super(key: key);

  @override
  State<MenstrualCycleCard> createState() => _MenstrualCycleCardState();
}

class _MenstrualCycleCardState extends State<MenstrualCycleCard>
    with SingleTickerProviderStateMixin {
  // State variables - matching CycleScreen structure
  DateTime? _lastPeriodStart;
  DateTime? _lastPeriodEnd;
  int _averageCycleLength = 31;
  List<Map<String, DateTime>> _periodRanges = [];
  bool _isExpanded = false; // New state for expansion

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCycleData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  // DATA LOADING - Compatible with CycleScreen
  Future<void> _loadCycleData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load last period dates
    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');

    if (lastStartStr != null) _lastPeriodStart = DateTime.parse(lastStartStr);
    if (lastEndStr != null) _lastPeriodEnd = DateTime.parse(lastEndStr);

    // Load average cycle length
    _averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;

    // Load period ranges (same format as CycleScreen)
    final rangesStr = prefs.getStringList('period_ranges') ?? [];
    _periodRanges = rangesStr.map((range) {
      final parts = range.split('|');
      return {
        'start': DateTime.parse(parts[0]),
        'end': DateTime.parse(parts[1]),
      };
    }).toList();

    if (mounted) setState(() {});
  }

  // HELPER METHODS - Matching CycleScreen logic
  bool _isCurrentlyOnPeriod() {
    return _lastPeriodStart != null && _lastPeriodEnd == null;
  }

  String _getCyclePhase() {
    if (_lastPeriodStart == null) return "No data available";

    final now = DateTime.now();
    final daysSinceStart = now.difference(_lastPeriodStart!).inDays;

    if (_isCurrentlyOnPeriod()) {
      return "Menstruation (Day ${daysSinceStart + 1})";
    }

    if (_lastPeriodEnd != null) {
      final daysSinceEnd = now.difference(_lastPeriodEnd!).inDays;
      final totalCycleDays = _lastPeriodEnd!.difference(_lastPeriodStart!).inDays + daysSinceEnd + 1;

      return _getPhaseFromCycleDays(totalCycleDays);
    } else {
      return _getPhaseFromCycleDays(daysSinceStart);
    }
  }

  String _getPhaseFromCycleDays(int cycleDays) {
    if (cycleDays <= 13) {
      return "Follicular Phase";
    } else if (cycleDays <= 16) {
      return "Ovulation";
    } else {
      final lutealDay = cycleDays - 16;
      final expectedLutealLength = _averageCycleLength - 16;

      if (lutealDay <= expectedLutealLength / 3) {
        return "Early Luteal Phase";
      } else if (lutealDay <= (expectedLutealLength * 2) / 3) {
        return "Middle Luteal Phase";
      } else {
        return "Late Luteal Phase";
      }
    }
  }

  String _getCycleInfo() {
    if (_lastPeriodStart == null) return "Track your first period to begin";

    final nextPeriodStart = _lastPeriodStart!.add(Duration(days: _averageCycleLength));
    final daysUntilPeriod = nextPeriodStart.difference(DateTime.now()).inDays;

    // Period expected today or overdue
    if (daysUntilPeriod <= 0) {
      if (daysUntilPeriod == 0) {
        return "Period expected today! 🩸";
      } else {
        final daysOverdue = -daysUntilPeriod;
        return "Period is $daysOverdue days overdue";
      }
    }

    // Pre-period warnings (1-6 days)
    if (daysUntilPeriod <= 6) {
      final messages = {
        1: "Period expected tomorrow! Take care of yourself 💝",
        2: "Period in 2 days. Rest and stay comfortable 🛋️",
        3: "Period in 3 days. Listen to your body 🤗",
        4: "Period in 4 days. Symptoms may begin 😌",
        5: "Period in 5 days. Take it easy 🌸",
        6: "Period in 6 days. Stay hydrated 💧",
      };
      return messages[daysUntilPeriod] ?? "$daysUntilPeriod days until period";
    }

    // Current period info
    if (_isCurrentlyOnPeriod()) {
      final currentDay = DateTime.now().difference(_lastPeriodStart!).inDays + 1;
      return "Day $currentDay of period";
    }

    // Cycle day info
    final daysSinceStart = DateTime.now().difference(_lastPeriodStart!).inDays + 1;

    if (daysSinceStart <= 11) {
      return "Back in the game";
    } else if (daysSinceStart <= 15) {
      final ovulationDay = 14;
      final daysToOvulation = ovulationDay - daysSinceStart;

      if (daysToOvulation == 0) {
        return "Ovulation day! 🥚";
      } else if (daysToOvulation == 1) {
        return "Ovulation tomorrow";
      } else if (daysToOvulation == -1) {
        return "Ovulation was yesterday";
      } else {
        return "Ovulation window";
      }
    } else {
      if (daysUntilPeriod <= 3) {
        return "$daysUntilPeriod days until next period";
      }
      return "Just keep swimming";
    }
  }

  Color _getPhaseColor() {
    final phase = _getCyclePhase();

    if (phase.startsWith("Menstruation")) return Colors.red.shade400;
    if (phase == "Follicular Phase") return Colors.green.shade400;
    if (phase == "Ovulation") return Colors.orange.shade400;
    if (phase.contains("Early Luteal")) return Colors.purple.shade300;
    if (phase.contains("Middle Luteal")) return Colors.purple.shade400;
    if (phase.contains("Late Luteal")) return Colors.purple.shade500;
    if (phase.contains("Luteal")) return Colors.purple.shade400;

    return Colors.grey.shade500;
  }

  IconData _getPhaseIcon() {
    final phase = _getCyclePhase();

    if (phase.startsWith("Menstruation")) return Icons.water_drop_rounded;
    if (phase == "Follicular Phase") return Icons.eco_rounded;
    if (phase == "Ovulation") return Icons.favorite_rounded;
    if (phase.contains("Luteal")) return Icons.nights_stay_rounded;

    return Icons.timeline_rounded;
  }

  String _getPhaseEmoji() {
    final phase = _getCyclePhase();

    if (phase.startsWith("Menstruation")) return "🩸";
    if (phase == "Follicular Phase") return "🌱";
    if (phase == "Ovulation") return "🥚";
    if (phase.contains("Early Luteal")) return "🌸";
    if (phase.contains("Middle Luteal")) return "🌺";
    if (phase.contains("Late Luteal")) return "🌙";
    if (phase.contains("Luteal")) return "🌸";

    return "📅";
  }

  Widget _buildAnimatedEmoji() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Text(
              _getPhaseEmoji(),
              style: const TextStyle(fontSize: 36),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getPhaseColor().withOpacity(0.15),
              _getPhaseColor().withOpacity(0.05),
              Colors.white,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Header - Always tappable for expansion
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getPhaseColor().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getPhaseIcon(),
                        color: _getPhaseColor(),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCyclePhase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCycleInfo(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAnimatedEmoji()
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getPhaseColor().withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _getPhaseColor().withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: _getPhaseColor(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
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
}