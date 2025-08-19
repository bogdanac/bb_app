import 'package:flutter/material.dart';
import 'category_edit_dialog.dart';
import 'tasks_data_models.dart';

// TASK CATEGORIES SCREEN
class TaskCategoriesScreen extends StatefulWidget {
  final List<TaskCategory> categories;
  final Function(List<TaskCategory>) onCategoriesUpdated;

  const TaskCategoriesScreen({
    Key? key,
    required this.categories,
    required this.onCategoriesUpdated,
  }) : super(key: key);

  @override
  State<TaskCategoriesScreen> createState() => _TaskCategoriesScreenState();
}

class _TaskCategoriesScreenState extends State<TaskCategoriesScreen> {
  late List<TaskCategory> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  _addCategory() {
    showDialog(
      context: context,
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

  _editCategory(TaskCategory category) {
    showDialog(
      context: context,
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

  _deleteCategory(TaskCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _categories.remove(category);
                // Update order for remaining categories
                for (int i = 0; i < _categories.length; i++) {
                  _categories[i].order = i;
                }
              });
              _saveCategories();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  _saveCategories() {
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
                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}