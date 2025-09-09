import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../Tasks/tasks_data_models.dart';
import '../Tasks/task_service.dart';
import '../Tasks/todo_screen.dart';
import '../Tasks/task_edit_screen.dart';
import '../Tasks/task_card_utils.dart';
import '../Tasks/task_completion_animation.dart';

class DailyTasksCard extends StatefulWidget {
  const DailyTasksCard({super.key});

  @override
  State<DailyTasksCard> createState() => _DailyTasksCardState();
}

class _DailyTasksCardState extends State<DailyTasksCard> {
  List<Task> _prioritizedTasks = [];
  List<TaskCategory> _categories = [];
  final TaskService _taskService = TaskService();
  bool _isLoading = true;
  final Set<String> _completingTasks = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
    // Refresh periodically to update reminders and time-sensitive priorities
    _startPeriodicRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this screen
    _loadTasks();
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

      // Filter to only show non-completed tasks (like TodoScreen's default behavior)
      final filteredTasks = tasks.where((task) => !task.isCompleted).toList();
      
      // Further filter to exclude tasks that are clearly postponed (have future deadlines with no current relevance)
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final relevantTasks = filteredTasks.where((task) {
        // Always include tasks without deadlines
        if (task.deadline == null) return true;
        
        // Always include overdue tasks
        final deadlineDate = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
        if (deadlineDate.isBefore(todayDate)) return true;
        
        // Include tasks due today
        if (deadlineDate.isAtSameMomentAs(todayDate)) return true;
        
        // For recurring tasks with future deadlines, check if they're naturally due today
        if (task.recurrence != null) {
          return task.recurrence!.isDueOn(today, taskCreatedAt: task.createdAt);
        }
        
        // Exclude tasks with future deadlines (likely postponed)
        return false;
      }).toList();

      final prioritized = _taskService.getPrioritizedTasks(
          relevantTasks,
          categories,
          settings.maxTasksOnHomePage,
          includeCompleted: false
      );

      if (mounted) {
        setState(() {
          _prioritizedTasks = prioritized;
          _categories = categories;
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
      debugPrint('=== DAILY TASKS TOGGLE COMPLETION DEBUG ===');
      debugPrint('Task: ${task.title}');
      debugPrint('Current completion status: ${task.isCompleted}');
      debugPrint('Toggling to: ${!task.isCompleted}');
      
      final newCompletionStatus = !task.isCompleted;
      
      // If completing a task, start completion animation
      if (newCompletionStatus) {
        setState(() {
          _completingTasks.add(task.id);
        });
      }
      
      // Handle recurring task completion logic
      if (!task.isCompleted && task.recurrence != null) {
        await _handleRecurringTaskCompletion(task);
      } else {
        // Normal toggle for non-recurring tasks or uncompleting tasks
        task.isCompleted = !task.isCompleted;
        task.completedAt = task.isCompleted ? DateTime.now() : null;

        // Update the local state immediately for animation
        setState(() {
          final localIndex = _prioritizedTasks.indexWhere((t) => t.id == task.id);
          if (localIndex != -1) {
            _prioritizedTasks[localIndex] = task;
          }
        });

        // Save tasks - load fresh data to avoid conflicts
        final allTasks = await _taskService.loadTasks();
        final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
        if (taskIndex != -1) {
          // Update the task with completion status and timestamp
          allTasks[taskIndex].isCompleted = task.isCompleted;
          allTasks[taskIndex].completedAt = task.completedAt;
          await _taskService.saveTasks(allTasks);
          debugPrint('Task saved successfully: ${task.title} - ${task.isCompleted}');
          debugPrint('=== END DAILY TASKS TOGGLE DEBUG ===');
        } else {
          debugPrint('Task not found in all tasks list: ${task.id}');
        }
      }


      // If task is completed, wait for animation then reload full task list
      if (task.isCompleted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          // Reload full task list instead of just removing from local list
          await _loadTasks();
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

  void _onCompletionAnimationFinished(String taskId) {
    if (mounted) {
      setState(() {
        _completingTasks.remove(taskId);
      });
    }
  }

  Future<void> _handleRecurringTaskCompletion(Task task) async {
    // Mark current task as completed
    task.isCompleted = true;
    task.completedAt = DateTime.now();

    // Update the local state immediately for animation
    setState(() {
      final localIndex = _prioritizedTasks.indexWhere((t) => t.id == task.id);
      if (localIndex != -1) {
        _prioritizedTasks[localIndex] = task;
      }
    });

    // Get next due date for the recurring task
    final nextDueDate = task.recurrence!.getNextDueDate(DateTime.now());
    
    if (nextDueDate != null) {
      // Load fresh task list
      final allTasks = await _taskService.loadTasks();
      
      // Update current task
      final currentTaskIndex = allTasks.indexWhere((t) => t.id == task.id);
      if (currentTaskIndex != -1) {
        allTasks[currentTaskIndex] = task;
      }
      
      // Check if next instance already exists to prevent duplicates
      final existingNextTask = allTasks.where((t) => 
        t.title == task.title && 
        t.recurrence != null &&
        t.deadline != null &&
        t.deadline!.year == nextDueDate.year &&
        t.deadline!.month == nextDueDate.month &&
        t.deadline!.day == nextDueDate.day &&
        !t.isCompleted
      ).toList();
      
      if (existingNextTask.isEmpty) {
        // Create new instance for next occurrence only if it doesn't exist
        final nextTask = Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: task.title,
          description: task.description,
          categoryIds: List.from(task.categoryIds),
          deadline: nextDueDate,
          reminderTime: task.reminderTime != null && task.deadline != null
              ? _calculateNextReminderTime(task.reminderTime!, task.deadline!, nextDueDate)
              : null,
          isImportant: task.isImportant,
          recurrence: task.recurrence,
          isCompleted: false,
        );
        
        // Add next instance
        allTasks.add(nextTask);
        
        debugPrint('Created next recurring task instance for: ${nextDueDate.toString()}');
      } else {
        debugPrint('Next recurring task instance already exists for: ${nextDueDate.toString()}');
      }
      
      await _taskService.saveTasks(allTasks);
    } else {
      // Just mark as completed if no next date found
      final allTasks = await _taskService.loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
      
      if (taskIndex != -1) {
        allTasks[taskIndex] = task;
        await _taskService.saveTasks(allTasks);
      }
    }


    // If task is completed, wait for animation then reload full task list
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _loadTasks();
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
            debugPrint('Updating task - Original ID: ${task.id}, Updated ID: ${updatedTask.id}');

            // Update the task in the list
            final allTasks = await _taskService.loadTasks();
            final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
            
            debugPrint('Found task at index: $taskIndex out of ${allTasks.length} tasks');
            
            if (taskIndex != -1) {
              allTasks[taskIndex] = updatedTask;
              await _taskService.saveTasks(allTasks);
              debugPrint('Task updated successfully');
            } else {
              // This shouldn't happen, but handle it just in case
              debugPrint('Task not found for update: ${task.id}. Adding as new task.');
              allTasks.add(updatedTask);
              await _taskService.saveTasks(allTasks);
            }
            
            // Reload the tasks display
            await _loadTasks();
            
            // Task updated silently - no snackbar needed
          },
        ),
      ),
    );
  }

  Future<void> _postponeTask(Task task) async {
    try {
      debugPrint('Postponing task: ${task.title}');
      await _taskService.postponeTaskToTomorrow(task);
      debugPrint('Task postponed, reloading tasks...');
      await _loadTasks(); // Reload to reflect changes
      debugPrint('Tasks reloaded. New task count: ${_prioritizedTasks.length}');
      
      // Removed postpone snackbar notification as requested
    } catch (e) {
      debugPrint('Error postponing task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to postpone task: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
      // For recurring tasks, it's more of a habit/reminder than a deadline
      if (task.recurrence != null) {
        return 'Scheduled today';
      } else {
        return 'Due today';
      }
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

    // Check recurring - but not for postponed tasks
    if (task.recurrence != null && task.isDueToday()) {
      // If task has deadline for today or future (postponed), don't show as "recurring today"
      if (task.deadline != null && !task.deadline!.isBefore(today)) {
        // This is a postponed recurring task, don't show as "recurring today"
      } else {
        return 'Recurring today';
      }
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
      case 'Scheduled today':
        return Colors.blue; // Less urgent than "Due today"
      case 'Recurring today':
        return Colors.orange;
      case 'Due tomorrow':
        return Colors.amber;
      case 'Important':
        return AppColors.pink;
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

  // Calculate reminder time for next recurring instance, preserving the relative offset
  DateTime? _calculateNextReminderTime(DateTime originalReminder, DateTime originalDeadline, DateTime nextDeadline) {
    try {
      // Calculate the offset in days between original reminder and deadline
      final originalReminderDate = DateTime(originalReminder.year, originalReminder.month, originalReminder.day);
      final originalDeadlineDate = DateTime(originalDeadline.year, originalDeadline.month, originalDeadline.day);
      final dayOffset = originalReminderDate.difference(originalDeadlineDate).inDays;
      
      // Apply the same offset to the next deadline
      final nextReminderDate = DateTime(nextDeadline.year, nextDeadline.month, nextDeadline.day + dayOffset);
      
      // Keep the same time of day
      return DateTime(
        nextReminderDate.year,
        nextReminderDate.month,
        nextReminderDate.day,
        originalReminder.hour,
        originalReminder.minute,
      );
    } catch (e) {
      // Fallback to simple time transfer if calculation fails
      return DateTime(nextDeadline.year, nextDeadline.month, nextDeadline.day,
                     originalReminder.hour, originalReminder.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.coral.withValues(alpha: 0.1),
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TodoScreen()),
              ).then((_) => _loadTasks()); // Reload when returning
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 48), // Extra bottom padding for plus button
              child: Column(
                children: [

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
                    
                    // Check if this task is completing
                    final isCompleting = _completingTasks.contains(task.id);

                    Widget taskWidget = AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      height: task.isCompleted && !isCompleting ? 0 : null,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: task.isCompleted && !isCompleting ? 0.0 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: priorityColor.withValues(alpha: 0.3),
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
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 3,
                                        children: [
                                          if (priorityReason.isNotEmpty) 
                                            TaskCardUtils.buildInfoChip(
                                              Icons.priority_high_rounded,
                                              priorityReason,
                                              priorityColor,
                                            ),
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
                                              AppColors.purple,
                                            ),
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
                                              return TaskCardUtils.buildCategoryChip(
                                                category.name,
                                                category.color,
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
                                    color: AppColors.pink,
                                    size: 16,
                                  ),
                                ),
                              // Postpone button for tasks due today
                              if (TaskService.isTaskDueToday(task) && !task.isCompleted)
                                Padding(
                                  padding: const EdgeInsets.only(right: 0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        debugPrint('Postpone button tapped for task: ${task.title}');
                                        _postponeTask(task);
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
                    
                    return TaskCompletionAnimation(
                      key: ValueKey('animation_${task.id}'),
                      isCompleting: isCompleting,
                      onAnimationComplete: () => _onCompletionAnimationFinished(task.id),
                      child: taskWidget,
                    );
                  }).toList(),
                ),

                ],
              ),
            ),
          ),
          // Discreet plus button in bottom right corner
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskEditScreen(
                          categories: _categories,
                          onSave: (newTask) async {
                            final allTasks = await _taskService.loadTasks();
                            
                            // Check if task already exists (to prevent duplicates)
                            final existingIndex = allTasks.indexWhere((t) => t.id == newTask.id);
                            if (existingIndex != -1) {
                              allTasks[existingIndex] = newTask;
                            } else {
                              allTasks.add(newTask);
                            }
                            
                            await _taskService.saveTasks(allTasks);
                            await _loadTasks();
                          },
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}