import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();

  /// Show as a full-screen page
  static Future<bool?> show(BuildContext context) async {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryManagerDialog(),
      ),
    );
  }
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  List<ChoreCategory> _categories = [];
  bool _isLoading = true;

  static const List<IconData> _availableIcons = [
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
    Icons.garage_rounded,
    Icons.deck_rounded,
    Icons.pool_rounded,
  ];

  static const List<Color> _availableColors = [
    Color(0xFFFF7043), // coral
    Color(0xFFFFB74D), // orange
    Color(0xFFFFD54F), // yellow
    Color(0xFFE57373), // red
    Color(0xFF81C784), // green
    Color(0xFF64B5F6), // waterBlue
    Color(0xFF4DD0E1), // cyan
    Color(0xFF9575CD), // purple
    Color(0xFFF06292), // pink
    Color(0xFFA1887F), // brown
    Color(0xFF90A4AE), // grey
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ChoreService.loadCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => _CategoryEditScreen(
          availableIcons: _availableIcons,
          availableColors: _availableColors,
        ),
      ),
    );

    if (result != null && mounted) {
      final newCategory = ChoreCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['name'],
        icon: result['icon'],
        color: result['color'] ?? AppColors.waterBlue,
      );
      await ChoreService.addCategory(newCategory);
      await _loadCategories();
    }
  }

  Future<void> _editCategory(ChoreCategory category) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => _CategoryEditScreen(
          initialName: category.name,
          initialIcon: category.icon,
          initialColor: category.color,
          availableIcons: _availableIcons,
          availableColors: _availableColors,
        ),
      ),
    );

    if (result != null && result['name'] != null && mounted) {
      final updatedCategory = category.copyWith(
        name: result['name'],
        icon: result['icon'],
        color: result['color'],
      );
      await ChoreService.updateCategory(updatedCategory);

      // Update all chores using this category
      final chores = await ChoreService.loadChores();
      for (var chore in chores) {
        if (chore.category == category.name) {
          await ChoreService.moveChoreToCategory(chore.id, result['name']);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot delete: ${usedByChores.length} chore(s) use this category',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ChoreService.deleteCategory(category.id);
      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(
                Icons.check_rounded,
                color: AppColors.successGreen,
              ),
              label: Text(
                'Done',
                style: TextStyle(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        backgroundColor: AppColors.waterBlue,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                    return _buildCategoryCard(category, index);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_rounded,
            size: 64,
            color: AppColors.grey300,
          ),
          const SizedBox(height: 16),
          Text(
            'No categories yet',
            style: TextStyle(
              color: AppColors.greyText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add one',
            style: TextStyle(
              color: AppColors.grey300,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(ChoreCategory category, int index) {
    return Container(
      key: ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(category.icon, color: category.color, size: 24),
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Drag to reorder',
          style: TextStyle(
            color: AppColors.grey300,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 20, color: AppColors.greyText),
              onPressed: () => _editCategory(category),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded, size: 20, color: AppColors.error),
              onPressed: () => _deleteCategory(category),
              tooltip: 'Delete',
            ),
            Icon(Icons.drag_handle_rounded, color: AppColors.grey300),
          ],
        ),
      ),
    );
  }
}

/// Internal screen for adding/editing a category
class _CategoryEditScreen extends StatefulWidget {
  final String? initialName;
  final IconData? initialIcon;
  final Color? initialColor;
  final List<IconData> availableIcons;
  final List<Color> availableColors;

  const _CategoryEditScreen({
    this.initialName,
    this.initialIcon,
    this.initialColor,
    required this.availableIcons,
    required this.availableColors,
  });

  @override
  State<_CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<_CategoryEditScreen> {
  late TextEditingController _nameController;
  late IconData _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon ?? Icons.category_rounded;
    _selectedColor = widget.initialColor ?? const Color(0xFF64B5F6);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, {
      'name': name,
      'icon': _selectedIcon,
      'color': _selectedColor,
    });
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName != null;

    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Category' : 'New Category'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _canSave ? _submit : null,
              icon: Icon(
                Icons.check_rounded,
                color: _canSave ? AppColors.successGreen : AppColors.grey300,
              ),
              label: Text(
                isEditing ? 'Save' : 'Add',
                style: TextStyle(
                  color: _canSave ? AppColors.successGreen : AppColors.grey300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview card at top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedIcon,
                      color: _selectedColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text.isEmpty ? 'Category Name' : _nameController.text,
                    style: TextStyle(
                      color: _nameController.text.isEmpty ? AppColors.grey300 : AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            _buildFieldContainer(
              icon: Icons.label_rounded,
              iconColor: AppColors.purple,
              label: 'Category Name',
              child: TextField(
                controller: _nameController,
                decoration: AppStyles.inputDecoration(
                  hintText: 'e.g., Garage, Garden',
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: widget.initialName == null,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker
            _buildFieldContainer(
              icon: Icons.palette_rounded,
              iconColor: _selectedColor,
              label: 'Color',
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.availableColors.map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check_rounded, color: AppColors.white, size: 24)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Icon picker
            _buildFieldContainer(
              icon: Icons.emoji_symbols_rounded,
              iconColor: _selectedColor,
              label: 'Icon',
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.availableIcons.map((icon) {
                    final isSelected = _selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? _selectedColor : AppColors.grey700,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: isSelected ? _selectedColor : AppColors.greyText,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldContainer({
    required IconData icon,
    required Color iconColor,
    required String label,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.greyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }
}
