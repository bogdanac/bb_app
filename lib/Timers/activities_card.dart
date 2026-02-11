import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';
import 'timer_notification_helper.dart';

class ActivitiesCard extends StatefulWidget {
  final VoidCallback? onNavigateToTimers;

  const ActivitiesCard({super.key, this.onNavigateToTimers});

  @override
  State<ActivitiesCard> createState() => _ActivitiesCardState();
}

class _ActivitiesCardState extends State<ActivitiesCard> {
  List<Activity> _activities = [];
  bool _isExpanded = false;
  bool _isLoading = true;

  // Running activity timer state
  String? _runningActivityId;
  Timer? _activityTimer;
  Duration _activityElapsed = Duration.zero;
  DateTime? _activityStartTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    if (_runningActivityId != null) {
      _saveActiveTimerState();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final activities = await TimerService.loadActivities();
    await _restoreActiveTimer();

    if (mounted) {
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreActiveTimer() async {
    final state = await TimerService.loadActiveTimerState();
    if (state == null) return;

    try {
      if (state['type'] == 'activity') {
        final savedAt = DateTime.parse(state['savedAt']);
        final timeSinceSave = DateTime.now().difference(savedAt);

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
      // Ignore restore errors
    }
  }

  Future<void> _saveActiveTimerState() async {
    if (_runningActivityId != null) {
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

  void _startActivityTimer(String activityId) {
    HapticFeedback.lightImpact();

    // Stop any running timer first
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
      if (mounted) {
        setState(() {
          _activityElapsed += const Duration(seconds: 1);
        });
        if (_activityElapsed.inSeconds % 30 == 0) {
          _updateActivityNotification();
        }
      }
    });
  }

  void _stopActivityTimer({required bool save}) {
    HapticFeedback.lightImpact();
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

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_activities.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show max 3 activities when collapsed, all when expanded
    final displayActivities = _isExpanded
        ? _activities
        : _activities.take(3).toList();
    final hasMore = _activities.length > 3;

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
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_rounded,
                    color: AppColors.purple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Activities',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_runningActivityId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.purple,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatElapsed(_activityElapsed),
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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

          // Activities list
          ...displayActivities.map((activity) {
            final isRunning = _runningActivityId == activity.id;
            return _buildActivityRow(activity, isRunning);
          }),

          // Expand/collapse button
          if (hasMore)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded
                          ? 'Show less'
                          : 'Show ${_activities.length - 3} more',
                      style: TextStyle(
                        color: AppColors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

          if (!hasMore)
            const SizedBox(height: 4),
        ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(Activity activity, bool isRunning) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isRunning ? FontWeight.w600 : FontWeight.w500,
                    color: isRunning ? AppColors.purple : null,
                  ),
                ),
                if (isRunning)
                  Text(
                    _formatElapsed(_activityElapsed),
                    style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          // Play/Stop button
          GestureDetector(
            onTap: () {
              if (isRunning) {
                _stopActivityTimer(save: true);
              } else {
                _startActivityTimer(activity.id);
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isRunning
                    ? AppColors.deleteRed.withValues(alpha: 0.15)
                    : AppColors.purple.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: isRunning ? AppColors.deleteRed : AppColors.purple,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
