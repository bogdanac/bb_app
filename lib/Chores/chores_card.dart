import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class ChoresCard extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onChoreCompleted;

  const ChoresCard({
    super.key,
    this.onTap,
    this.onChoreCompleted,
  });

  @override
  State<ChoresCard> createState() => _ChoresCardState();
}

class _ChoresCardState extends State<ChoresCard> {
  List<Chore> _todayChores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChores();
  }

  Future<void> _loadChores() async {
    final settings = await ChoreService.loadSettings();
    final today = DateTime.now().weekday; // 1=Monday, 7=Sunday

    // Only load if today is a preferred day
    if (!settings.preferredCleaningDays.contains(today)) {
      setState(() {
        _todayChores = [];
        _isLoading = false;
      });
      return;
    }

    final chores = await ChoreService.getTodayChores();

    setState(() {
      _todayChores = chores;
      _isLoading = false;
    });
  }

  Future<void> _completeChore(Chore chore) async {
    await ChoreService.completeChore(chore.id);
    await _loadChores();
    widget.onChoreCompleted?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${chore.name} completed! 🎉'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show card if loading or no chores
    if (_isLoading || _todayChores.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayChores = _todayChores.take(5).toList();
    final hasMore = _todayChores.length > 5;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration:
            AppStyles.cardDecoration(color: AppColors.homeCardBackground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.cleaning_services_rounded,
                      color: AppColors.waterBlue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chores',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.grey300, size: 20),
                ],
              ),
            ),

            // Chores list
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  ...displayChores.map((chore) => _buildChoreItem(chore)),
                  if (hasMore) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onTap,
                      child: Text(
                        'View all (${_todayChores.length})',
                        style: TextStyle(color: AppColors.waterBlue),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoreItem(Chore chore) {
    final categories = ChoreService.loadCategories();

    return FutureBuilder<List<ChoreCategory>>(
      future: categories,
      builder: (context, snapshot) {
        final categoryIcon = snapshot.hasData
            ? snapshot.data!
                .firstWhere(
                  (c) => c.name == chore.category,
                  orElse: () => ChoreCategory(
                    id: 'default',
                    name: chore.category,
                    icon: Icons.category_rounded,
                  ),
                )
                .icon
            : Icons.category_rounded;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Category icon
              Icon(categoryIcon, size: 16, color: AppColors.greyText),
              const SizedBox(width: 8),

              // Chore name and condition bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chore.name,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chore.isCritical)
                          const Text(
                            '🔴',
                            style: TextStyle(fontSize: 12),
                          ),
                        if (chore.isOverdue && !chore.isCritical)
                          const Text(
                            '⚠️',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppStyles.borderRadiusSmall,
                            child: LinearProgressIndicator(
                              value: chore.currentCondition,
                              minHeight: 6,
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
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: chore.conditionColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Complete button
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _completeChore(chore),
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Complete',
                color: chore.conditionColor,
              ),
            ],
          ),
        );
      },
    );
  }
}
