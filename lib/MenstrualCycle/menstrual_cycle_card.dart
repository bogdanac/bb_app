import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    )
      ..repeat();

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

    if (mounted) setState(() {});
  }

  // HELPER METHODS - Matching CycleScreen logic
  bool _isCurrentlyOnPeriod() {
    return _lastPeriodStart != null && _lastPeriodEnd == null;
  }

  String _getCyclePhase() {
    if (_lastPeriodStart == null) return "No data available";

    final now = DateTime.now();
    final daysSinceStart = now
        .difference(_lastPeriodStart!)
        .inDays;

    if (_isCurrentlyOnPeriod()) {
      return "Menstruation (Day ${daysSinceStart + 1})";
    }

    if (_lastPeriodEnd != null) {
      final daysSinceEnd = now
          .difference(_lastPeriodEnd!)
          .inDays;
      final totalCycleDays = _lastPeriodEnd!.difference(_lastPeriodStart!)
          .inDays + daysSinceEnd + 1;

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

    final nextPeriodStart = _lastPeriodStart!.add(
        Duration(days: _averageCycleLength));
    final daysUntilPeriod = nextPeriodStart
        .difference(DateTime.now())
        .inDays;

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
      final currentDay = DateTime
          .now()
          .difference(_lastPeriodStart!)
          .inDays + 1;
      return "Day $currentDay of period";
    }

    // Cycle day info
    final daysSinceStart = DateTime
        .now()
        .difference(_lastPeriodStart!)
        .inDays + 1;

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

    if (phase.startsWith("Menstruation")) return AppColors.error; // Red for menstruation (important)
    if (phase == "Follicular Phase") return AppColors.successGreen; // Green leaf color for growth phase
    if (phase == "Ovulation") return AppColors.orange;
    if (phase.contains("Early Luteal")) return AppColors.purple;
    if (phase.contains("Middle Luteal")) return AppColors.purple;
    if (phase.contains("Late Luteal")) return AppColors.purple;
    if (phase.contains("Luteal")) return AppColors.purple;

    return AppColors.coral;
  }
  
  Color _getPastelPhaseColor() {
    final phase = _getCyclePhase();

    if (phase.startsWith("Menstruation")) return AppColors.pastelRed; // Pastel red for menstruation
    if (phase == "Follicular Phase") return AppColors.successGreen.withOpacity(0.3); // Pastel green for growth phase
    if (phase == "Ovulation") return AppColors.pastelOrange; // Pastel orange
    if (phase.contains("Early Luteal")) return AppColors.lightPurple; // Light purple
    if (phase.contains("Middle Luteal")) return AppColors.pastelPurple; // Pastel purple
    if (phase.contains("Late Luteal")) return AppColors.pastelPurple; // Pastel purple
    if (phase.contains("Luteal")) return AppColors.pastelPurple; // Pastel purple

    return AppColors.pastelCoral; // Default pastel coral
  }

  IconData _getPhaseIcon() {
    final phase = _getCyclePhase();

    if (phase.startsWith("Menstruation")) return Icons.water_drop_rounded;
    if (phase == "Follicular Phase") return Icons.energy_savings_leaf; // Energy/growth icon - perfect for follicular phase renewal
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

  // Removed animated emoji method

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _getPhaseColor().withOpacity(0.08),
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Row(
            children: [
              Icon(
                _getPhaseIcon(),
                color: _getPhaseColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCyclePhase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _getCycleInfo(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}