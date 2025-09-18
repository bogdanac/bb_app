import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tasks_data_models.dart';
import '../theme/app_colors.dart';
import 'task_card_utils.dart';
import 'task_completion_animation.dart';

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
        DismissDirection.endToStart: 0.8, // Require 80% swipe left to delete
        DismissDirection.startToEnd: 0.8, // Require 80% swipe right to postpone
      } : const {
        DismissDirection.endToStart: 0.8, // Only delete swipe for completed tasks
      },
      confirmDismiss: (direction) async {
        return true; // Skip confirmation dialog
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          debugPrint('=== SWIPE DELETE: ${widget.task.title} ===');
          widget.onDelete();
        } else if (direction == DismissDirection.startToEnd && widget.onPostpone != null) {
          debugPrint('=== SWIPE POSTPONE: ${widget.task.title} ===');
          widget.onPostpone!();
        }
      },
      onUpdate: (details) {
        // Visual feedback when reaching threshold
        final threshold = 0.8;
        final reachedThreshold = details.progress >= threshold;

        if (reachedThreshold != _isAtThreshold) {
          setState(() {
            _isAtThreshold = reachedThreshold;
          });
        }
      },
      background: widget.onPostpone != null ? Container(
        decoration: BoxDecoration(
          color: _isAtThreshold ? AppColors.yellow : AppColors.yellow.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isAtThreshold ? [
            BoxShadow(
              color: AppColors.yellow.withValues(alpha: 0.6),
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
              _isAtThreshold ? Icons.check_circle : Icons.schedule_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              _isAtThreshold ? 'Ready!' : 'Postpone',
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
          color: _isAtThreshold ? AppColors.deleteRed : AppColors.deleteRed.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isAtThreshold ? [
            BoxShadow(
              color: AppColors.deleteRed.withValues(alpha: 0.6),
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
              _isAtThreshold ? Icons.delete_sweep : Icons.delete_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              _isAtThreshold ? 'Ready!' : 'Delete',
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
          borderRadius: BorderRadius.circular(16),
          side: widget.task.isImportant
              ? BorderSide(color: AppColors.coral.withValues(alpha: 0.3), width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                                      DateFormat('MMM dd').format(widget.task.deadline!),
                                      TaskCardUtils.getDeadlineColor(widget.task.deadline!),
                                    ),
                                  if (widget.task.reminderTime != null)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.notifications_rounded,
                                      DateFormat('HH:mm').format(widget.task.reminderTime!),
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