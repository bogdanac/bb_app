import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tasks_data_models.dart';
import 'task_service.dart';
import '../theme/app_colors.dart';
import 'task_card_utils.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final List<TaskCategory> categories;
  final VoidCallback onToggleCompletion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPostpone;
  const TaskCard({
    super.key,
    required this.task,
    required this.categories,
    required this.onToggleCompletion,
    required this.onEdit,
    required this.onDelete,
    this.onPostpone,
  });

  @override
  Widget build(BuildContext context) {
    // Null safety checks
    if (task.title.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.8, // Require 80% swipe to delete
      },
      confirmDismiss: (direction) async {
        return true; // Skip confirmation dialog
      },
      onDismissed: (direction) {
        onDelete();
      },
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.lightCoral,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_rounded,
              color: Colors.white,
              size: 32,
            ),
            SizedBox(height: 4),
            Text(
              'Swipe fully',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            Text(
              'to delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: task.isImportant ? 6 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: task.isImportant
              ? BorderSide(color: AppColors.coral, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: task.isImportant
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.coral.withValues(alpha: 0.05),
                  AppColors.coral.withValues(alpha: 0.02),
                ],
              )
                  : null,
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
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.isCompleted
                                          ? Colors.grey
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (task.isImportant) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.coral.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: AppColors.coral,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Important',
                                          style: TextStyle(
                                            color: AppColors.pink,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // All labels directly after title
                            if (task.deadline != null || task.reminderTime != null || task.recurrence != null || task.categoryIds.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 3,
                                children: [
                                  if (task.deadline != null)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.schedule_rounded,
                                      DateFormat('MMM dd').format(task.deadline!),
                                      TaskCardUtils.getDeadlineColor(task.deadline!),
                                    ),
                                  if (task.reminderTime != null)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.notifications_rounded,
                                      DateFormat('HH:mm').format(task.reminderTime!),
                                      TaskCardUtils.getReminderColor(task.reminderTime!),
                                    ),
                                  if (task.recurrence != null)
                                    TaskCardUtils.buildInfoChip(
                                      Icons.repeat_rounded,
                                      TaskCardUtils.getShortRecurrenceText(task.recurrence!),
                                      AppColors.pink,
                                    ),
                                  if (task.categoryIds.isNotEmpty) ...[
                                    ...task.categoryIds.map((categoryId) {
                                      final category = categories.firstWhere(
                                            (cat) => cat.id == categoryId,
                                        orElse: () => TaskCategory(
                                            id: '',
                                            name: 'Unknown',
                                            color: Colors.grey,
                                            order: 0
                                        ),
                                      );
                                      return TaskCardUtils.buildCategoryChip(
                                        category.name,
                                        category.color,
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Postpone button for tasks due today
                      if (TaskService.isTaskDueToday(task) && !task.isCompleted && onPostpone != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1),
                            ),
                            child: InkWell(
                              onTap: () {
                                debugPrint('Postpone button tapped for task: ${task.title}');
                                onPostpone!();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(
                                  Icons.skip_next_rounded,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Checkbox on the right
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onToggleCompletion,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: task.isCompleted,
                              onChanged: (_) => onToggleCompletion(),
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
    );
  }

}