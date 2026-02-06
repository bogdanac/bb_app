import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();

  /// Show dialog to manage categories
  static Future<bool?> show(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => const CategoryManagerDialog(),
    );
  }
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  List<ChoreCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ChoreService.loadCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    final TextEditingController nameController = TextEditingController();
    IconData selectedIcon = Icons.category_rounded;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Garage, Garden',
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // Icon selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Icons.home_rounded,
                  Icons.home_work_rounded,
                  Icons.house_rounded,
                  Icons.local_florist_rounded,
                  Icons.fitness_center_rounded,
                  Icons.kitchen_rounded,
                  Icons.bathroom_rounded,
                  Icons.bed_rounded,
                  Icons.living_rounded,
                  Icons.local_laundry_service_rounded,
                  Icons.yard_rounded,
                  Icons.cleaning_services_rounded,
                  Icons.category_rounded,
                ].map((icon) {
                  final isSelected = icon == selectedIcon;
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedIcon = icon;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.waterBlue.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: AppStyles.borderRadiusSmall,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.waterBlue
                              : AppColors.grey300,
                        ),
                      ),
                      child: Icon(icon, size: 28),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, {
                    'name': name,
                    'icon': selectedIcon,
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final newCategory = ChoreCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['name'],
        icon: result['icon'],
      );
      await ChoreService.addCategory(newCategory);
      await _loadCategories();
    }
  }

  Future<void> _editCategory(ChoreCategory category) async {
    final TextEditingController nameController =
        TextEditingController(text: category.name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final updatedCategory = category.copyWith(name: result);
      await ChoreService.updateCategory(updatedCategory);

      // Update all chores using this category
      final chores = await ChoreService.loadChores();
      for (var chore in chores) {
        if (chore.category == category.name) {
          await ChoreService.moveChoreToCategory(chore.id, result);
        }
      }

      await _loadCategories();
    }
  }

  Future<void> _deleteCategory(ChoreCategory category) async {
    // Check if any chores use this category
    final chores = await ChoreService.loadChores();
    final usedByChores = chores.where((c) => c.category == category.name).toList();

    if (usedByChores.isNotEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: Text(
              'This category is used by ${usedByChores.length} chore(s). '
              'Please reassign or delete those chores first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ChoreService.deleteCategory(category.id);
      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Categories'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
              width: double.maxFinite,
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                onReorder: (oldIndex, newIndex) async {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex--;
                    }
                    final item = _categories.removeAt(oldIndex);
                    _categories.insert(newIndex, item);
                  });
                  await ChoreService.saveCategories(_categories);
                },
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ListTile(
                    key: ValueKey(category.id),
                    leading: Icon(category.icon),
                    title: Text(category.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editCategory(category),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _deleteCategory(category),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: _addCategory,
          child: const Text('Add Category'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
