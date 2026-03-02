import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../Settings/app_customization_service.dart';
import '../Energy/energy_service.dart';
import '../Tasks/task_card_utils.dart';

class ChoresCard extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onChoreCompleted;

  const ChoresCard({
    super.key,
    this.onTap,
    this.onChoreCompleted,
  });

  @override
  State<ChoresCard> createState() => ChoresCardState();
}

class ChoresCardState extends State<ChoresCard> {
  /// Refresh chores data from outside (e.g., when returning to Home tab)
  void refresh() => _loadChores();
  List<Chore> _todayChores = [];
  bool _isLoading = true;
  bool _isLowEnergy = false;
  bool _energyModuleEnabled = false;

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

    _energyModuleEnabled = energyEnabled;

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

    final displayChores = _todayChores.take(2).toList();
    final extraCount = _todayChores.length - displayChores.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppStyles.borderRadiusLarge,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppStyles.borderRadiusLarge,
            color: AppColors.homeCardBackground,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...displayChores.map((chore) => _buildChoreItem(chore)),
                if (extraCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '+$extraCount more',
                      style: TextStyle(fontSize: 12, color: AppColors.greyText),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Condition dot (matches activity row style)
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: chore.conditionColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Chore name
          Expanded(
            child: Text(
              chore.name,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Energy chip
          if (_energyModuleEnabled && chore.energyLevel != 0) ...[
            TaskCardUtils.buildEnergyChip(chore.energyLevel),
            const SizedBox(width: 8),
          ],

          // Complete button (matches activity row circle style)
          GestureDetector(
            onTap: () => _completeChore(chore),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.successGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
