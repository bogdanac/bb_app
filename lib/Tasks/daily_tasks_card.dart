import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../Tasks/tasks_data_models.dart';
import '../Tasks/task_service.dart';
import '../Tasks/todo_screen.dart';
import '../Tasks/task_edit_screen.dart';

class DailyTasksCard extends StatefulWidget {
  const DailyTasksCard({Key? key}) : super(key: key);

  @override
  State<DailyTasksCard> createState() => _DailyTasksCardState();
}

class _DailyTasksCardState extends State<DailyTasksCard> {
  List<Task> _prioritizedTasks = [];
  List<TaskCategory> _categories = [];
  final TaskService _taskService = TaskService();
  TaskSettings _taskSettings = TaskSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    // Refresh periodically to update reminders and time-sensitive priorities
    _startPeriodicRefresh();
  }

  Timer? _refreshTimer;

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _loadTasks(); // Refresh every minute to update time-sensitive reminders
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _taskService.loadTasks();
      final categories = await _taskService.loadCategories();
      final settings = await _taskService.loadTaskSettings();

      final prioritized = _taskService.getPrioritizedTasks(
          tasks,
          categories,
          settings.maxTasksOnHomePage
      );

      if (mounted) {
        setState(() {
          _prioritizedTasks = prioritized;
          _categories = categories;
          _taskSettings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      debugPrint('Toggling task completion for: ${task.title}');
      
      // Update task completion status
      final wasCompleted = task.isCompleted;
      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? DateTime.now() : null;

      // Update the local state immediately for animation
      setState(() {
        final localIndex = _prioritizedTasks.indexWhere((t) => t.id == task.id);
        if (localIndex != -1) {
          _prioritizedTasks[localIndex] = task;
        }
      });

      // Save tasks
      final allTasks = await _taskService.loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        allTasks[taskIndex] = task;
        await _taskService.saveTasks(allTasks);
        debugPrint('Task saved successfully: ${task.title} - ${task.isCompleted}');
      } else {
        debugPrint('Task not found in all tasks list: ${task.id}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              task.isCompleted
                  ? 'Task completed! 🎉'
                  : 'Task marked as incomplete',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: task.isCompleted ? Colors.green : Colors.orange,
          ),
        );
      }

      // If task is completed, wait for animation then remove from list
      if (task.isCompleted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          setState(() {
            _prioritizedTasks.removeWhere((t) => t.id == task.id);
          });
        }
      } else {
        // If uncompleted, reload to get updated priority list
        await _loadTasks();
      }
      
    } catch (e) {
      debugPrint('Error toggling task completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _editTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          task: task,
          categories: _categories,
          onSave: (updatedTask) async {
            // Update the task in the list
            final allTasks = await _taskService.loadTasks();
            final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
            if (taskIndex != -1) {
              allTasks[taskIndex] = updatedTask;
              await _taskService.saveTasks(allTasks);
            }
            // Reload the tasks display
            await _loadTasks();
          },
        ),
      ),
    );
  }

  String _getTaskPriorityReason(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check reminder time - highest priority display
    if (task.reminderTime != null) {
      final reminderDiff = task.reminderTime!.difference(now).inMinutes;
      if (reminderDiff <= 15 && reminderDiff >= -15) {
        if (reminderDiff <= 0) {
          return 'Reminder now!';
        } else {
          return 'Reminder in ${reminderDiff}m';
        }
      } else if (reminderDiff <= 60 && reminderDiff >= -30) {
        if (reminderDiff <= 0) {
          return 'Reminder ${(-reminderDiff)}m ago';
        } else {
          return 'Reminder in ${reminderDiff}m';
        }
      } else if (reminderDiff <= 120 && reminderDiff >= -60) {
        if (reminderDiff <= 0) {
          return 'Reminder past';
        } else {
          return 'Reminder in ${(reminderDiff / 60).round()}h';
        }
      }
    }

    // Check deadline today
    if (task.deadline != null &&
        DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)
            .isAtSameMomentAs(today)) {
      return 'Due today';
    }

    // Check overdue deadlines
    if (task.deadline != null && 
        task.deadline!.isBefore(today)) {
      final daysPast = today.difference(DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)).inDays;
      if (daysPast == 1) {
        return 'Overdue (1 day)';
      } else if (daysPast <= 7) {
        return 'Overdue ($daysPast days)';
      } else {
        return 'Overdue';
      }
    }

    // Check recurring
    if (task.recurrence != null && task.isDueToday()) {
      return 'Recurring today';
    }

    // Check deadline tomorrow
    final tomorrow = today.add(const Duration(days: 1));
    if (task.deadline != null &&
        DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day)
            .isAtSameMomentAs(tomorrow)) {
      return 'Due tomorrow';
    }

    // Check important
    if (task.isImportant) {
      return 'Important';
    }

    return '';
  }

  Color _getPriorityColor(String reason) {
    if (reason.contains('Reminder now!') || reason.contains('Reminder in') && reason.endsWith('m')) {
      final minutes = int.tryParse(reason.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      if (minutes <= 15) {
        return Colors.red; // Urgent - very close reminder
      } else if (minutes <= 60) {
        return Colors.deepOrange; // High priority - close reminder
      }
      return Colors.orange; // Medium priority reminder
    }
    
    switch (reason) {
      case 'Due today':
      case 'Reminder now!':
        return Colors.red;
      case 'Recurring today':
        return Colors.orange;
      case 'Due tomorrow':
        return Colors.amber;
      case 'Important':
        return Theme.of(context).colorScheme.primary;
      default:
        if (reason.contains('Overdue')) {
          return Colors.red.shade700; // Dark red for overdue
        }
        if (reason.contains('Reminder')) {
          return Colors.orange;
        }
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.coral.withOpacity(0.08), // More subtle coral
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TodoScreen()),
          ).then((_) => _loadTasks()); // Reload when returning
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    color: AppColors.coral, // Coral instead of pink
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Today\'s Priority Tasks',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_prioritizedTasks.isEmpty)
                const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: Colors.green,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All caught up! 🎉',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No priority tasks for today',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _prioritizedTasks.map((task) {
                    final priorityReason = _getTaskPriorityReason(task);
                    final priorityColor = _getPriorityColor(priorityReason);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      height: task.isCompleted ? 0 : null,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: task.isCompleted ? 0.0 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: priorityColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _editTask(task),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: task.isCompleted ? Colors.white60 : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (priorityReason.isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2
                                              ),
                                              decoration: BoxDecoration(
                                                color: priorityColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                priorityReason,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: priorityColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (task.categoryIds.isNotEmpty) ...[
                                            ...task.categoryIds.take(2).map((categoryId) {
                                              final category = _categories.firstWhere(
                                                    (cat) => cat.id == categoryId,
                                                orElse: () => TaskCategory(
                                                    id: '',
                                                    name: '?',
                                                    color: Colors.white70,
                                                    order: 0
                                                ),
                                              );
                                              return Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: category.color.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    category.name,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: category.color,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (task.isImportant)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 16,
                                  ),
                                ),
                              GestureDetector(
                                onTap: () => _toggleTaskCompletion(task),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Transform.scale(
                                    scale: 1.2,
                                    child: Checkbox(
                                      value: task.isCompleted,
                                      onChanged: (_) => _toggleTaskCompletion(task),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      activeColor: AppColors.coral,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              if (_prioritizedTasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Tap to view all tasks',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}