import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tasks_data_models.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final List<TaskCategory> categories;
  final VoidCallback onToggleCompletion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;

  const TaskCard({
    super.key,
    required this.task,
    required this.categories,
    required this.onToggleCompletion,
    required this.onEdit,
    required this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return true; // Skip confirmation dialog
      },
      onDismissed: (direction) {
        onDelete();
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.red,
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
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: task.isImportant ? 6 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: task.isImportant
              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
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
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.02),
                ],
              )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Duplicate button on the left
                      if (onDuplicate != null) ...[
                        IconButton(
                          onPressed: onDuplicate,
                          icon: const Icon(Icons.copy_rounded),
                          tooltip: 'Duplicate',
                          iconSize: 20,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Title and content in the middle (expanded)
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.isCompleted
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ),
                                if (task.isImportant) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Important',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
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
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Checkbox on the right
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: task.isCompleted,
                          onChanged: (_) => onToggleCompletion(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),

              // Time and recurrence info
              if (task.deadline != null || task.reminderTime != null || task.recurrence != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (task.deadline != null)
                      _buildInfoChip(
                        Icons.schedule_rounded,
                        DateFormat('MMM dd').format(task.deadline!),
                        _getDeadlineColor(task.deadline!),
                      ),
                    if (task.reminderTime != null)
                      _buildInfoChip(
                        Icons.notifications_rounded,
                        DateFormat('HH:mm').format(task.reminderTime!),
                        _getReminderColor(task.reminderTime!),
                      ),
                    if (task.recurrence != null)
                      _buildInfoChip(
                        Icons.repeat_rounded,
                        _getShortRecurrenceText(task.recurrence!),
                        Theme.of(context).colorScheme.secondary,
                      ),
                  ],
                ),
              ],

              // Categories
              if (task.categoryIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: task.categoryIds.map((categoryId) {
                    final category = categories.firstWhere(
                          (cat) => cat.id == categoryId,
                      orElse: () => TaskCategory(
                          id: '',
                          name: 'Unknown',
                          color: Colors.grey,
                          order: 0
                      ),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: category.color.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: category.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getShortRecurrenceText(TaskRecurrence recurrence) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
        return recurrence.interval == 1 ? 'Daily' : '${recurrence.interval}d';
      case RecurrenceType.weekly:
        return recurrence.interval == 1 ? 'Weekly' : '${recurrence.interval}w';
      case RecurrenceType.monthly:
        return recurrence.interval == 1 ? 'Monthly' : '${recurrence.interval}m';
      case RecurrenceType.custom:
        return 'Custom';
    }
  }

  Color _getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    final difference = deadlineDay.difference(today).inDays;

    if (difference < 0) return Colors.red;
    if (difference == 0) return Colors.orange;
    if (difference == 1) return Colors.amber;
    return Colors.blue;
  }

  Color _getReminderColor(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now).inMinutes;

    if (difference < -30) return Colors.grey; // Past
    if (difference <= 0) return Colors.red; // Now or just passed
    if (difference <= 60) return Colors.orange; // Within an hour
    return Colors.blue; // Future
  }
}