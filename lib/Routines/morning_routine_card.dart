import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:bb_app/Routines/routines_screen.dart';
import 'package:bb_app/Routines/routine_data_models.dart';

// MORNING ROUTINE CARD - UPDATED
class MorningRoutineCard extends StatefulWidget {
  final VoidCallback onCompleted;

  const MorningRoutineCard({Key? key, required this.onCompleted}) : super(key: key);

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

  _loadCurrentRoutine() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Load current routine progress for today
    final progressJson = prefs.getString('morning_routine_progress_$today');

    // Load routines to get the morning routine
    final routinesJson = prefs.getStringList('routines') ?? [];

    if (routinesJson.isNotEmpty) {
      final routines = routinesJson
          .map((json) => Routine.fromJson(jsonDecode(json)))
          .toList();

      // Find morning routine (assuming it's the first one or has "morning" in title)
      _currentRoutine = routines.firstWhere(
            (routine) => routine.title.toLowerCase().contains('morning'),
        orElse: () => routines.first,
      );

      if (progressJson != null) {
        // Load today's progress
        final progressData = jsonDecode(progressJson);
        _currentStepIndex = progressData['currentStepIndex'] ?? 0;

        // Update completion status from saved progress
        final completedSteps = List<bool>.from(progressData['completedSteps'] ?? []);
        for (int i = 0; i < _currentRoutine!.items.length && i < completedSteps.length; i++) {
          _currentRoutine!.items[i].isCompleted = completedSteps[i];
        }
      } else {
        // Reset for new day
        _currentStepIndex = 0;
        for (var item in _currentRoutine!.items) {
          item.isCompleted = false;
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  _saveProgress() async {
    if (_currentRoutine == null) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final progressData = {
      'currentStepIndex': _currentStepIndex,
      'completedSteps': _currentRoutine!.items.map((item) => item.isCompleted).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    await prefs.setString('morning_routine_progress_$today', jsonEncode(progressData));
  }

  _completeCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length) return;

    setState(() {
      _currentRoutine!.items[_currentStepIndex].isCompleted = true;
      if (_currentStepIndex < _currentRoutine!.items.length - 1) {
        _currentStepIndex++;
      }
    });

    await _saveProgress();

    // Check if all steps are completed
    if (_currentRoutine!.items.every((item) => item.isCompleted)) {
      widget.onCompleted();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Morning routine completed! Great job!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  _skipCurrentStep() async {
    if (_currentRoutine == null || _currentStepIndex >= _currentRoutine!.items.length - 1) return;

    setState(() {
      _currentStepIndex++;
    });

    await _saveProgress();
  }

  _completeEntireRoutine() async {
    if (_currentRoutine == null) return;

    setState(() {
      for (var item in _currentRoutine!.items) {
        item.isCompleted = true;
      }
    });

    await _saveProgress();
    widget.onCompleted();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Morning routine completed! Great job!'),
        backgroundColor: Colors.green,
      ),
    );
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
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              ],
            ),
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
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              ],
            ),
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
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
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
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            LinearProgressIndicator(
              value: completedCount / _currentRoutine!.items.length,
              backgroundColor: Colors.grey.withOpacity(0.3),
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
                  color: Colors.green.withOpacity(0.2),
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
              // Current step
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next step:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentStep.text,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _completeCurrentStep,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _skipCurrentStep,
                      child: const Text('Skip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Bottom buttons
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RoutinesScreen(),
                        ),
                      );
                      // Refresh routine data when returning
                      _loadCurrentRoutine();
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Routines'),
                  ),
                ),
                if (!allCompleted) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _completeEntireRoutine,
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Complete All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}