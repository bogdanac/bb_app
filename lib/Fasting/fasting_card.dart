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
import 'scheduled_fastings_service.dart';
import '../shared/snackbar_utils.dart';
import '../shared/date_picker_utils.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';

class FastingCard extends StatefulWidget {
  final VoidCallback? onHiddenForToday;
  final Function(bool)? onFastingStatusChanged;
  final VoidCallback? onTap;

  const FastingCard({super.key, this.onHiddenForToday, this.onFastingStatusChanged, this.onTap});

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
  ScheduledFasting? _todayScheduledFast;
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

    // Also load the scheduled fasting object for today
    ScheduledFasting? todayFast;
    if (recommended.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final allFastings = await ScheduledFastingsService.getScheduledFastings();
      todayFast = allFastings.cast<ScheduledFasting?>().firstWhere(
        (f) => f != null &&
               f.date.year == today.year &&
               f.date.month == today.month &&
               f.date.day == today.day &&
               f.isEnabled,
        orElse: () => null,
      );
    }

    if (mounted) {
      setState(() {
        recommendedFast = recommended;
        _todayScheduledFast = todayFast;
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

  // Show options to postpone or cancel the scheduled fast
  void _showFastOptionsSheet() {
    if (_todayScheduledFast == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Fast Options',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_todayScheduledFast!.fastType} scheduled for today',
              style: const TextStyle(fontSize: 13, color: AppColors.white54),
            ),

            const SizedBox(height: 20),

            // Postpone option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule, color: AppColors.purple),
              ),
              title: const Text(
                'Postpone Fast',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Reschedule to another day within the next 3 days',
                style: TextStyle(color: AppColors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showPostponeDialog();
              },
            ),

            const SizedBox(height: 8),

            // Cancel option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cancel_outlined, color: AppColors.red),
              ),
              title: Text(
                'Cancel Fast',
                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Skip this scheduled fast entirely',
                style: TextStyle(color: AppColors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCancelConfirmation();
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Show date picker to postpone fast (up to 3 days)
  Future<void> _showPostponeDialog() async {
    if (_todayScheduledFast == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 3));

    final DateTime? newDate = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 1)),
      firstDate: today.add(const Duration(days: 1)), // Tomorrow at earliest
      lastDate: maxDate, // Max 3 days from today
    );

    if (newDate != null && mounted) {
      final updatedFasting = _todayScheduledFast!.copyWith(
        date: newDate,
        isAutoGenerated: false, // Mark as manually modified
      );

      await ScheduledFastingsService.updateScheduledFasting(updatedFasting);
      await _loadFastingState(); // Reload to update UI

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Fast postponed to ${updatedFasting.formattedDate}',
        );
        widget.onHiddenForToday?.call(); // Hide the card since no fast today anymore
      }
    }
  }

  // Show confirmation to cancel the fast
  Future<void> _showCancelConfirmation() async {
    if (_todayScheduledFast == null) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Cancel Scheduled Fast?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will disable the ${_todayScheduledFast!.fastType} scheduled for today. You can re-enable it from the Scheduled Fastings screen.',
          style: const TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep', style: TextStyle(color: AppColors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Cancel Fast'),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      final updatedFasting = _todayScheduledFast!.copyWith(isEnabled: false);
      await ScheduledFastingsService.updateScheduledFasting(updatedFasting);
      await _loadFastingState(); // Reload to update UI

      if (mounted) {
        SnackBarUtils.showError(context, 'Fast cancelled for today');
        widget.onHiddenForToday?.call(); // Hide the card
      }
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
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppStyles.borderRadiusLarge,
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
                    // Options button (postpone/cancel) inline with Start button
                    if (_todayScheduledFast != null) ...[
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: _showFastOptionsSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white54,
                          side: const BorderSide(color: AppColors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppStyles.borderRadiusXLarge,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(35, 35),
                        ),
                        child: const Icon(Icons.more_horiz, size: 16),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ],
        ),
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