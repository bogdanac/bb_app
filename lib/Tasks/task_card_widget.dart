import 'package:flutter/material.dart';
import 'dart:async';
import 'tasks_data_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'task_card_utils.dart';
import 'task_completion_animation.dart';
import '../shared/date_format_utils.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final List<TaskCategory> categories;
  final VoidCallback onToggleCompletion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPostpone;
  final String? priorityReason;
  final Color? priorityColor;
  const TaskCard({
    super.key,
    required this.task,
    required this.categories,
    required this.onToggleCompletion,
    required this.onEdit,
    required this.onDelete,
    this.onPostpone,
    this.priorityReason,
    this.priorityColor,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isAtThreshold = false;
  bool _isCompleting = false;
  bool _isHoldingForPostpone = false;
  bool _isHoldingForDelete = false;
  bool _actionExecuted = false; // Prevent gesture loops after action
  bool _showPostponeConfirm = false;
  bool _showDeleteConfirm = false;
  Timer? _holdTimer;
  Timer? _confirmTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _confirmTimer?.cancel();
    super.dispose();
  }

  void _startHoldTimer(DismissDirection direction) {
    // Don't start a new timer if one is already running
    if (_holdTimer != null) return;

    if (direction == DismissDirection.startToEnd && widget.onPostpone != null) {
      setState(() => _isHoldingForPostpone = true);
      _holdTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && _isHoldingForPostpone && _isAtThreshold) {
          setState(() {
            _isHoldingForPostpone = false;
            _showPostponeConfirm = true; // Show confirmation message
          });
          _holdTimer?.cancel();
          _holdTimer = null;

          // Show confirmation for 1 second, then execute action
          _confirmTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _actionExecuted = true; // Mark action as executed
                _showPostponeConfirm = false;
              });
              widget.onPostpone!();
            }
          });
        }
      });
    } else if (direction == DismissDirection.endToStart) {
      setState(() => _isHoldingForDelete = true);
      _holdTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && _isHoldingForDelete && _isAtThreshold) {
          setState(() {
            _isHoldingForDelete = false;
            _showDeleteConfirm = true; // Show confirmation message
          });
          _holdTimer?.cancel();
          _holdTimer = null;

          // Show confirmation for 1 second, then execute action
          _confirmTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _actionExecuted = true; // Mark action as executed
                _showDeleteConfirm = false;
              });
              widget.onDelete();
            }
          });
        }
      });
    }
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _confirmTimer?.cancel();
    _holdTimer = null;
    _confirmTimer = null;
    if (mounted) {
      setState(() {
        _isAtThreshold = false;
        _isHoldingForPostpone = false;
        _isHoldingForDelete = false;
        _showPostponeConfirm = false;
        _showDeleteConfirm = false;
        // Don't reset _actionExecuted here - it needs to stay true until swipe is released
      });
    }
  }

  void _handleCompletion() {
    if (_isCompleting) return;

    // If task is already completed, toggle back immediately without animation
    if (widget.task.isCompleted) {
      widget.onToggleCompletion();
      return;
    }

    // Start completion animation for uncompleted tasks
    setState(() {
      _isCompleting = true;
    });
  }

  void _onAnimationComplete() {
    widget.onToggleCompletion();
    setState(() {
      _isCompleting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Null safety checks
    if (widget.task.title.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return TaskCompletionAnimation(
      isCompleting: _isCompleting,
      onAnimationComplete: _onAnimationComplete,
      child: Dismissible(
      key: ValueKey(widget.task.id),
      direction: widget.onPostpone != null ? DismissDirection.horizontal : DismissDirection.endToStart,
      dismissThresholds: widget.onPostpone != null ? const {
        DismissDirection.endToStart: 0.7, // Lower threshold to make swiping easier
        DismissDirection.startToEnd: 0.7, // Lower threshold for postpone
      } : const {
        DismissDirection.endToStart: 0.7, // Only delete swipe for completed tasks
      },
      confirmDismiss: (direction) async {
        return false; // Never auto-dismiss, require manual hold confirmation
      },
      onUpdate: (details) {
        final threshold = 0.7;
        final reachedThreshold = details.progress >= threshold;

        // Reset action flag when swipe is completely released
        if (details.progress == 0 && _actionExecuted) {
          setState(() {
            _actionExecuted = false;
          });
        }

        // When threshold reached, start hold detection
        if (reachedThreshold && !_isAtThreshold && _holdTimer == null && !_actionExecuted) {
          setState(() => _isAtThreshold = true);
          _startHoldTimer(details.direction);
        } else if (!reachedThreshold && _isAtThreshold && !_actionExecuted && !_showPostponeConfirm && !_showDeleteConfirm) {
          // Cancel hold if swipe is released before threshold (but not if action was executed or confirmation is showing)
          _cancelHoldTimer();
        }
      },
      background: widget.onPostpone != null ? Container(
        decoration: BoxDecoration(
          color: _showPostponeConfirm
              ? AppColors.successGreen
              : _isHoldingForPostpone
                  ? AppColors.yellow
                  : AppColors.yellow.withValues(alpha: 0.8),
          borderRadius: AppStyles.borderRadiusLarge,
          boxShadow: (_isHoldingForPostpone || _showPostponeConfirm) ? [
            BoxShadow(
              color: (_showPostponeConfirm ? AppColors.successGreen : AppColors.yellow).withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 0,
            )
          ] : null,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showPostponeConfirm
                  ? Icons.check_circle_rounded
                  : _isHoldingForPostpone
                      ? Icons.timer_rounded
                      : Icons.schedule_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              _showPostponeConfirm
                  ? 'Postponed!'
                  : _isHoldingForPostpone
                      ? 'Hold to Postpone'
                      : 'Postpone',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ) : Container(), // Empty container instead of null to satisfy Flutter requirement
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: _showDeleteConfirm
              ? AppColors.successGreen
              : _isHoldingForDelete
                  ? AppColors.deleteRed
                  : AppColors.deleteRed.withValues(alpha: 0.8),
          borderRadius: AppStyles.borderRadiusLarge,
          boxShadow: (_isHoldingForDelete || _showDeleteConfirm) ? [
            BoxShadow(
              color: (_showDeleteConfirm ? AppColors.successGreen : AppColors.deleteRed).withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 0,
            )
          ] : null,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showDeleteConfirm
                  ? Icons.check_circle_rounded
                  : _isHoldingForDelete
                      ? Icons.timer_rounded
                      : Icons.delete_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              _showDeleteConfirm
                  ? 'Deleted!'
                  : _isHoldingForDelete
                      ? 'Hold to Delete'
                      : 'Delete',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: widget.task.isImportant ? 6 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: AppStyles.borderRadiusLarge,
          side: widget.task.isImportant
              ? BorderSide(color: AppColors.coral.withValues(alpha: 0.3), width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onEdit,
          borderRadius: AppStyles.borderRadiusLarge,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppStyles.borderRadiusLarge,
              color: AppColors.normalCardBackground,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Title and content (expanded)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.task.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      decoration: widget.task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: widget.task.isCompleted
                                          ? AppColors.greyText
                                          : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // All labels directly after title
                            if (widget.task.deadline != null || widget.task.reminderTime != null || widget.task.recurrence != null || widget.task.categoryIds.isNotEmpty || widget.task.isDueToday() || (widget.priorityReason != null && widget.priorityReason!.isNotEmpty)) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 3,
                                children: [
                                  // Priority chip (highest priority)
                                  if (widget.priorityReason != null && widget.priorityReason!.isNotEmpty)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.today_rounded,
                                      widget.priorityReason!,
                                      widget.priorityColor ?? Colors.orange,
                                    ),
                                  // Scheduled date chip (show when different from priority)
                                  if (TaskCardUtils.getScheduledDateText(widget.task, widget.priorityReason ?? '') != null)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.event_rounded,
                                      'Scheduled ${TaskCardUtils.getScheduledDateText(widget.task, widget.priorityReason ?? '')}',
                                      AppColors.successGreen,
                                    ),
                                  if (widget.task.deadline != null && !widget.task.isDueToday())
                                    TaskCardUtils.buildInfoChip(
                                      Icons.schedule_rounded,
                                      DateFormatUtils.formatShort(widget.task.deadline!),
                                      TaskCardUtils.getDeadlineColor(widget.task.deadline!),
                                    ),
                                  if (widget.task.reminderTime != null)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.notifications_rounded,
                                      DateFormatUtils.formatTime24(widget.task.reminderTime!),
                                      TaskCardUtils.getReminderColor(widget.task.reminderTime!),
                                    ),
                                  if (widget.task.recurrence != null)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.repeat_rounded,
                                      widget.task.recurrence!.reminderTime != null
                                          ? '${TaskCardUtils.getShortRecurrenceText(widget.task.recurrence!)} ${widget.task.recurrence!.reminderTime!.format(context)}'
                                          : TaskCardUtils.getShortRecurrenceText(widget.task.recurrence!),
                                      AppColors.pink,
                                    ),
                                  if (widget.task.categoryIds.isNotEmpty) ...[
                                    ...widget.task.categoryIds.map((categoryId) {
                                      try {
                                        final category = widget.categories.firstWhere(
                                              (cat) => cat.id == categoryId,
                                        );
                                        return TaskCardUtils.buildCategoryChip(
                                          category.name,
                                          category.color,
                                        );
                                      } catch (e) {
                                        // Skip deleted categories instead of showing "Unknown"
                                        return null;
                                      }
                                    }).where((chip) => chip != null).cast<Widget>(),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Checkbox on the right
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _handleCompletion,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: widget.task.isCompleted,
                              onChanged: (_) => _handleCompletion(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              activeColor: AppColors.coral,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

}