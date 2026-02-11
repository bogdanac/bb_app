import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../Settings/app_customization_service.dart';

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
  late int _intervalValue;
  late String _intervalUnit;
  late double _condition;
  late DateTime _lastCompleted;
  late int _energyLevel;
  int? _activeMonth;
  List<ChoreCategory> _categories = [];
  bool _isLoading = true;
  bool _energyModuleEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chore?.name ?? '');
    _notesController = TextEditingController(text: widget.chore?.notes ?? '');
    _selectedCategory = widget.chore?.category ?? 'House';
    _intervalValue = widget.chore?.intervalValue ?? 7;
    _intervalUnit = widget.chore?.intervalUnit ?? 'days';
    _condition = widget.chore?.currentCondition ?? 1.0;
    _lastCompleted = widget.chore?.lastCompleted ?? DateTime.now();
    _energyLevel = widget.chore?.energyLevel ?? 0;
    _activeMonth = widget.chore?.activeMonth;
    _loadCategories();
    _loadEnergyModuleState();
  }

  Future<void> _loadCategories() async {
    final categories = await ChoreService.loadCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _loadEnergyModuleState() async {
    final states = await AppCustomizationService.loadAllModuleStates();
    if (mounted) {
      setState(() {
        _energyModuleEnabled = states[AppCustomizationService.moduleEnergy] ?? false;
      });
    }
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

    // Reverse decay: slider shows currentCondition, but we store the base
    // value so that currentCondition getter reproduces the slider value.
    // storedCondition = sliderValue + daysSince * decayRate
    final int totalIntervalDays;
    switch (_intervalUnit) {
      case 'weeks': totalIntervalDays = _intervalValue * 7; break;
      case 'months': totalIntervalDays = _intervalValue * 30; break;
      case 'years': totalIntervalDays = _intervalValue * 365; break;
      default: totalIntervalDays = _intervalValue;
    }
    final daysSince = DateTime.now().difference(_lastCompleted).inDays;
    final decayRate = 1.0 / totalIntervalDays;
    final storedCondition = (_condition + daysSince * decayRate).clamp(0.0, 1.0);

    final effectiveActiveMonth = _intervalUnit == 'years' ? _activeMonth : null;

    final chore = widget.chore?.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          intervalValue: _intervalValue,
          intervalUnit: _intervalUnit,
          condition: storedCondition,
          lastCompleted: _lastCompleted,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          energyLevel: _energyLevel,
          activeMonth: effectiveActiveMonth,
          clearActiveMonth: effectiveActiveMonth == null,
        ) ??
        Chore(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          intervalValue: _intervalValue,
          intervalUnit: _intervalUnit,
          condition: _condition, // New chore: no decay to reverse
          lastCompleted: _lastCompleted,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          energyLevel: _energyLevel,
          activeMonth: effectiveActiveMonth,
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

  String _buildIntervalDisplayText() {
    final unit = _intervalValue == 1
        ? _intervalUnit.substring(0, _intervalUnit.length - 1)
        : _intervalUnit;
    return 'Every $_intervalValue $unit';
  }

  Color _getConditionColor(double condition) {
    if (condition >= 0.7) return AppColors.successGreen;
    if (condition >= 0.4) return AppColors.orange;
    return AppColors.coral;
  }

  Color _getEnergyColor(int level) {
    if (level <= -4) return AppColors.coral;
    if (level <= -2) return AppColors.orange;
    if (level < 0) return AppColors.yellow;
    if (level == 0) return AppColors.greyText;
    if (level <= 2) return AppColors.lightGreen;
    return AppColors.successGreen;
  }

  String _getEnergyDescription(int level) {
    switch (level) {
      case -5: return 'Exhausting (-50%)';
      case -4: return 'Very draining (-40%)';
      case -3: return 'Draining (-30%)';
      case -2: return 'Moderate effort (-20%)';
      case -1: return 'Light effort (-10%)';
      case 0: return 'Neutral (0%)';
      case 1: return 'Relaxing (+10%)';
      case 2: return 'Refreshing (+20%)';
      case 3: return 'Energizing (+30%)';
      case 4: return 'Very energizing (+40%)';
      case 5: return 'Restorative (+50%)';
      default: return 'Unknown';
    }
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
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

            // Repeat Interval Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(color: AppColors.greyText),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
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
                                _buildIntervalDisplayText(),
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
                              onPressed: _intervalValue > 1
                                  ? () => setState(() => _intervalValue--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppColors.purple,
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$_intervalValue',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _intervalValue < 365
                                  ? () => setState(() => _intervalValue++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                              color: AppColors.purple,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Unit selector
                    Row(
                      children: [
                        for (final unit in ['days', 'weeks', 'months', 'years'])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ChoiceChip(
                                label: Text(
                                  unit[0].toUpperCase() + unit.substring(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _intervalUnit == unit ? AppColors.white : AppColors.greyText,
                                  ),
                                ),
                                selected: _intervalUnit == unit,
                                selectedColor: AppColors.purple,
                                backgroundColor: AppColors.dialogBackground.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) setState(() => _intervalUnit = unit);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Active month selector (only for yearly interval)
                    if (_intervalUnit == 'years') ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (int m = 1; m <= 12; m++)
                            ChoiceChip(
                              label: Text(
                                const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _activeMonth == m ? AppColors.white : AppColors.greyText,
                                ),
                              ),
                              selected: _activeMonth == m,
                              selectedColor: AppColors.purple,
                              backgroundColor: AppColors.dialogBackground.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                              showCheckmark: false,
                              onSelected: (selected) {
                                setState(() => _activeMonth = selected ? m : null);
                              },
                            ),
                        ],
                      ),
                    ],
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

            // Energy Level Section (only if energy module active)
            if (_energyModuleEnabled) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.dialogBackground.withValues(alpha: 0.08),
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: _energyLevel != 0
                        ? _getEnergyColor(_energyLevel).withValues(alpha: 0.3)
                        : AppColors.greyText,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _energyLevel < 0 ? Icons.battery_3_bar_rounded : Icons.battery_charging_full_rounded,
                        color: _energyLevel != 0
                            ? _getEnergyColor(_energyLevel)
                            : AppColors.greyText,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: _getEnergyColor(_energyLevel),
                                inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.2),
                                thumbColor: _getEnergyColor(_energyLevel),
                                overlayColor: _getEnergyColor(_energyLevel).withValues(alpha: 0.2),
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              ),
                              child: Slider(
                                value: _energyLevel.toDouble(),
                                min: -5,
                                max: 5,
                                divisions: 10,
                                onChanged: (value) {
                                  setState(() => _energyLevel = value.round());
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                _getEnergyDescription(_energyLevel),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _energyLevel != 0 ? _getEnergyColor(_energyLevel) : AppColors.greyText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Active status badge (for critical condition)
            if (isActive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.waterBlue.withValues(alpha: 0.1),
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: AppColors.waterBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.spa_rounded, size: 20, color: AppColors.waterBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A little care goes a long way — this one could use some love!',
                        style: TextStyle(color: AppColors.waterBlue, fontSize: 14),
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
      ),
      ),
    );
  }

  String _getConditionLabel(double condition) {
    if (condition >= 0.8) return 'Excellent';
    if (condition >= 0.6) return 'Good';
    if (condition >= 0.4) return 'Fair';
    if (condition >= 0.2) return 'Needs attention';
    return 'Overdue';
  }
}
