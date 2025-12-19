import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import 'routine_service.dart';
import 'routine_widget_service.dart';
import 'routine_progress_service.dart';
import 'dart:async';
import '../shared/snackbar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/error_logger.dart';
import '../Energy/energy_service.dart';

class RoutineCard extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback? onEnergyChanged;

  const RoutineCard({
    super.key,
    required this.onCompleted,
    this.onEnergyChanged,
  });

  @override
  State<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<RoutineCard> with WidgetsBindingObserver {
  Routine? _currentRoutine;
  int _currentStepIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentRoutine();

    // Don't sync on init - let the card read widget progress first
    // RoutineWidgetService.syncWithWidget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't save progress here - it's already saved on lifecycle changes
    // and saving here can overwrite widget updates when the card is recreated
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Don't save when going to background - progress is already saved after each action
    // and saving here can overwrite widget updates that happen while app is backgrounded

    // Reload routine when app comes back to foreground to pick up widget changes
    if (state == AppLifecycleState.resumed) {
      // Don't sync - just reload to read widget progress
      _loadCurrentRoutine();
    }
  }

  Future<void> _loadCurrentRoutine() async {
    if (!mounted) return; // Don't proceed if widget is disposed

    // Set loading state at the start to prevent stale renders
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Load all routines
      final routines = await RoutineService.loadRoutines();

      // Find currently active routine using unified method
      try {
        _currentRoutine = await RoutineService.getCurrentActiveRoutine(routines);
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'RoutineCard._loadCurrentRoutine.getCurrentActiveRoutine',
          error: 'Error in getCurrentActiveRoutine: $e',
          stackTrace: stackTrace.toString(),
        );
        _currentRoutine = null;
      }

      if (_currentRoutine != null) {
        // Check if we have progress saved for today
        final progressData = await RoutineProgressService.loadRoutineProgress(_currentRoutine!.id);

        if (progressData != null) {
          // Load today's progress - resume from where we left off
          _currentStepIndex = progressData['currentStepIndex'] ?? 0;

          // Initialize all items properly first
          for (int i = 0; i < _currentRoutine!.items.length; i++) {
            _currentRoutine!.items[i].isSkipped = false;
            _currentRoutine!.items[i].isPostponed = false;
          }

          // Update completion status from saved progress
          final completedSteps = List<bool>.from(progressData['completedSteps'] ?? []);
          final skippedSteps = List<bool>.from(progressData['skippedSteps'] ?? []);
          final postponedSteps = List<bool>.from(progressData['postponedSteps'] ?? []);
          for (int i = 0; i < _currentRoutine!.items.length && i < completedSteps.length; i++) {
            _currentRoutine!.items[i].isCompleted = completedSteps[i];
          }
          for (int i = 0; i < _currentRoutine!.items.length && i < skippedSteps.length; i++) {
            _currentRoutine!.items[i].isSkipped = skippedSteps[i];
          }
          for (int i = 0; i < _currentRoutine!.items.length && i < postponedSteps.length; i++) {
            _currentRoutine!.items[i].isPostponed = postponedSteps[i];
          }
        } else {
          // Reset for new day or first time today
          _currentStepIndex = 0;
          for (var item in _currentRoutine!.items) {
            item.isCompleted = false;
            item.isSkipped = false;
            item.isPostponed = false;
          }

          // Clear old progress
          await RoutineProgressService.clearRoutineProgress(_currentRoutine!.id);
        }
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RoutineCard._loadCurrentRoutine',
        error: 'Error loading routine: $e',
        stackTrace: stackTrace.toString(),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProgress() async {
    if (_currentRoutine == null) return;

    try {
      // Ensure we have valid data before saving
      if (_currentStepIndex < 0) _currentStepIndex = 0;
      if (_currentStepIndex >= _currentRoutine!.items.length) {
        _currentStepIndex = _currentRoutine!.items.length - 1;
      }

      await RoutineProgressService.saveRoutineProgress(
        routineId: _currentRoutine!.id,
        currentStepIndex: _currentStepIndex,
        items: _currentRoutine!.items,
      );

      // Update widget after saving progress
      RoutineWidgetService.updateWidget();
      
    } catch (e) {
      // Retry once after a short delay
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        await RoutineService.saveRoutineProgress(
          currentStepIndex: _currentStepIndex,
          items: _currentRoutine!.items,
        );
      } catch (retryError) {
        // Silent fail after retry
      }
    }
  }

  Future<void> _completeCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) {
      return;
    }

    // If step is already completed, just move to next step
    if (_currentRoutine!.items[_currentStepIndex].isCompleted) {
      setState(() {
        _moveToNextUnfinishedStep();
      });
      return;
    }

    // Store step info before setState changes the index
    final completedStep = _currentRoutine!.items[_currentStepIndex];
    final energyLevel = completedStep.energyLevel ?? 0;

    setState(() {
      _currentRoutine!.items[_currentStepIndex].isCompleted = true;
      _currentRoutine!.items[_currentStepIndex].isSkipped = false; // Unmark as skipped if it was
      _moveToNextUnfinishedStep();
    });

    // Track energy/flow points for completed step
    await EnergyService.addRoutineStepEnergyConsumption(
      stepId: completedStep.id,
      stepTitle: completedStep.text,
      energyLevel: energyLevel,
      routineTitle: _currentRoutine!.title,
    );

    // Notify that energy changed so home card can refresh
    widget.onEnergyChanged?.call();

    // Save progress after each step
    await _saveProgress();

    // Check if all steps are done (completed or permanently skipped, but not postponed)
    if (_currentRoutine!.items.every((item) => item.isCompleted || item.isSkipped)) {
      // Mark current routine as completed for today
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();
      final completedKey = 'routine_completed_${_currentRoutine!.id}_$today';
      await prefs.setBool(completedKey, true);

      if (mounted) {
        SnackBarUtils.showSuccess(context, '🎉 Routine completed! Great job!');
      }

      // Try to load the next routine automatically
      final hasNextRoutine = await _loadNextRoutine();
      // If no next routine available, hide the card
      if (!hasNextRoutine) {
        widget.onCompleted();
      }
    }
  }

  Future<void> _skipCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) return;

    setState(() {
      // Mark the current step as permanently skipped - won't come back
      _currentRoutine!.items[_currentStepIndex].isSkipped = true;
      _currentRoutine!.items[_currentStepIndex].isPostponed = false;
      _currentRoutine!.items[_currentStepIndex].isCompleted = false;

      // Move to the next unfinished step (skips postponed steps too)
      _moveToNextUnfinishedStep();
    });

    // Save progress after skipping
    await _saveProgress();

    // Check if all steps are done (completed or permanently skipped, but not postponed)
    if (_currentRoutine!.items.every((item) => item.isCompleted || item.isSkipped)) {
      // Mark current routine as completed for today
      final prefs = await SharedPreferences.getInstance();
      final today = RoutineService.getEffectiveDate();
      final completedKey = 'routine_completed_${_currentRoutine!.id}_$today';
      await prefs.setBool(completedKey, true);

      // Try to load the next routine automatically
      final hasNextRoutine = await _loadNextRoutine();
      // If no next routine available, hide the card
      if (!hasNextRoutine) {
        widget.onCompleted();
      }
    }
  }

  Future<void> _postponeCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) return;

    setState(() {
      // Mark the current step as postponed - will come back later
      _currentRoutine!.items[_currentStepIndex].isPostponed = true;
      _currentRoutine!.items[_currentStepIndex].isSkipped = false;
      _currentRoutine!.items[_currentStepIndex].isCompleted = false;

      // Move to the next unfinished step
      _moveToNextUnfinishedStep();
    });

    // Save progress after postponing
    await _saveProgress();
  }

  Future<void> _skipRoutine() async {
    if (_currentRoutine == null) return;

    // Store the current routine ID before any async operations
    final currentRoutineId = _currentRoutine!.id;

    // Mark current routine as completed (skipped)
    final prefs = await SharedPreferences.getInstance();
    final today = RoutineService.getEffectiveDate();
    final completedKey = 'routine_completed_${currentRoutineId}_$today';
    await prefs.setBool(completedKey, true);

    final hasNextRoutine = await _loadNextRoutine();

    if (!hasNextRoutine) {
      // No more routines, hide the card
      widget.onCompleted();
    }
  }

  Future<bool> _loadNextRoutine() async {
    try {
      // Load all routines
      final routines = await RoutineService.loadRoutines();

      // Get the next uncompleted routine
      final nextRoutine = await RoutineService.getNextRoutine(routines, _currentRoutine?.id);

      if (nextRoutine == null) {
        return false;
      }

      // Set the next routine as active override
      await RoutineService.setActiveRoutineOverride(nextRoutine.id);

      // Clear the progress for the new routine
      await RoutineProgressService.clearRoutineProgress(nextRoutine.id);

      // Reload the routine card
      await _loadCurrentRoutine();

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Next routine: ${nextRoutine.title}');
      }

      return true;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'RoutineCard._loadNextRoutine',
        error: 'Error loading next routine: $e',
        stackTrace: stackTrace.toString(),
      );
      // On error, reload current routine to try to recover
      // Don't return false (which hides the card) unless we're sure there's no next routine
      await _loadCurrentRoutine();
      // Check if we have a routine loaded after recovery attempt
      return _currentRoutine != null;
    }
  }

  void _moveToNextUnfinishedStep() {
    // Start searching from the next index
    int startIndex = (_currentStepIndex + 1) % _currentRoutine!.items.length;

    // Priority 1: Find next step that is not completed, not skipped, and not postponed
    for (int i = 0; i < _currentRoutine!.items.length; i++) {
      int checkIndex = (startIndex + i) % _currentRoutine!.items.length;
      final item = _currentRoutine!.items[checkIndex];
      if (!item.isCompleted && !item.isSkipped && !item.isPostponed) {
        _currentStepIndex = checkIndex;
        return;
      }
    }

    // Priority 2: If all regular steps are done, go back to postponed steps
    // Start from the next index to cycle through postponed steps
    for (int i = 0; i < _currentRoutine!.items.length; i++) {
      int checkIndex = (startIndex + i) % _currentRoutine!.items.length;
      final item = _currentRoutine!.items[checkIndex];
      if (item.isPostponed && !item.isCompleted && !item.isSkipped) {
        _currentStepIndex = checkIndex;
        // Clear postponed flag so it can be postponed again
        item.isPostponed = false;
        return;
      }
    }

    // Skipped steps are permanently skipped - never return to them

    // No more unfinished steps found - all steps are completed or permanently skipped
    // Keep current index if everything is completed
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: AppStyles.borderRadiusLarge,
            color: AppColors.homeCardBackground, // Home card background
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_currentRoutine == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: AppStyles.borderRadiusLarge,
            color: AppColors.homeCardBackground, // Home card background
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    color: AppColors.yellow,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Routine',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('No routine found. Create one in the Routines tab.'),
            ],
          ),
        ),
      );
    }

    final completedCount = _currentRoutine!.items.where((item) => item.isCompleted).length;
    final allCompleted = completedCount == _currentRoutine!.items.length;
    final currentStep = _currentStepIndex < _currentRoutine!.items.length
        ? _currentRoutine!.items[_currentStepIndex]
        : null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusLarge,
          color: AppColors.homeCardBackground, // Home card background
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_rounded,
                  color: AppColors.yellow,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentRoutine!.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                // Skip routine button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _skipRoutine,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.greyText.withValues(alpha: 0.6),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),



            if (allCompleted) ...[
              // All completed
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Routine completed! 🎉'),
                  ],
                ),
              ),
            ] else if (currentStep != null) ...[
              // Current step with buttons on the right
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                          border: Border(
                            top: BorderSide(color: AppColors.yellow.withValues(alpha: 0.4)),
                            left: BorderSide(color: AppColors.yellow.withValues(alpha: 0.4)),
                            bottom: BorderSide(color: AppColors.yellow.withValues(alpha: 0.4)),
                          ),
                        ),
                        child: Text(
                          currentStep.text,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    // Action buttons on the right - unified rectangular style
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Skip button - left section
                        Material(
                          color: AppColors.greyText.withValues(alpha: 0.2),
                          child: InkWell(
                            onTap: _skipCurrentStep,
                            child: Container(
                              width: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.greyText.withValues(alpha: 0.4), width: 1),
                              ),
                              child: Icon(Icons.close_rounded, size: 20, color: AppColors.greyText),
                            ),
                          ),
                        ),
                        // Postpone button - middle section
                        Material(
                          color: Colors.orange.withValues(alpha: 0.08),
                          child: InkWell(
                            onTap: _postponeCurrentStep,
                            child: Container(
                              width: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.orange.withValues(alpha: 0.22), width: 1),
                                  bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.22), width: 1),
                                ),
                              ),
                              child: Icon(Icons.schedule_rounded, size: 20, color: Colors.orange.withValues(alpha: 0.65)),
                            ),
                          ),
                        ),
                        // Complete button - right section
                        Material(
                          color: Colors.green.withValues(alpha: 0.2),
                          child: InkWell(
                            onTap: _completeCurrentStep,
                            child: Container(
                              width: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Icon(Icons.check_rounded, size: 20, color: Colors.green),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}