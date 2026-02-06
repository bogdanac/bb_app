import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class ChoreEditDialog extends StatefulWidget {
  final Chore? chore; // Null for creating new chore

  const ChoreEditDialog({super.key, this.chore});

  @override
  State<ChoreEditDialog> createState() => _ChoreEditDialogState();

  /// Show dialog to create or edit a chore
  static Future<bool?> show(BuildContext context, {Chore? chore}) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => ChoreEditDialog(chore: chore),
    );
  }
}

class _ChoreEditDialogState extends State<ChoreEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late String _selectedCategory;
  late int _intervalDays;
  late double _condition;
  late DateTime _lastCompleted;
  List<ChoreCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chore?.name ?? '');
    _notesController = TextEditingController(text: widget.chore?.notes ?? '');
    _selectedCategory = widget.chore?.category ?? 'House';
    _intervalDays = widget.chore?.intervalDays ?? 7;
    _condition = widget.chore?.condition ?? 1.0;
    _lastCompleted = widget.chore?.lastCompleted ?? DateTime.now();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ChoreService.loadCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a chore name')),
      );
      return;
    }

    final chore = widget.chore?.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          intervalDays: _intervalDays,
          condition: _condition,
          lastCompleted: _lastCompleted,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ) ??
        Chore(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          intervalDays: _intervalDays,
          condition: _condition,
          lastCompleted: _lastCompleted,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (widget.chore == null) {
      await ChoreService.addChore(chore);
    } else {
      await ChoreService.updateChore(chore);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _pickLastCompleted() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastCompleted,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _lastCompleted = picked;
      });
    }
  }

  Future<void> _addNewCategory() async {
    final TextEditingController categoryController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Garage, Garden',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = categoryController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newCategory = ChoreCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result,
        icon: Icons.category_rounded,
      );
      await ChoreService.addCategory(newCategory);
      await _loadCategories();
      setState(() {
        _selectedCategory = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isActive = _condition < 0.1;

    return AlertDialog(
      title: Text(widget.chore == null ? 'New Chore' : 'Edit Chore'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Chore Name *',
                hintText: 'e.g., Clean Kitchen',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),

            // Category dropdown with add new option
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _categories.any((c) => c.name == _selectedCategory)
                        ? _selectedCategory
                        : _categories.first.name,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: [
                      ..._categories.map((category) {
                        return DropdownMenuItem(
                          value: category.name,
                          child: Row(
                            children: [
                              Icon(category.icon, size: 20),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _addNewCategory,
                  tooltip: 'Add new category',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Interval Days picker
            Row(
              children: [
                const Expanded(
                  child: Text('Repeat every'),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller:
                        TextEditingController(text: _intervalDays.toString()),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      suffix: Text('days'),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed >= 1 && parsed <= 365) {
                        setState(() {
                          _intervalDays = parsed;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Condition slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Condition'),
                    Text(
                      '${(_condition * 100).round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getConditionColor(_condition),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _condition,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  activeColor: _getConditionColor(_condition),
                  label: '${(_condition * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _condition = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Last Completed date picker
            InkWell(
              onTap: _pickLastCompleted,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Last Completed',
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('MMM d, yyyy').format(_lastCompleted)),
                    const Icon(Icons.calendar_today, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any notes or details',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),

            // Active status badge (read-only)
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active, size: 16, color: Colors.red),
                    SizedBox(width: 6),
                    Text(
                      'Active (condition < 10%)',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(widget.chore == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Color _getConditionColor(double condition) {
    if (condition >= 0.7) return Colors.green;
    if (condition >= 0.4) return Colors.orange;
    return Colors.red;
  }
}
