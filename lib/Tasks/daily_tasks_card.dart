import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../Tasks/tasks_data_models.dart';
import '../Tasks/task_service.dart';
import '../Tasks/todo_screen.dart';
import '../Tasks/task_edit_screen.dart';

class DailyTasksCard extends StatefulWidget {
  const DailyTasksCard({super.key});

  @override
  State<DailyTasksCard> createState() => _DailyTasksCardState();
}

class _DailyTasksCardState extends State<DailyTasksCard> {
  List<Task> _prioritizedTasks = [];
  List<TaskCategory> _categories = [];
  final TaskService _taskService = TaskService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    
    // Listen for global task changes
    _taskService.addTaskChangeListener(_loadTasks);
  }
  
  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    _taskService.removeTaskChangeListener(_loadTasks);
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final tasks = await _taskService.loadTasks();
      final categories = await _taskService.loadCategories();

      if (!mounted) return;

      // Filter to only show non-completed tasks (like TodoScreen's default behavior)
      final filteredTasks = tasks.where((task) => !task.isCompleted).toList();
      
      // Let TodoScreen handle all the filtering - it already knows how to handle scheduledDate vs deadline properly

      final prioritized = _taskService.getPrioritizedTasks(
        filteredTasks, 
        categories, 
        100, // Limit to top 100
        includeCompleted: false
      );

      setState(() {
        _prioritizedTasks = prioritized;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading tasks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.homeCardBackground,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Tasks Display
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_prioritizedTasks.isEmpty)
                    SizedBox(
                      height: 100,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'All caught up!',
                              style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No urgent tasks for today',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Use TodoScreen for consistent task display
                    SizedBox(
                      height: 400, // Reduced height to leave space for button
                      child: Material(
                        color: Colors.transparent,
                        child: TodoScreen(
                          showFilters: false,
                          showAddButton: false,
                          enableRefresh: false, // Disable pull-to-refresh in daily tasks card
                          onTasksChanged: _loadTasks, // Reload daily tasks when embedded TodoScreen tasks change
                        ),
                      ),
                    ),

                  // Space for the add button
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          // Add task button
          Positioned(
            bottom: 16,
            right: 16,
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
                            allTasks.add(newTask);
                            await _taskService.saveTasks(allTasks);
                            if (mounted) {
                              await _loadTasks();
                            }
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