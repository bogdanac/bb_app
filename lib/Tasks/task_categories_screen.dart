import 'package:flutter/material.dart';
import 'category_edit_dialog.dart';
import 'tasks_data_models.dart';
import 'task_service.dart';
import '../theme/app_colors.dart';

// TASK CATEGORIES SCREEN
class TaskCategoriesScreen extends StatefulWidget {
  final List<TaskCategory> categories;
  final Function(List<TaskCategory>) onCategoriesUpdated;

  const TaskCategoriesScreen({
    super.key,
    required this.categories,
    required this.onCategoriesUpdated,
  });

  @override
  State<TaskCategoriesScreen> createState() => _TaskCategoriesScreenState();
}

class _TaskCategoriesScreenState extends State<TaskCategoriesScreen> {
  late List<TaskCategory> _categories;
  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  void _addCategory() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => CategoryEditDialog(
        onSave: (name, color) {
          setState(() {
            _categories.add(TaskCategory(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              color: color,
              order: _categories.length,
            ));
          });
          _saveCategories();
        },
      ),
    );
  }

  void _editCategory(TaskCategory category) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => CategoryEditDialog(
        initialName: category.name,
        initialColor: category.color,
        onSave: (name, color) {
          setState(() {
            category.name = name;
            category.color = color;
          });
          _saveCategories();
        },
      ),
    );
  }

  void _deleteCategory(TaskCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"? Tasks assigned to this category will remain but will no longer be categorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              // Remove category from all tasks before deleting category
              await _removeCategoryFromTasks(category.id);
              
              setState(() {
                _categories.remove(category);
                // Update order for remaining categories
                for (int i = 0; i < _categories.length; i++) {
                  _categories[i].order = i;
                }
              });
              _saveCategories();
              navigator.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.lightCoral),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeCategoryFromTasks(String categoryId) async {
    // Load all tasks
    final tasks = await _taskService.loadTasks();
    
    // Remove the category ID from all tasks that have it
    bool hasChanges = false;
    for (final task in tasks) {
      if (task.categoryIds.contains(categoryId)) {
        task.categoryIds.remove(categoryId);
        hasChanges = true;
      }
    }
    
    // Save tasks only if there were changes
    if (hasChanges) {
      await _taskService.saveTasks(tasks);
    }
  }

  void _saveCategories() {
    widget.onCategoriesUpdated(_categories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Categories'),
        backgroundColor: Colors.transparent,
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final category = _categories.removeAt(oldIndex);
            _categories.insert(newIndex, category);

            // Update order for all categories
            for (int i = 0; i < _categories.length; i++) {
              _categories[i].order = i;
            }
          });
          _saveCategories();
        },
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Card(
            key: ValueKey(category.id),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: category.color,
                child: Text(
                  category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(category.name),
              subtitle: Text('Priority: ${index + 1}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _editCategory(category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: AppColors.lightCoral),
                    onPressed: () => _deleteCategory(category),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        backgroundColor: AppColors.successGreen,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}