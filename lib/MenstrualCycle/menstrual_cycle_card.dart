import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menstrual_cycle_utils.dart';

class MenstrualCycleCard extends StatefulWidget {
  final VoidCallback? onTap;

  const MenstrualCycleCard({
    super.key,
    this.onTap,
  });

  @override
  State<MenstrualCycleCard> createState() => _MenstrualCycleCardState();
}

class _MenstrualCycleCardState extends State<MenstrualCycleCard>
    with SingleTickerProviderStateMixin {
  // State variables - matching CycleScreen structure
  DateTime? _lastPeriodStart;
  DateTime? _lastPeriodEnd;
  int _averageCycleLength = 31;

  late AnimationController _animationController;

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

  // HELPER METHODS - Using shared utility
  String _getCyclePhase() {
    return MenstrualCycleUtils.getCyclePhase(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength);
  }

  String _getCycleInfo() {
    return MenstrualCycleUtils.getCycleInfo(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength);
  }

  Color _getPhaseColor() {
    return MenstrualCycleUtils.getPhaseColor(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength);
  }

  IconData _getPhaseIcon() {
    return MenstrualCycleUtils.getPhaseIcon(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _getPhaseColor().withValues(alpha: 0.15),
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
                        fontSize: 14,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
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