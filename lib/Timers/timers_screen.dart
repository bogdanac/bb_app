import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/snackbar_utils.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';
import 'timer_notification_helper.dart';
import 'add_activity_dialog.dart';
import 'activity_detail_screen.dart';

class TimersScreen extends StatefulWidget {
  const TimersScreen({super.key});

  @override
  State<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends State<TimersScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Activity> _activities = [];
  bool _isLoading = true;

  // --- Productivity tab state ---
  bool _isCountdownMode = true;
  String? _selectedActivityId;
  int _countdownMinutes = 25;
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
    _countdownMinutes = await TimerService.getCountdownMinutes();
    _workMinutes = await TimerService.getPomodoroWorkMinutes();
    _breakMinutes = await TimerService.getPomodoroBreakMinutes();
    _remainingTime = Duration(minutes: _isCountdownMode ? _countdownMinutes : _workMinutes);

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
        'mode': _isCountdownMode ? 'countdown' : 'pomodoro',
        'wasRunning': _isRunning,
        'remainingSeconds': _remainingTime.inSeconds,
        'accumulatedWorkSeconds': _accumulatedWorkTime.inSeconds,
        'isPomodoroBreak': _isPomodoroBreak,
        'pomodoroCount': _pomodoroCount,
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
        _isCountdownMode = state['mode'] == 'countdown';
        _isPomodoroBreak = state['isPomodoroBreak'] ?? false;
        _pomodoroCount = state['pomodoroCount'] ?? 0;
        _accumulatedWorkTime =
            Duration(seconds: state['accumulatedWorkSeconds'] ?? 0);
        _sessionStartTime = state['startedAt'] != null
            ? DateTime.parse(state['startedAt'])
            : null;

        final savedRemaining = Duration(seconds: state['remainingSeconds'] ?? 0);

        if (state['wasRunning'] == true) {
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
        } else {
          _remainingTime = savedRemaining;
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
    });
  }

  void _pauseProductivityTimer() {
    _timer?.cancel();
    _isRunning = false;
    _saveActiveTimerState();
    _updateProductivityNotification();
    setState(() {});
  }

  void _resetProductivityTimer() {
    _timer?.cancel();
    _isRunning = false;
    _isPomodoroBreak = false;
    _productivityTimerActive = false;
    _pomodoroCount = 0;
    _accumulatedWorkTime = Duration.zero;
    _sessionStartTime = null;
    _remainingTime = Duration(
        minutes: _isCountdownMode ? _countdownMinutes : _workMinutes);
    TimerService.clearActiveTimerState();
    TimerNotificationHelper.cancelTimerNotification();
    setState(() {});
  }

  void _onProductivityTimerComplete() {
    _timer?.cancel();

    if (_isCountdownMode) {
      // Countdown done
      _saveProductivitySession();
      _isRunning = false;
      _productivityTimerActive = false;
      TimerNotificationHelper.cancelTimerNotification();
      TimerService.clearActiveTimerState();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Timer complete!');
      }
    } else {
      // Pomodoro mode
      if (_isPomodoroBreak) {
        // Break over → start work
        _isPomodoroBreak = false;
        _pomodoroCount++;
        _remainingTime = Duration(minutes: _workMinutes);
        _startProductivityTicker();
        _updateProductivityNotification();
      } else {
        // Work over → save session, start break
        _saveProductivitySession();
        _isPomodoroBreak = true;
        _remainingTime = Duration(minutes: _breakMinutes);
        _startProductivityTicker();
        _updateProductivityNotification();
        if (mounted) {
          SnackBarUtils.showInfo(context, 'Break time!');
        }
      }
    }
    setState(() {});
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
      type: _isCountdownMode
          ? TimerSessionType.countdown
          : TimerSessionType.pomodoro,
    );
    TimerService.addSession(session);
    _accumulatedWorkTime = Duration.zero;
    _sessionStartTime = DateTime.now();
  }

  void _updateProductivityNotification() {
    final activityName = _activities
            .where((a) => a.id == _selectedActivityId)
            .map((a) => a.name)
            .firstOrNull ??
        'Timer';
    TimerNotificationHelper.showTimerNotification(
      activityName: activityName,
      remaining: _remainingTime,
      isPomodoro: !_isCountdownMode,
      isBreak: _isPomodoroBreak,
      isPaused: !_isRunning,
    );
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
        title: const Text('Timers'),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AddActivityDialog(onAdd: _addActivity),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.purple,
          labelColor: AppColors.purple,
          unselectedLabelColor: AppColors.grey200,
          tabs: const [
            Tab(text: 'Productivity'),
            Tab(text: 'Activities'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductivityTab(),
                _buildActivitiesTab(),
              ],
            ),
    );
  }

  // --- Productivity Tab ---

  Widget _buildProductivityTab() {
    final totalSeconds = _isCountdownMode
        ? _countdownMinutes * 60
        : (_isPomodoroBreak ? _breakMinutes * 60 : _workMinutes * 60);
    final progress =
        totalSeconds > 0 ? _remainingTime.inSeconds / totalSeconds : 0.0;

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
                  child: GestureDetector(
                    onTap: _productivityTimerActive
                        ? null
                        : () {
                            setState(() {
                              _isCountdownMode = true;
                              _remainingTime =
                                  Duration(minutes: _countdownMinutes);
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isCountdownMode
                            ? AppColors.purple.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                      child: Center(
                        child: Text(
                          'Countdown',
                          style: TextStyle(
                            color: _isCountdownMode
                                ? AppColors.purple
                                : AppColors.grey200,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _productivityTimerActive
                        ? null
                        : () {
                            setState(() {
                              _isCountdownMode = false;
                              _remainingTime =
                                  Duration(minutes: _workMinutes);
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isCountdownMode
                            ? AppColors.purple.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                      child: Center(
                        child: Text(
                          'Pomodoro',
                          style: TextStyle(
                            color: !_isCountdownMode
                                ? AppColors.purple
                                : AppColors.grey200,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
          if (!_isCountdownMode) ...[
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
            const SizedBox(height: 16),
          ] else ...[
            GestureDetector(
              onTap: _productivityTimerActive
                  ? null
                  : () => _editDuration(
                        title: 'Countdown Duration',
                        currentValue: _countdownMinutes,
                        onSave: (v) {
                          setState(() {
                            _countdownMinutes = v;
                            _remainingTime = Duration(minutes: v);
                          });
                          TimerService.setCountdownMinutes(v);
                        },
                      ),
              child: Text(
                '$_countdownMinutes min',
                style: TextStyle(
                  color: AppColors.grey200,
                  fontSize: 14,
                ),
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
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: AppColors.grey700,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isPomodoroBreak
                          ? AppColors.lime
                          : AppColors.purple,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isCountdownMode)
                      Text(
                        _isPomodoroBreak ? 'BREAK' : 'FOCUS #${_pomodoroCount + 1}',
                        style: TextStyle(
                          color: _isPomodoroBreak
                              ? AppColors.lime
                              : AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      _formatTimer(_remainingTime),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
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
                  onPressed: _resetProductivityTimer,
                  icon: const Icon(Icons.stop_rounded),
                  iconSize: 40,
                  color: AppColors.grey200,
                ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (_isRunning) {
                    _pauseProductivityTimer();
                  } else {
                    _startProductivityTimer();
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.purple,
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
            ],
          ),
        ],
      ),
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
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AddActivityDialog(onAdd: _addActivity),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
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
