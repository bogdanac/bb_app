import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';
import 'timer_notification_helper.dart';

enum ProductivityMode { countdown, pomodoro }

class ProductivityCard extends StatefulWidget {
  final VoidCallback? onNavigateToTimers;
  final VoidCallback? onHideTemporarily;
  final void Function(String title, String message, bool isBreak)? onTimerComplete;

  const ProductivityCard({
    super.key,
    this.onNavigateToTimers,
    this.onHideTemporarily,
    this.onTimerComplete,
  });

  @override
  State<ProductivityCard> createState() => _ProductivityCardState();
}

class _ProductivityCardState extends State<ProductivityCard> {
  ProductivityMode _mode = ProductivityMode.pomodoro;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isBreak = false;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  Duration _totalDuration = Duration.zero;
  DateTime? _startTime;

  // Settings
  int _pomodoroWorkMinutes = 25;
  int _pomodoroBreakMinutes = 5;
  int _countdownMinutes = 10;

  // Activity linking
  List<Activity> _activities = [];
  String? _linkedActivityId;

  // Stream subscription for real-time sync
  StreamSubscription<Map<String, dynamic>?>? _timerStateSubscription;
  bool _isUpdatingFromStream = false; // Prevent feedback loop

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _restoreTimerState();
    _subscribeToTimerStream();
  }

  @override
  void dispose() {
    _timerStateSubscription?.cancel();
    _timer?.cancel();
    if (_isRunning) {
      _saveTimerState();
    }
    super.dispose();
  }

  void _subscribeToTimerStream() {
    _timerStateSubscription = TimerService.timerStateStream.listen((state) {
      if (_isUpdatingFromStream) return; // Skip if we triggered this update
      _handleExternalTimerChange(state);
    });
  }

  void _handleExternalTimerChange(Map<String, dynamic>? state) {
    if (!mounted) return;

    if (state == null) {
      // Timer was cleared externally
      if (_isRunning) {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _isPaused = false;
          _isBreak = false;
          _remaining = Duration.zero;
        });
      }
      return;
    }

    // Only handle productivity type timers
    if (state['type'] != 'productivity') {
      // Different timer type started - stop our timer
      if (_isRunning) {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _isPaused = false;
          _isBreak = false;
          _remaining = Duration.zero;
        });
      }
      return;
    }

    // Update from external productivity timer state
    final newMode = state['mode'] == 'countdown'
        ? ProductivityMode.countdown
        : ProductivityMode.pomodoro;
    final newIsBreak = state['isPomodoroBreak'] ?? state['isBreak'] ?? false;
    final newRemaining = Duration(
      seconds: state['remainingSeconds'] ?? state['remaining'] ?? 0,
    );
    final wasRunning = state['wasRunning'] ?? false;

    setState(() {
      _mode = newMode;
      _isBreak = newIsBreak;
      _remaining = newRemaining;
      _totalDuration = newIsBreak
          ? Duration(minutes: _pomodoroBreakMinutes)
          : (newMode == ProductivityMode.pomodoro
              ? Duration(minutes: _pomodoroWorkMinutes)
              : Duration(minutes: _countdownMinutes));
      _startTime = state['startedAt'] != null
          ? DateTime.tryParse(state['startedAt'])
          : null;

      if (wasRunning && !_isRunning) {
        _isRunning = true;
        _isPaused = false;
        _startTicker();
      } else if (!wasRunning && _isRunning) {
        _timer?.cancel();
        _isRunning = true;
        _isPaused = true;
      }
    });
  }

  Future<void> _loadSettings() async {
    final workMinutes = await TimerService.getPomodoroWorkMinutes();
    final breakMinutes = await TimerService.getPomodoroBreakMinutes();
    final countdownMinutes = await TimerService.getCountdownMinutes();
    final activities = await TimerService.loadActivities();

    if (mounted) {
      setState(() {
        _pomodoroWorkMinutes = workMinutes;
        _pomodoroBreakMinutes = breakMinutes;
        _countdownMinutes = countdownMinutes > 0 ? countdownMinutes : 10;
        _activities = activities;
      });
    }
  }

  Future<void> _restoreTimerState() async {
    final state = await TimerService.loadActiveTimerState();
    if (state == null) return;

    try {
      // Only restore productivity timer state (compatible with timers_screen.dart format)
      if (state['type'] == 'productivity') {
        final savedAt = DateTime.parse(state['savedAt']);
        final timeSinceSave = DateTime.now().difference(savedAt);
        // Support both 'remainingSeconds' (from tab) and 'remaining' (legacy)
        final savedRemaining = Duration(
          seconds: state['remainingSeconds'] ?? state['remaining'] ?? 0,
        );

        _mode = state['mode'] == 'countdown'
            ? ProductivityMode.countdown
            : ProductivityMode.pomodoro;
        // Support both 'isPomodoroBreak' (from tab) and 'isBreak' (legacy)
        _isBreak = state['isPomodoroBreak'] ?? state['isBreak'] ?? false;
        _totalDuration = _isBreak
            ? Duration(minutes: _pomodoroBreakMinutes)
            : (_mode == ProductivityMode.pomodoro
                ? Duration(minutes: _pomodoroWorkMinutes)
                : Duration(minutes: _countdownMinutes));
        _startTime = state['startedAt'] != null
            ? DateTime.parse(state['startedAt'])
            : null;

        if (state['wasRunning'] == true) {
          // Timer was running - subtract elapsed time
          _remaining = savedRemaining - timeSinceSave;
          if (_remaining.isNegative || _remaining == Duration.zero) {
            _remaining = Duration.zero;
            _onTimerComplete();
            return;
          }
          _isRunning = true;
          _isPaused = false;
          _startTicker();
        } else {
          // Timer was paused
          _remaining = savedRemaining;
          _isRunning = true;
          _isPaused = true;
        }

        if (mounted) setState(() {});
      }
    } catch (_) {
      // Ignore restore errors
    }
  }

  Future<void> _saveTimerState() async {
    if (_isRunning) {
      _isUpdatingFromStream = true;
      // Save in format compatible with timers_screen.dart
      await TimerService.saveActiveTimerState({
        'type': 'productivity',
        'activityId': _linkedActivityId,
        'mode': _mode == ProductivityMode.countdown ? 'countdown' : 'pomodoro',
        'remainingSeconds': _remaining.inSeconds,
        'accumulatedWorkSeconds': (_totalDuration - _remaining).inSeconds,
        'isPomodoroBreak': _isBreak,
        'pomodoroCount': 0,
        'startedAt': _startTime?.toIso8601String(),
        'wasRunning': !_isPaused,
        'savedAt': DateTime.now().toIso8601String(),
      });
      _isUpdatingFromStream = false;
    }
  }

  void _startTimer() {
    HapticFeedback.lightImpact();

    if (_mode == ProductivityMode.pomodoro) {
      _totalDuration = Duration(minutes: _pomodoroWorkMinutes);
      _isBreak = false;
    } else {
      _totalDuration = Duration(minutes: _countdownMinutes);
    }

    _remaining = _totalDuration;
    _startTime = DateTime.now();
    _isRunning = true;
    _isPaused = false;
    _startTicker();
    _updateNotification();
    _saveTimerState();
    setState(() {});
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) {
        setState(() {
          _remaining -= const Duration(seconds: 1);
          if (_remaining.isNegative || _remaining == Duration.zero) {
            _timer?.cancel();
            _onTimerComplete();
          }
        });
        // Update notification every 30 seconds to reduce battery usage
        if (_remaining.inSeconds % 30 == 0) {
          _updateNotification();
        }
      }
    });
  }

  void _onTimerComplete() {
    HapticFeedback.heavyImpact();

    if (_mode == ProductivityMode.pomodoro && !_isBreak) {
      // Work session complete - record it
      final session = TimerSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        activityId: _linkedActivityId ?? 'productivity_pomodoro',
        startTime: _startTime ?? DateTime.now().subtract(_totalDuration),
        endTime: DateTime.now(),
        duration: _totalDuration,
        type: TimerSessionType.pomodoro,
      );
      TimerService.addSession(session);

      // Show completion notification for work session
      _showCompletionAlert(
        title: 'Focus Session Complete! 🎯',
        message: 'Great work! Time for a $_pomodoroBreakMinutes minute break.',
        isBreak: false,
      );

      // Start break
      _isBreak = true;
      _totalDuration = Duration(minutes: _pomodoroBreakMinutes);
      _remaining = _totalDuration;
      _startTime = DateTime.now();
      _startTicker();
      _updateNotification();
      _saveTimerState();
      setState(() {});
    } else if (_mode == ProductivityMode.pomodoro && _isBreak) {
      // Break complete - show notification and stop
      _showCompletionAlert(
        title: 'Break Complete! 💪',
        message: 'Ready for another focus session?',
        isBreak: true,
      );
      _stopTimer(save: false);
    } else {
      // Countdown complete - record and stop
      final session = TimerSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        activityId: _linkedActivityId ?? 'productivity_countdown',
        startTime: _startTime ?? DateTime.now().subtract(_totalDuration),
        endTime: DateTime.now(),
        duration: _totalDuration,
        type: TimerSessionType.countdown,
      );
      TimerService.addSession(session);

      // Show completion notification
      _showCompletionAlert(
        title: 'Timer Complete! ⏰',
        message: 'Your countdown has finished.',
        isBreak: false,
      );
      _stopTimer(save: false);
    }
  }

  void _showCompletionAlert({
    required String title,
    required String message,
    required bool isBreak,
  }) {
    // Show system notification (works on mobile, limited on desktop)
    TimerNotificationHelper.showCompletionNotification(
      title: title,
      body: message,
      isBreakComplete: isBreak,
    );

    // Call the in-app callback for additional alert (especially useful on desktop)
    widget.onTimerComplete?.call(title, message, isBreak);
  }

  void _pauseTimer() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    _isPaused = true;
    _updateNotification();
    _saveTimerState();
    setState(() {});
  }

  void _resumeTimer() {
    HapticFeedback.lightImpact();
    _isPaused = false;
    _startTicker();
    _updateNotification();
    _saveTimerState();
    setState(() {});
  }

  void _stopTimer({required bool save}) async {
    HapticFeedback.lightImpact();
    _timer?.cancel();

    if (save && _isRunning && _totalDuration.inSeconds - _remaining.inSeconds > 60) {
      // Only save if ran for more than a minute
      final session = TimerSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        activityId: _linkedActivityId ??
            (_mode == ProductivityMode.pomodoro
                ? 'productivity_pomodoro'
                : 'productivity_countdown'),
        startTime: _startTime ?? DateTime.now().subtract(_totalDuration - _remaining),
        endTime: DateTime.now(),
        duration: _totalDuration - _remaining,
        type: _mode == ProductivityMode.pomodoro
            ? TimerSessionType.pomodoro
            : TimerSessionType.countdown,
      );
      TimerService.addSession(session);
    }

    _isRunning = false;
    _isPaused = false;
    _isBreak = false;
    _remaining = Duration.zero;
    _startTime = null;
    _linkedActivityId = null;
    TimerNotificationHelper.cancelTimerNotification();
    _isUpdatingFromStream = true;
    await TimerService.clearActiveTimerState();
    _isUpdatingFromStream = false;
    setState(() {});
  }

  void _updateNotification() {
    final label = _mode == ProductivityMode.pomodoro
        ? (_isBreak ? 'Break' : 'Focus')
        : 'Countdown';

    TimerNotificationHelper.showTimerNotification(
      activityName: label,
      remaining: _remaining,
      isPomodoro: _mode == ProductivityMode.pomodoro,
      isBreak: _isBreak,
      isPaused: _isPaused,
    );
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppStyles.cardDecoration(),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: widget.onNavigateToTimers,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    color: AppColors.purple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Productivity',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_isBreak ? AppColors.pastelGreen : AppColors.purple)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isPaused)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _isBreak ? AppColors.pastelGreen : AppColors.purple,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (_isPaused)
                            Icon(
                              Icons.pause,
                              size: 10,
                              color: AppColors.grey300,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            _isBreak ? 'Break' : (_mode == ProductivityMode.pomodoro ? 'Focus' : 'Timer'),
                            style: TextStyle(
                              color: _isBreak ? AppColors.pastelGreen : AppColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Hide button (only when not running and callback provided)
                  if (!_isRunning && widget.onHideTemporarily != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onHideTemporarily?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.visibility_off_outlined,
                          color: AppColors.grey300,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.grey300,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Timer content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _isRunning ? _buildRunningState() : _buildIdleState(),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      children: [
        // Mode selector
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _mode = ProductivityMode.pomodoro);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _mode == ProductivityMode.pomodoro
                        ? AppColors.purple.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _mode == ProductivityMode.pomodoro
                          ? AppColors.purple
                          : AppColors.grey300.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        size: 16,
                        color: _mode == ProductivityMode.pomodoro
                            ? AppColors.purple
                            : AppColors.grey300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pomodoro',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _mode == ProductivityMode.pomodoro
                              ? AppColors.purple
                              : AppColors.grey300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _mode = ProductivityMode.countdown);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _mode == ProductivityMode.countdown
                        ? AppColors.purple.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _mode == ProductivityMode.countdown
                          ? AppColors.purple
                          : AppColors.grey300.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 16,
                        color: _mode == ProductivityMode.countdown
                            ? AppColors.purple
                            : AppColors.grey300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Countdown',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _mode == ProductivityMode.countdown
                              ? AppColors.purple
                              : AppColors.grey300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Activity selector (only show if activities exist)
        if (_activities.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grey300.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _linkedActivityId,
                hint: Text(
                  'Link to activity (optional)',
                  style: TextStyle(fontSize: 13, color: AppColors.grey300),
                ),
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down, color: AppColors.grey300, size: 20),
                style: const TextStyle(fontSize: 13),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No activity', style: TextStyle(color: AppColors.grey300)),
                  ),
                  ..._activities.map((activity) => DropdownMenuItem<String?>(
                    value: activity.id,
                    child: Text(activity.name),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _linkedActivityId = value);
                },
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Duration info and start button
        Row(
          children: [
            Expanded(
              child: Text(
                _mode == ProductivityMode.pomodoro
                    ? '$_pomodoroWorkMinutes min focus + $_pomodoroBreakMinutes min break'
                    : '$_countdownMinutes min countdown',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grey300,
                ),
              ),
            ),
            GestureDetector(
              onTap: _startTimer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Start',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRunningState() {
    final progress = _totalDuration.inSeconds > 0
        ? 1 - (_remaining.inSeconds / _totalDuration.inSeconds)
        : 0.0;

    return Column(
      children: [
        // Timer display
        Row(
          children: [
            // Circular progress
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: AppColors.grey300.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isBreak ? AppColors.pastelGreen : AppColors.purple,
                    ),
                  ),
                  Text(
                    _formatTime(_remaining),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isBreak ? AppColors.pastelGreen : AppColors.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isBreak
                        ? 'Break Time'
                        : (_mode == ProductivityMode.pomodoro ? 'Focus Time' : 'Countdown'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _isPaused
                        ? 'Paused'
                        : '${_formatTime(_remaining)} remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey300,
                    ),
                  ),
                ],
              ),
            ),

            // Control buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pause/Resume
                GestureDetector(
                  onTap: _isPaused ? _resumeTimer : _pauseTimer,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: AppColors.purple,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Stop
                GestureDetector(
                  onTap: () => _stopTimer(save: true),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.deleteRed.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.stop_rounded,
                      color: AppColors.deleteRed,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
