import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'tasks_data_models.dart';
import 'task_card_widget.dart';
import 'task_categories_screen.dart';
import 'task_edit_screen.dart';
import 'task_service.dart';
import '../theme/app_colors.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<Task> _tasks = [];
  List<TaskCategory> _categories = [];
  List<String> _selectedCategoryFilters = [];
  bool _showCompleted = false;
  final TaskService _taskService = TaskService();
  TaskSettings _taskSettings = TaskSettings();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCategories();
    await _loadTasks();
    await _loadTaskSettings();
  }

  Future<void> _loadCategories() async {
    final categories = await _taskService.loadCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
      });
    }
  }

  Future<void> _loadTasks() async {
    final tasks = await _taskService.loadTasks();
    if (mounted) {
      setState(() {
        _tasks = tasks;
      });
    }
  }

  Future<void> _loadTaskSettings() async {
    final settings = await _taskService.loadTaskSettings();
    if (mounted) {
      setState(() {
        _taskSettings = settings;
      });
    }
  }

  Future<void> _saveTasks() async {
    await _taskService.saveTasks(_tasks);
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
          onSave: (task) async {
            setState(() {
              // Check if task already exists (to prevent duplicates during auto-save)
              final existingIndex = _tasks.indexWhere((t) => t.id == task.id);
              if (existingIndex != -1) {
                _tasks[existingIndex] = task;
              } else {
                _tasks.add(task);
              }
            });
            await _saveTasks();
            // Priority ordering will be recalculated automatically in build method
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
            setState(() {
              final index = _tasks.indexWhere((t) => t.id == task.id);
              if (index != -1) {
                _tasks[index] = updatedTask;
              }
            });
            await _saveTasks();
            // Priority ordering will be recalculated automatically in build method
          },
        ),
      ),
    );
  }

  void _toggleTaskCompletion(Task task) async {
    setState(() {
      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? DateTime.now() : null;
    });
    await _saveTasks();
  }

  void _deleteTask(Task task) async {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    await _saveTasks();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" deleted'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _tasks.add(task);
              });
              await _saveTasks();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void _duplicateTask(Task task) async {
    final duplicatedTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${task.title} (Copy)',
      description: task.description,
      categoryIds: List.from(task.categoryIds),
      deadline: task.deadline,
      reminderTime: task.reminderTime,
      isImportant: task.isImportant,
      recurrence: task.recurrence,
      isCompleted: false,
    );

    setState(() {
      _tasks.add(duplicatedTask);
    });
    await _saveTasks();
    // Priority ordering will be recalculated automatically in build method

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" duplicated'),
          duration: const Duration(seconds: 3),
        ),
      );
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

  void _showTaskSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Task Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Max tasks on home page: ${_taskSettings.maxTasksOnHomePage}'),
              Slider(
                value: _taskSettings.maxTasksOnHomePage.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _taskSettings.maxTasksOnHomePage.toString(),
                onChanged: (value) {
                  setDialogState(() {
                    _taskSettings.maxTasksOnHomePage = value.round();
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Show completed tasks on home'),
                value: _taskSettings.showCompletedTasks,
                onChanged: (value) {
                  setDialogState(() {
                    _taskSettings.showCompletedTasks = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _taskService.saveTaskSettings(_taskSettings);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings saved')),
                  );
                  // Update the main widget state after saving
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  List<Task> _getFilteredTasks() {
    List<Task> filtered = _tasks;

    if (!_showCompleted) {
      filtered = filtered.where((task) => !task.isCompleted).toList();
    }

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

  @override
  Widget build(BuildContext context) {
    final prioritizedTasks = _getPrioritizedTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showTaskSettings,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
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
          IconButton(
            icon: const Icon(Icons.casino_rounded),
            onPressed: _selectRandomTask,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: _selectedCategoryFilters.isEmpty,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryFilters.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            ..._categories.map((category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category.name),
                                selected: _selectedCategoryFilters.contains(category.id),
                                backgroundColor: category.color.withOpacity(0.1),
                                selectedColor: category.color.withOpacity(0.3),
                                checkmarkColor: category.color,
                                side: BorderSide(color: category.color.withOpacity(0.5)),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedCategoryFilters.add(category.id);
                                    } else {
                                      _selectedCategoryFilters.remove(category.id);
                                    }
                                  });
                                },
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: Text(_showCompleted ? 'Hide Completed' : 'Show Completed'),
                      selected: _showCompleted,
                      onSelected: (selected) {
                        setState(() {
                          _showCompleted = selected;
                        });
                      },
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${prioritizedTasks.where((task) => !task.isCompleted).length} active tasks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
            child: prioritizedTasks.isEmpty
                ? const Center(
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
                ],
              ),
            )
                : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: prioritizedTasks.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final task = prioritizedTasks.removeAt(oldIndex);
                  prioritizedTasks.insert(newIndex, task);
                });
                // Note: This doesn't change the actual priority logic,
                // just the visual order temporarily
              },
              itemBuilder: (context, index) {
                final task = prioritizedTasks[index];
                return TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  categories: _categories,
                  onToggleCompletion: () => _toggleTaskCompletion(task),
                  onEdit: () => _editTask(task),
                  onDelete: () => _deleteTask(task),
                  onDuplicate: () => _duplicateTask(task),
                );
              },
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