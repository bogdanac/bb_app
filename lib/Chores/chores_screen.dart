import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import 'chore_edit_dialog.dart';
import 'category_manager_dialog.dart';
import 'chore_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class ChoresScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const ChoresScreen({super.key, this.onOpenDrawer});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Chore> _chores = [];
  List<ChoreCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final chores = await ChoreService.loadChores();
    final categories = await ChoreService.loadCategories();

    setState(() {
      _chores = chores;
      _categories = categories;
      _isLoading = false;
    });
  }

  List<Chore> _getFilteredChores() {
    switch (_tabController.index) {
      case 0: // All
        return _chores;
      case 1: // Today
        // Return chores sorted by priority
        final today = _chores.where((c) {
          final settings = ChoreService.loadSettings();
          // This is async, so we'll need to handle this differently
          // For now, just show all chores
          return true;
        }).toList();
        today.sort((a, b) {
          final aPriority = ChoreService.calculatePriority(a);
          final bPriority = ChoreService.calculatePriority(b);
          return bPriority.compareTo(aPriority);
        });
        return today;
      case 2: // Overdue
        return _chores.where((c) => c.isOverdue).toList();
      case 3: // Critical
        return _chores.where((c) => c.isCritical).toList();
      default:
        return _chores;
    }
  }

  Map<String, List<Chore>> _groupByCategory(List<Chore> chores) {
    final grouped = <String, List<Chore>>{};
    for (final chore in chores) {
      grouped.putIfAbsent(chore.category, () => []).add(chore);
    }

    // Sort by category name if not Today tab
    if (_tabController.index != 1) {
      for (final list in grouped.values) {
        list.sort((a, b) => a.name.compareTo(b.name));
      }
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

  Future<void> _deleteChore(Chore chore) async {
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

    if (confirmed == true) {
      await ChoreService.deleteChore(chore.id);
      await _loadData();
    }
  }

  Future<void> _completeChore(Chore chore) async {
    await ChoreService.completeChore(chore.id);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${chore.name} completed! 🎉'),
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
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Today'),
            Tab(text: 'Overdue'),
            Tab(text: 'Critical'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addChore,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final filteredChores = _getFilteredChores();

    if (filteredChores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cleaning_services_rounded,
                size: 64, color: AppColors.grey300),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(),
              style: TextStyle(color: AppColors.greyText, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final grouped = _groupByCategory(filteredChores);
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) {
          final category = sortedCategories[index];
          final choresInCategory = grouped[category]!;
          final categoryIcon = _categories
              .firstWhere(
                (c) => c.name == category,
                orElse: () => ChoreCategory(
                  id: 'default',
                  name: category,
                  icon: Icons.category_rounded,
                ),
              )
              .icon;

          return _buildCategorySection(
            category,
            categoryIcon,
            choresInCategory,
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(
      String category, IconData icon, List<Chore> chores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.waterBlue),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${chores.length})',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),

        // Chores in this category
        ...chores.map((chore) => _buildChoreTile(chore)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildChoreTile(Chore chore) {
    return Dismissible(
      key: Key(chore.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
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
      },
      onDismissed: (_) async {
        await ChoreService.deleteChore(chore.id);
        await _loadData();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => _editChore(chore),
          onLongPress: () => _completeChore(chore),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chore.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (chore.isActive)
                      const Icon(Icons.notifications_active,
                          size: 16, color: Colors.red),
                    if (chore.getStreak() > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.2),
                          borderRadius: AppStyles.borderRadiusSmall,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department,
                                size: 12, color: AppColors.successGreen),
                            const SizedBox(width: 4),
                            Text(
                              '${chore.getStreak()}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Condition progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppStyles.borderRadiusSmall,
                        child: LinearProgressIndicator(
                          value: chore.currentCondition,
                          minHeight: 8,
                          backgroundColor: AppColors.grey300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            chore.conditionColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${chore.conditionPercentage}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: chore.conditionColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Due date and interval info
                Row(
                  children: [
                    Icon(
                      chore.isOverdue
                          ? Icons.warning_rounded
                          : Icons.schedule_rounded,
                      size: 14,
                      color: chore.isOverdue ? Colors.red : AppColors.greyText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getDueText(chore),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            chore.isOverdue ? Colors.red : AppColors.greyText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Every ${chore.intervalDays} days',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  String _getEmptyMessage() {
    switch (_tabController.index) {
      case 0:
        return 'No chores yet. Tap + to add one!';
      case 1:
        return 'No chores for today';
      case 2:
        return 'No overdue chores';
      case 3:
        return 'No critical chores';
      default:
        return 'No chores';
    }
  }
}
