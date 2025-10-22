import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tasks_data_models.dart';
import '../shared/date_format_utils.dart';
import 'task_card_widget.dart';
import 'task_categories_screen.dart';
import 'task_edit_screen.dart';
import 'task_service.dart';
import 'task_card_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../MenstrualCycle/menstrual_cycle_utils.dart';
import '../MenstrualCycle/menstrual_cycle_constants.dart';
import '../shared/snackbar_utils.dart';

class TodoScreen extends StatefulWidget {
  final bool showFilters;
  final bool showAddButton;
  final bool enableRefresh; // Whether to enable pull-to-refresh
  final VoidCallback? onTasksChanged; // Callback when tasks are modified
  final bool? initialShowAllTasks; // Initial state for menstrual cycle filtering

  const TodoScreen({
    super.key,
    this.showFilters = true,
    this.showAddButton = true,
    this.enableRefresh = true,
    this.onTasksChanged,
    this.initialShowAllTasks,
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
  
  Task? _currentTask;
  Task? _selectedTask;
  bool _isShuffling = false;
  bool _hasSelected = false;
  Timer? _shuffleTimer;
  int _shuffleCount = 0;
  int _triesUsed = 0;
  final int _maxTries = 3;
  final List<String> _selectedCategoryFilters = [];
  String? _noTasksMessage;

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

    _currentTask = null; // Don't show task initially
    
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

    // Always get fresh filtered tasks (don't cache) to handle category changes
    final availableTasks = _getFilteredTasks();
    if (availableTasks.isEmpty) {
      _showNoTasksMessage("No tasks available for this category selection.");
      return;
    }
    if (availableTasks.length == 1) {
      _showNoTasksMessage("Only 1 task available. Need at least 2 tasks to shuffle.");
      return;
    }

    setState(() {
      _isShuffling = true;
      _shuffleCount = 0;
      _triesUsed++;
    });

    _glowController.repeat(reverse: true);

    // Set initial random task when shuffling starts
    final initialTasks = _getFilteredTasks();
    setState(() {
      _currentTask = initialTasks[Random().nextInt(initialTasks.length)];
    });

    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_shuffleCount >= 20) { // Shuffle for 3 seconds
        timer.cancel();
        _stopShuffling();
        return;
      }

      // Get fresh filtered tasks each time to handle category changes
      final currentFilteredTasks = _getFilteredTasks();
      if (currentFilteredTasks.isEmpty) {
        timer.cancel();
        _stopShuffling();
        return;
      }

      setState(() {
        _currentTask = currentFilteredTasks[Random().nextInt(currentFilteredTasks.length)];
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
      // Don't set _hasSelected = true here - only when user actually chooses the task
    });
    
    _glowController.stop();
    _glowController.reset();
    _scaleController.forward();
  }

  List<Task> _getFilteredTasks() {
    List<Task> filtered;

    if (_selectedCategoryFilters.isEmpty) {
      filtered = widget.tasks;
    } else {
      filtered = widget.tasks.where((task) {
        if (task.categoryIds.isEmpty) return false;
        return task.categoryIds.any((categoryId) => _selectedCategoryFilters.contains(categoryId));
      }).toList();
    }

    return filtered;
  }

  void _showNoTasksMessage(String message) {
    setState(() {
      _noTasksMessage = message;
    });
    // Clear message after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _noTasksMessage = null;
        });
      }
    });
  }

  void _addTaskToToday(Task task) async {
    // Mark as selected when user chooses the task
    setState(() {
      _hasSelected = true;
      _selectedTask = task;
    });
    
    try {
      // Set the task's scheduled date to today
      final today = DateTime.now();
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        categoryIds: task.categoryIds,
        deadline: task.deadline,
        scheduledDate: DateTime(today.year, today.month, today.day),
        reminderTime: task.reminderTime,
        isImportant: task.isImportant,
        isPostponed: task.isPostponed,
        recurrence: task.recurrence,
        isCompleted: task.isCompleted,
        completedAt: task.completedAt,
        createdAt: task.createdAt,
      );

      // Load all tasks, update this specific task, and save back
      final taskService = TaskService();
      final allTasks = await taskService.loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
      
      if (taskIndex != -1) {
        allTasks[taskIndex] = updatedTask;
        await taskService.saveTasks(allTasks);
      }
      
      // Close dialog
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCancel();
      }
      
    } catch (e) {
      debugPrint('Error adding task to today: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppStyles.borderRadiusLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - more compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Task Randomizer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (!_isShuffling)
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ),
            
            // Category filters (optional)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by category (optional):',
                    style: TextStyle(fontSize: 12, color: AppColors.greyText),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('All', style: TextStyle(fontSize: 12)),
                        selected: _selectedCategoryFilters.isEmpty,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategoryFilters.clear();
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      ...widget.categories.map((category) => FilterChip(
                        label: Text(
                          category.name,
                          style: TextStyle(
                            color: _selectedCategoryFilters.contains(category.id)
                                ? Colors.white
                                : null,
                            fontSize: 12,
                          ),
                        ),
                        selected: _selectedCategoryFilters.contains(category.id),
                        selectedColor: category.color,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: category.color.withValues(alpha: 0.5),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategoryFilters.add(category.id);
                            } else {
                              _selectedCategoryFilters.remove(category.id);
                            }
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            
            
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Task display area or dice
                    if (_currentTask != null)
                      // Show task when available
                      Flexible(
                        flex: 2,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasSelected
                                ? AppColors.successGreen.withValues(alpha: 0.1)
                                : AppColors.coral.withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusLarge,
                            border: Border.all(
                              color: _hasSelected 
                                  ? AppColors.successGreen
                                  : AppColors.coral,
                              width: 2,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: _buildTaskContent(_currentTask!),
                          ),
                        ),
                      )
                    else
                      // Show dice when no task available
                      Flexible(
                        flex: 3,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _triesUsed < _maxTries ? _startShuffling : null,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _triesUsed < _maxTries 
                                          ? AppColors.normalCardBackground
                                          : AppColors.normalCardBackground,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.casino,
                                    color: _triesUsed < _maxTries 
                                        ? AppColors.greyText.withValues(alpha: 0.7)
                                        : AppColors.normalCardBackground,
                                    size: 60,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_maxTries - _triesUsed} tries remaining',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _triesUsed < _maxTries
                                      ? AppColors.greyText.withValues(alpha: 0.7)
                                      : AppColors.greyText.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // Error message display
                              if (_noTasksMessage != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: AppStyles.borderRadiusSmall,
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    _noTasksMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 4),
                    
                    // Action buttons
                    if (_isShuffling) 
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.coral),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Shuffling...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (!_hasSelected)
                      // When task is shown but not selected
                      if (_currentTask != null)
                        Column(
                          children: [
                            // Add to Today button (always available when task is shown)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _addTaskToToday(_currentTask!),
                                icon: const Icon(Icons.today_rounded, size: 18),
                                label: const Text('Add to Today'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.successGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppStyles.borderRadiusMedium,
                                  ),
                                ),
                              ),
                            ),
                            // Second row with Cancel and Try Again (if tries remain)
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: widget.onCancel,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                if (_triesUsed < _maxTries) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _startShuffling();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.coral,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppStyles.borderRadiusMedium,
                                        ),
                                      ),
                                      child: Text('Try Again ($_triesUsed/$_maxTries)'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      else
                        // Just Cancel when no task is shown
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: widget.onCancel,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        )
                    else
                      // When task is selected - Close and Add to Today on same row
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: widget.onCancel,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _addTaskToToday(_selectedTask!),
                              icon: const Icon(Icons.today_rounded),
                              label: const Text('Add to Today'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.coral,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppStyles.borderRadiusMedium,
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: const TextStyle(fontSize: 13),
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
                'Due ${DateFormatUtils.formatShort(task.deadline!)}',
                AppColors.lightCoral,
              ),
            if (task.reminderTime != null)
              _buildInfoChip(
                Icons.notifications_rounded,
                DateFormatUtils.formatTime24(task.reminderTime!),
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
                try {
                  final category = widget.categories.firstWhere(
                    (cat) => cat.id == categoryId,
                  );
                  return _buildInfoChip(
                    Icons.label_rounded,
                    category.name,
                    category.color,
                  );
                } catch (e) {
                  // Skip deleted categories instead of showing "Unknown"
                  return null;
                }
              }).where((chip) => chip != null).cast<Widget>(),
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
        borderRadius: AppStyles.borderRadiusSmall,
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
  List<Task> _displayTasks = []; // Tasks to display after filtering/sorting
  List<TaskCategory> _categories = [];
  List<String> _selectedCategoryFilters = [];
  bool _showCompleted = false;
  late bool _showAllTasks; // Will be initialized in initState
  bool _isRecalculating = false;
  bool _isLoading = true;
  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    // Initialize _showAllTasks based on widget parameter, defaulting to true (original behavior)
    _showAllTasks = widget.initialShowAllTasks ?? true;
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
    // Removed automatic refresh on app resume to prevent unwanted UI updates
    // Tasks will refresh only when explicitly triggered by user actions
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadCategories();
    // Only load category filters when filters UI is shown
    if (widget.showFilters) {
      await _loadCategoryFilters();
    }
    await _loadTasks();
    _updateDisplayTasks();
    setState(() => _isLoading = false);
  }

  void _updateDisplayTasks() async {
    // For simple cases, use sync filtering for immediate update
    if (_showAllTasks || _showCompleted) {
      final filteredTasks = _getFilteredTasks();
      _displayTasks = _taskService.getPrioritizedTasks(
        filteredTasks,
        _categories,
        100,
        includeCompleted: _showCompleted,
      );
      setState(() {});
    } else {
      // For menstrual cycle filtering, use async
      final filteredTasks = await _getFilteredTasksAsync();
      _displayTasks = _taskService.getPrioritizedTasks(
        filteredTasks,
        _categories,
        100,
        includeCompleted: _showCompleted,
      );
      setState(() {});
    }
  }


  Future<void> _loadCategories() async {
    final categories = await _taskService.loadCategories();
    if (mounted) {
      _categories = categories;
    }
  }

  Future<void> _loadCategoryFilters() async {
    final savedFilters = await _taskService.loadSelectedCategoryFilters();
    if (mounted) {
      _selectedCategoryFilters = savedFilters;
    }
  }

  Future<void> _saveCategoryFilters() async {
    await _taskService.saveSelectedCategoryFilters(_selectedCategoryFilters);
  }

  Future<void> _loadTasks() async {
    final tasks = await _taskService.loadTasks();

    // Clean up duplicates by keeping only the latest version of each unique ID
    final Map<String, Task> uniqueTasks = {};
    for (final task in tasks) {
      if (!uniqueTasks.containsKey(task.id) ||
          (task.completedAt != null && uniqueTasks[task.id]!.completedAt == null)) {
        uniqueTasks[task.id] = task;
      }
    }

    final cleanTasks = uniqueTasks.values.toList();

    if (cleanTasks.length != tasks.length) {
      // Save the cleaned list back to storage
      await _taskService.saveTasks(cleanTasks);
    }

    if (mounted) {
      _tasks = cleanTasks;
      _updateDisplayTasks();
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
            // Update in-memory list immediately for instant UI update
            final existingIndex = _tasks.indexWhere((t) => t.id == task.id);
            if (existingIndex != -1) {
              _tasks[existingIndex] = task;
            } else {
              _tasks.add(task);
            }
            _updateDisplayTasks(); // Immediate UI refresh

            // Save to disk asynchronously
            final allTasks = await _taskService.loadTasks();
            final diskIndex = allTasks.indexWhere((t) => t.id == task.id);
            if (diskIndex != -1) {
              allTasks[diskIndex] = task;
            } else {
              allTasks.add(task);
            }
            await _taskService.saveTasks(allTasks);
            widget.onTasksChanged?.call();
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
            // Update in-memory list immediately for instant UI update
            final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
            if (taskIndex != -1) {
              _tasks[taskIndex] = updatedTask;
              _updateDisplayTasks(); // Immediate UI refresh
            }

            // Save to disk asynchronously
            final allTasks = await _taskService.loadTasks();
            final diskIndex = allTasks.indexWhere((t) => t.id == task.id);
            if (diskIndex != -1) {
              allTasks[diskIndex] = updatedTask;
              await _taskService.saveTasks(allTasks);
              widget.onTasksChanged?.call();
            }
          },
        ),
      ),
    );
  }

  void _toggleTaskCompletion(Task task) async {
    final newCompletionStatus = !task.isCompleted;

    // For recurring tasks being completed, reschedule immediately instead of marking as completed
    if (!task.isCompleted && task.recurrence != null && newCompletionStatus) {
      await _handleRecurringTaskCompletion(task);
      return; // Exit early - the recurring handler will update the task
    }

    // For non-recurring tasks or uncompleting a task, just toggle the status
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      categoryIds: List.from(task.categoryIds),
      deadline: task.deadline,
      scheduledDate: task.scheduledDate,
      reminderTime: task.reminderTime,
      isImportant: task.isImportant,
      isPostponed: task.isPostponed,
      recurrence: task.recurrence,
      isCompleted: newCompletionStatus,
      completedAt: newCompletionStatus ? DateTime.now() : null,
      createdAt: task.createdAt,
    );

    // Update in-memory list immediately for instant UI update
    final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
    if (taskIndex != -1) {
      _tasks[taskIndex] = updatedTask;
      _updateDisplayTasks(); // Immediate UI refresh
    }

    // Save to disk asynchronously
    final allTasks = await _taskService.loadTasks();
    final diskTaskIndex = allTasks.indexWhere((t) => t.id == task.id);
    if (diskTaskIndex != -1) {
      allTasks[diskTaskIndex] = updatedTask;
      await _taskService.saveTasks(allTasks);
      widget.onTasksChanged?.call();
    }
  }


  Future<void> _handleRecurringTaskCompletion(Task task) async {
    if (kDebugMode) {
      print('=== HANDLING RECURRING TASK COMPLETION ===');
      print('Task: ${task.title}');
      print('Task ID: ${task.id}');
      print('Previous completion status: ${task.isCompleted}');
    }

    try {

    // Special handling for menstrual phase tasks with phaseDay:
    // These should NOT auto-recalculate. User will manually recalculate when next period comes.
    final isMenstrualPhaseTask = task.recurrence!.phaseDay != null &&
        (task.recurrence!.types.contains(RecurrenceType.menstrualPhase) ||
         task.recurrence!.types.contains(RecurrenceType.follicularPhase) ||
         task.recurrence!.types.contains(RecurrenceType.ovulationPhase) ||
         task.recurrence!.types.contains(RecurrenceType.earlyLutealPhase) ||
         task.recurrence!.types.contains(RecurrenceType.lateLutealPhase));

    if (isMenstrualPhaseTask) {
      // For menstrual phase tasks with specific phaseDay, just clear scheduledDate
      // and mark as completed - user will recalculate when next period comes
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        categoryIds: List.from(task.categoryIds),
        deadline: task.deadline,
        scheduledDate: null, // Clear scheduled date - will be recalculated later
        reminderTime: task.reminderTime,
        isImportant: task.isImportant,
        isPostponed: false,
        recurrence: task.recurrence,
        isCompleted: true, // Mark as completed
        completedAt: DateTime.now(),
        createdAt: task.createdAt,
      );

      final allTasks = await _taskService.loadTasks();
      final currentTaskIndex = allTasks.indexWhere((t) => t.id == task.id);

      if (currentTaskIndex != -1) {
        allTasks[currentTaskIndex] = updatedTask;
        await _taskService.saveTasks(allTasks);

        // Update in-memory list immediately
        final memoryTaskIndex = _tasks.indexWhere((t) => t.id == task.id);
        if (memoryTaskIndex != -1) {
          _tasks[memoryTaskIndex] = updatedTask;
          _updateDisplayTasks();
        }

        await _loadTasks();

        if (kDebugMode) {
          print('✅ Menstrual phase task completed and scheduledDate cleared');
          print('   Will be recalculated when user updates period info');
        }
      }
      return;
    }

    // Get next due date for regular recurring tasks
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
      // Determine reminderTime from either task or recurrence
      DateTime? newReminderTime;
      if (task.reminderTime != null) {
        newReminderTime = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day,
                       task.reminderTime!.hour, task.reminderTime!.minute);
      } else if (task.recurrence!.reminderTime != null) {
        newReminderTime = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day,
                       task.recurrence!.reminderTime!.hour, task.recurrence!.reminderTime!.minute);
      }

      final updatedTask = Task(
        id: task.id, // Keep same ID
        title: task.title,
        description: task.description,
        categoryIds: List.from(task.categoryIds),
        deadline: task.deadline, // Keep original deadline unchanged
        scheduledDate: nextDueDate, // Update scheduled date to next occurrence
        reminderTime: newReminderTime,
        isImportant: task.isImportant,
        isPostponed: false, // Reset postponed status - it's now scheduled naturally
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

        // Reschedule notification for the updated recurring task
        await _taskService.scheduleTaskNotification(updatedTask);

        // Update in-memory list immediately
        final memoryTaskIndex = _tasks.indexWhere((t) => t.id == task.id);
        if (memoryTaskIndex != -1) {
          _tasks[memoryTaskIndex] = updatedTask;
          _updateDisplayTasks();
        }

        await _loadTasks();
        
        if (kDebugMode) {
          print('✅ Updated recurring task to next due date: ${nextDueDate.toString()}');
          print('   Task is now unchecked and scheduled for next occurrence');
          print('   Original deadline preserved: ${task.deadline}');
          print('   Reference date used: ${referenceDate.toString()}');
          print('   Previous scheduled date: ${task.scheduledDate?.toString() ?? "none"}');
          if (updatedTask.reminderTime != null) {
            print('   Notification rescheduled for: ${updatedTask.reminderTime.toString()}');
          }
        }
      }
      
    } else {
      // If no next date found, just mark as completed
      final completedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        categoryIds: task.categoryIds,
        deadline: task.deadline,
        scheduledDate: task.scheduledDate,
        reminderTime: task.reminderTime,
        isImportant: task.isImportant,
        isPostponed: task.isPostponed,
        recurrence: task.recurrence,
        isCompleted: true,
        completedAt: DateTime.now(),
        createdAt: task.createdAt,
      );

      final allTasks = await _taskService.loadTasks();
      final taskIndex = allTasks.indexWhere((t) => t.id == task.id);

      if (taskIndex != -1) {
        allTasks[taskIndex] = completedTask;
        await _taskService.saveTasks(allTasks);

        // Update in-memory list immediately
        final memoryTaskIndex = _tasks.indexWhere((t) => t.id == task.id);
        if (memoryTaskIndex != -1) {
          _tasks[memoryTaskIndex] = completedTask;
          _updateDisplayTasks();
        }

        await _loadTasks();
      }
    }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ ERROR in recurring task completion: $e');
        print('Stack trace: $stackTrace');
      }
      
      // Fallback: just mark task as completed without recurring
      try {
        final completedTask = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          categoryIds: task.categoryIds,
          deadline: task.deadline,
          scheduledDate: task.scheduledDate,
          reminderTime: task.reminderTime,
          isImportant: task.isImportant,
          isPostponed: task.isPostponed,
          recurrence: task.recurrence,
          isCompleted: true,
          completedAt: DateTime.now(),
          createdAt: task.createdAt,
        );
        
        final allTasks = await _taskService.loadTasks();
        final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
        
        if (taskIndex != -1) {
          allTasks[taskIndex] = completedTask;
          await _taskService.saveTasks(allTasks);

          // Update in-memory list immediately
          final memoryTaskIndex = _tasks.indexWhere((t) => t.id == task.id);
          if (memoryTaskIndex != -1) {
            _tasks[memoryTaskIndex] = completedTask;
            _updateDisplayTasks();
          }

          await _loadTasks();
          widget.onTasksChanged?.call();
        }
        
        if (kDebugMode) {
          print('✅ Fallback: Task marked as completed without recurring');
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('❌ CRITICAL: Fallback completion also failed: $fallbackError');
        }
      }
    }
  }

  void _deleteTask(Task task) async {
    // Update in-memory list immediately for instant UI update
    _tasks.removeWhere((t) => t.id == task.id);
    _updateDisplayTasks(); // Immediate UI refresh

    // Save to disk asynchronously
    final allTasks = await _taskService.loadTasks();
    allTasks.removeWhere((t) => t.id == task.id);
    await _taskService.saveTasks(allTasks);

    // Notify parent widget that tasks have changed
    widget.onTasksChanged?.call();
  }

  Future<void> _postponeTask(Task task) async {
    try {
      // Calculate tomorrow's date
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final postponedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        categoryIds: List.from(task.categoryIds),
        deadline: task.deadline,
        scheduledDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        reminderTime: task.reminderTime,
        isImportant: task.isImportant,
        isPostponed: true,
        recurrence: task.recurrence,
        isCompleted: task.isCompleted,
        completedAt: task.completedAt,
        createdAt: task.createdAt,
      );

      // Update in-memory list immediately for instant UI update
      final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        _tasks[taskIndex] = postponedTask;
        _updateDisplayTasks(); // Immediate UI refresh
      }

      // Save to disk asynchronously
      await _taskService.postponeTaskToTomorrow(task);
      widget.onTasksChanged?.call();
    } catch (e) {
      if (kDebugMode) {
        print('Error postponing task: $e');
      }
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to postpone task: $e');
      }
    }
  }

  Future<void> _recalculateRecurringTasks() async {
    if (_isRecalculating) return;

    setState(() {
      _isRecalculating = true;
    });

    try {
      final updatedCount = await _taskService.recalculateAllRecurringTasks();

      if (mounted) {
        // Reload tasks to show updated scheduled dates
        await _loadTasks();

        // Notify parent widget that tasks have changed
        widget.onTasksChanged?.call();

        // Show appropriate feedback
        String message;
        Color backgroundColor;

        if (updatedCount > 0) {
          message = '✅ Updated $updatedCount recurring task${updatedCount == 1 ? '' : 's'} with new scheduled dates';
          backgroundColor = AppColors.successGreen;
        } else {
          message = 'ℹ️ All recurring tasks already have current scheduled dates';
          backgroundColor = AppColors.greyText;
        }

        if (mounted && context.mounted) {
          SnackBarUtils.showCustom(context, message, backgroundColor: backgroundColor);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error recalculating recurring tasks: $e');
      }
      if (mounted) {
        SnackBarUtils.showError(context, '⚠️ Failed to recalculate tasks: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecalculating = false;
        });
      }
    }
  }


  void _selectRandomTask() {
    _getFilteredTasksAsync().then((filteredTasks) {
      if (!mounted) return;

      final availableTasks = filteredTasks.where((task) =>
        !task.isCompleted && task.recurrence == null  // Filter out completed AND recurring tasks
      ).toList();

      if (availableTasks.isEmpty) {
        if (context.mounted) {
          SnackBarUtils.showInfo(context, 'No tasks available for random selection');
        }
        return;
      }

      if (context.mounted) {
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
    });
  }


  Future<List<Task>> _getFilteredTasksAsync() async {
    List<Task> filtered = _tasks;

    if (!_showCompleted) {
      // Show incomplete tasks only
      filtered = filtered.where((task) => !task.isCompleted).toList();
    } else {
      // Show ONLY completed tasks, ordered by completion date (newest first)
      filtered = filtered.where((task) => task.isCompleted).toList();
      filtered.sort((a, b) {
        // Sort by completion date - newest first (most recently completed)
        if (a.completedAt == null && b.completedAt == null) return 0;
        if (a.completedAt == null) return 1;  // Incomplete tasks last
        if (b.completedAt == null) return -1; // Incomplete tasks last
        return b.completedAt!.compareTo(a.completedAt!); // Newest first
      });
    }

    // Menstrual cycle filtering logic:
    // When flower icon is OFF (_showAllTasks = false): Show ALL tasks regardless of menstrual phase settings
    // When flower icon is ON (pink) (_showAllTasks = true): Show only current phase tasks + tasks without menstrual settings
    if (_showAllTasks) {
      // Flower icon ON (pink): Show tasks from current phase + tasks without menstrual phase settings
      List<Task> menstrualFiltered = [];
      for (Task task in filtered) {
        // Show non-menstrual tasks
        if (task.recurrence == null || !_isMenstrualCycleTask(task.recurrence!)) {
          menstrualFiltered.add(task);
        }
        // For menstrual tasks, check if they're due in current phase
        else if (await _isMenstrualTaskDueToday(task)) {
          menstrualFiltered.add(task);
        }
      }
      filtered = menstrualFiltered;
    }
    // When flower icon is OFF: Show ALL tasks without any menstrual filtering

    // Only apply category filtering if filters are shown (not in daily tasks card)
    if (widget.showFilters && _selectedCategoryFilters.isNotEmpty) {
      filtered = filtered.where((task) =>
          task.categoryIds.isNotEmpty &&
          // Check that the task has ALL selected categories (not just any)
          _selectedCategoryFilters.every((selectedCategoryId) => task.categoryIds.contains(selectedCategoryId))
      ).toList();
    }

    return filtered;
  }

  List<Task> _getFilteredTasks() {
    // Simple synchronous filtering for immediate UI updates
    List<Task> filtered = _tasks;

    if (!_showCompleted) {
      filtered = filtered.where((task) => !task.isCompleted).toList();
    } else {
      filtered = filtered.where((task) => task.isCompleted).toList();
      filtered.sort((a, b) {
        if (a.completedAt == null && b.completedAt == null) return 0;
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!);
      });
    }

    // Apply category filters
    if (_selectedCategoryFilters.isNotEmpty) {
      filtered = filtered.where((task) {
        if (task.categoryIds.isEmpty) return false;
        return task.categoryIds.any((categoryId) =>
          _selectedCategoryFilters.contains(categoryId));
      }).toList();
    }

    return filtered;
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

  Future<bool> _isMenstrualTaskDueToday(Task task) async {
    if (task.recurrence == null) return false;

    final recurrenceTypes = task.recurrence!.types;

    final hasRegularRecurrence = recurrenceTypes.any((type) =>
      type == RecurrenceType.daily ||
      type == RecurrenceType.weekly ||
      type == RecurrenceType.monthly ||
      type == RecurrenceType.yearly ||
      type == RecurrenceType.custom
    );

    final hasMenstrualPhases = _isMenstrualCycleTask(task.recurrence!);

    // If task has NO menstrual phases, use regular due today logic
    if (!hasMenstrualPhases) {
      return task.isDueToday();
    }

    // If task HAS menstrual phases, we need to check the current phase
    final prefs = await SharedPreferences.getInstance();
    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');
    final averageCycleLength = prefs.getInt('average_cycle_length') ?? 28;

    if (lastStartStr == null) return false;

    final lastPeriodStart = DateTime.parse(lastStartStr);
    final lastPeriodEnd = lastEndStr != null ? DateTime.parse(lastEndStr) : null;

    // Get current menstrual cycle phase
    final currentPhase = MenstrualCycleUtils.getCyclePhase(lastPeriodStart, lastPeriodEnd, averageCycleLength);

    // Check if current phase matches any of the selected menstrual phases
    bool isInCorrectPhase = false;

    if (recurrenceTypes.contains(RecurrenceType.menstrualPhase) &&
        currentPhase == MenstrualCycleConstants.menstrualPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.follicularPhase) &&
        currentPhase == MenstrualCycleConstants.follicularPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.ovulationPhase) &&
        currentPhase == MenstrualCycleConstants.ovulationPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.earlyLutealPhase) &&
        currentPhase == MenstrualCycleConstants.earlyLutealPhase) {
      isInCorrectPhase = true;
    }
    if (recurrenceTypes.contains(RecurrenceType.lateLutealPhase) &&
        currentPhase == MenstrualCycleConstants.lateLutealPhase) {
      isInCorrectPhase = true;
    }

    // If not in the correct menstrual phase, don't show the task
    if (!isInCorrectPhase) {
      return false;
    }

    // Note: phaseDay tasks always appear during their target phase
    // Priority handling (high priority on target day, lower priority on other days)
    // is handled in the priority scoring system, not here

    // If task has BOTH regular recurrence AND menstrual phases:
    // Show only if BOTH conditions are met: correct phase AND due today
    if (hasRegularRecurrence && hasMenstrualPhases) {
      return task.isDueToday(); // Must also be due according to regular recurrence
    }

    // If task has ONLY menstrual phases (no regular recurrence):
    // Show if we're in the correct phase (already checked above)
    return true;
  }

  Widget _buildTasksList(List<Task> prioritizedTasks) {
    return prioritizedTasks.isEmpty
        ? ListView(
          // Need ListView for RefreshIndicator to work with empty state
          children: [
            const SizedBox(height: 200), // Spacer to center content
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt_rounded, size: 64, color: AppColors.normalCardBackground),
                  SizedBox(height: 16),
                  Text(
                    'No tasks found',
                    style: TextStyle(fontSize: 18, color: AppColors.normalCardBackground),
                  ),
                  Text(
                    'Add a task to get started',
                    style: TextStyle(color: AppColors.normalCardBackground),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
            // Only show "Pull down to refresh" text if refresh is enabled
            if (widget.enableRefresh)
              const Center(
                child: Text(
                  'Pull down to refresh',
                  style: TextStyle(fontSize: 12, color: AppColors.normalCardBackground),
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

            // Calculate priority for display - but not for completed tasks
            final priorityReason = task.isCompleted ? '' : TaskCardUtils.getTaskPriorityReason(task);
            final priorityColor = task.isCompleted ? null : TaskCardUtils.getPriorityColor(priorityReason);

            return TaskCard(
              key: ValueKey('task_${task.id}'),
              task: task,
              categories: _categories,
              onToggleCompletion: () => _toggleTaskCompletion(task),
              onEdit: () => _editTask(task),
              onDelete: () => _deleteTask(task),
              onPostpone: task.isCompleted ? null : () => _postponeTask(task), // No postpone for completed tasks
              priorityReason: priorityReason.isNotEmpty ? priorityReason : null,
              priorityColor: priorityColor,
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: widget.showFilters ? AppBar(
          title: const Text('Tasks'),
          backgroundColor: Colors.transparent,
        ) : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return _buildMainScaffold(_displayTasks);
  }

  Widget _buildMainScaffold(List<Task> prioritizedTasks) {
    return Scaffold(
      appBar: widget.showFilters ? AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: _isRecalculating
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                ),
              )
                  : const Icon(Icons.auto_fix_high),
              tooltip: 'Recalculate Recurring Tasks',
              onPressed: _isRecalculating ? null : _recalculateRecurringTasks,
            ),
          ),
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
                _updateDisplayTasks();
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
                _updateDisplayTasks();
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
              padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category filter chips - wrap with start alignment
                Wrap(
                  alignment: WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategoryFilters.isEmpty,
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      selectedColor: Colors.grey.withValues(alpha: 0.3),
                      checkmarkColor: Colors.grey,
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryFilters.clear();
                        });
                        _saveCategoryFilters();
                        _updateDisplayTasks();
                      },
                    ),
                    ..._categories.map((category) => FilterChip(
                      label: Text(category.name),
                      selected: _selectedCategoryFilters.contains(category.id),
                      backgroundColor: category.color.withValues(alpha: 0.1),
                      selectedColor: category.color.withValues(alpha: 0.3),
                      checkmarkColor: category.color,
                      side: BorderSide(color: category.color.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
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
                        _updateDisplayTasks();
                      },
                    )),
                  ],
                ),
              ],
            ),
          ),


          // Tasks List
          Expanded(
            child: RefreshIndicator(
                onRefresh: () async {
                  await _loadData();
                },
                color: AppColors.coral,
                backgroundColor: AppColors.coral,
                child: _buildTasksList(prioritizedTasks),
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