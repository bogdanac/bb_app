import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:bb_app/Routines/routine_data_models.dart';

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

class _MorningRoutineCardState extends State<MorningRoutineCard> {
  Routine? _currentRoutine;
  int _currentStepIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentRoutine();
  }

  Future<void> _loadCurrentRoutine() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Load routines to get the morning routine
    final routinesJson = prefs.getStringList('routines') ?? [];

    if (kDebugMode) {
      print('Loading morning routine - Found ${routinesJson.length} routines');
    }

    if (routinesJson.isNotEmpty) {
      final routines = routinesJson
          .map((json) => Routine.fromJson(jsonDecode(json)))
          .toList();

      if (kDebugMode) {
        print('Available routines: ${routines.map((r) => r.title).toList()}');
      }

      // Find morning routine (assuming it's the first one or has "morning" in title)
      _currentRoutine = routines.firstWhere(
            (routine) => routine.title.toLowerCase().contains('morning'),
        orElse: () => routines.first,
      );

      if (kDebugMode) {
        print('Selected morning routine: ${_currentRoutine?.title}');
      }

      // Check if we have progress saved for today
      final progressJson = prefs.getString('morning_routine_progress_$today');
      final lastSavedDate = prefs.getString('morning_routine_last_date');
      
      if (progressJson != null && lastSavedDate == today) {
        // Load today's progress - resume from where we left off
        final progressData = jsonDecode(progressJson);
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
        
        // Clear old progress and set today's date
        await prefs.remove('morning_routine_progress_$today');
        await prefs.setString('morning_routine_last_date', today);
        
        if (kDebugMode) {
          print('Started fresh morning routine for $today');
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProgress() async {
    if (_currentRoutine == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final progressData = {
        'currentStepIndex': _currentStepIndex,
        'completedSteps': _currentRoutine!.items.map((item) => item.isCompleted).toList(),
        'skippedSteps': _currentRoutine!.items.map((item) => item.isSkipped).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await prefs.setString('morning_routine_progress_$today', jsonEncode(progressData));
      await prefs.setString('morning_routine_last_date', today);
      
      if (kDebugMode) {
        print('Saved morning routine progress: step $_currentStepIndex');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving progress: $e');
      }
    }
  }

  Future<void> _completeCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) {
      if (kDebugMode) {
        print('Cannot complete step: currentRoutine=${_currentRoutine != null}, currentStepIndex=$_currentStepIndex, length=${_currentRoutine?.items.length}');
      }
      return;
    }

    if (kDebugMode) {
      print('Completing step $_currentStepIndex: ${_currentRoutine!.items[_currentStepIndex].text}');
    }

    setState(() {
      _currentRoutine!.items[_currentStepIndex].isCompleted = true;
      _currentRoutine!.items[_currentStepIndex].isSkipped = false; // Unmark as skipped if it was
      _moveToNextUnfinishedStep();
    });

    // Save progress after each step
    await _saveProgress();

    // Check if all steps are completed or skipped
    if (_currentRoutine!.items.every((item) => item.isCompleted || item.isSkipped)) {
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
  }

  Future<void> _skipCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) return;

    setState(() {
      _currentRoutine!.items[_currentStepIndex].isSkipped = true;
      // Simply move to the next step in sequence
      if (_currentStepIndex < _currentRoutine!.items.length - 1) {
        _currentStepIndex++;
      } else {
        _moveToNextUnfinishedStep();
      }
    });

    // Save progress after skipping
    await _saveProgress();
  }

  void _moveToNextUnfinishedStep() {
    if (kDebugMode) {
      print('Moving to next unfinished step. Current index: $_currentStepIndex');
    }
    
    // Find next step that is neither completed nor skipped
    for (int i = 0; i < _currentRoutine!.items.length; i++) {
      if (!_currentRoutine!.items[i].isCompleted && !_currentRoutine!.items[i].isSkipped) {
        if (kDebugMode) {
          print('Found unfinished step at index $i: ${_currentRoutine!.items[i].text}');
        }
        _currentStepIndex = i;
        return;
      }
    }
    
    // All steps are either completed or skipped - routine is done
    if (kDebugMode) {
      print('All steps are completed or skipped. Routine finished.');
    }
    
    // Check if all steps are completed or skipped to trigger completion
    final allDone = _currentRoutine!.items.every((item) => item.isCompleted || item.isSkipped);
    if (allDone) {
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
            color: AppColors.orange.withValues(alpha: 0.08), // More subtle orange
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
            color: AppColors.orange.withValues(alpha: 0.08), // More subtle orange
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    color: Theme.of(context).colorScheme.secondary,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.yellow.withValues(alpha: 0.08), // More subtle yellow
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentRoutine!.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$completedCount/${_currentRoutine!.items.length}',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
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
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            LinearProgressIndicator(
              value: completedCount / _currentRoutine!.items.length,
              backgroundColor: Colors.grey.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.secondary,
              ),
            ),

            const SizedBox(height: 16),


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
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        currentStep.text,
                        style: const TextStyle(fontSize: 16),
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
            ],
          ],
        ),
      ),
    );
  }
}