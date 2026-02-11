import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';
import 'timer_notification_helper.dart';

enum ProductivityMode { focus, pomodoro }

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
  Duration _elapsed = Duration.zero; // For timer (count-up) mode
  DateTime? _startTime;

  // Settings
  int _pomodoroWorkMinutes = 25;
  int _pomodoroBreakMinutes = 5;

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
      if (_isUpdatingFromStream) return;
      _handleExternalTimerChange(state);
    });
  }

  void _handleExternalTimerChange(Map<String, dynamic>? state) {
    if (!mounted) return;

    if (state == null) {
      if (_isRunning) {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _isPaused = false;
          _isBreak = false;
          _remaining = Duration.zero;
          _elapsed = Duration.zero;
        });
      }
      return;
    }

    if (state['type'] != 'productivity') {
      if (_isRunning) {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _isPaused = false;
          _isBreak = false;
          _remaining = Duration.zero;
          _elapsed = Duration.zero;
        });
      }
      return;
    }

    // 'countdown' or 'timer' both map to timer mode
    final modeStr = state['mode'];
    final newMode = (modeStr == 'countdown' || modeStr == 'timer')
        ? ProductivityMode.focus
        : ProductivityMode.pomodoro;
    final newIsBreak = state['isPomodoroBreak'] ?? state['isBreak'] ?? false;
    final wasRunning = state['wasRunning'] ?? false;

    setState(() {
      _mode = newMode;
      _isBreak = newIsBreak;
      _startTime = state['startedAt'] != null
          ? DateTime.tryParse(state['startedAt'])
          : null;

      if (newMode == ProductivityMode.focus) {
        // Timer (count-up) mode
        _elapsed = Duration(
          seconds: state['accumulatedWorkSeconds'] ?? state['elapsed'] ?? 0,
        );
        _remaining = Duration.zero;
        _totalDuration = Duration.zero;
      } else {
        // Pomodoro mode
        _remaining = Duration(
          seconds: state['remainingSeconds'] ?? state['remaining'] ?? 0,
        );
        _totalDuration = newIsBreak
            ? Duration(minutes: _pomodoroBreakMinutes)
            : Duration(minutes: _pomodoroWorkMinutes);
      }

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
    final activities = await TimerService.loadActivities();

    if (mounted) {
      setState(() {
        _pomodoroWorkMinutes = workMinutes;
        _pomodoroBreakMinutes = breakMinutes;
        _activities = activities;
      });
    }
  }

  Future<void> _restoreTimerState() async {
    final state = await TimerService.loadActiveTimerState();
    if (state == null) return;

    try {
      if (state['type'] == 'productivity') {
        final savedAt = DateTime.parse(state['savedAt']);
        final timeSinceSave = DateTime.now().difference(savedAt);

        final modeStr = state['mode'];
        _mode = (modeStr == 'countdown' || modeStr == 'timer')
            ? ProductivityMode.focus
            : ProductivityMode.pomodoro;
        _isBreak = state['isPomodoroBreak'] ?? state['isBreak'] ?? false;
        _startTime = state['startedAt'] != null
            ? DateTime.parse(state['startedAt'])
            : null;

        if (_mode == ProductivityMode.focus) {
          // Timer (count-up) mode
          final savedElapsed = Duration(
            seconds: state['accumulatedWorkSeconds'] ?? state['elapsed'] ?? 0,
          );

          if (state['wasRunning'] == true) {
            _elapsed = savedElapsed + timeSinceSave;
            _isRunning = true;
            _isPaused = false;
            _startTicker();
          } else {
            _elapsed = savedElapsed;
            _isRunning = true;
            _isPaused = true;
          }
        } else {
          // Pomodoro mode
          final savedRemaining = Duration(
            seconds: state['remainingSeconds'] ?? state['remaining'] ?? 0,
          );
          _totalDuration = _isBreak
              ? Duration(minutes: _pomodoroBreakMinutes)
              : Duration(minutes: _pomodoroWorkMinutes);

          if (state['wasRunning'] == true) {
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
            _remaining = savedRemaining;
            _isRunning = true;
            _isPaused = true;
          }
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
      if (_mode == ProductivityMode.focus) {
        // Timer (count-up) mode
        await TimerService.saveActiveTimerState({
          'type': 'productivity',
          'activityId': _linkedActivityId,
          'mode': 'countdown', // Keep 'countdown' for backward compat with timers_screen
          'remainingSeconds': 0,
          'accumulatedWorkSeconds': _elapsed.inSeconds,
          'isPomodoroBreak': false,
          'pomodoroCount': 0,
          'startedAt': _startTime?.toIso8601String(),
          'wasRunning': !_isPaused,
          'savedAt': DateTime.now().toIso8601String(),
        });
      } else {
        // Pomodoro mode
        await TimerService.saveActiveTimerState({
          'type': 'productivity',
          'activityId': _linkedActivityId,
          'mode': 'pomodoro',
          'remainingSeconds': _remaining.inSeconds,
          'accumulatedWorkSeconds': (_totalDuration - _remaining).inSeconds,
          'isPomodoroBreak': _isBreak,
          'pomodoroCount': 0,
          'startedAt': _startTime?.toIso8601String(),
          'wasRunning': !_isPaused,
          'savedAt': DateTime.now().toIso8601String(),
        });
      }
      _isUpdatingFromStream = false;
    }
  }

  void _startTimer() {
    HapticFeedback.lightImpact();

    if (_mode == ProductivityMode.pomodoro) {
      _totalDuration = Duration(minutes: _pomodoroWorkMinutes);
      _remaining = _totalDuration;
      _isBreak = false;
    } else {
      // Timer (count-up) mode — start from 0
      _elapsed = Duration.zero;
      _totalDuration = Duration.zero;
      _remaining = Duration.zero;
    }

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
          if (_mode == ProductivityMode.focus) {
            // Count UP
            _elapsed += const Duration(seconds: 1);
          } else {
            // Count DOWN (pomodoro)
            _remaining -= const Duration(seconds: 1);
            if (_remaining.isNegative || _remaining == Duration.zero) {
              _timer?.cancel();
              _onTimerComplete();
            }
          }
        });
        // Update notification every 30 seconds
        final seconds = _mode == ProductivityMode.focus
            ? _elapsed.inSeconds
            : _remaining.inSeconds;
        if (seconds % 30 == 0) {
          _updateNotification();
        }
      }
    });
  }

  void _onTimerComplete() {
    HapticFeedback.heavyImpact();

    if (_mode == ProductivityMode.pomodoro && !_isBreak) {
      // Work session complete
      final session = TimerSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        activityId: _linkedActivityId ?? 'productivity_pomodoro',
        startTime: _startTime ?? DateTime.now().subtract(_totalDuration),
        endTime: DateTime.now(),
        duration: _totalDuration,
        type: TimerSessionType.pomodoro,
      );
      TimerService.addSession(session);

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
      _showCompletionAlert(
        title: 'Break Complete! 💪',
        message: 'Ready for another focus session?',
        isBreak: true,
      );
      _stopTimer(save: false);
    }
    // Timer (count-up) mode never auto-completes
  }

  void _showCompletionAlert({
    required String title,
    required String message,
    required bool isBreak,
  }) {
    TimerNotificationHelper.showCompletionNotification(
      title: title,
      body: message,
      isBreakComplete: isBreak,
    );
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

    if (save && _isRunning) {
      final duration = _mode == ProductivityMode.focus
          ? _elapsed
          : _totalDuration - _remaining;

      if (duration.inSeconds > 60) {
        final session = TimerSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          activityId: _linkedActivityId ??
              (_mode == ProductivityMode.pomodoro
                  ? 'productivity_pomodoro'
                  : 'productivity_timer'),
          startTime: _startTime ?? DateTime.now().subtract(duration),
          endTime: DateTime.now(),
          duration: duration,
          type: _mode == ProductivityMode.pomodoro
              ? TimerSessionType.pomodoro
              : TimerSessionType.countdown,
        );
        TimerService.addSession(session);

        // Show encouraging message for longer focus sessions
        if (_mode == ProductivityMode.focus && duration.inMinutes >= 15 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Great session — stretch and breathe.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }

    _isRunning = false;
    _isPaused = false;
    _isBreak = false;
    _remaining = Duration.zero;
    _elapsed = Duration.zero;
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
        : 'Focus';

    TimerNotificationHelper.showTimerNotification(
      activityName: label,
      remaining: _mode == ProductivityMode.focus ? _elapsed : _remaining,
      isPomodoro: _mode == ProductivityMode.pomodoro,
      isBreak: _isBreak,
      isPaused: _isPaused,
    );
  }

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Container(
      decoration: BoxDecoration(
        borderRadius: AppStyles.borderRadiusLarge,
        color: AppColors.homeCardBackground,
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: widget.onNavigateToTimers,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
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
                            _isBreak ? 'Break' : (_mode == ProductivityMode.pomodoro ? 'Focus' : 'Focus'),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: _isRunning ? _buildRunningState() : _buildIdleState(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      children: [
        // Mode selector - wrapped to prevent Dismissible from stealing taps
        GestureDetector(
          onHorizontalDragUpdate: (_) {},
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _mode = ProductivityMode.focus);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _mode == ProductivityMode.focus
                          ? AppColors.purple.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _mode == ProductivityMode.focus
                            ? AppColors.purple
                            : AppColors.grey300.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.av_timer_rounded,
                          size: 16,
                          color: _mode == ProductivityMode.focus
                              ? AppColors.purple
                              : AppColors.grey300,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Focus',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _mode == ProductivityMode.focus
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
                    : 'Counts up from 0:00',
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
    final bool isTimerMode = _mode == ProductivityMode.focus;
    final displayDuration = isTimerMode ? _elapsed : _remaining;
    final progress = isTimerMode
        ? null // No progress for count-up
        : (_totalDuration.inSeconds > 0
            ? 1 - (_remaining.inSeconds / _totalDuration.inSeconds)
            : 0.0);

    return Column(
      children: [
        Row(
          children: [
            // Circular progress / elapsed display
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isTimerMode)
                    // Pulsing ring for count-up timer
                    CircularProgressIndicator(
                      value: null, // Indeterminate
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isPaused
                            ? AppColors.grey300.withValues(alpha: 0.3)
                            : AppColors.purple.withValues(alpha: 0.6),
                      ),
                    )
                  else
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: AppColors.grey300.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isBreak ? AppColors.pastelGreen : AppColors.purple,
                      ),
                    ),
                  Text(
                    _formatTime(displayDuration),
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
                        : (isTimerMode ? 'Focus' : 'Focus Time'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _isPaused
                        ? 'Paused'
                        : isTimerMode
                            ? _formatTime(_elapsed)
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
