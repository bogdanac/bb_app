import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'tasks_data_models.dart';
import 'task_card_widget.dart';
import 'task_categories_screen.dart';
import 'task_edit_screen.dart';
import 'task_service.dart';
import 'task_completion_animation.dart';
import '../theme/app_colors.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with WidgetsBindingObserver {
  List<Task> _tasks = [];
  List<TaskCategory> _categories = [];
  List<String> _selectedCategoryFilters = [];
  bool _showCompleted = false;
  bool _showAllTasks = false; // Bypass menstrual cycle filtering
  final TaskService _taskService = TaskService();
  final Set<String> _completingTasks = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      // Refresh data when app comes back to foreground
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await _loadCategories();
    await _loadCategoryFilters();
    await _loadTasks();
  }

  Future<void> _refreshTasks() async {
    if (kDebugMode) {
      print('Refreshing tasks...');
    }
    await _loadData();
  }

  Future<void> _loadCategories() async {
    final categories = await _taskService.loadCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
      });
    }
  }

  Future<void> _loadCategoryFilters() async {
    final savedFilters = await _taskService.loadSelectedCategoryFilters();
    if (mounted) {
      setState(() {
        _selectedCategoryFilters = savedFilters;
      });
    }
  }

  Future<void> _saveCategoryFilters() async {
    await _taskService.saveSelectedCategoryFilters(_selectedCategoryFilters);
  }

  Future<void> _loadTasks() async {
    final tasks = await _taskService.loadTasks();
    
    // Debug: Examine each loaded task
    if (kDebugMode) {
      print('=== LOADING TASKS DEBUG ===');
      print('Total tasks loaded: ${tasks.length}');
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        print('Task $i:');
        print('  ID: ${task.id}');
        print('  Title: "${task.title}" (length: ${task.title.length}, trimmed: ${task.title.trim().length})');
        print('  Description: "${task.description}"');
        print('  Completed: ${task.isCompleted}');
        print('  Important: ${task.isImportant}');
        print('  Categories: ${task.categoryIds}');
        print('  Created: ${task.createdAt}');
        
        // Check for potential issues
        if (task.title.trim().isEmpty) {
          print('  ⚠️  WARNING: Empty title!');
        }
        if (task.id.isEmpty) {
          print('  ⚠️  WARNING: Empty ID!');
        }
      }
      print('=== END LOADING DEBUG ===');
    }
    
    if (mounted) {
      setState(() {
        _tasks = tasks;
      });
    }
  }

  Future<void> _saveCategories() async {
    await _taskService.saveCategories(_categories);
  }

  void _addTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          categories: _categories,
          initialCategoryIds: _selectedCategoryFilters.isNotEmpty ? _selectedCategoryFilters : null,
          onSave: (task) async {

            // Load fresh task list and add/update the task
            final allTasks = await _taskService.loadTasks();
            final existingIndex = allTasks.indexWhere((t) => t.id == task.id);
            
            if (existingIndex != -1) {
              allTasks[existingIndex] = task;
            } else {
              allTasks.add(task);
            }
            
            await _taskService.saveTasks(allTasks);
            
            // Reload local list to stay synchronized
            await _loadTasks();
            
            // Task added silently - no snackbar needed
          },
        ),
      ),
    );
  }

  void _editTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          task: task,
          categories: _categories,
          onSave: (updatedTask) async {
            if (kDebugMode) {
              print('=== TODO SCREEN EDIT TASK DEBUG ===');
              print('Original task ID: ${task.id}');
              print('Updated task ID: ${updatedTask.id}');
              print('Tasks before update: ${_tasks.length}');
            }

            // Load fresh task list to avoid conflicts with daily tasks card
            final allTasks = await _taskService.loadTasks();
            final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
            
            if (kDebugMode) {
              print('Found task at index: $taskIndex out of ${allTasks.length} tasks');
            }
            
            if (taskIndex != -1) {
              // Update the existing task
              allTasks[taskIndex] = updatedTask;
              await _taskService.saveTasks(allTasks);
              
              // Reload the local list to stay synchronized
              await _loadTasks();
              
              if (kDebugMode) {
                print('Task updated successfully');
                print('Tasks after update: ${_tasks.length}');
                print('=== END TODO SCREEN EDIT DEBUG ===');
              }
            } else {
              if (kDebugMode) {
                print('ERROR: Task not found for update: ${task.id}');
                print('=== END TODO SCREEN EDIT DEBUG ===');
              }
            }
          },
        ),
      ),
    );
  }

  void _toggleTaskCompletion(Task task) async {
    if (kDebugMode) {
      print('=== TODO SCREEN TOGGLE COMPLETION DEBUG ===');
      print('Task: ${task.title}');
      print('Current completion status: ${task.isCompleted}');
      print('Toggling to: ${!task.isCompleted}');
      print('Task has recurrence: ${task.recurrence != null}');
    }
    
    final newCompletionStatus = !task.isCompleted;
    
    // If completing a task and not showing completed, start animation
    if (newCompletionStatus && !_showCompleted) {
      setState(() {
        _completingTasks.add(task.id);
      });
    }
    
    // Update the local task immediately for instant UI feedback
    final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (taskIndex != -1) {
      setState(() {
        _tasks[taskIndex].isCompleted = newCompletionStatus;
        _tasks[taskIndex].completedAt = newCompletionStatus ? DateTime.now() : null;
      });
    }
    
    // Handle recurring task completion logic - only when completing (not uncompleting)
    if (!task.isCompleted && task.recurrence != null && newCompletionStatus) {
      await _handleRecurringTaskCompletion(task);
      return; // Exit early for recurring tasks as they have their own feedback
    }
    
    // Normal toggle for non-recurring tasks or uncompleting tasks
    // Create updated task
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      categoryIds: List.from(task.categoryIds),
      deadline: task.deadline,
      reminderTime: task.reminderTime,
      isImportant: task.isImportant,
      recurrence: task.recurrence,
      isCompleted: newCompletionStatus,
      completedAt: newCompletionStatus ? DateTime.now() : null,
      createdAt: task.createdAt,
    );

    // Load fresh task list and update it
    final allTasks = await _taskService.loadTasks();
    final savedTaskIndex = allTasks.indexWhere((t) => t.id == task.id);
    
    if (savedTaskIndex != -1) {
      allTasks[savedTaskIndex] = updatedTask;
      await _taskService.saveTasks(allTasks);
      
      // Reload local list to stay synchronized
      await _loadTasks();
      
      if (kDebugMode) {
        print('Task completion saved successfully');
        print('New completion status: ${updatedTask.isCompleted}');
        print('Completed at: ${updatedTask.completedAt}');
        print('=== END TODO SCREEN TOGGLE DEBUG ===');
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
    if (kDebugMode) {
      print('=== HANDLING RECURRING TASK COMPLETION ===');
      print('Task: ${task.title}');
      print('Task ID: ${task.id}');
      print('Previous completion status: ${task.isCompleted}');
    }
    
    // Mark current task as completed
    task.isCompleted = true;
    task.completedAt = DateTime.now();

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
          reminderTime: task.reminderTime != null 
              ? DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day,
                         task.reminderTime!.hour, task.reminderTime!.minute)
              : null,
          isImportant: task.isImportant,
          recurrence: task.recurrence,
          isCompleted: false,
        );
        
        // Add next instance
        allTasks.add(nextTask);
        
        if (kDebugMode) {
          print('✅ Created next recurring task instance for: ${nextDueDate.toString()}');
          print('   New task ID: ${nextTask.id}');
          print('   Total tasks after creation: ${allTasks.length}');
        }
      } else {
        if (kDebugMode) {
          print('Next recurring task instance already exists for: ${nextDueDate.toString()}');
        }
      }
      
      await _taskService.saveTasks(allTasks);
      await _loadTasks();
      
    } else {
      // Just mark as completed if no next date found
      final allTasks = await _taskService.loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
      
      if (taskIndex != -1) {
        allTasks[taskIndex] = task;
        await _taskService.saveTasks(allTasks);
        await _loadTasks();
      }
    }
  }

  void _deleteTask(Task task) async {
    if (kDebugMode) {
      print('=== DELETING TASK DEBUG ===');
      print('Task: ${task.title}');
      print('Task ID: ${task.id}');
      print('Has recurrence: ${task.recurrence != null}');
      print('Is completed: ${task.isCompleted}');
    }
    
    // Load fresh task list and remove the task
    final allTasks = await _taskService.loadTasks();
    final beforeCount = allTasks.length;
    allTasks.removeWhere((t) => t.id == task.id);
    final afterCount = allTasks.length;
    
    if (kDebugMode) {
      print('Tasks before deletion: $beforeCount');
      print('Tasks after deletion: $afterCount');
      print('Removed ${beforeCount - afterCount} task(s)');
    }
    
    await _taskService.saveTasks(allTasks);
    
    // Reload local list to stay synchronized
    await _loadTasks();
    
    if (kDebugMode) {
      print('=== END DELETING TASK DEBUG ===');
    }
  }

  Future<void> _postponeTask(Task task) async {
    try {
      await _taskService.postponeTaskToTomorrow(task);
      await _loadTasks(); // Reload to reflect changes
      
      // Removed postpone snackbar notification as requested
    } catch (e) {
      if (kDebugMode) {
        print('Error postponing task: $e');
      }
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


  void _selectRandomTask() {
    final availableTasks = _getFilteredTasks().where((task) => !task.isCompleted).toList();

    if (availableTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tasks available for random selection')),
      );
      return;
    }

    final randomTask = availableTasks[Random().nextInt(availableTasks.length)];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎲 Random Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              randomTask.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (randomTask.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(randomTask.description),
            ],
            if (randomTask.deadline != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text('Due: ${DateFormat('MMM dd, yyyy').format(randomTask.deadline!)}'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleTaskCompletion(randomTask);
            },
            child: const Text('Mark Done'),
          ),
        ],
      ),
    );
  }


  List<Task> _getFilteredTasks() {
    List<Task> filtered = _tasks;

    if (!_showCompleted) {
      // Show incomplete tasks + completing tasks (for animation)
      filtered = filtered.where((task) => 
        !task.isCompleted || _completingTasks.contains(task.id)
      ).toList();
    }

    // Menstrual cycle filtering logic:
    // When flower icon is OFF (_showAllTasks = false): Show ALL tasks regardless of menstrual phase settings
    // When flower icon is ON (pink) (_showAllTasks = true): Show only current phase tasks + tasks without menstrual settings
    if (_showAllTasks) {
      // Flower icon ON (pink): Show tasks from current phase + tasks without menstrual phase settings
      filtered = filtered.where((task) => 
        // Show non-menstrual tasks OR menstrual tasks that are due today (current phase)
        (task.recurrence == null || !_isMenstrualCycleTask(task.recurrence!)) || 
        (task.recurrence != null && _isMenstrualCycleTask(task.recurrence!) && task.shouldShowToday())
      ).toList();
    }
    // When flower icon is OFF: Show ALL tasks without any menstrual filtering

    if (_selectedCategoryFilters.isNotEmpty) {
      filtered = filtered.where((task) =>
          task.categoryIds.any((id) => _selectedCategoryFilters.contains(id))
      ).toList();
    }

    return filtered;
  }

  List<Task> _getPrioritizedTasks() {
    return _taskService.getPrioritizedTasks(_getFilteredTasks(), _categories, 100, includeCompleted: _showCompleted);
  }

  bool _isMenstrualCycleTask(TaskRecurrence recurrence) {
    final menstrualTypes = [
      RecurrenceType.menstrualPhase, 
      RecurrenceType.follicularPhase, 
      RecurrenceType.ovulationPhase, 
      RecurrenceType.earlyLutealPhase, 
      RecurrenceType.lateLutealPhase
    ];
    return recurrence.types.any((type) => menstrualTypes.contains(type));
  }

  @override
  Widget build(BuildContext context) {
    final prioritizedTasks = _getPrioritizedTasks();

    // Debug logging
    if (kDebugMode) {
      print('=== TODO SCREEN DEBUG ===');
      print('Total tasks loaded: ${_tasks.length}');
      final activeTasks = _tasks.where((t) => !t.isCompleted).length;
      print('Active tasks: $activeTasks');
      print('Total prioritized tasks: ${prioritizedTasks.length}');
      print('Show completed: $_showCompleted');
      print('Category filters: $_selectedCategoryFilters');
      
      for (int i = 0; i < prioritizedTasks.length; i++) {
        final task = prioritizedTasks[i];
        print('Task $i: "${task.title}" (completed: ${task.isCompleted}, important: ${task.isImportant}, categories: ${task.categoryIds})');
      }
      
      // Also show filtered tasks details
      final filteredTasks = _getFilteredTasks();
      print('Filtered tasks count: ${filteredTasks.length}');
      print('=== END DEBUG ===');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(
                _showAllTasks ? Icons.local_florist_rounded : Icons.local_florist_rounded,
                color: _showAllTasks ? AppColors.white24 : AppColors.lightPink,
              ),
              tooltip: _showAllTasks ? 'Hide Cycle-Filtered Tasks' : 'Show All Tasks (Bypass Cycle Filtering)',
              onPressed: () {
                setState(() {
                  _showAllTasks = !_showAllTasks;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(
                _showCompleted ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: _showCompleted ? AppColors.successGreen : null,
              ),
              tooltip: _showCompleted ? 'Hide Completed' : 'Show Completed',
              onPressed: () {
                setState(() {
                  _showCompleted = !_showCompleted;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.category_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskCategoriesScreen(
                      categories: _categories,
                      onCategoriesUpdated: (updatedCategories) async {
                        setState(() {
                          _categories = updatedCategories;
                        });
                        await _saveCategories();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.casino_rounded),
              onPressed: _selectRandomTask,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategoryFilters.isEmpty,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryFilters.clear();
                        });
                        _saveCategoryFilters();
                      },
                    ),
                    ..._categories.map((category) => FilterChip(
                      label: Text(category.name),
                      selected: _selectedCategoryFilters.contains(category.id),
                      backgroundColor: category.color.withValues(alpha: 0.1),
                      selectedColor: category.color.withValues(alpha: 0.3),
                      checkmarkColor: category.color,
                      side: BorderSide(color: category.color.withValues(alpha: 0.5)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategoryFilters.add(category.id);
                          } else {
                            _selectedCategoryFilters.remove(category.id);
                          }
                        });
                        _saveCategoryFilters();
                      },
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Swipe left to delete',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),


          // Tasks List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshTasks,
              color: AppColors.coral,
              backgroundColor: AppColors.coral,
              child: prioritizedTasks.isEmpty
                  ? ListView(
                    // Need ListView for RefreshIndicator to work with empty state
                    children: const [
                      SizedBox(height: 200), // Spacer to center content
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No tasks found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            Text(
                              'Add a task to get started',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Pull down to refresh',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: prioritizedTasks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final task = prioritizedTasks[index];
                      
                      if (kDebugMode) {
                        print('Building TaskCard for index $index: "${task.title}" (id: ${task.id})');
                      }
                      
                      // Check if this task is completing
                      final isCompleting = _completingTasks.contains(task.id);
                      
                      return TaskCompletionAnimation(
                        key: ValueKey('animation_${task.id}'),
                        isCompleting: isCompleting,
                        onAnimationComplete: () => _onCompletionAnimationFinished(task.id),
                        child: TaskCard(
                          key: ValueKey('task_${task.id}'),
                          task: task,
                          categories: _categories,
                          onToggleCompletion: () => _toggleTaskCompletion(task),
                          onEdit: () => _editTask(task),
                          onDelete: () => _deleteTask(task),
                          onPostpone: () => _postponeTask(task),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: AppColors.successGreen,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}