import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'fasting_history_screen.dart';
import 'scheduled_fastings_screen.dart';
import 'fasting_notifier.dart';
import '../Notifications/notification_service.dart';
import 'fasting_phases.dart';
import '../shared/snackbar_utils.dart';
import 'fasting_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../shared/time_picker_utils.dart';
import 'fasting_stage_timeline.dart';
import 'scheduled_fastings_service.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import '../shared/error_logger.dart';
import 'package:flutter/services.dart';
import 'start_fast_dialog.dart';
import 'extended_fast_guide_screen.dart';
import 'fasting_guide_screen.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen>
    with TickerProviderStateMixin {
  DateTime? _currentFastStart;
  DateTime? _currentFastEnd;
  bool _isFasting = false;
  Timer? _fastingTimer;
  Duration _elapsedTime = Duration.zero;
  Duration _totalFastDuration = Duration.zero;
  List<Map<String, dynamic>> _fastingHistory = [];
  String _currentFastType = '';
  late AnimationController _progressController;
  late AnimationController _pulseController;
  bool _isTimelineExpanded = false;
  final FastingNotifier _notifier = FastingNotifier();
  final NotificationService _notificationService = NotificationService();
  String _recommendedFastType = '';
  bool _hasLateLutealWarning = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    // Start pulse animation only when fasting
    _loadFastingData();
    _startFastingTimer();
    _notifier.addListener(_onFastingStateChanged);
  }

  @override
  void dispose() {
    _fastingTimer?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    _notifier.removeListener(_onFastingStateChanged);
    super.dispose();
  }

  void _onFastingStateChanged() {
    _loadFastingData();
  }

  Future<void> _loadFastingData() async {
    final prefs = await SharedPreferences.getInstance();

    _isFasting = prefs.getBool('is_fasting') ?? false;
    final startStr = prefs.getString('current_fast_start');
    final endStr = prefs.getString('current_fast_end');

    if (startStr != null) _currentFastStart = DateTime.parse(startStr);
    if (endStr != null) _currentFastEnd = DateTime.parse(endStr);

    _currentFastType = prefs.getString('current_fast_type') ?? '';

    // Load fasting history
    List<String> historyStr;
    try {
      historyStr = prefs.getStringList('fasting_history') ?? [];
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FastingScreen._loadFastingData',
        error: 'Fasting history data type mismatch, clearing corrupted data: $e',
        stackTrace: stackTrace.toString(),
      );
      await prefs.remove('fasting_history');
      historyStr = [];
    }
    _fastingHistory = historyStr
        .map((item) => Map<String, dynamic>.from(jsonDecode(item) as Map))
        .toList();

    // Sort history by end time (most recent first)
    _fastingHistory.sort((a, b) {
      final aEndTime = DateTime.parse(a['endTime'] as String);
      final bEndTime = DateTime.parse(b['endTime'] as String);
      return bEndTime.compareTo(aEndTime);
    });

    _calculateFastingProgress();

    // Update recommended fast type based on scheduled fastings
    await _updateRecommendedFastType();

    // Start/stop pulse animation based on fasting state
    if (_isFasting && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
      // Show notification if fasting is in progress
      _updateFastingNotification();
    } else if (!_isFasting && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
      // Cancel notification if not fasting
      _notificationService.cancelFastingProgressNotification();
    }

    // Check for late luteal phase conflicts
    await _checkLateLutealConflicts();

    if (mounted) setState(() {});
  }

  Future<void> _checkLateLutealConflicts() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if today's fast conflicts with late luteal phase
      _hasLateLutealWarning = await MenstrualCycleUtils.isFastingConflictWithLateLuteal(today);

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FastingScreen._checkLateLutealConflicts',
        error: 'Error checking late luteal conflicts: $e',
        stackTrace: stackTrace.toString(),
      );
      _hasLateLutealWarning = false;
    }
  }

  Future<void> _deactivateScheduledFast(DateTime date) async {
    try {
      final scheduledFastings = await ScheduledFastingsService.getScheduledFastings();
      final fastToDeactivate = scheduledFastings.firstWhere(
        (fast) => fast.date.year == date.year &&
                  fast.date.month == date.month &&
                  fast.date.day == date.day,
      );

      final updatedFast = fastToDeactivate.copyWith(isEnabled: false);
      await ScheduledFastingsService.updateScheduledFasting(updatedFast);

      // Refresh data
      await _loadFastingData();

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Scheduled fast deactivated for your wellbeing 💝');
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FastingScreen._deactivateScheduledFast',
        error: 'Error deactivating fast: $e',
        stackTrace: stackTrace.toString(),
        context: {'date': date.toString()},
      );
      if (mounted) {
        SnackBarUtils.showError(context, 'Error deactivating fast: $e');
      }
    }
  }

  Future<void> _saveFastingData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('is_fasting', _isFasting);
    if (_currentFastStart != null) {
      await prefs.setString(
          'current_fast_start', _currentFastStart!.toIso8601String());
    } else {
      await prefs.remove('current_fast_start');
    }
    if (_currentFastEnd != null) {
      await prefs.setString(
          'current_fast_end', _currentFastEnd!.toIso8601String());
    } else {
      await prefs.remove('current_fast_end');
    }
    await prefs.setString('current_fast_type', _currentFastType);

    // Save history
    final historyStr = _fastingHistory.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('fasting_history', historyStr);

    // Notifică toate componentele că starea s-a schimbat
    _notifier.notifyFastingStateChanged();
  }

  void _calculateFastingProgress() {
    if (_isFasting && _currentFastStart != null) {
      final now = DateTime.now();
      final previousElapsed = _elapsedTime;
      _elapsedTime = now.difference(_currentFastStart!);

      if (_currentFastEnd != null) {
        _totalFastDuration = _currentFastEnd!.difference(_currentFastStart!);
      }

      // Check for milestone notifications
      _checkFastingMilestones(previousElapsed, _elapsedTime);
    }
  }

  final Set<int> _triggeredMilestones = <int>{};

  void _checkFastingMilestones(
      Duration previousElapsed, Duration currentElapsed) {
    final previousHours = previousElapsed.inHours;
    final currentHours = currentElapsed.inHours;

    // Define milestone hours and their messages
    final milestones = {
      4: {
        'phase': 'Digestion Complete',
        'message': 'Your body has finished processing your last meal! 🍽️'
      },
      8: {
        'phase': 'Glycogen Depletion',
        'message': 'Now switching to stored energy sources! ⚡'
      },
      12: {
        'phase': 'Fat Burning Mode',
        'message': 'Your body is now burning fat for fuel! 🔥'
      },
      16: {
        'phase': 'Ketosis Beginning',
        'message': 'Ketone production is starting! Mental clarity incoming! 🧠'
      },
      20: {
        'phase': 'Deep Ketosis',
        'message': 'You\'re in deep ketosis - feel that energy surge! ✨'
      },
      24: {
        'phase': 'Growth Hormone Peak',
        'message': 'HGH levels are significantly elevated! 💪'
      },
      36: {
        'phase': 'Autophagy Active',
        'message': 'Cellular repair and regeneration is in full swing! 🔄'
      },
      48: {
        'phase': 'Enhanced Autophagy',
        'message': 'Peak cellular cleanup - your body is rejuvenating! 🌟'
      },
    };

    for (final milestoneHour in milestones.keys) {
      if (previousHours < milestoneHour &&
          currentHours >= milestoneHour &&
          !_triggeredMilestones.contains(milestoneHour)) {
        _triggeredMilestones.add(milestoneHour);
        final milestone = milestones[milestoneHour]!;
        _notificationService.showFastingMilestoneNotification(
          milestone: milestone['phase']!,
          message: milestone['message']!,
          elapsedTime: currentElapsed,
        );
      }
    }
  }

  void _startFastingTimer() {
    _fastingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isFasting) {
        _calculateFastingProgress();
        // Update notification every 15 minutes to avoid spam
        if (_elapsedTime.inSeconds % 900 == 0) {
          _updateFastingNotification();
        }
        if (mounted) setState(() {});
      }
    });
  }

  void _updateFastingNotification() {
    if (_isFasting && _currentFastStart != null) {
      final phaseInfo = _getFastingPhaseInfo();
      _notificationService.showFastingProgressNotification(
        fastType: _currentFastType,
        elapsedTime: _elapsedTime,
        totalDuration: _totalFastDuration,
        currentPhase: phaseInfo['phase'],
      );
    }
  }

  Future<void> _updateRecommendedFastType() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    // Get all scheduled fastings
    final scheduledFastings =
        await ScheduledFastingsService.getScheduledFastings();

    // Check if there's a scheduled fast for today, yesterday, or 2 days ago
    final hasScheduledFastToday = scheduledFastings.any((fasting) =>
        fasting.isEnabled &&
        fasting.date.year == today.year &&
        fasting.date.month == today.month &&
        fasting.date.day == today.day);

    final hasScheduledFastYesterday = scheduledFastings.any((fasting) =>
        fasting.isEnabled &&
        fasting.date.year == yesterday.year &&
        fasting.date.month == yesterday.month &&
        fasting.date.day == yesterday.day);

    final hasScheduledFastTwoDaysAgo = scheduledFastings.any((fasting) =>
        fasting.isEnabled &&
        fasting.date.year == twoDaysAgo.year &&
        fasting.date.month == twoDaysAgo.month &&
        fasting.date.day == twoDaysAgo.day);

    String recommendedFast = '';

    // Show button if there's a scheduled fast for today, yesterday, or 2 days ago (3-day grace period)
    if (hasScheduledFastToday || hasScheduledFastYesterday || hasScheduledFastTwoDaysAgo) {
      recommendedFast = _getRecommendedFastTypeFromLogic();
    }

    if (mounted) {
      setState(() {
        _recommendedFastType = recommendedFast;
      });
    }
  }

  String _getRecommendedFastType() {
    return _recommendedFastType;
  }

  String _getRecommendedFastTypeFromLogic() {
    final now = DateTime.now();
    final isFriday = now.weekday == 5;
    final is25th = now.day == 25;

    // Smart scheduling: combine Friday and 25th fasts when close
    if (isFriday || is25th) {
      return _getSmartFastRecommendation(now, isFriday, is25th);
    }

    // Fasting screen has a 5-day grace period - check recent fasting days
    return _getRecommendedFastWithGracePeriod(now);
  }

  // Smart scheduling logic to avoid double fasts when Friday and 25th are close
  String _getSmartFastRecommendation(DateTime now, bool isFriday, bool is25th) {
    // If today is the 25th, check if there was a recent Friday or upcoming Friday
    if (is25th) {
      final month = now.month;
      String longerFastType;
      if (month == 1 || month == 9) {
        longerFastType = FastingUtils.waterFast;
      } else if (month % 3 == 1) {
        longerFastType = FastingUtils.quarterlyFast;
      } else {
        longerFastType = FastingUtils.monthlyFast;
      }

      // Check if Friday was within the last 4-6 days or will be within next 4-6 days
      final daysUntilFriday = (5 - now.weekday + 7) %
          7; // Days until next Friday (0 if today is Friday)
      final daysSinceLastFriday = now.weekday >= 5
          ? now.weekday - 5
          : now.weekday + 2; // Days since last Friday

      // If Friday is close (within 6 days either way), skip Friday fast and do the longer fast on 25th
      if (daysSinceLastFriday <= 6 || daysUntilFriday <= 6) {
        return longerFastType; // Do the longer fast on the 25th
      }

      return longerFastType;
    }

    // If today is Friday, check if 25th is close
    if (isFriday) {
      final daysUntil25th = 25 - now.day;

      // If 25th is within 4-6 days, do the longer fast on Friday instead
      if (daysUntil25th >= 0 && daysUntil25th <= 6) {
        final month = now.month;

        // Use the appropriate longer fast type
        if (month == 1 || month == 9) {
          return FastingUtils.waterFast;
        } else if (month % 3 == 1) {
          return FastingUtils.quarterlyFast;
        } else {
          return FastingUtils.monthlyFast;
        }
      }

      // Check if 25th was recent (within last 6 days)
      if (now.day < 25 && (25 - now.day) > 25) {
        // 25th was last month
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final daysSince25thLastMonth =
            now.day + (DateTime(now.year, now.month, 0).day - 25);

        if (daysSince25thLastMonth <= 6) {
          // 25th was recent, do the longer fast type on Friday
          if (lastMonth == 1 || lastMonth == 9) {
            return FastingUtils.waterFast;
          } else if (lastMonth % 3 == 1) {
            return FastingUtils.quarterlyFast;
          } else {
            return FastingUtils.monthlyFast;
          }
        }
      }

      return FastingUtils.weeklyFast; // Normal Friday fast
    }

    return '';
  }

  // Get recommended fast with 5-day grace period (for fasting screen only)
  String _getRecommendedFastWithGracePeriod(DateTime now) {
    // Check if Friday was within the last 5 days
    final daysSinceLastFriday =
        now.weekday >= 5 ? now.weekday - 5 : now.weekday + 2;
    if (daysSinceLastFriday <= 5 && daysSinceLastFriday > 0) {
      // Calculate what the fast would have been on that Friday
      final lastFriday = now.subtract(Duration(days: daysSinceLastFriday));
      final daysUntil25thFromLastFriday = 25 - lastFriday.day;

      // Check if 25th was close to that Friday
      if (daysUntil25thFromLastFriday >= 0 &&
          daysUntil25thFromLastFriday <= 6) {
        final month = lastFriday.month;
        if (month == 1 || month == 9) {
          return FastingUtils.waterFast;
        } else if (month % 3 == 1) {
          return FastingUtils.quarterlyFast;
        } else {
          return FastingUtils.monthlyFast;
        }
      } else {
        return FastingUtils.weeklyFast;
      }
    }

    // Check if 25th was within the last 5 days
    final daysSince25th = now.day > 25 ? now.day - 25 : 0;
    if (daysSince25th <= 5 && daysSince25th > 0) {
      final month = now.month;
      if (month == 1 || month == 9) {
        return FastingUtils.waterFast;
      } else if (month % 3 == 1) {
        return FastingUtils.quarterlyFast;
      } else {
        return FastingUtils.monthlyFast;
      }
    }

    // Check if 25th was in the previous month within 5 days
    if (now.day <= 5) {
      final lastMonth = now.month == 1 ? 12 : now.month - 1;
      final daysInLastMonth = DateTime(now.year, now.month, 0).day;
      final daysSince25thLastMonth = now.day + (daysInLastMonth - 25);

      if (daysSince25thLastMonth <= 5) {
        if (lastMonth == 1 || lastMonth == 9) {
          return FastingUtils.waterFast;
        } else if (lastMonth % 3 == 1) {
          return FastingUtils.quarterlyFast;
        } else {
          return FastingUtils.monthlyFast;
        }
      }
    }

    return '';
  }

  void _startFast(String fastType) {
    final now = DateTime.now();
    final duration = FastingUtils.getFastDuration(fastType);

    setState(() {
      _isFasting = true;
      _currentFastStart = now;
      _currentFastEnd = now.add(duration);
      _currentFastType = fastType;
      _elapsedTime = Duration.zero;
      _totalFastDuration = duration;
    });

    // Reset milestone tracking for new fast
    _triggeredMilestones.clear();

    _saveFastingData();
    _progressController.forward();
    _pulseController.repeat(reverse: true);

    // Show started notification
    _notificationService.showFastingStartedNotification(
      fastType: fastType,
      totalDuration: duration,
    );

    // Show initial progress notification
    _updateFastingNotification();

    SnackBarUtils.showSuccess(context, '🚀 $fastType started! You got this!');
  }

  // Start quick fast (20h or 16h)
  void _startQuickFast(int hours) {
    final now = DateTime.now();
    final duration = Duration(hours: hours);
    final fastType = '${hours}h Fast';

    setState(() {
      _isFasting = true;
      _currentFastStart = now;
      _currentFastEnd = now.add(duration);
      _currentFastType = fastType;
      _elapsedTime = Duration.zero;
      _totalFastDuration = duration;
    });

    // Reset milestone tracking for new fast
    _triggeredMilestones.clear();

    _saveFastingData();
    _progressController.forward();
    _pulseController.repeat(reverse: true);

    // Show started notification
    _notificationService.showFastingStartedNotification(
      fastType: fastType,
      totalDuration: duration,
    );

    // Show initial progress notification
    _updateFastingNotification();

    SnackBarUtils.showSuccess(context, '🚀 $fastType started!');
  }

  // Show custom fast dialog from card tap
  Future<void> _showStartFastDialog() async {
    HapticFeedback.lightImpact();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const StartFastDialog(defaultHours: 18),
    );

    if (result != null && mounted) {
      final hours = result['hours'] as int;
      final startTime = result['startTime'] as DateTime;
      final endTime = result['endTime'] as DateTime;
      final duration = Duration(hours: hours);
      final fastType = '${hours}h Fast';

      setState(() {
        _isFasting = true;
        _currentFastStart = startTime;
        _currentFastEnd = endTime;
        _currentFastType = fastType;
        _elapsedTime = DateTime.now().difference(startTime);
        _totalFastDuration = duration;
      });

      // Reset milestone tracking for new fast
      _triggeredMilestones.clear();

      _saveFastingData();
      _progressController.forward();
      _pulseController.repeat(reverse: true);

      // Show started notification
      _notificationService.showFastingStartedNotification(
        fastType: fastType,
        totalDuration: duration,
      );

      // Show initial progress notification
      _updateFastingNotification();

      SnackBarUtils.showSuccess(context, '🚀 $fastType started!');
    }
  }

  void _endFast() {
    if (_currentFastStart != null) {
      final currentDuration = DateTime.now().difference(_currentFastStart!);
      _showEndFastConfirmationDialog(currentDuration);
    }
  }

  void _showEndFastConfirmationDialog(Duration currentDuration) {
    DateTime? customEndTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final effectiveDuration = customEndTime != null
              ? customEndTime!.difference(_currentFastStart!)
              : currentDuration;

          return AlertDialog(
            backgroundColor: AppColors.dialogBackground,
            title: const Text(
              'End Fast?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to end your $_currentFastType?',
                  style: const TextStyle(color: AppColors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dialogCardBackground,
                    borderRadius: AppStyles.borderRadiusMedium,
                    border: Border.all(color: AppColors.greyText.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer, color: AppColors.coral, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Current Duration:',
                            style: TextStyle(color: AppColors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        FastingUtils.formatDuration(effectiveDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_totalFastDuration.inMinutes > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Target: ${FastingUtils.formatDuration(_totalFastDuration)}',
                          style: const TextStyle(
                            color: AppColors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // End time picker
                InkWell(
                  onTap: () async {
                    final currentContext = context;
                    final selectedDateTime = await DatePickerUtils.showStyledDateTimePicker(
                      context: currentContext,
                      initialDateTime: customEndTime ?? DateTime.now(),
                      firstDate: _currentFastStart!,
                      lastDate: DateTime.now(),
                    );

                    if (selectedDateTime != null) {
                      setDialogState(() {
                        customEndTime = selectedDateTime;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.coral),
                      borderRadius: AppStyles.borderRadiusSmall,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: AppColors.coral, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customEndTime != null
                                ? 'End: ${customEndTime!.day}/${customEndTime!.month} at ${customEndTime!.hour.toString().padLeft(2, '0')}:${customEndTime!.minute.toString().padLeft(2, '0')}'
                                : 'Change end time (optional)',
                            style: TextStyle(
                              color: customEndTime != null ? Colors.white : AppColors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue', style: TextStyle(color: AppColors.white54)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cancelFast();
                },
                child: const Text('Cancel Fast', style: TextStyle(color: AppColors.orange)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmEndFast(customEndTime: customEndTime);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End Fast'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _cancelFast() {
    setState(() {
      _isFasting = false;
      _currentFastStart = null;
      _currentFastEnd = null;
      _currentFastType = '';
      _elapsedTime = Duration.zero;
      _totalFastDuration = Duration.zero;
    });

    _saveFastingData();
    _progressController.reset();
    _pulseController.stop();
    _pulseController.reset();

    _notificationService.cancelFastingProgressNotification();

    SnackBarUtils.showWarning(context, 'Fast cancelled');
  }

  void _confirmEndFast({DateTime? customEndTime}) {
    if (_currentFastStart != null) {
      final endTime = customEndTime ?? DateTime.now();
      final actualDuration = endTime.difference(_currentFastStart!);

      _fastingHistory.add({
        'type': _currentFastType,
        'startTime': _currentFastStart!.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'plannedDuration': _totalFastDuration.inMinutes,
        'actualDuration': actualDuration.inMinutes,
      });

      setState(() {
        _isFasting = false;
        _currentFastStart = null;
        _currentFastEnd = null;
        _currentFastType = '';
        _elapsedTime = Duration.zero;
        _totalFastDuration = Duration.zero;
      });

      _saveFastingData();
      _progressController.reset();
      _pulseController.stop();
      _pulseController.reset();

      // Cancel progress notification and show completion notification
      _notificationService.cancelFastingProgressNotification();
      _notificationService.showFastingCompletedNotification(
        fastType: _currentFastType,
        actualDuration: actualDuration,
      );

      _showCongratulationDialog(actualDuration);
    }
  }

  void _postponeFast() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final newStartTime =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0);

    setState(() {
      _currentFastStart = newStartTime;
      _currentFastEnd = newStartTime.add(_totalFastDuration);
    });

    _saveFastingData();

    SnackBarUtils.showWarning(context, 'Fast postponed to tomorrow at 2 PM');
  }

  void _editCurrentFastStartTime() {
    if (!_isFasting || _currentFastStart == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
        title: const Text('Edit Fast Start Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current start time: ${_currentFastStart!.hour.toString().padLeft(2, '0')}:${_currentFastStart!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose new start time:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final currentContext = context;
              Navigator.pop(currentContext);
              final TimeOfDay? picked =
                  await TimePickerUtils.showStyledTimePicker(
                context: currentContext,
                initialTime: TimeOfDay.fromDateTime(_currentFastStart!),
              );

              if (picked != null) {
                _updateFastStartTime(picked);
              }
            },
            child: const Text('Select Time'),
          ),
        ],
      ),
    );
  }

  void _updateFastStartTime(TimeOfDay newTime) {
    if (_currentFastStart == null || !_isFasting) return;

    final currentDate = _currentFastStart!;
    final newStartTime = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
      newTime.hour,
      newTime.minute,
    );

    // Calculate new end time based on original duration
    final newEndTime = newStartTime.add(_totalFastDuration);
    final now = DateTime.now();

    // Validate that start time is not in the future
    if (newStartTime.isAfter(now)) {
      SnackBarUtils.showError(context, 'Start time cannot be in the future');
      return;
    }

    setState(() {
      _currentFastStart = newStartTime;
      _currentFastEnd = newEndTime;
      // Recalculate elapsed time
      _elapsedTime = now.difference(newStartTime);
      // Reset triggered milestones since start time changed
      _triggeredMilestones.clear();
    });

    _saveFastingData();

    // Immediately update the notification with correct progress
    _updateFastingNotification();

    // Check if we should trigger any milestones that were missed due to the time change
    _checkFastingMilestones(Duration.zero, _elapsedTime);

    SnackBarUtils.showSuccess(context, 'Fast start time updated to ${newTime.format(context)}');
  }

  void _showCongratulationDialog(Duration actualDuration) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
        title: const Text('🎉 Congratulations!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You completed your fast!'),
            const SizedBox(height: 16),
            Text(
              'Duration: ${FastingUtils.formatDuration(actualDuration)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  // Enhanced fasting phases with detailed information
  Map<String, dynamic> _getFastingPhaseInfo() {
    return FastingPhases.getFastingPhaseInfo(_elapsedTime, _isFasting);
  }

  String _getLongestFast() {
    if (_fastingHistory.isEmpty) return '0h 0m';

    final longestMinutes = _fastingHistory
        .map((fast) => fast['actualDuration'] as int)
        .reduce((a, b) => a > b ? a : b);

    final hours = longestMinutes ~/ 60;
    final minutes = longestMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  // Toggle timeline expansion
  void _toggleTimelineExpanded() {
    setState(() {
      _isTimelineExpanded = !_isTimelineExpanded;
    });
  }

  // Select start time - suppress linter warning as context is safe to use here
  // ignore: use_build_context_synchronously
  void _selectStartTime(BuildContext context, Function(DateTime) onTimeSelected,
      DateTime? currentStartTime, DateTime now) async {
    final selectedDateTime = await DatePickerUtils.showStyledDateTimePicker(
      context: context,
      initialDateTime: currentStartTime ?? now.subtract(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );

    if (selectedDateTime != null && mounted) {
      onTimeSelected(selectedDateTime);
    }
  }

  // Select end time - suppress linter warning as context is safe to use here
  // ignore: use_build_context_synchronously
  void _selectEndTime(BuildContext context, Function(DateTime) onTimeSelected,
      DateTime? currentEndTime, DateTime? startTime, DateTime now) async {
    final selectedDateTime = await DatePickerUtils.showStyledDateTimePicker(
      context: context,
      initialDateTime: currentEndTime ?? now,
      firstDate: startTime ?? now.subtract(const Duration(days: 30)),
      lastDate: now,
    );

    if (selectedDateTime != null && mounted) {
      onTimeSelected(selectedDateTime);
    }
  }

  // Show manual fast entry dialog
  Future<void> _showManualFastDialog() async {
    final currentContext = context;
    DateTime? startTime;
    DateTime? endTime;
    String fastType = FastingUtils.weeklyFast;
    final now = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: currentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: Center(
              child: const Text(
              'Add Completed Fast',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
          )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Fast Type:',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: fastType,
                    dropdownColor: AppColors.dialogBackground,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    underline: Container(),
                    items: FastingUtils.fastTypes
                        .map((String type) => DropdownMenuItem(
                            value: type,
                            child: Text(type,
                                style: const TextStyle(fontSize: 16))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          fastType = value;
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  // Start time
                  const Text(
                    'Start Time:',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(width: 24),
                  InkWell(
                    onTap: () {
                      _selectStartTime(context, (DateTime selectedTime) {
                        setDialogState(() {
                          startTime = selectedTime;
                        });
                      }, startTime, now);
                    },
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.pastelGreen),
                        borderRadius: AppStyles.borderRadiusSmall,
                      ),
                      child: Text(
                        startTime != null
                            ? '${startTime!.day}/${startTime!.month} at ${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
                            : 'Select start time',
                        style: TextStyle(
                            color: startTime != null
                                ? Colors.white
                                : AppColors.greyText),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  // End time
                  const Text(
                    'End Time:',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(width: 36),
                  InkWell(
                    onTap: () {
                      _selectEndTime(context, (DateTime selectedTime) {
                        setDialogState(() {
                          endTime = selectedTime;
                        });
                      }, endTime, startTime, now);
                    },
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.pastelGreen),
                        borderRadius: AppStyles.borderRadiusSmall,
                      ),
                      child: Text(
                        endTime != null
                            ? '${endTime!.day}/${endTime!.month} at ${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
                            : 'Select end time',
                        style: TextStyle(
                            color:
                            endTime != null ? Colors.white : AppColors.greyText),
                      ),
                    ),
                  ),
                ],
              ),

              if (startTime != null && endTime != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Duration: ${FastingUtils.formatDuration(endTime!.difference(startTime!))}',
                  style: const TextStyle(
                      color: AppColors.successGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.greyText, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: startTime != null &&
                      endTime != null &&
                      endTime!.isAfter(startTime!)
                  ? () => Navigator.pop(context, {
                        'startTime': startTime,
                        'endTime': endTime,
                        'fastType': fastType,
                      })
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Fast', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _addManualFastToHistory(
        result['startTime'] as DateTime,
        result['endTime'] as DateTime,
        result['fastType'] as String,
      );
    }
  }

  // Add manual fast to history
  Future<void> _addManualFastToHistory(
      DateTime startTime, DateTime endTime, String fastType) async {
    final actualDuration = endTime.difference(startTime);
    final plannedDuration = FastingUtils.getFastDuration(fastType);

    final fastEntry = {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'fastType': fastType,
      'actualDuration': actualDuration.inMinutes,
      'plannedDuration': plannedDuration.inMinutes,
      'completed': true,
    };

    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings;
    try {
      historyStrings = prefs.getStringList('fasting_history') ?? [];
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'FastingScreen._addManualFastToHistory',
        error: 'Fasting history data type mismatch, clearing corrupted data: $e',
        stackTrace: stackTrace.toString(),
      );
      await prefs.remove('fasting_history');
      historyStrings = [];
    }
    historyStrings.add(jsonEncode(fastEntry));
    await prefs.setStringList('fasting_history', historyStrings);

    // Reload data to show the new entry
    await _loadFastingData();

    if (mounted) {
      SnackBarUtils.showSuccess(context, '✅ Added $fastType (${FastingUtils.formatDuration(actualDuration)}) to history');
    }
  }

  Widget _buildEnhancedCircularProgress() {
    final phaseInfo = _getFastingPhaseInfo();
    final totalProgress = _totalFastDuration.inMinutes > 0
        ? _elapsedTime.inMinutes / _totalFastDuration.inMinutes
        : 0.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow effect - doar dacă se face fasting
              if (_isFasting)
                Container(
                  width: 260 + (_pulseController.value * 20),
                  height: 260 + (_pulseController.value * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: phaseInfo['color']
                            .withValues(alpha: 0.3 * _pulseController.value),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),

              // Background circle
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: phaseInfo['color'].withValues(alpha: 0.1),
                ),
              ),

              // Main progress circle
              SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: totalProgress.clamp(0.0, 1.0),
                  strokeWidth: 12,
                  backgroundColor: AppColors.dialogBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(phaseInfo['color']),
                ),
              ),

              // Phase progress circle (inner)
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: phaseInfo['progress'],
                  strokeWidth: 8,
                  backgroundColor: AppColors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      phaseInfo['color'].withValues(alpha: 0.2)),
                ),
              ),

              // Center content
              Container(
                width: 200,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.normalCardBackground,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black,
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isFasting) ...[
                      Text(
                        FastingUtils.formatDuration(_elapsedTime),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: phaseInfo['color'],
                        ),
                      ),
                      if (_currentFastEnd != null) ...[
                        Text(
                          'of ${FastingUtils.formatDuration(_totalFastDuration)}',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.greyText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(totalProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: phaseInfo['color'],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ends at ${_currentFastEnd!.hour.toString().padLeft(2, '0')}:${_currentFastEnd!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.white54,
                          ),
                        ),
                      ],
                    ] else ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 36,
                        color: AppColors.greyText,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No fasting started',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                            color: AppColors.greyText),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendedFast = _getRecommendedFastType();
    final phaseInfo = _getFastingPhaseInfo();
    final showPostponeButton = !_isFasting && recommendedFast.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasting'),
        backgroundColor: AppColors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showManualFastDialog,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FastingHistoryScreen(history: _fastingHistory),
                  ),
                );
                // Refresh data when returning from history
                _loadFastingData();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.schedule_rounded),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScheduledFastingsScreen(),
                  ),
                );
                // Refresh data when returning from scheduled fastings
                _loadFastingData();
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Late luteal phase warning
            if (_hasLateLutealWarning && !_isFasting) ...[
              Card(
                color: AppColors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_rounded, color: AppColors.orange, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Late Luteal Phase Warning',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.orange,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fasting during late luteal phase may add extra stress to your body.',
                        style: TextStyle(
                          color: AppColors.greyText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _deactivateScheduledFast(DateTime.now());
                              },
                              icon: Icon(Icons.spa_rounded, size: 18),
                              label: Text('Deactivate Fast'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.orange,
                                side: BorderSide(color: AppColors.orange),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _hasLateLutealWarning = false;
                                });
                              },
                              icon: Icon(Icons.check_rounded, size: 18),
                              label: Text('No, it\'s okay'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.greyText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Quick start buttons - always visible at top
            if (!_isFasting) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Quick start buttons row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startQuickFast(16),
                              icon: const Icon(Icons.timer_outlined),
                              label: const Text('16h Fast'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successGreen,
                                foregroundColor: AppColors.white,
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppStyles.borderRadiusMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startQuickFast(20),
                              icon: const Icon(Icons.timer_outlined),
                              label: const Text('20h Fast'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lime,
                                foregroundColor: AppColors.white,
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppStyles.borderRadiusMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Recommended fast button
                      if (recommendedFast.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _startFast(recommendedFast),
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(Icons.play_arrow_rounded, size: 20),
                            ),
                            label: Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: Text('Start $recommendedFast',
                                  style: TextStyle(fontSize: 16)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusMedium,
                              ),
                            ),
                          ),
                        ),

                        // Fast Guide button (show for all fast types)
                        if (recommendedFast.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => recommendedFast == FastingUtils.waterFast
                                        ? const ExtendedFastGuideScreen()
                                        : FastingGuideScreen(fastType: recommendedFast),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.menu_book_rounded, size: 18),
                              label: Text(recommendedFast == FastingUtils.waterFast
                                  ? 'View 72h Fast Guide'
                                  : 'View Fasting Guide'),
                              style: TextButton.styleFrom(
                                foregroundColor: recommendedFast == FastingUtils.waterFast
                                    ? AppColors.pink
                                    : AppColors.purple,
                              ),
                            ),
                          ),
                        ],

                        // Postpone button
                        if (showPostponeButton) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _postponeFast,
                              icon: const Icon(Icons.schedule_rounded),
                              label: const Text('Postpone to Tomorrow'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.yellow,
                                side: const BorderSide(color: AppColors.yellow),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppStyles.borderRadiusMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Enhanced Current Fast Status Card
            GestureDetector(
              onTap: _isFasting ? null : _showStartFastDialog,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: AppStyles.borderRadiusXLarge),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: AppStyles.borderRadiusXLarge,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        phaseInfo['color'].withValues(alpha: 0.2),
                        phaseInfo['color'].withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Column(
                  children: [
                    // Enhanced Circular Progress
                    _buildEnhancedCircularProgress(),

                    const SizedBox(height: 16),

                    // Phase Information
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isFasting
                            ? phaseInfo['color'].withValues(alpha: 0.15)
                            : AppColors.greyText.withValues(alpha: 0.15),
                        borderRadius: AppStyles.borderRadiusLarge,
                        border: Border.all(
                          color: _isFasting
                              ? phaseInfo['color'].withValues(alpha: 0.3)
                              : AppColors.greyText.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isFasting ? Icons.bolt : Icons.timer_outlined,
                                color: _isFasting
                                    ? phaseInfo['color']
                                    : AppColors.greyText,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                phaseInfo['phase'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _isFasting
                                      ? phaseInfo['color']
                                      : AppColors.greyText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            phaseInfo['message'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.greyText,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Fasting Stage Timeline
                    if (_isFasting) ...[
                      const SizedBox(height: 24),
                      FastingStageTimeline(
                        elapsedTime: _elapsedTime,
                        isFasting: _isFasting,
                        isExpanded: _isTimelineExpanded,
                        onToggleExpanded: _toggleTimelineExpanded,
                      ),
                    ],
                  ],
                ),
                ),
              ),
            ),

            const SizedBox(height: 2),

            // Control Buttons
            if (_isFasting) ...[
              Row(
                children: [
                  // Main End Fast Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _endFast,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('End Fast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Edit Start Time Button
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _editCurrentFastStartTime,
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: const Text('Edit Start Time'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF98834),
                        side: const BorderSide(color: Color(0xFFF98834)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Statistics Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.borderRadiusLarge),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Progress',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.white70),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Total Fasts',
                          '${_fastingHistory.length}',
                          Icons.flag_rounded,
                          AppColors.purple,
                        ),
                        _buildStatItem(
                          'Longest Fast',
                          _getLongestFast(),
                          Icons.timer_rounded,
                          AppColors.lightGreen,
                        ),
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

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.greyText),
        ),
      ],
    );
  }
}
