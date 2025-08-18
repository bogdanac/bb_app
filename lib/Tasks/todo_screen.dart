import 'dart:convert';

import 'package:bb_app/Tasks/task_card_widget.dart';
import 'package:bb_app/Tasks/task_categories_screen.dart';
import 'package:bb_app/Tasks/task_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'tasks_data_models.dart';

// TODO SCREEN
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  _loadData() async {
    await _loadCategories();
    await _loadTasks();
  }

  _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList('task_categories') ?? [];

    if (categoriesJson.isEmpty) {
      // Default categories
      _categories = [
        TaskCategory(id: '1', name: 'Cleaning', color: Colors.blue, order: 0),
        TaskCategory(id: '2', name: 'At Home', color: Colors.green, order: 1),
        TaskCategory(id: '3', name: 'Research', color: Colors.purple, order: 2),
        TaskCategory(id: '4', name: 'Travel', color: Colors.orange, order: 3),
      ];
      await _saveCategories();
    } else {
      _categories = categoriesJson
          .map((json) => TaskCategory.fromJson(jsonDecode(json)))
          .toList();
    }

    if (mounted) setState(() {});
  }

  _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = _categories
        .map((category) => jsonEncode(category.toJson()))
        .toList();
    await prefs.setStringList('task_categories', categoriesJson);
  }

  _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getStringList('tasks') ?? [];

    _tasks = tasksJson
        .map((json) => Task.fromJson(jsonDecode(json)))
        .toList();

    if (mounted) setState(() {});
  }

  _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = _tasks
        .map((task) => jsonEncode(task.toJson()))
        .toList();
    await prefs.setStringList('tasks', tasksJson);
  }

  _addTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          categories: _categories,
          onSave: (task) {
            setState(() {
              _tasks.add(task);
            });
            _saveTasks();
          },
        ),
      ),
    );
  }

  _editTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          task: task,
          categories: _categories,
          onSave: (updatedTask) {
            setState(() {
              final index = _tasks.indexWhere((t) => t.id == task.id);
              if (index != -1) {
                _tasks[index] = updatedTask;
              }
            });
            _saveTasks();
          },
        ),
      ),
    );
  }

  _toggleTaskCompletion(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? DateTime.now() : null;
    });
    _saveTasks();
  }

  _deleteTask(Task task) {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    _saveTasks();
  }

  _duplicateTask(Task task) {
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
    _saveTasks();
  }

  _selectRandomTask() {
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
    final filtered = _getFilteredTasks();
    final now = DateTime.now();

    filtered.sort((a, b) {
      // 1. Deadline is today
      final aDeadlineToday = a.deadline != null &&
          DateFormat('yyyy-MM-dd').format(a.deadline!) ==
              DateFormat('yyyy-MM-dd').format(now);
      final bDeadlineToday = b.deadline != null &&
          DateFormat('yyyy-MM-dd').format(b.deadline!) ==
              DateFormat('yyyy-MM-dd').format(now);

      if (aDeadlineToday && !bDeadlineToday) return -1;
      if (!aDeadlineToday && bDeadlineToday) return 1;

      // 2. Has reminder time and it's approaching/passed
      if (a.reminderTime != null && b.reminderTime == null) return -1;
      if (a.reminderTime == null && b.reminderTime != null) return 1;

      // 3. Deadline is tomorrow
      final aDeadlineTomorrow = a.deadline != null &&
          a.deadline!.difference(now).inDays == 1;
      final bDeadlineTomorrow = b.deadline != null &&
          b.deadline!.difference(now).inDays == 1;

      if (aDeadlineTomorrow && !bDeadlineTomorrow) return -1;
      if (!aDeadlineTomorrow && bDeadlineTomorrow) return 1;

      // 4. Important flag
      if (a.isImportant && !b.isImportant) return -1;
      if (!a.isImportant && b.isImportant) return 1;

      // 5. Category importance (based on order)
      final aCategoryOrder = _getCategoryImportance(a.categoryIds);
      final bCategoryOrder = _getCategoryImportance(b.categoryIds);

      return aCategoryOrder.compareTo(bCategoryOrder);
    });

    return filtered;
  }

  int _getCategoryImportance(List<String> categoryIds) {
    if (categoryIds.isEmpty) return 999;

    int minOrder = 999;
    for (final categoryId in categoryIds) {
      final category = _categories.firstWhere(
            (cat) => cat.id == categoryId,
        orElse: () => TaskCategory(id: '', name: '', color: Colors.grey, order: 999),
      );
      if (category.order < minOrder) {
        minOrder = category.order;
      }
    }
    return minOrder;
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
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskCategoriesScreen(
                    categories: _categories,
                    onCategoriesUpdated: (updatedCategories) {
                      setState(() {
                        _categories = updatedCategories;
                      });
                      _saveCategories();
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
                      child: Wrap(
                        spacing: 8,
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
                          ..._categories.map((category) => FilterChip(
                            label: Text(category.name),
                            selected: _selectedCategoryFilters.contains(category.id),
                            backgroundColor: category.color.withOpacity(0.2),
                            selectedColor: category.color.withOpacity(0.5),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategoryFilters.add(category.id);
                                } else {
                                  _selectedCategoryFilters.remove(category.id);
                                }
                              });
                            },
                          )),
                        ],
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}