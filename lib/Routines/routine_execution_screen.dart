import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'routine_data_models.dart';
import 'routine_progress_service.dart';
import '../shared/snackbar_utils.dart';
import '../shared/error_logger.dart';
import '../Energy/energy_service.dart';
import '../Energy/energy_celebrations.dart';
import '../Energy/flow_calculator.dart';
import '../Settings/app_customization_service.dart';

// ROUTINE EXECUTION SCREEN - UPDATED WITH SAVE FUNCTIONALITY
class RoutineExecutionScreen extends StatefulWidget {
  final Routine routine;
  final VoidCallback onCompleted;

  const RoutineExecutionScreen({
    super.key,
    required this.routine,
    required this.onCompleted,
  });

  @override
  State<RoutineExecutionScreen> createState() => _RoutineExecutionScreenState();
}

class _RoutineExecutionScreenState extends State<RoutineExecutionScreen> {
  late List<RoutineItem> _items;
  bool _playMusic = false;
  bool _energyModuleEnabled = true;

  @override
  void initState() {
    super.initState();
    // Preserve energyLevel from original routine items
    _items = widget.routine.items.map((item) => RoutineItem(
      id: item.id,
      text: item.text,
      isCompleted: false,
      isSkipped: false,
      energyLevel: item.energyLevel,
    )).toList();
    _loadProgress();
    _loadEnergyModuleState();
  }

  Future<void> _loadEnergyModuleState() async {
    final enabled = await AppCustomizationService.isModuleEnabled(AppCustomizationService.moduleEnergy);
    if (mounted) {
      setState(() => _energyModuleEnabled = enabled);
    }
  }

  Future<void> _loadProgress() async {
    final progressData = await RoutineProgressService.loadRoutineProgress(widget.routine.id);

    if (progressData != null) {
      try {
        final completedSteps = List<bool>.from(progressData['completedSteps'] ?? []);
        final skippedSteps = List<bool>.from(progressData['skippedSteps'] ?? []);
        final postponedSteps = List<bool>.from(progressData['postponedSteps'] ?? []);
        final savedItemCount = progressData['itemCount'] as int?;

        // Validate that the saved data matches current routine structure
        if (savedItemCount != null && savedItemCount != _items.length) {
          return; // Don't load progress if routine structure changed
        }

        setState(() {
          for (int i = 0; i < _items.length; i++) {
            if (i < completedSteps.length) {
              _items[i].isCompleted = completedSteps[i];
            }
            if (i < skippedSteps.length) {
              _items[i].isSkipped = skippedSteps[i];
            }
            if (i < postponedSteps.length) {
              _items[i].isPostponed = postponedSteps[i];
            }
          }
        });
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'RoutineExecutionScreen._loadProgress',
          error: 'Error loading progress: $e',
          stackTrace: stackTrace.toString(),
          context: {'routineId': widget.routine.id},
        );
      }
    }
  }

  Future<void> _saveProgress() async {
    try {
      // Find the current step index (first non-completed, non-skipped step)
      int currentStepIndex = 0;
      for (int i = 0; i < _items.length; i++) {
        if (!_items[i].isCompleted && !_items[i].isSkipped) {
          currentStepIndex = i;
          break;
        }
      }
      
      await RoutineProgressService.saveRoutineProgress(
        routineId: widget.routine.id,
        currentStepIndex: currentStepIndex,
        items: _items,
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RoutineExecutionScreen._saveProgress',
        error: 'Error saving routine progress: $e',
        stackTrace: stackTrace.toString(),
        context: {'routineId': widget.routine.id},
      );
    }
  }

  Future<void> _toggleItem(int index) async {
    final item = _items[index];
    final wasCompleted = item.isCompleted;

    setState(() {
      _items[index].isCompleted = !_items[index].isCompleted;
      if (_items[index].isCompleted) {
        _items[index].isSkipped = false; // If completed, it's no longer skipped
      }
    });
    await _saveProgress();

    // Track energy when completing/uncompleting a step (only if energy module is enabled)
    if (_energyModuleEnabled) {
      // Use energyLevel if set, otherwise default to 0 (neutral - no battery impact)
      final energyLevel = item.energyLevel ?? 0;
      if (!wasCompleted && _items[index].isCompleted) {
        // Just completed - add energy
        await EnergyService.addRoutineStepEnergyConsumption(
          stepId: item.id,
          stepTitle: item.text,
          energyLevel: energyLevel,
          routineTitle: widget.routine.title,
        );
        if (mounted) {
          await _showEnergyCelebration(energyLevel);
        }
      } else if (wasCompleted && !_items[index].isCompleted) {
        // Uncompleted - remove energy
        await EnergyService.removeEnergyConsumption(item.id);
      }
    }
  }

  Future<void> _showEnergyCelebration(int energyLevel) async {
    // Get today's record for proper flow points tracking
    final record = await EnergyService.getTodayRecord();
    if (record == null) return;

    final flowPoints = record.flowPoints;
    final flowGoal = record.flowGoal;
    final pointsEarned = FlowCalculator.calculateFlowPoints(energyLevel);
    final settings = await EnergyService.loadSettings();

    // Check if goal was JUST met (not already met before this task)
    final flowPointsBefore = flowPoints - pointsEarned;
    final goalJustMet = record.isGoalMet && flowPointsBefore < flowGoal;

    // Check for achievements - only celebrate when goal is JUST crossed
    if (goalJustMet && mounted) {
      // Check if this is a streak milestone
      final milestone = FlowCalculator.getStreakMilestone(settings.currentStreak);
      if (milestone != null) {
        await EnergyCelebrations.showStreakMilestoneCelebration(context, settings.currentStreak);
      } else if (record.isPR) {
        // Personal record!
        await EnergyCelebrations.showPersonalRecordCelebration(
          context,
          flowPoints,
          settings.personalRecord > flowPoints ? settings.personalRecord : flowPointsBefore,
        );
      } else {
        // Goal met celebration
        await EnergyCelebrations.showGoalMetCelebration(context, flowPoints, flowGoal);
      }
    } else {
      // Regular flow points added - show snackbar
      if (mounted) {
        final batteryChange = FlowCalculator.calculateBatteryChange(energyLevel);
        final batteryText = batteryChange >= 0 ? '+$batteryChange%' : '$batteryChange%';
        SnackBarUtils.showSuccess(
          context,
          '⚡ $batteryText battery, $pointsEarned pts ($flowPoints/$flowGoal)',
        );
      }
    }
  }

  Color _getEnergyColor(int level) {
    // -5 to +5 scale: negative = draining (red), positive = charging (green)
    if (level <= -4) return AppColors.coral;
    if (level <= -2) return AppColors.orange;
    if (level < 0) return Colors.amber;
    if (level == 0) return Colors.grey;
    if (level <= 2) return Colors.lightGreen;
    return Colors.green;
  }

  Future<void> _skipItem(int index) async {
    setState(() {
      _items[index].isSkipped = !_items[index].isSkipped;
      if (_items[index].isSkipped) {
        _items[index].isCompleted = false; // If skipped, it's not completed
        _items[index].isPostponed = false; // If skipped, it's not postponed
      }
    });
    await _saveProgress();
  }

  Future<void> _postponeItem(int index) async {
    setState(() {
      _items[index].isPostponed = !_items[index].isPostponed;
      if (_items[index].isPostponed) {
        _items[index].isCompleted = false; // If postponed, it's not completed
        _items[index].isSkipped = false; // If postponed, it's not skipped
      }
    });
    await _saveProgress();
  }

  bool _isAllCompleted() {
    return _items.every((item) => item.isCompleted);
  }

  bool _areAllNonSkippedCompleted() {
    return _items.where((item) => !item.isSkipped).every((item) => item.isCompleted);
  }

  bool _areAllNonPostponedNonSkippedCompleted() {
    return _items.where((item) => !item.isSkipped && !item.isPostponed).every((item) => item.isCompleted);
  }

  List<RoutineItem> _getSkippedItems() {
    return _items.where((item) => item.isSkipped).toList();
  }

  List<RoutineItem> _getPostponedItems() {
    return _items.where((item) => item.isPostponed).toList();
  }

  bool _hasSkippedItems() {
    return _items.any((item) => item.isSkipped);
  }

  bool _hasPostponedItems() {
    return _items.any((item) => item.isPostponed);
  }

  Future<void> _completeRoutine() async {
    // Mark all items as completed
    setState(() {
      for (var item in _items) {
        item.isCompleted = true;
      }
    });
    await _saveProgress();

    widget.onCompleted();
    if (mounted) {
      Navigator.pop(context);
      SnackBarUtils.showSuccess(context, '🎉 ${widget.routine.title} completed! Great job!');
    }
  }

  Future<void> _completePartialRoutine() async {
    await _saveProgress();

    final completedCount = _items.where((item) => item.isCompleted).length;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save Progress'),
          content: Text(
            'You completed $completedCount out of ${_items.length} steps. Your progress has been saved!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close routine screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _items.where((item) => item.isCompleted).length;
    final skippedCount = _items.where((item) => item.isSkipped).length;
    final postponedCount = _items.where((item) => item.isPostponed).length;
    final allCompleted = _isAllCompleted();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.title),
        backgroundColor: AppColors.orange.withValues(alpha: 0.3),
        actions: [
          IconButton(
            icon: Icon(
              _playMusic ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            onPressed: () {
              setState(() {
                _playMusic = !_playMusic;
              });
              SnackBarUtils.showInfo(context, _playMusic ? 'Music enabled' : 'Music disabled');
            },
          ),
          // Save progress button
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _completePartialRoutine,
            tooltip: 'Save Progress',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.orange.withValues(alpha: 0.3),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '✨ ${widget.routine.title}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          Text(
                            'Progress: $completedCount/${_items.length}',
                            style: const TextStyle(fontSize: 16, color: AppColors.greyText),
                          ),
                          if (postponedCount > 0)
                            Text(
                              'Postponed: $postponedCount deferred',
                              style: TextStyle(fontSize: 14, color: Colors.blue[600]),
                            ),
                          if (skippedCount > 0)
                            Text(
                              'Skipped: $skippedCount',
                              style: TextStyle(fontSize: 14, color: Colors.orange[600]),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: completedCount / _items.length,
                        backgroundColor: AppColors.greyText,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: Column(
                  children: [
                    // Show notification if regular items are done but postponed items remain
                    if (_areAllNonPostponedNonSkippedCompleted() && _hasPostponedItems()) ...[
                      Card(
                        color: Colors.blue.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.blue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Great progress! You have ${_getPostponedItems().length} postponed step${_getPostponedItems().length == 1 ? '' : 's'} waiting. Complete them when ready!',
                                  style: TextStyle(color: Colors.blue[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                    // Show notification if skipped items remain
                    if (_areAllNonSkippedCompleted() && _hasSkippedItems() && !_hasPostponedItems()) ...[
                      Card(
                        color: Colors.orange.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.skip_next, color: Colors.orange),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You have ${_getSkippedItems().length} skipped step${_getSkippedItems().length == 1 ? '' : 's'}. Unskip them if you want to complete them.',
                                  style: TextStyle(color: Colors.orange[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                    
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final hasEnergy = item.energyLevel != null;

                          // Determine card color based on state
                          Color? cardColor;
                          if (item.isPostponed) {
                            cardColor = Colors.blue.withValues(alpha: 0.1);
                          } else if (item.isSkipped) {
                            cardColor = Colors.orange.withValues(alpha: 0.1);
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: cardColor,
                            child: ListTile(
                              leading: Checkbox(
                                value: item.isCompleted,
                                onChanged: (_) => _toggleItem(index),
                                activeColor: AppColors.orange,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.text,
                                      style: TextStyle(
                                        fontSize: 16,
                                        decoration: item.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: item.isPostponed
                                            ? Colors.blue[700]
                                            : item.isSkipped
                                                ? Colors.orange[700]
                                                : null,
                                      ),
                                    ),
                                  ),
                                  // Energy indicator (only show if energy module enabled)
                                  if (hasEnergy && _energyModuleEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getEnergyColor(item.energyLevel!).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bolt_rounded,
                                            size: 14,
                                            color: _getEnergyColor(item.energyLevel!),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${item.energyLevel}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _getEnergyColor(item.energyLevel!),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: item.isPostponed
                                  ? Text(
                                      'Postponed - Will return later',
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontSize: 12,
                                      ),
                                    )
                                  : item.isSkipped
                                      ? Text(
                                          'Skipped',
                                          style: TextStyle(
                                            color: Colors.orange[600],
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Postpone button (defer to later)
                                  IconButton(
                                    icon: Icon(
                                      item.isPostponed ? Icons.undo : Icons.schedule,
                                      color: item.isPostponed ? Colors.blue : AppColors.greyText,
                                    ),
                                    onPressed: () => _postponeItem(index),
                                    tooltip: item.isPostponed ? 'Unpostpone' : 'Postpone',
                                  ),
                                  // Skip button (permanent skip)
                                  IconButton(
                                    icon: Icon(
                                      item.isSkipped ? Icons.undo : Icons.close,
                                      color: item.isSkipped ? Colors.orange : AppColors.greyText,
                                    ),
                                    onPressed: () => _skipItem(index),
                                    tooltip: item.isSkipped ? 'Unskip' : 'Skip',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom buttons
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    // Save & Exit button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _completePartialRoutine,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save & Exit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppStyles.borderRadiusMedium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Complete button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: allCompleted ? _completeRoutine : _completeRoutine,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(allCompleted ? 'Complete' : 'Complete All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppStyles.borderRadiusMedium,
                          ),
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
    );
  }
}