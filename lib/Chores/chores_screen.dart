import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import 'chore_edit_dialog.dart';
import 'category_manager_dialog.dart';
import 'chore_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../shared/date_format_utils.dart';

class ChoresScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const ChoresScreen({super.key, this.onOpenDrawer});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> {
  List<Chore> _chores = [];
  List<ChoreCategory> _categories = [];
  bool _isLoading = true;
  Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final chores = await ChoreService.loadChores();
    final categories = await ChoreService.loadCategories();

    // Expand categories that have critical or overdue chores by default
    final expandedByDefault = <String>{};
    for (final chore in chores) {
      if (chore.isCritical || chore.isOverdue) {
        expandedByDefault.add(chore.category);
      }
    }

    setState(() {
      _chores = chores;
      _categories = categories;
      _expandedCategories = expandedByDefault;
      _isLoading = false;
    });
  }

  Map<String, List<Chore>> _groupByCategory() {
    final grouped = <String, List<Chore>>{};
    for (final chore in _chores) {
      grouped.putIfAbsent(chore.category, () => []).add(chore);
    }

    // Sort chores within each category by condition (worst first)
    for (final list in grouped.values) {
      list.sort((a, b) => a.currentCondition.compareTo(b.currentCondition));
    }

    return grouped;
  }

  Future<void> _addChore() async {
    final result = await ChoreEditDialog.show(context);
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _editChore(Chore chore) async {
    final result = await ChoreEditDialog.show(context, chore: chore);
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _completeChore(Chore chore) async {
    await ChoreService.completeChore(chore.id);
    await _loadData();

    if (mounted) {
      final remaining = _chores.where((c) => c.isCritical || c.isOverdue).length;
      String message;
      if (remaining == 0) {
        message = 'All done — home is happy today!';
      } else {
        message = '${chore.name} done!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setLastDoneDate(Chore chore) async {
    final now = DateTime.now();
    final initialDate = chore.lastCompleted.isAfter(now) ? now : chore.lastCompleted;

    final picked = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: chore.createdAt,
      lastDate: now,
    );

    if (picked == null || !mounted) return;

    final pickedDateTime = DateTime(picked.year, picked.month, picked.day, 12);
    final updatedChore = chore.copyWith(
      lastCompleted: pickedDateTime,
      condition: 1.0,
      completionHistory: [
        ...chore.completionHistory,
        ChoreCompletion(completedAt: pickedDateTime),
      ],
    );

    await ChoreService.updateChore(updatedChore);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${chore.name}" marked as done ${DateFormatUtils.formatRelative(picked)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openCategoryManager() async {
    final result = await CategoryManagerDialog.show(context);
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChoreSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.category_rounded),
            onPressed: _openCategoryManager,
            tooltip: 'Manage Categories',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _isLoading
              ? const CircularProgressIndicator()
              : _buildBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addChore,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_chores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cleaning_services_rounded,
                size: 64, color: AppColors.grey300),
            const SizedBox(height: 16),
            Text(
              'A tidy space starts with one chore',
              style: TextStyle(color: AppColors.greyText, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to add your first one',
              style: TextStyle(color: AppColors.grey300, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Get priority chores (sorted by condition, worst first)
    final priorityChores = _chores
        .where((c) => c.isCritical || c.isOverdue)
        .toList()
      ..sort((a, b) => a.currentCondition.compareTo(b.currentCondition));

    final grouped = _groupByCategory();
    final categoryOrder = _categories.map((c) => c.name).toList();

    // Sort categories by defined order
    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) {
        final aIndex = categoryOrder.indexOf(a);
        final bIndex = categoryOrder.indexOf(b);
        if (aIndex == -1 && bIndex == -1) return a.compareTo(b);
        if (aIndex == -1) return 1;
        if (bIndex == -1) return -1;
        return aIndex.compareTo(bIndex);
      });

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Priority section
          if (priorityChores.isNotEmpty) ...[
            _buildPrioritySection(priorityChores),
            const SizedBox(height: 16),
          ],

          // Categories section header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'By Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
          ),

          // Category list
          ...sortedCategories.map((category) {
            final choresInCategory = grouped[category]!;
            final categoryData = _categories.firstWhere(
              (c) => c.name == category,
              orElse: () => ChoreCategory(
                id: 'default',
                name: category,
                icon: Icons.category_rounded,
              ),
            );

            return _buildExpandableCategory(
              category,
              categoryData.icon,
              choresInCategory,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPrioritySection(List<Chore> priorityChores) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusMedium,
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.priority_high_rounded, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Needs Attention',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Spacer(),
                Text(
                  '${priorityChores.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.red.withValues(alpha: 0.2),
          ),
          // Priority chores list
          ...priorityChores.take(3).map((chore) => _buildPriorityTile(chore)),
          if (priorityChores.length > 3)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '+${priorityChores.length - 3} more',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriorityTile(Chore chore) {
    final categoryData = _categories.firstWhere(
      (c) => c.name == chore.category,
      orElse: () => ChoreCategory(
        id: 'default',
        name: chore.category,
        icon: Icons.category_rounded,
      ),
    );

    return InkWell(
      onTap: () => _editChore(chore),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(categoryData.icon, size: 18, color: AppColors.greyText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chore.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${chore.conditionPercentage}% • ${_daysAgoText(chore)} • ${_getDueText(chore)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: chore.isOverdue ? Colors.red : AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            _buildChorePopupMenu(chore),
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: () => _completeChore(chore),
              iconSize: 24,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: AppColors.successGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableCategory(
      String category, IconData icon, List<Chore> chores) {
    final isExpanded = _expandedCategories.contains(category);
    final criticalCount = chores.where((c) => c.isCritical).length;
    final overdueCount = chores.where((c) => c.isOverdue && !c.isCritical).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.normalCardBackground,
        borderRadius: AppStyles.borderRadiusMedium,
      ),
      child: Column(
        children: [
          // Category header (tap to expand/collapse)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(category);
                } else {
                  _expandedCategories.add(category);
                }
              });
            },
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : AppStyles.borderRadiusMedium,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: AppColors.waterBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${chores.length} ${chores.length == 1 ? 'chore' : 'chores'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badges
                  if (criticalCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: AppStyles.borderRadiusSmall,
                      ),
                      child: Text(
                        '$criticalCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (overdueCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.2),
                        borderRadius: AppStyles.borderRadiusSmall,
                      ),
                      child: Text(
                        '$overdueCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.greyText,
                  ),
                ],
              ),
            ),
          ),

          // Expanded chores list
          if (isExpanded) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: AppColors.grey700,
            ),
            ...chores.map((chore) => _buildChoreTile(chore)),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteChore(Chore chore) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chore'),
        content: Text('Delete "${chore.name}"?'),
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
    if (confirmed == true && mounted) {
      await ChoreService.deleteChore(chore.id);
      await _loadData();
    }
  }

  Widget _buildChorePopupMenu(Chore chore) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppColors.grey300, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: AppColors.normalCardBackground,
      onSelected: (value) {
        if (value == 'edit') {
          _editChore(chore);
        } else if (value == 'set_last_done') {
          _setLastDoneDate(chore);
        } else if (value == 'delete') {
          _confirmDeleteChore(chore);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18),
              SizedBox(width: 12),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'set_last_done',
          child: Row(
            children: [
              Icon(Icons.event_available_rounded, size: 18, color: Colors.blue),
              const SizedBox(width: 12),
              Text('Set last done date', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoreTile(Chore chore) {
    return InkWell(
      onTap: () => _editChore(chore),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Condition indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: chore.conditionColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Text(
                    chore.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Info row
                  Row(
                    children: [
                      Text(
                        '${chore.conditionPercentage}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: chore.conditionColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _daysAgoText(chore),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.grey300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getDueText(chore),
                        style: TextStyle(
                          fontSize: 12,
                          color: chore.isOverdue ? Colors.red : AppColors.greyText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        chore.intervalDisplayText,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Options menu
            _buildChorePopupMenu(chore),

            // Complete button
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: () => _completeChore(chore),
              iconSize: 28,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: AppColors.successGreen,
              tooltip: 'Complete',
            ),
          ],
        ),
      ),
    );
  }

  String _daysAgoText(Chore chore) {
    final days = DateTime.now().difference(chore.lastCompleted).inDays;
    if (days == 0) return 'today';
    if (days == 1) return '1d ago';
    return '${days}d ago';
  }

  String _getDueText(Chore chore) {
    final days = chore.daysUntilDue;
    if (days < 0) {
      return '${-days} ${-days == 1 ? 'day' : 'days'} overdue';
    } else if (days == 0) {
      return 'Due today';
    } else if (days == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in $days days';
    }
  }

}
