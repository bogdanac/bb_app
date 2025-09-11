// fasting_card.dart - Actualizat cu sincronizare
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'fasting_notifier.dart';
import '../Notifications/notification_service.dart';
import 'fasting_utils.dart';
import 'fasting_phases.dart';

class FastingCard extends StatefulWidget {
  final VoidCallback? onHiddenForToday;
  
  const FastingCard({super.key, this.onHiddenForToday});

  @override
  State<FastingCard> createState() => _FastingCardState();
}

class _FastingCardState extends State<FastingCard> {
  bool isFasting = false;
  DateTime? fastingStartTime;
  DateTime? fastingEndTime;
  Duration fastingDuration = Duration.zero;
  Timer? _timer;
  String currentFastType = '';
  String recommendedFast = '';
  final FastingNotifier _notifier = FastingNotifier();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadFastingState();
    _notifier.addListener(_onFastingStateChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notifier.removeListener(_onFastingStateChanged);
    super.dispose();
  }

  void _onFastingStateChanged() {
    _loadFastingState();
  }

  Future<void> _loadRecommendedFast() async {
    final recommended = await FastingUtils.getRecommendedFastType();
    debugPrint('[FastingCard] Recommended fast loaded: "$recommended"');
    if (mounted) {
      setState(() {
        recommendedFast = recommended;
      });
      debugPrint('[FastingCard] State updated with recommendedFast: "$recommendedFast"');
    }
  }

  // Load fasting state from SharedPreferences (sincronizat cu FastingScreen)
  Future<void> _loadFastingState() async {
    final prefs = await SharedPreferences.getInstance();

    // Folosim aceleași chei ca în FastingScreen pentru sincronizare perfectă
    final isFastingStored = prefs.getBool('is_fasting') ?? false;
    final startTimeString = prefs.getString('current_fast_start');
    final endTimeString = prefs.getString('current_fast_end');
    final fastType = prefs.getString('current_fast_type') ?? '';

    if (startTimeString != null) {
      final startTime = DateTime.parse(startTimeString);
      final endTime = endTimeString != null ? DateTime.parse(endTimeString) : null;
      final now = DateTime.now();

      // Check if we have a valid ongoing fast
      if (isFastingStored && endTime != null && now.isBefore(endTime) && now.isAfter(startTime)) {
        setState(() {
          isFasting = true;
          fastingStartTime = startTime;
          fastingEndTime = endTime;
          currentFastType = fastType;
          fastingDuration = now.difference(startTime);
        });
        _startTimer();
      } else if (!isFastingStored || (endTime != null && now.isAfter(endTime))) {
        // Only clear if explicitly not fasting OR fast has definitely ended
        setState(() {
          isFasting = false;
          fastingStartTime = null;
          fastingEndTime = null;
          currentFastType = '';
          fastingDuration = Duration.zero;
        });
        _timer?.cancel();
      }
    } else {
      // Only clear if no start time and explicitly not fasting
      if (!isFastingStored) {
        setState(() {
          isFasting = false;
          fastingStartTime = null;
          fastingEndTime = null;
          currentFastType = '';
          fastingDuration = Duration.zero;
        });
        _timer?.cancel();
      }
    }

    // Load recommended fast
    await _loadRecommendedFast();
  }

  // Save fasting state (sincronizat cu FastingScreen)
  Future<void> _saveFastingState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('is_fasting', isFasting);

    if (isFasting && fastingStartTime != null && fastingEndTime != null) {
      await prefs.setString('current_fast_start', fastingStartTime!.toIso8601String());
      await prefs.setString('current_fast_end', fastingEndTime!.toIso8601String());
      await prefs.setString('current_fast_type', currentFastType);
    } else {
      await prefs.remove('current_fast_start');
      await prefs.remove('current_fast_end');
      await prefs.remove('current_fast_type');
    }

    // Notifică toate componentele că starea s-a schimbat
    _notifier.notifyFastingStateChanged();
  }


  // Start fasting timer
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (fastingStartTime != null && fastingEndTime != null) {
        final now = DateTime.now();
        final newDuration = now.difference(fastingStartTime!);

        setState(() {
          fastingDuration = newDuration;
        });

        // Don't update notifications from the card - let fasting screen handle it
      }
    });
  }

  void _updateFastingNotification() {
    if (isFasting && fastingStartTime != null && fastingEndTime != null) {
      final totalDuration = fastingEndTime!.difference(fastingStartTime!);
      final phaseInfo = _getFastingPhaseInfo();
      _notificationService.showFastingProgressNotification(
        fastType: currentFastType,
        elapsedTime: fastingDuration,
        totalDuration: totalDuration,
        currentPhase: phaseInfo['phase'],
      );
    }
  }

  // Start fasting (compatible cu FastingScreen)
  void _startFast() {
    HapticFeedback.mediumImpact();

    if (recommendedFast.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fast scheduled for today'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final duration = FastingUtils.getFastDuration(recommendedFast);

    setState(() {
      isFasting = true;
      fastingStartTime = now;
      fastingEndTime = now.add(duration);
      currentFastType = recommendedFast;
      fastingDuration = Duration.zero;
    });

    _saveFastingState();
    _startTimer();

    // Show initial notification
    _updateFastingNotification();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 $recommendedFast started!'),
        backgroundColor: AppColors.lightGreen, // Green for success
      ),
    );
  }



  // Calculate progress percentage
  double _getProgress() {
    if (!isFasting || fastingStartTime == null || fastingEndTime == null) return 0.0;

    final totalDuration = fastingEndTime!.difference(fastingStartTime!);
    return FastingUtils.getProgress(fastingDuration, totalDuration);
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
          color: isFasting 
              ? AppColors.lightGreen.withValues(alpha: 0.15) // Green theme when fasting
              : AppColors.pastelGreen.withValues(alpha: 0.15), // Green theme when not fasting
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFasting) ...[
              // Progress section when fasting
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: AppColors.lightGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${FastingUtils.formatDuration(fastingDuration)} / $currentFastType',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (fastingEndTime != null)
                          Text(
                            'Ends at ${fastingEndTime!.hour.toString().padLeft(2, '0')}:${fastingEndTime!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.white54,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _getProgress(),
                  backgroundColor: AppColors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(_getCurrentPhaseColor()),
                  minHeight: 12,
                ),
              ),
            ] else ...[
              // Not fasting section - compact horizontal layout
              Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    color: AppColors.pastelGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: recommendedFast.isNotEmpty
                    ? Text(
                        'Start fast $recommendedFast',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      )
                    : const Text(
                        'No fast today',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white70),
                          ),
                  ),
                  if (recommendedFast.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: _startFast,
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: const Text('Start', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lightGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: const Size(80, 40),
                      ),
                    ),
                    // Not Today button inline with Start button
                    if (widget.onHiddenForToday != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onHiddenForToday,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white54,
                          side: const BorderSide(color: AppColors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(0, 40),
                        ),
                        child: const Icon(Icons.update, size: 16),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Get current fasting phase info (synchronized with fasting screen)
  Map<String, dynamic> _getFastingPhaseInfo() {
    return FastingPhases.getFastingPhaseInfo(fastingDuration, isFasting);
  }

  // Get current fasting phase color
  Color _getCurrentPhaseColor() {
    return _getFastingPhaseInfo()['color'];
  }

}