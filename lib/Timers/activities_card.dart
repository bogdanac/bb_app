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
  State<ActivitiesCard> createState() => ActivitiesCardState();
}

class ActivitiesCardState extends State<ActivitiesCard> {
  /// Refresh activities data from outside (e.g., when returning to Home tab)
  void refresh() => _loadData();
  List<Activity> _activities = [];
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

    // Sort by most used (session count)
    final sessions = await TimerService.loadSessions();
    final sessionCounts = <String, int>{};
    for (final s in sessions) {
      sessionCounts[s.activityId] = (sessionCounts[s.activityId] ?? 0) + 1;
    }
    activities.sort((a, b) =>
        (sessionCounts[b.id] ?? 0).compareTo(sessionCounts[a.id] ?? 0));

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

  Color _modeColor(Activity activity) {
    switch (activity.energyMode) {
      case ActivityEnergyMode.recharging: return AppColors.successGreen;
      case ActivityEnergyMode.draining: return AppColors.orange;
      case ActivityEnergyMode.neutral: return AppColors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _activities.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayActivities = _activities.take(3).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusLarge,
          color: AppColors.homeCardBackground,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — matches food card style
            GestureDetector(
              onTap: widget.onNavigateToTimers,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded, color: AppColors.purple, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _runningActivityId != null ? 'Timer running' : 'Activities',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_runningActivityId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatElapsed(_activityElapsed),
                              style: TextStyle(color: AppColors.purple, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(Icons.chevron_right_rounded, color: AppColors.grey300, size: 20),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.white24),

            // Activity rows
            ...displayActivities.map((activity) => _buildActivityRow(activity)),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(Activity activity) {
    final isRunning = _runningActivityId == activity.id;
    final color = _modeColor(activity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
      child: Row(
        children: [
          // Energy mode dot
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isRunning ? color : color.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Activity name
          Expanded(
            child: Text(
              activity.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isRunning ? FontWeight.w600 : FontWeight.w400,
                color: isRunning ? color : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Circle play/stop button
          GestureDetector(
            onTap: () => isRunning ? _stopActivityTimer(save: true) : _startActivityTimer(activity.id),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: (isRunning ? AppColors.deleteRed : color).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: isRunning ? AppColors.deleteRed : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
