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
import 'task_card_utils.dart';
import '../theme/app_colors.dart';

class TodoScreen extends StatefulWidget {
  final bool showFilters;
  final bool showAddButton;
  final VoidCallback? onTasksChanged; // Callback when tasks are modified
  
  const TodoScreen({
    super.key, 
    this.showFilters = true,
    this.showAddButton = true,
    this.onTasksChanged,
  });

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _AnimatedTaskRandomizer extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onTaskSelected;
  final VoidCallback onCancel;
  final List<TaskCategory> categories;

  const _AnimatedTaskRandomizer({
    required this.tasks,
    required this.onTaskSelected,
    required this.onCancel,
    required this.categories,
  });

  @override
  State<_AnimatedTaskRandomizer> createState() => _AnimatedTaskRandomizerState();
}

class _AnimatedTaskRandomizerState extends State<_AnimatedTaskRandomizer>
    with TickerProviderStateMixin {
  late AnimationController _shuffleController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _shuffleAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  Task? _currentTask;
  Task? _selectedTask;
  bool _isShuffling = false;
  bool _hasSelected = false;
  Timer? _shuffleTimer;
  int _shuffleCount = 0;

  @override
  void initState() {
    super.initState();
    _shuffleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shuffleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shuffleController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _currentTask = widget.tasks[Random().nextInt(widget.tasks.length)];
    
    // Start with scale animation
    _scaleController.forward();
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _shuffleTimer?.cancel();
    super.dispose();
  }

  void _startShuffling() {
    if (_hasSelected) return;
    
    setState(() {
      _isShuffling = true;
      _shuffleCount = 0;
    });

    _glowController.repeat(reverse: true);
    
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_shuffleCount >= 20) { // Shuffle for 3 seconds
        timer.cancel();
        _stopShuffling();
        return;
      }
      
      setState(() {
        _currentTask = widget.tasks[Random().nextInt(widget.tasks.length)];
        _shuffleCount++;
      });
      
      _shuffleController.forward().then((_) {
        _shuffleController.reverse();
      });
    });
  }

  void _stopShuffling() {
    setState(() {
      _isShuffling = false;
      _hasSelected = true;
      _selectedTask = _currentTask;
    });
    
    _glowController.stop();
    _glowController.reset();
    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.coral, AppColors.lightCoral],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _shuffleAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _shuffleAnimation.value * 2 * 3.14159,
                        child: const Icon(
                          Icons.casino_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Task Randomizer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_isShuffling)
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                ],
              ),
            ),
            
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Task display area
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _hasSelected ? _scaleAnimation.value : 1.0,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _hasSelected 
                                      ? AppColors.successGreen.withValues(alpha: 0.1)
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _hasSelected 
                                        ? AppColors.successGreen
                                        : (_isShuffling 
                                            ? AppColors.coral.withValues(alpha: 0.3 + _glowAnimation.value * 0.7)
                                            : AppColors.grey.withValues(alpha: 0.3)),
                                    width: _hasSelected ? 3 : 2,
                                  ),
                                  boxShadow: _hasSelected ? [
                                    BoxShadow(
                                      color: AppColors.successGreen.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ] : null,
                                ),
                                child: _currentTask != null 
                                    ? _buildTaskContent(_currentTask!)
                                    : const SizedBox.shrink(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    if (!_hasSelected) ...[
                      if (!_isShuffling) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startShuffling,
                            icon: const Icon(Icons.shuffle_rounded),
                            label: const Text('Shuffle Tasks!'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.coral,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: widget.onCancel,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.coral),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Shuffling tasks...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: widget.onCancel,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Skip This Task'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => widget.onTaskSelected(_selectedTask!),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Complete Task'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskContent(Task task) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            task.description,
            style: const TextStyle(fontSize: 16),
          ),
        ],
        const SizedBox(height: 16),
        
        // Task details
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (task.deadline != null)
              _buildInfoChip(
                Icons.schedule_rounded,
                'Due ${DateFormat('MMM dd').format(task.deadline!)}',
                AppColors.lightCoral,
              ),
            if (task.reminderTime != null)
              _buildInfoChip(
                Icons.notifications_rounded,
                DateFormat('HH:mm').format(task.reminderTime!),
                AppColors.coral,
              ),
            if (task.isImportant)
              _buildInfoChip(
                Icons.star_rounded,
                'Important',
                AppColors.coral,
              ),
            if (task.categoryIds.isNotEmpty)
              ...task.categoryIds.map((categoryId) {
                final category = widget.categories.firstWhere(
                  (cat) => cat.id == categoryId,
                  orElse: () => TaskCategory(
                    id: '',
                    name: 'Unknown',
                    color: Colors.grey,
                    order: 0,
                  ),
                );
                return _buildInfoChip(
                  Icons.label_rounded,
                  category.name,
                  category.color,
                );
              }),
          ],
        ),
      ],
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
          Icon(icon, size: 12, color: color),
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
}

class _TodoScreenState extends State<TodoScreen> with WidgetsBindingObserver {
  List<Task> _tasks = [];
  List<TaskCategory> _categories = [];
  List<String> _selectedCategoryFilters = [];
  bool _showCompleted = false;
  bool _showAllTasks = true; // Default: show only current menstrual phase tasks
  final TaskService _taskService = TaskService();
  final Set<String> _completingTasks = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    
    // Listen for global task changes
    _taskService.addTaskChangeListener(_refreshTasks);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskService.removeTaskChangeListener(_refreshTasks);
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
      scheduledDate: task.scheduledDate,
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
      
      // Notify parent widget that tasks have changed
      widget.onTasksChanged?.call();
      
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
    
    // Get next due date for the recurring task
    // For postponed tasks, we need to skip the current cycle to respect the postponement
    DateTime referenceDate;
    if (task.scheduledDate != null) {
      // Task was postponed - find the next occurrence after the scheduled date
      // This ensures we don't go back to the original cycle day that was skipped
      referenceDate = task.scheduledDate!;
    } else {
      // Task completed on time - use natural recurrence from today
      referenceDate = DateTime.now();
    }
    
    final nextDueDate = task.recurrence!.getNextDueDate(referenceDate);
    
    if (nextDueDate != null) {
      // Update the existing task's scheduledDate instead of deadline
      final updatedTask = Task(
        id: task.id, // Keep same ID
        title: task.title,
        description: task.description,
        categoryIds: List.from(task.categoryIds),
        deadline: task.deadline, // Keep original deadline unchanged
        scheduledDate: nextDueDate, // Update scheduled date to next occurrence
        reminderTime: task.reminderTime != null 
            ? DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day,
                       task.reminderTime!.hour, task.reminderTime!.minute)
            : null,
        isImportant: task.isImportant,
        recurrence: task.recurrence,
        isCompleted: false, // Reset completion status
        completedAt: null,  // Clear completion timestamp
        createdAt: task.createdAt, // Keep original creation date
      );
      
      // Load fresh task list and update the existing task
      final allTasks = await _taskService.loadTasks();
      final currentTaskIndex = allTasks.indexWhere((t) => t.id == task.id);
      
      if (currentTaskIndex != -1) {
        allTasks[currentTaskIndex] = updatedTask;
        await _taskService.saveTasks(allTasks);
        await _loadTasks();
        
        if (kDebugMode) {
          print('✅ Updated recurring task to next due date: ${nextDueDate.toString()}');
          print('   Task is now unchecked and scheduled for next occurrence');
          print('   Original deadline preserved: ${task.deadline}');
          print('   Reference date used: ${referenceDate.toString()}');
          print('   Previous scheduled date: ${task.scheduledDate?.toString() ?? "none"}');
        }
      }
      
    } else {
      // If no next date found, just mark as completed
      task.isCompleted = true;
      task.completedAt = DateTime.now();
      
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
    
    // Notify parent widget that tasks have changed
    widget.onTasksChanged?.call();
    
    if (kDebugMode) {
      print('=== END DELETING TASK DEBUG ===');
    }
  }

  Future<void> _postponeTask(Task task) async {
    debugPrint('=== _postponeTask called for: ${task.title} ===');
    try {
      await _taskService.postponeTaskToTomorrow(task);
      await _loadTasks(); // Reload to reflect changes
      
      // Notify parent widget that tasks have changed
      widget.onTasksChanged?.call();
      
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AnimatedTaskRandomizer(
        tasks: availableTasks,
        onTaskSelected: (task) {
          Navigator.pop(context);
          _toggleTaskCompletion(task);
        },
        onCancel: () => Navigator.pop(context),
        categories: _categories,
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
        (task.recurrence != null && _isMenstrualCycleTask(task.recurrence!) && task.isDueToday())
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

    return Scaffold(
      appBar: widget.showFilters ? AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(
                Icons.local_florist_rounded,
                color: _showAllTasks ? AppColors.lightPink : AppColors.white24,
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
      ) : null,
      backgroundColor: widget.showFilters ? null : Colors.transparent,
      body: Column(
        children: [
          // Filter Section
          if (widget.showFilters) 
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stretched category filter chips
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
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
                    ),
                    if (_categories.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      ..._categories.expand((category) => [
                        Expanded(
                          child: FilterChip(
                            label: Text(
                              category.name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                          ),
                        ),
                        if (_categories.last != category) const SizedBox(width: 4),
                      ]),
                    ],
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
                      
                      // Calculate priority for display
                      final priorityReason = TaskCardUtils.getTaskPriorityReason(task);
                      final priorityColor = TaskCardUtils.getPriorityColor(priorityReason);
                      
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
                          priorityReason: priorityReason.isNotEmpty ? priorityReason : null,
                          priorityColor: priorityColor,
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.showAddButton ? FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: AppColors.successGreen,
        child: const Icon(Icons.add_rounded),
      ) : null,
    );
  }
}