import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';

class ChoreEditDialog extends StatefulWidget {
  final Chore? chore; // Null for creating new chore

  const ChoreEditDialog({super.key, this.chore});

  @override
  State<ChoreEditDialog> createState() => _ChoreEditDialogState();

  /// Show dialog to create or edit a chore
  static Future<bool?> show(BuildContext context, {Chore? chore}) async {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ChoreEditDialog(chore: chore),
        fullscreenDialog: true,
      ),
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
    final picked = await DatePickerUtils.showStyledDatePicker(
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
        backgroundColor: AppColors.dialogBackground,
        title: const Text('New Category'),
        content: TextField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Garage, Garden',
            border: OutlineInputBorder(
              borderRadius: AppStyles.borderRadiusMedium,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = categoryController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.waterBlue,
            ),
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

  Color _getConditionColor(double condition) {
    if (condition >= 0.7) return AppColors.successGreen;
    if (condition >= 0.4) return AppColors.orange;
    return AppColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.dialogBackground,
        appBar: AppBar(
          title: Text(widget.chore == null ? 'New Chore' : 'Edit Chore'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isActive = _condition < 0.1;

    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: Text(widget.chore == null ? 'New Chore' : 'Edit Chore'),
        backgroundColor: Colors.transparent,
        actions: [
          // Save button in app bar
          TextButton.icon(
            onPressed: _nameController.text.trim().isNotEmpty ? _save : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.chore == null ? 'Create' : 'Save'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.waterBlue,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chore Name Section
            TextField(
              controller: _nameController,
              minLines: 1,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Chore Name *',
                hintText: 'e.g., Clean Kitchen',
                border: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                  borderSide: BorderSide(color: AppColors.greyText),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                  borderSide: BorderSide(color: AppColors.waterBlue, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 16),

            // Category Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(color: AppColors.greyText),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.waterBlue.withValues(alpha: 0.1),
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                      child: Icon(
                        _categories.firstWhere(
                          (c) => c.name == _selectedCategory,
                          orElse: () => _categories.first,
                        ).icon,
                        color: AppColors.waterBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categories.any((c) => c.name == _selectedCategory)
                              ? _selectedCategory
                              : _categories.first.name,
                          isExpanded: true,
                          icon: const Icon(Icons.expand_more_rounded),
                          dropdownColor: AppColors.dialogBackground,
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category.name,
                              child: Row(
                                children: [
                                  Icon(category.icon, size: 20, color: AppColors.greyText),
                                  const SizedBox(width: 12),
                                  Text(category.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: AppColors.waterBlue),
                      onPressed: _addNewCategory,
                      tooltip: 'Add new category',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Interval Days Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(color: AppColors.greyText),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.1),
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                      child: Icon(
                        Icons.repeat_rounded,
                        color: AppColors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Repeat Interval',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Every $_intervalDays days',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _intervalDays > 1
                              ? () => setState(() => _intervalDays--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: AppColors.purple,
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$_intervalDays',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _intervalDays < 365
                              ? () => setState(() => _intervalDays++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current Condition Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: _getConditionColor(_condition).withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getConditionColor(_condition).withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusMedium,
                          ),
                          child: Icon(
                            _condition >= 0.7
                                ? Icons.sentiment_satisfied_rounded
                                : _condition >= 0.4
                                    ? Icons.sentiment_neutral_rounded
                                    : Icons.sentiment_dissatisfied_rounded,
                            color: _getConditionColor(_condition),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Condition',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.greyText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(_condition * 100).round()}% - ${_getConditionLabel(_condition)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getConditionColor(_condition),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _getConditionColor(_condition),
                        inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.2),
                        thumbColor: _getConditionColor(_condition),
                        overlayColor: _getConditionColor(_condition).withValues(alpha: 0.2),
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: _condition,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        onChanged: (value) {
                          setState(() {
                            _condition = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Last Completed Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(color: AppColors.greyText),
              ),
              child: InkWell(
                onTap: _pickLastCompleted,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.successGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Completed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, yyyy').format(_lastCompleted),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.greyText,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notes Section
            TextField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any notes or details',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                  borderSide: BorderSide(color: AppColors.greyText),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                  borderSide: BorderSide(color: AppColors.waterBlue, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),

            // Active status badge (for critical condition)
            if (isActive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.1),
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.coral.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, size: 20, color: AppColors.coral),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This chore is in critical condition and needs attention!',
                        style: TextStyle(color: AppColors.coral, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getConditionLabel(double condition) {
    if (condition >= 0.8) return 'Excellent';
    if (condition >= 0.6) return 'Good';
    if (condition >= 0.4) return 'Fair';
    if (condition >= 0.2) return 'Needs attention';
    return 'Critical';
  }
}
