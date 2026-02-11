import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../Settings/app_customization_service.dart';
import '../Energy/energy_service.dart';

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
  bool _isLowEnergy = false;

  @override
  void initState() {
    super.initState();
    _loadChores();
  }

  Future<void> _loadChores() async {
    final settings = await ChoreService.loadSettings();
    final today = DateTime.now().weekday;

    if (!settings.preferredCleaningDays.contains(today)) {
      setState(() {
        _todayChores = [];
        _isLoading = false;
      });
      return;
    }

    var chores = await ChoreService.getTodayChores();

    // Energy-aware filtering: if energy module active and battery is low,
    // prefer chores with lower effort (energyLevel closer to 0 or positive)
    final states = await AppCustomizationService.loadAllModuleStates();
    final energyEnabled = states[AppCustomizationService.moduleEnergy] ?? false;

    if (energyEnabled && chores.isNotEmpty) {
      final record = await EnergyService.getTodayRecord();
      final battery = record?.currentBattery ?? 50;

      if (battery < 30) {
        _isLowEnergy = true;
        // Low energy: only show easy chores (effort -1 to +5, i.e. not draining)
        final easyChores = chores.where((c) => c.energyLevel >= -1).toList();
        // Fall back to all chores if no easy ones match
        if (easyChores.isNotEmpty) {
          chores = easyChores;
        }
      } else if (battery < 50) {
        // Medium energy: filter out very draining chores (-4, -5)
        final mediumChores = chores.where((c) => c.energyLevel >= -2).toList();
        if (mediumChores.isNotEmpty) {
          chores = mediumChores;
        }
      }
    }

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
      String message;
      if (_todayChores.isEmpty) {
        message = 'All done — home is happy today!';
      } else if (_isLowEnergy) {
        message = 'Nice — you got it done even on a low day!';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _todayChores.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayChores = _todayChores.take(3).toList();
    final hasMore = _todayChores.length > 3;

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppStyles.borderRadiusLarge,
              color: AppColors.homeCardBackground,
            ),
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
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'Chores',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_isLowEnergy) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Easy mode',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (chore.isOverdue && !chore.isCritical)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: AppColors.grey300,
                              shape: BoxShape.circle,
                            ),
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
                        const SizedBox(width: 6),
                        Text(
                          '${chore.conditionPercentage}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: chore.conditionColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _daysAgoText(chore),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.grey300,
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

  String _daysAgoText(Chore chore) {
    final days = DateTime.now().difference(chore.lastCompleted).inDays;
    if (days == 0) return 'today';
    if (days == 1) return '1d ago';
    return '${days}d ago';
  }
}
