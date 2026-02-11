import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/snackbar_utils.dart';
import '../Energy/energy_service.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';
import 'timer_notification_helper.dart';
import 'add_activity_dialog.dart';
import 'edit_activity_dialog.dart';
import 'activity_detail_screen.dart';
import 'timer_global_history_screen.dart';
import 'productivity_assistant.dart';

class TimersScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const TimersScreen({super.key, this.onOpenDrawer});

  @override
  State<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends State<TimersScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Activity> _activities = [];
  bool _isLoading = true;

  // --- Productivity tab state ---
  bool _isFocusMode = false; // Focus = count-up timer (formerly "countdown")
  String? _selectedActivityId;
  Duration _focusElapsed = Duration.zero; // Elapsed time for focus count-up mode
  int _workMinutes = 25;
  int _breakMinutes = 5;
  Duration _remainingTime = const Duration(minutes: 25);
  bool _isRunning = false;
  bool _isPomodoroBreak = false;
  int _pomodoroCount = 0;
  Timer? _timer;
  DateTime? _sessionStartTime;
  Duration _accumulatedWorkTime = Duration.zero;
  bool _productivityTimerActive = false;
  bool _autoFlowMode = true; // Auto-continue without breaks (default ON)
  bool _isInFlowState = false; // Currently in flow (past initial work time)
  Duration _flowExtraTime = Duration.zero; // Time beyond the work period
  Set<int> _reachedMilestones = {}; // Track which milestones we've celebrated (in minutes)

  // Flow stats
  int _longestFlowSession = 0;
  int _totalFlowTime = 0;

  // --- Activities tab state ---
  String? _runningActivityId;
  Timer? _activityTimer;
  Duration _activityElapsed = Duration.zero;
  DateTime? _activityStartTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _activityTimer?.cancel();
    if (_productivityTimerActive || _runningActivityId != null) {
      _saveActiveTimerState();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _activities = await TimerService.loadActivities();
    _workMinutes = await TimerService.getPomodoroWorkMinutes();
    _breakMinutes = await TimerService.getPomodoroBreakMinutes();
    _autoFlowMode = await TimerService.getAutoFlowMode();
    _remainingTime = _isFocusMode ? Duration.zero : Duration(minutes: _workMinutes);

    // Load flow stats
    final flowStats = await TimerService.getFlowStats();
    _longestFlowSession = flowStats['longestSession'] ?? 0;
    _totalFlowTime = flowStats['totalTime'] ?? 0;

    await _restoreActiveTimer();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Active timer persistence ---

  Future<void> _saveActiveTimerState() async {
    if (_productivityTimerActive) {
      await TimerService.saveActiveTimerState({
        'type': 'productivity',
        'activityId': _selectedActivityId,
        'startedAt': _sessionStartTime?.toIso8601String(),
        'mode': _isFocusMode ? 'countdown' : 'pomodoro',
        'wasRunning': _isRunning,
        'remainingSeconds': _remainingTime.inSeconds,
        'accumulatedWorkSeconds': _accumulatedWorkTime.inSeconds,
        'isPomodoroBreak': _isPomodoroBreak,
        'pomodoroCount': _pomodoroCount,
        'isInFlowState': _isInFlowState,
        'flowExtraSeconds': _flowExtraTime.inSeconds,
        'savedAt': DateTime.now().toIso8601String(),
      });
    } else if (_runningActivityId != null) {
      await TimerService.saveActiveTimerState({
        'type': 'activity',
        'activityId': _runningActivityId,
        'startedAt': _activityStartTime?.toIso8601String(),
        'elapsed': _activityElapsed.inSeconds,
        'wasRunning': true,
        'savedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _restoreActiveTimer() async {
    final state = await TimerService.loadActiveTimerState();
    if (state == null) return;

    try {
      final savedAt = DateTime.parse(state['savedAt']);
      final timeSinceSave = DateTime.now().difference(savedAt);

      if (state['type'] == 'productivity') {
        _selectedActivityId = state['activityId'];
        _isFocusMode = state['mode'] == 'countdown';
        _isPomodoroBreak = state['isPomodoroBreak'] ?? false;
        _pomodoroCount = state['pomodoroCount'] ?? 0;
        _isInFlowState = state['isInFlowState'] ?? false;
        _flowExtraTime = Duration(seconds: state['flowExtraSeconds'] ?? 0);
        _accumulatedWorkTime =
            Duration(seconds: state['accumulatedWorkSeconds'] ?? 0);
        _sessionStartTime = state['startedAt'] != null
            ? DateTime.parse(state['startedAt'])
            : null;

        final savedRemaining = Duration(seconds: state['remainingSeconds'] ?? 0);

        if (state['wasRunning'] == true) {
          if (_isFocusMode) {
            // Focus mode: count-up — add time since save
            _focusElapsed = _accumulatedWorkTime + timeSinceSave;
            _accumulatedWorkTime += timeSinceSave;
            _productivityTimerActive = true;
            _startProductivityTicker();
          } else if (_isInFlowState) {
            // Restore flow state - add time since save
            _flowExtraTime += timeSinceSave;
            _accumulatedWorkTime += timeSinceSave;
            _productivityTimerActive = true;
            _startFlowTicker();
          } else {
            final adjusted = savedRemaining - timeSinceSave;
            if (adjusted.inSeconds <= 0) {
              // Timer would have completed while away
              if (!_isPomodoroBreak) {
                _accumulatedWorkTime += savedRemaining;
              }
              _saveProductivitySession();
              await TimerService.clearActiveTimerState();
              _resetProductivityTimer();
              return;
            }
            _remainingTime = adjusted;
            if (!_isPomodoroBreak) {
              _accumulatedWorkTime += timeSinceSave;
            }
            _productivityTimerActive = true;
            _startProductivityTicker();
          }
        } else {
          if (_isFocusMode) {
            _focusElapsed = _accumulatedWorkTime;
          } else {
            _remainingTime = savedRemaining;
          }
          _productivityTimerActive = true;
        }
      } else if (state['type'] == 'activity') {
        _runningActivityId = state['activityId'];
        _activityStartTime = state['startedAt'] != null
            ? DateTime.parse(state['startedAt'])
            : null;
        final savedElapsed = Duration(seconds: state['elapsed'] ?? 0);

        if (state['wasRunning'] == true) {
          _activityElapsed = savedElapsed + timeSinceSave;
          _startActivityTicker();
        } else {
          _activityElapsed = savedElapsed;
        }
      }
    } catch (_) {
      await TimerService.clearActiveTimerState();
    }
  }

  // --- Productivity timer ---

  void _startProductivityTimer() {
    if (_runningActivityId != null) {
      _stopActivityTimer(save: true);
    }
    _sessionStartTime ??= DateTime.now();
    _isRunning = true;
    _productivityTimerActive = true;
    _startProductivityTicker();
    _updateProductivityNotification();
    _saveActiveTimerState();
    setState(() {});
  }

  void _startProductivityTicker() {
    _isRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isFocusMode) {
        // Focus mode: count UP
        setState(() {
          _focusElapsed += const Duration(seconds: 1);
          _accumulatedWorkTime += const Duration(seconds: 1);
        });
        if (_focusElapsed.inSeconds % 30 == 0) {
          _updateProductivityNotification();
        }
      } else {
        // Pomodoro mode: count DOWN
        if (_remainingTime.inSeconds <= 0) {
          _onProductivityTimerComplete();
          return;
        }
        setState(() {
          _remainingTime -= const Duration(seconds: 1);
          if (!_isPomodoroBreak) {
            _accumulatedWorkTime += const Duration(seconds: 1);
          }
        });
        if (_remainingTime.inSeconds % 30 == 0) {
          _updateProductivityNotification();
        }
      }
    });
  }

  void _pauseProductivityTimer() {
    _timer?.cancel();
    _isRunning = false;
    _saveActiveTimerState();
    TimerNotificationHelper.cancelTimerNotification();
    setState(() {});
  }

  Future<void> _resetProductivityTimer() async {
    _timer?.cancel();
    _isRunning = false;
    _isPomodoroBreak = false;
    _productivityTimerActive = false;
    _pomodoroCount = 0;
    _accumulatedWorkTime = Duration.zero;
    _sessionStartTime = null;
    _isInFlowState = false;
    _flowExtraTime = Duration.zero;
    _reachedMilestones = {};
    _focusElapsed = Duration.zero;
    _remainingTime = _isFocusMode ? Duration.zero : Duration(minutes: _workMinutes);
    await TimerService.clearActiveTimerState();
    await TimerNotificationHelper.cancelTimerNotification();
    if (mounted) setState(() {});
  }

  void _onProductivityTimerComplete() {
    _timer?.cancel();

    if (_isFocusMode) {
      // Focus mode never auto-completes (count-up), this shouldn't be called
      return;
    } else {
      // Pomodoro mode
      if (_isPomodoroBreak) {
        // Break over → show dialog to let user choose
        _isRunning = false;
        setState(() {});
        _showBreakCompleteDialog();
      } else {
        // Work over
        if (_autoFlowMode) {
          // Auto-flow mode: continue counting UP
          _isInFlowState = true;
          _flowExtraTime = Duration.zero;
          _pomodoroCount++;
          _startFlowTicker();
          _updateProductivityNotification();
          // Haptic feedback for entering flow state
          HapticFeedback.heavyImpact();
          if (mounted) {
            SnackBarUtils.showSuccess(context, 'Flow mode activated!');
          }
        } else {
          // Normal mode: save session and show dialog
          _saveProductivitySession();
          _isRunning = false;
          setState(() {});
          _showPomodoroCompleteDialog();
        }
      }
    }
    setState(() {});
  }

  // Flow milestones (in minutes of total accumulated work time)
  static const List<int> _flowMilestones = [50, 75, 100, 120, 150, 180];

  void _startFlowTicker() {
    _timer?.cancel();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _flowExtraTime += const Duration(seconds: 1);
        _accumulatedWorkTime += const Duration(seconds: 1);
      });

      // Check for milestone celebrations
      final totalMinutes = _accumulatedWorkTime.inMinutes;
      for (final milestone in _flowMilestones) {
        if (totalMinutes >= milestone && !_reachedMilestones.contains(milestone)) {
          _reachedMilestones.add(milestone);
          _showMilestoneCelebration(milestone);
          break; // Only show one milestone at a time
        }
      }

      if (_flowExtraTime.inSeconds % 30 == 0) {
        _updateProductivityNotification();
      }
    });
  }

  void _showMilestoneCelebration(int minutes) {
    if (!mounted) return;

    // Haptic feedback for milestone
    HapticFeedback.mediumImpact();

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    String title;
    String message;
    int owlExcitement; // 1-3 scale

    if (minutes >= 120) {
      title = 'LEGENDARY!';
      message = '$timeStr of pure focus! You\'re unstoppable!';
      owlExcitement = 3;
    } else if (minutes >= 100) {
      title = 'INCREDIBLE!';
      message = '$timeStr milestone! You\'re a focus master!';
      owlExcitement = 3;
    } else if (minutes >= 75) {
      title = 'AMAZING!';
      message = '$timeStr of deep work! Keep the flow going!';
      owlExcitement = 2;
    } else {
      title = 'AWESOME!';
      message = '$timeStr focused! You\'re in the zone!';
      owlExcitement = 1;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FlowMilestoneDialog(
        title: title,
        message: message,
        minutes: minutes,
        excitementLevel: owlExcitement,
        onContinue: () => Navigator.pop(context),
      ),
    );
  }

  void _pauseFlowTimer() {
    _timer?.cancel();
    _isRunning = false;
    _saveActiveTimerState();
    TimerNotificationHelper.cancelTimerNotification();
    setState(() {});
  }

  void _resumeFlowTimer() {
    _startFlowTicker();
    _updateProductivityNotification();
    _saveActiveTimerState();
  }

  void _stopFlowAndSave() async {
    // Record flow stats before resetting
    if (_isInFlowState && _accumulatedWorkTime.inMinutes > 0) {
      await TimerService.recordFlowSession(_accumulatedWorkTime.inMinutes);
      // Refresh stats
      final flowStats = await TimerService.getFlowStats();
      _longestFlowSession = flowStats['longestSession'] ?? 0;
      _totalFlowTime = flowStats['totalTime'] ?? 0;
    }

    _saveProductivitySession();
    _resetProductivityTimer();
  }

  void _showFlowModeHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: Row(
          children: [
            Icon(Icons.local_fire_department_rounded, color: AppColors.orange),
            const SizedBox(width: 8),
            const Text('Flow Mode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When enabled, the timer automatically continues after your focus period ends.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.greyText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _buildFlowHelpItem(
              Icons.timer_rounded,
              'Auto-continue',
              'No interruptions when you\'re in the zone',
            ),
            const SizedBox(height: 8),
            _buildFlowHelpItem(
              Icons.trending_up_rounded,
              'Count up',
              'See how long you\'ve been focused (+26:00, +27:00...)',
            ),
            const SizedBox(height: 8),
            _buildFlowHelpItem(
              Icons.pause_rounded,
              'Pause anytime',
              'Take a break without losing your session',
            ),
            const SizedBox(height: 8),
            _buildFlowHelpItem(
              Icons.check_circle_rounded,
              'Finish when ready',
              'Stop and save your extended session',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: AppStyles.textButtonStyle(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.orange, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPomodoroCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PomodoroCompleteDialog(
        completedPomodoros: _pomodoroCount + 1,
        totalWorkTime: Duration(minutes: (_pomodoroCount + 1) * _workMinutes),
        onTakeBreak: () {
          _isPomodoroBreak = true;
          _pomodoroCount++;
          _remainingTime = Duration(minutes: _breakMinutes);
          _startProductivityTicker();
          _updateProductivityNotification();
        },
        onContinueFocus: () {
          // Skip break and continue with another focus session
          _isPomodoroBreak = false;
          _pomodoroCount++;
          _remainingTime = Duration(minutes: _workMinutes);
          _startProductivityTicker();
          _updateProductivityNotification();
        },
        onStop: () {
          _resetProductivityTimer();
        },
      ),
    );
  }

  void _showBreakCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProductivityAssistant(
              state: AssistantState.encouraging,
              message: "Break's over! Ready to focus?",
              size: 100,
            ),
            const SizedBox(height: 16),
            Text(
              'Break Complete',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.lime,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _isPomodoroBreak = false;
                  _remainingTime = Duration(minutes: _workMinutes);
                  _startProductivityTicker();
                  _updateProductivityNotification();
                },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Start Focus'),
                style: AppStyles.elevatedButtonStyle(
                  backgroundColor: AppColors.purple,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetProductivityTimer();
                },
                style: AppStyles.textButtonStyle(),
                child: Text(
                  'Stop for now',
                  style: TextStyle(color: AppColors.greyText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveProductivitySession() {
    if (_selectedActivityId == null || _accumulatedWorkTime.inSeconds == 0) {
      return;
    }
    final session = TimerSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityId: _selectedActivityId!,
      startTime: _sessionStartTime ?? DateTime.now(),
      endTime: DateTime.now(),
      duration: _accumulatedWorkTime,
      type: _isFocusMode
          ? TimerSessionType.countdown
          : TimerSessionType.pomodoro,
    );
    TimerService.addSession(session);

    // Track energy for timer session
    final activity = _activities.firstWhere(
      (a) => a.id == _selectedActivityId,
      orElse: () => Activity(id: '', name: 'Unknown'),
    );
    if (activity.id.isNotEmpty) {
      EnergyService.addTimerSessionEnergyConsumption(
        sessionId: session.id,
        activityName: activity.name,
        batteryPer25Min: activity.batteryChangePer25Min,
        durationMinutes: _accumulatedWorkTime.inMinutes,
      );
    }

    _accumulatedWorkTime = Duration.zero;
    _sessionStartTime = DateTime.now();
  }

  void _updateProductivityNotification() {
    final activityName = _activities
            .where((a) => a.id == _selectedActivityId)
            .map((a) => a.name)
            .firstOrNull ??
        'Timer';

    if (_isInFlowState) {
      // Use flow-specific notification
      TimerNotificationHelper.showFlowNotification(
        activityName: activityName,
        flowExtra: _flowExtraTime,
        totalTime: _accumulatedWorkTime,
        isPaused: !_isRunning,
      );
    } else {
      TimerNotificationHelper.showTimerNotification(
        activityName: activityName,
        remaining: _isFocusMode ? _focusElapsed : _remainingTime,
        isPomodoro: !_isFocusMode,
        isBreak: _isPomodoroBreak,
        isPaused: !_isRunning,
      );
    }
  }

  // --- Activity timer (stopwatch) ---

  void _startActivityTimer(String activityId) {
    if (_productivityTimerActive && _isRunning) {
      _pauseProductivityTimer();
    }
    if (_runningActivityId != null && _runningActivityId != activityId) {
      _stopActivityTimer(save: true);
    }

    _runningActivityId = activityId;
    _activityStartTime = DateTime.now();
    _activityElapsed = Duration.zero;
    _startActivityTicker();
    _updateActivityNotification();
    _saveActiveTimerState();
    setState(() {});
  }

  void _startActivityTicker() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _activityElapsed += const Duration(seconds: 1);
      });
      if (_activityElapsed.inSeconds % 30 == 0) {
        _updateActivityNotification();
      }
    });
  }

  void _stopActivityTimer({required bool save}) {
    _activityTimer?.cancel();
    if (save && _runningActivityId != null && _activityElapsed.inSeconds > 0) {
      final session = TimerSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        activityId: _runningActivityId!,
        startTime: _activityStartTime ?? DateTime.now(),
        endTime: DateTime.now(),
        duration: _activityElapsed,
        type: TimerSessionType.activity,
      );
      TimerService.addSession(session);

      // Track energy for activity timer
      final activity = _activities.firstWhere(
        (a) => a.id == _runningActivityId,
        orElse: () => Activity(id: '', name: 'Unknown'),
      );
      if (activity.id.isNotEmpty) {
        EnergyService.addTimerSessionEnergyConsumption(
          sessionId: session.id,
          activityName: activity.name,
          batteryPer25Min: activity.batteryChangePer25Min,
          durationMinutes: _activityElapsed.inMinutes,
        );
      }
    }
    _runningActivityId = null;
    _activityElapsed = Duration.zero;
    _activityStartTime = null;
    TimerNotificationHelper.cancelTimerNotification();
    TimerService.clearActiveTimerState();
    setState(() {});
  }

  void _updateActivityNotification() {
    final activityName = _activities
            .where((a) => a.id == _runningActivityId)
            .map((a) => a.name)
            .firstOrNull ??
        'Activity';
    TimerNotificationHelper.showActivityTimerNotification(
      activityName: activityName,
      elapsed: _activityElapsed,
    );
  }

  // --- Activity CRUD ---

  Future<void> _addActivity(Activity activity) async {
    await TimerService.addActivity(activity);
    _activities = await TimerService.loadActivities();
    setState(() {});
  }

  Future<void> _deleteActivity(String activityId) async {
    if (_runningActivityId == activityId) {
      _stopActivityTimer(save: false);
    }
    if (_selectedActivityId == activityId) {
      _selectedActivityId = null;
      if (_productivityTimerActive) {
        _resetProductivityTimer();
      }
    }
    await TimerService.deleteActivity(activityId);
    _activities = await TimerService.loadActivities();
    setState(() {});
  }

  Future<void> _editActivity(Activity activity) async {
    await EditActivityDialog.show(
      context,
      activity: activity,
      onSave: (updated) async {
        await TimerService.updateActivity(updated);
        _activities = await TimerService.loadActivities();
        setState(() {});
      },
    );
  }

  void _reorderActivities(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _activities.removeAt(oldIndex);
      _activities.insert(newIndex, item);
    });
    TimerService.saveActivities(_activities);
  }

  // --- Duration editing ---

  Future<void> _editDuration({
    required String title,
    required int currentValue,
    required ValueChanged<int> onSave,
  }) async {
    int value = currentValue;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: Text(title),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: value > 1
                    ? () => setDialogState(() => value--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.purple,
              ),
              const SizedBox(width: 16),
              Text(
                '$value min',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: value < 120
                    ? () => setDialogState(() => value++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.purple,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: AppStyles.textButtonStyle(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, value),
              style: AppStyles.elevatedButtonStyle(
                  backgroundColor: AppColors.purple),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      onSave(result);
    }
  }

  // --- Format helpers ---

  String _formatTimer(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
              )
            : null,
        title: const Text('Timers'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_tabController.index == 1) ...[
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'All Activities History',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimerGlobalHistoryScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => AddActivityDialog.show(
                context,
                onAdd: _addActivity,
              ),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.purple,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.white,
              unselectedLabelColor: AppColors.lightPurple,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Productivity'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Activities'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductivityTab(),
                    _buildActivitiesTab(),
                  ],
                ),
        ),
      ),
    );
  }

  // --- Productivity Tab ---

  Widget _buildProductivityTab() {
    final totalSeconds = _isFocusMode
        ? 0 // Focus mode: count-up, no total
        : (_isPomodoroBreak ? _breakMinutes * 60 : _workMinutes * 60);
    final progress = _isFocusMode
        ? null // No progress for count-up
        : (totalSeconds > 0 ? _remainingTime.inSeconds / totalSeconds : 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mode toggle
          Container(
            decoration: AppStyles.cardDecoration(),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _productivityTimerActive
                        ? null
                        : () {
                            setState(() {
                              _isFocusMode = false;
                              _remainingTime =
                                  Duration(minutes: _workMinutes);
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isFocusMode
                          ? AppColors.purple.withValues(alpha: _productivityTimerActive ? 0.1 : 0.25)
                          : Colors.transparent,
                      foregroundColor: !_isFocusMode
                          ? AppColors.purple
                          : AppColors.grey300,
                      disabledBackgroundColor: !_isFocusMode
                          ? AppColors.purple.withValues(alpha: 0.1)
                          : Colors.transparent,
                      disabledForegroundColor: !_isFocusMode
                          ? AppColors.purple.withValues(alpha: 0.5)
                          : AppColors.grey300.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusMedium,
                        side: !_isFocusMode
                            ? BorderSide(
                                color: AppColors.purple.withValues(alpha: _productivityTimerActive ? 0.2 : 0.5),
                                width: 1.5,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      'Pomodoro',
                      style: TextStyle(
                        fontWeight: !_isFocusMode
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _productivityTimerActive
                        ? null
                        : () {
                            setState(() {
                              _isFocusMode = true;
                              _focusElapsed = Duration.zero;
                              _remainingTime = Duration.zero;
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFocusMode
                          ? AppColors.purple.withValues(alpha: _productivityTimerActive ? 0.1 : 0.25)
                          : Colors.transparent,
                      foregroundColor: _isFocusMode
                          ? AppColors.purple
                          : AppColors.grey300,
                      disabledBackgroundColor: _isFocusMode
                          ? AppColors.purple.withValues(alpha: 0.1)
                          : Colors.transparent,
                      disabledForegroundColor: _isFocusMode
                          ? AppColors.purple.withValues(alpha: 0.5)
                          : AppColors.grey300.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusMedium,
                        side: _isFocusMode
                            ? BorderSide(
                                color: AppColors.purple.withValues(alpha: _productivityTimerActive ? 0.2 : 0.5),
                                width: 1.5,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      'Focus',
                      style: TextStyle(
                        fontWeight: _isFocusMode
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Activity selector
          Container(
            decoration: AppStyles.cardDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedActivityId,
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: 'Activity (optional)',
              ),
              dropdownColor: AppColors.normalCardBackground,
              items: _activities
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ))
                  .toList(),
              onChanged: _productivityTimerActive
                  ? null
                  : (value) {
                      setState(() {
                        _selectedActivityId = value;
                      });
                    },
            ),
          ),
          const SizedBox(height: 24),

          // Timer settings
          if (!_isFocusMode) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeChip(
                  label: 'Work',
                  minutes: _workMinutes,
                  onTap: _productivityTimerActive
                      ? null
                      : () => _editDuration(
                            title: 'Work Duration',
                            currentValue: _workMinutes,
                            onSave: (v) {
                              setState(() {
                                _workMinutes = v;
                                if (!_isPomodoroBreak) {
                                  _remainingTime = Duration(minutes: v);
                                }
                              });
                              TimerService.setPomodoroWorkMinutes(v);
                            },
                          ),
                ),
                const SizedBox(width: 12),
                _buildTimeChip(
                  label: 'Break',
                  minutes: _breakMinutes,
                  onTap: _productivityTimerActive
                      ? null
                      : () => _editDuration(
                            title: 'Break Duration',
                            currentValue: _breakMinutes,
                            onSave: (v) {
                              setState(() {
                                _breakMinutes = v;
                              });
                              TimerService.setPomodoroBreakMinutes(v);
                            },
                          ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Auto Flow Mode toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _productivityTimerActive
                      ? null
                      : () {
                          setState(() {
                            _autoFlowMode = !_autoFlowMode;
                          });
                          TimerService.setAutoFlowMode(_autoFlowMode);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _autoFlowMode
                          ? AppColors.yellow.withValues(alpha: 0.2)
                          : AppColors.grey700.withValues(alpha: 0.3),
                      borderRadius: AppStyles.borderRadiusMedium,
                      border: Border.all(
                        color: _autoFlowMode
                            ? AppColors.yellow.withValues(alpha: 0.5)
                            : AppColors.grey700.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: _autoFlowMode ? AppColors.orange : AppColors.grey300,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Flow Mode',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _autoFlowMode ? AppColors.orange : AppColors.grey300,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _autoFlowMode ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: _autoFlowMode ? AppColors.orange : AppColors.grey300,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showFlowModeHelp,
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 20,
                    color: AppColors.grey300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              'Counts up from 0:00',
              style: TextStyle(
                color: AppColors.grey200,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Circular timer display
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: _isFocusMode ? null : (_isInFlowState ? 1.0 : (progress ?? 0.0).clamp(0.0, 1.0)),
                    strokeWidth: 8,
                    backgroundColor: AppColors.grey700,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isInFlowState
                          ? AppColors.yellow
                          : _isPomodoroBreak
                              ? AppColors.lime
                              : AppColors.purple,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isFocusMode)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isInFlowState)
                            Icon(
                              Icons.local_fire_department_rounded,
                              color: AppColors.orange,
                              size: 16,
                            ),
                          if (_isInFlowState) const SizedBox(width: 4),
                          Text(
                            _isInFlowState
                                ? 'IN THE FLOW'
                                : _isPomodoroBreak
                                    ? 'BREAK'
                                    : 'FOCUS #${_pomodoroCount + 1}',
                            style: TextStyle(
                              color: _isInFlowState
                                  ? AppColors.orange
                                  : _isPomodoroBreak
                                      ? AppColors.lime
                                      : AppColors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    Text(
                      _isFocusMode
                          ? _formatTimer(_focusElapsed)
                          : _isInFlowState
                              ? '+${_formatTimer(_flowExtraTime)}'
                              : _formatTimer(_remainingTime),
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: _isFocusMode
                            ? AppColors.purple
                            : _isInFlowState ? AppColors.yellow : null,
                      ),
                    ),
                    if (_isInFlowState)
                      Text(
                        'Total: ${_formatTimer(_accumulatedWorkTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.greyText,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_productivityTimerActive)
                IconButton(
                  onPressed: _isInFlowState
                      ? _stopFlowAndSave
                      : _resetProductivityTimer,
                  icon: const Icon(Icons.stop_rounded),
                  iconSize: 40,
                  color: _isInFlowState ? AppColors.orange : AppColors.grey200,
                ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (_isInFlowState) {
                    // Flow mode: pause/resume or finish
                    if (_isRunning) {
                      _pauseFlowTimer();
                    } else {
                      _resumeFlowTimer();
                    }
                  } else {
                    // Normal mode
                    if (_isRunning) {
                      _pauseProductivityTimer();
                    } else {
                      _startProductivityTimer();
                    }
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _isInFlowState ? AppColors.orange : AppColors.purple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              // Finish button when in flow mode (paused)
              if (_isInFlowState && !_isRunning) ...[
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _stopFlowAndSave,
                  icon: const Icon(Icons.check_circle_rounded),
                  iconSize: 40,
                  color: AppColors.successGreen,
                  tooltip: 'Finish session',
                ),
              ],
            ],
          ),

          // Productivity assistant tip
          if (_productivityTimerActive) ...[
            const SizedBox(height: 24),
            MiniProductivityAssistant(
              state: _isInFlowState
                  ? AssistantState.inFlow
                  : _isPomodoroBreak
                      ? AssistantState.resting
                      : AssistantState.working,
            ),
          ],

          // Flow stats (show when not running or in flow mode)
          if (!_productivityTimerActive || _isInFlowState) ...[
            const SizedBox(height: 24),
            _buildFlowStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildFlowStats() {
    if (_longestFlowSession == 0 && _totalFlowTime == 0) {
      return const SizedBox.shrink();
    }

    String formatTime(int minutes) {
      if (minutes >= 60) {
        final h = minutes ~/ 60;
        final m = minutes % 60;
        return m > 0 ? '${h}h ${m}m' : '${h}h';
      }
      return '${minutes}m';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.08),
        borderRadius: AppStyles.borderRadiusMedium,
        border: Border.all(
          color: AppColors.yellow.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.orange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Flow Stats',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFlowStatItem(
                  icon: Icons.emoji_events_rounded,
                  label: 'Longest Session',
                  value: formatTime(_longestFlowSession),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.yellow.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildFlowStatItem(
                  icon: Icons.timer_rounded,
                  label: 'Total Flow Time',
                  value: formatTime(_totalFlowTime),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.yellow, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.orange,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.greyText,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChip({
    required String label,
    required int minutes,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: AppStyles.cardDecorationWithBorder(
          borderColor: AppColors.purple.withValues(alpha: 0.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(color: AppColors.grey200, fontSize: 14),
            ),
            Text(
              '${minutes}m',
              style: TextStyle(
                color: AppColors.purple,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 14, color: AppColors.grey300),
            ],
          ],
        ),
      ),
    );
  }

  // --- Activities Tab ---

  Widget _buildActivitiesTab() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 48, color: AppColors.grey300),
            const SizedBox(height: 12),
            Text(
              'No activities yet',
              style: TextStyle(color: AppColors.grey200, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => AddActivityDialog.show(
                context,
                onAdd: _addActivity,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Activity'),
              style: AppStyles.elevatedButtonStyle(
                  backgroundColor: AppColors.purple),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      onReorder: _reorderActivities,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 4,
          shadowColor: Colors.black26,
          borderRadius: AppStyles.borderRadiusMedium,
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final activity = _activities[index];
        final isRunning = _runningActivityId == activity.id;

        return Dismissible(
          key: Key('activity_${activity.id}'),
          direction: DismissDirection.endToStart,
          dismissThresholds: const {DismissDirection.endToStart: 0.4},
          confirmDismiss: (_) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.dialogBackground,
                title: const Text('Delete Activity'),
                content: Text(
                    'Delete "${activity.name}" and all its history?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: AppStyles.textButtonStyle(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: AppStyles.elevatedButtonStyle(
                        backgroundColor: AppColors.deleteRed),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            return confirm == true;
          },
          onDismissed: (_) => _deleteActivity(activity.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.deleteRed.withValues(alpha: 0.2),
              borderRadius: AppStyles.borderRadiusMedium,
            ),
            child: Icon(Icons.delete, color: AppColors.deleteRed),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: AppStyles.cardDecoration(),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle,
                      color: AppColors.grey300, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isRunning)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatElapsed(_activityElapsed),
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  onPressed: () => _editActivity(activity),
                  icon: Icon(Icons.edit_outlined,
                      color: AppColors.grey200, size: 20),
                  tooltip: 'Edit',
                ),
                // Details button
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ActivityDetailScreen(activity: activity),
                    ),
                  ),
                  icon: Icon(Icons.info_outline,
                      color: AppColors.grey200, size: 22),
                  tooltip: 'Details',
                ),
                // Play/Stop button
                IconButton(
                  onPressed: () {
                    if (isRunning) {
                      _stopActivityTimer(save: true);
                    } else {
                      _startActivityTimer(activity.id);
                    }
                  },
                  icon: Icon(
                    isRunning
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    color: isRunning ? AppColors.deleteRed : AppColors.purple,
                    size: 28,
                  ),
                  tooltip: isRunning ? 'Stop' : 'Start',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
