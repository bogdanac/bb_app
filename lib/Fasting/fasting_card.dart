// fasting_card.dart - Actualizat cu sincronizare
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'fasting_notifier.dart';
import '../Notifications/notification_service.dart';
import 'fasting_utils.dart';
import 'fasting_phases.dart';
import '../shared/snackbar_utils.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';

class FastingCard extends StatefulWidget {
  final VoidCallback? onHiddenForToday;
  final Function(bool)? onFastingStatusChanged;
  
  const FastingCard({super.key, this.onHiddenForToday, this.onFastingStatusChanged});

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
  bool _hasLateLutealWarning = false;

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
  
  void _notifyFastingStatusChanged() {
    widget.onFastingStatusChanged?.call(isFasting);
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

    // Never auto-end a fast - only user can end it manually
    if (isFastingStored && startTimeString != null) {
      final startTime = DateTime.parse(startTimeString);
      final endTime = endTimeString != null ? DateTime.parse(endTimeString) : null;
      final now = DateTime.now();

      setState(() {
        isFasting = true;
        fastingStartTime = startTime;
        fastingEndTime = endTime;
        currentFastType = fastType;
        fastingDuration = now.difference(startTime);
      });
      _notifyFastingStatusChanged();
      _startTimer();
    } else if (!isFastingStored) {
      // Only clear if explicitly not fasting (user ended it)
      setState(() {
        isFasting = false;
        fastingStartTime = null;
        fastingEndTime = null;
        currentFastType = '';
        fastingDuration = Duration.zero;
      });
      _notifyFastingStatusChanged();
      _timer?.cancel();
    }

    // Load recommended fast
    await _loadRecommendedFast();

    // Check for late luteal phase conflicts
    await _checkLateLutealConflicts();
  }

  Future<void> _checkLateLutealConflicts() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if today's fast conflicts with late luteal phase
      _hasLateLutealWarning = await MenstrualCycleUtils.isFastingConflictWithLateLuteal(today);

    } catch (e) {
      _hasLateLutealWarning = false;
    }
  }

  // Save fasting state (sincronizat cu FastingScreen)
  Future<void> _saveFastingState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('is_fasting', isFasting);

    if (isFasting && fastingStartTime != null) {
      await prefs.setString('current_fast_start', fastingStartTime!.toIso8601String());
      if (fastingEndTime != null) {
        await prefs.setString('current_fast_end', fastingEndTime!.toIso8601String());
      }
      await prefs.setString('current_fast_type', currentFastType);
    } else if (!isFasting) {
      // Only clear data when explicitly not fasting
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
      SnackBarUtils.showWarning(context, 'No fast scheduled for today');
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

    _notifyFastingStatusChanged();
    _saveFastingState();
    _startTimer();

    // Show initial notification
    _updateFastingNotification();

    SnackBarUtils.showSuccess(context, '🚀 $recommendedFast started!');
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
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8), // Reduced right padding for update button
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusLarge,
          color: AppColors.homeCardBackground, // Home card background
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Small late luteal phase warning
            if (_hasLateLutealWarning && !isFasting) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: AppStyles.borderRadiusSmall,
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppColors.orange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Late luteal phase - may add extra stress',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (isFasting) ...[
              // Progress section when fasting
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: AppColors.yellow,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${FastingUtils.formatDuration(fastingDuration)} / $currentFastType',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                borderRadius: AppStyles.borderRadiusSmall,
                child: LinearProgressIndicator(
                  value: _getProgress(),
                  backgroundColor: AppColors.appBackground,
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
                    color: AppColors.yellow,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: recommendedFast.isNotEmpty
                    ? Text(
                        recommendedFast,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      )
                    : const Text(
                        'No fast today',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.white70),
                          ),
                  ),
                  if (recommendedFast.isNotEmpty) ...[
                    ElevatedButton(
                      onPressed: _startFast,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
                        minimumSize: const Size(65, 35),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 16),
                          const SizedBox(width: 2), // Closer spacing
                          const Text('Start', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                    // Not Today button inline with Start button
                    if (widget.onHiddenForToday != null) ...[
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: widget.onHiddenForToday,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white54,
                          side: const BorderSide(color: AppColors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppStyles.borderRadiusXLarge,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(35, 35),
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