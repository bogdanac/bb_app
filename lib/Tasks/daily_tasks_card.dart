import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../Tasks/task_service.dart';
import '../Tasks/todo_screen.dart';
import '../Tasks/task_edit_screen.dart';

class DailyTasksCard extends StatefulWidget {
  const DailyTasksCard({super.key});

  @override
  State<DailyTasksCard> createState() => _DailyTasksCardState();
}

class _DailyTasksCardState extends State<DailyTasksCard> {
  // Track if we need to refresh
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _refreshTasks() {
    // Increment counter to force TodoScreen rebuild
    setState(() {
      _refreshCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: AppStyles.borderRadiusLarge,
              color: AppColors.homeCardBackground,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use TodoScreen for consistent task display
                  SizedBox(
                    height: 400,
                    child: Material(
                      color: Colors.transparent,
                      child: TodoScreen(
                        key: ValueKey(_refreshCounter), // Force rebuild when counter changes
                        showFilters: false,
                        showAddButton: false,
                        enableRefresh: false, // Disable pull-to-refresh in daily tasks card
                        onTasksChanged: _refreshTasks, // Refresh when tasks change
                        initialShowAllTasks: false, // Keep menstrual cycle filtering active, but disable category filters
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
                  onTap: () async {
                    // Get categories from TodoScreen
                    final categories = await TaskService().loadCategories();

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                        builder: (context) => TaskEditScreen(
                          categories: categories,
                          onSave: (newTask) async {
                            final taskService = TaskService();
                            final allTasks = await taskService.loadTasks();
                            allTasks.add(newTask);
                            await taskService.saveTasks(allTasks);

                            // Refresh the embedded TodoScreen
                            if (mounted) {
                              _refreshTasks();
                            }
                          },
                        ),
                        ),
                      );
                    }
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