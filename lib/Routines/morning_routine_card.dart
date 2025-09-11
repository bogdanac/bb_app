import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import 'routine_service.dart';
import 'routine_widget_service.dart';
import 'routine_progress_service.dart';
import 'dart:async';

class MorningRoutineCard extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback onHiddenForToday;

  const MorningRoutineCard({
    super.key,
    required this.onCompleted,
    required this.onHiddenForToday,
  });

  @override
  State<MorningRoutineCard> createState() => _MorningRoutineCardState();
}

class _MorningRoutineCardState extends State<MorningRoutineCard> with WidgetsBindingObserver {
  Routine? _currentRoutine;
  int _currentStepIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentRoutine();
    
    // Sync with widget on init
    RoutineWidgetService.syncWithWidget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Save progress one final time when disposing
    if (_currentRoutine != null) {
      _saveProgress();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Save progress when app goes to background or when pausing
    if ((state == AppLifecycleState.paused || 
         state == AppLifecycleState.inactive ||
         state == AppLifecycleState.detached) && 
        _currentRoutine != null) {
      _saveProgress();
    }
  }

  Future<void> _loadCurrentRoutine() async {
    try {
      if (kDebugMode) {
        print('Starting _loadCurrentRoutine');
      }
      
      // Load all routines
      final routines = await RoutineService.loadRoutines();

      if (kDebugMode) {
        print('Loading morning routine - Found ${routines.length} routines');
        print('Available routines: ${routines.map((r) => r.title).toList()}');
        // Force widget update for debugging
        await RoutineWidgetService.forceRefreshWidget();
      }

      // Find morning routine
      try {
        _currentRoutine = await RoutineService.findMorningRoutine(routines);
        
        if (kDebugMode) {
          print('Selected morning routine: ${_currentRoutine?.title}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error in findMorningRoutine: $e');
        }
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
            _currentRoutine!.items[i].isSkipped = false; // Ensure isSkipped is always initialized
          }
          
          // Update completion status from saved progress
          final completedSteps = List<bool>.from(progressData['completedSteps'] ?? []);
          final skippedSteps = List<bool>.from(progressData['skippedSteps'] ?? []);
          for (int i = 0; i < _currentRoutine!.items.length && i < completedSteps.length; i++) {
            _currentRoutine!.items[i].isCompleted = completedSteps[i];
          }
          for (int i = 0; i < _currentRoutine!.items.length && i < skippedSteps.length; i++) {
            _currentRoutine!.items[i].isSkipped = skippedSteps[i];
          }
          
          if (kDebugMode) {
            print('Resumed morning routine from step $_currentStepIndex');
          }
        } else {
          // Reset for new day or first time today
          _currentStepIndex = 0;
          for (var item in _currentRoutine!.items) {
            item.isCompleted = false;
            item.isSkipped = false;
          }
          
          // Clear old progress
          await RoutineService.clearMorningRoutineProgress();
          
          if (kDebugMode) {
            print('Started fresh morning routine for ${RoutineService.getTodayString()}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading routine: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
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
        await RoutineService.saveMorningRoutineProgress(
          currentStepIndex: _currentStepIndex,
          items: _currentRoutine!.items,
        );
      } catch (retryError) {
        // Silent fail after retry
      }
    }
  }

  Future<void> _completeCurrentStep() async {
    if (kDebugMode) {
      print('=== COMPLETE BUTTON PRESSED ===');
    }

    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) {
      if (kDebugMode) {
        print('Cannot complete step: currentRoutine=${_currentRoutine != null}, currentStepIndex=$_currentStepIndex, length=${_currentRoutine?.items.length}');
      }
      return;
    }

    if (kDebugMode) {
      print('Before completing: $_currentStepIndex: ${_currentRoutine!.items[_currentStepIndex].text}');
      print('Step status - isCompleted: ${_currentRoutine!.items[_currentStepIndex].isCompleted}, isSkipped: ${_currentRoutine!.items[_currentStepIndex].isSkipped}');
    }

    // If step is already completed, just move to next step
    if (_currentRoutine!.items[_currentStepIndex].isCompleted) {
      if (kDebugMode) {
        print('Step is already completed, just moving to next step');
      }
      setState(() {
        _moveToNextUnfinishedStep();
      });
      return;
    }

    setState(() {
      _currentRoutine!.items[_currentStepIndex].isCompleted = true;
      _currentRoutine!.items[_currentStepIndex].isSkipped = false; // Unmark as skipped if it was

      if (kDebugMode) {
        print('After marking completed: $_currentStepIndex: ${_currentRoutine!.items[_currentStepIndex].text}');
        print('Step status - isCompleted: ${_currentRoutine!.items[_currentStepIndex].isCompleted}, isSkipped: ${_currentRoutine!.items[_currentStepIndex].isSkipped}');
      }

      _moveToNextUnfinishedStep();

      if (kDebugMode) {
        print('After moveToNextUnfinishedStep: new currentStepIndex = $_currentStepIndex');
      }
    });

    // Save progress after each step
    await _saveProgress();

    // Check if all steps are actually completed (not just skipped)
    if (_currentRoutine!.items.every((item) => item.isCompleted)) {
      widget.onCompleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Morning routine completed! Great job!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (kDebugMode) {
      print('=== COMPLETE BUTTON FINISHED ===');
    }
  }

  Future<void> _skipCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) return;

    if (kDebugMode) {
      print('Skipping step $_currentStepIndex: ${_currentRoutine!.items[_currentStepIndex].text}');
    }

    setState(() {
      // Mark the current step as skipped (don't remove from list)
      _currentRoutine!.items[_currentStepIndex].isSkipped = true;
      _currentRoutine!.items[_currentStepIndex].isCompleted = false;
      
      // Move to the next unfinished step
      _moveToNextUnfinishedStep();
    });

    // Save progress after skipping
    await _saveProgress();
  }

  void _moveToNextUnfinishedStep() {
    if (kDebugMode) {
      print('Moving to next unfinished step. Current index: $_currentStepIndex');
    }

    // Start searching from the next index
    int startIndex = (_currentStepIndex + 1) % _currentRoutine!.items.length;
    
    // Find next step that is not completed and not skipped
    for (int i = 0; i < _currentRoutine!.items.length; i++) {
      int checkIndex = (startIndex + i) % _currentRoutine!.items.length;
      if (!_currentRoutine!.items[checkIndex].isCompleted && !_currentRoutine!.items[checkIndex].isSkipped) {
        if (kDebugMode) {
          print('Found unfinished non-skipped step at index $checkIndex: ${_currentRoutine!.items[checkIndex].text}');
        }
        _currentStepIndex = checkIndex;
        return;
      }
    }
    
    // If all non-skipped steps are completed, find the first skipped step
    for (int i = 0; i < _currentRoutine!.items.length; i++) {
      if (_currentRoutine!.items[i].isSkipped && !_currentRoutine!.items[i].isCompleted) {
        if (kDebugMode) {
          print('All non-skipped steps done. Found skipped step at index $i: ${_currentRoutine!.items[i].text}');
        }
        _currentStepIndex = i;
        return;
      }
    }
    
    // No more unfinished steps found - all steps are completed
    if (kDebugMode) {
      print('No unfinished steps found. All steps are completed.');
    }
    // Keep current index if everything is completed
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.yellow.withValues(alpha: 0.2), // Orange theme colors
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.yellow.withValues(alpha: 0.2), // Orange theme colors
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
                    'Morning Routine',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('No morning routine found. Create one in the Routines tab.'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.yellow.withValues(alpha: 0.2), // Orange theme colors
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.onHiddenForToday,
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text(
                    'Not Today',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 10),



            if (allCompleted) ...[
              // All completed
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Morning routine completed! 🎉'),
                  ],
                ),
              ),
            ] else if (currentStep != null) ...[
              // Current step with buttons on the right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.yellow.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        currentStep.text,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Action buttons on the right
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _completeCurrentStep,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        tooltip: 'Complete',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(32, 32),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _skipCurrentStep,
                        icon: const Icon(Icons.skip_next_rounded, size: 20),
                        tooltip: 'Skip',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(32, 32),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              // No current step available but not all completed - show skipped steps
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('You have skipped steps remaining:'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(_currentRoutine!.items
                        .where((item) => item.isSkipped)
                        .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.skip_next, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item.text, style: const TextStyle(color: Colors.grey))),
                            ],
                          ),
                        ))),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          // Reset all skipped steps so they can be retaken
                          for (var item in _currentRoutine!.items) {
                            if (item.isSkipped) {
                              item.isSkipped = false;
                            }
                          }
                          // Find the next unfinished step
                          _moveToNextUnfinishedStep();
                        });
                        _saveProgress();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Do Skipped Steps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
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