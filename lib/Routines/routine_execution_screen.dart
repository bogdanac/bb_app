import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'routine_data_models.dart';

// ROUTINE EXECUTION SCREEN - UPDATED WITH SAVE FUNCTIONALITY
class RoutineExecutionScreen extends StatefulWidget {
  final Routine routine;
  final VoidCallback onCompleted;

  const RoutineExecutionScreen({
    Key? key,
    required this.routine,
    required this.onCompleted,
  }) : super(key: key);

  @override
  State<RoutineExecutionScreen> createState() => _RoutineExecutionScreenState();
}

class _RoutineExecutionScreenState extends State<RoutineExecutionScreen> {
  late List<RoutineItem> _items;
  bool _playMusic = false;

  @override
  void initState() {
    super.initState();
    _items = widget.routine.items.map((item) => RoutineItem(
      id: item.id,
      text: item.text,
      isCompleted: false,
    )).toList();
    _loadProgress();
  }

  _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final progressKey = 'routine_progress_${widget.routine.id}_$today';

    final progressJson = prefs.getString(progressKey);
    if (progressJson != null) {
      final progressData = jsonDecode(progressJson);
      final completedSteps = List<bool>.from(progressData['completedSteps'] ?? []);

      setState(() {
        for (int i = 0; i < _items.length && i < completedSteps.length; i++) {
          _items[i].isCompleted = completedSteps[i];
        }
      });
    }
  }

  _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final progressKey = 'routine_progress_${widget.routine.id}_$today';

    final progressData = {
      'completedSteps': _items.map((item) => item.isCompleted).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    await prefs.setString(progressKey, jsonEncode(progressData));
  }

  _toggleItem(int index) async {
    setState(() {
      _items[index].isCompleted = !_items[index].isCompleted;
    });
    await _saveProgress();
  }

  _isAllCompleted() {
    return _items.every((item) => item.isCompleted);
  }

  _completeRoutine() async {
    // Mark all items as completed
    setState(() {
      for (var item in _items) {
        item.isCompleted = true;
      }
    });
    await _saveProgress();

    widget.onCompleted();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 ${widget.routine.title} completed! Great job!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  _completePartialRoutine() async {
    await _saveProgress();

    final completedCount = _items.where((item) => item.isCompleted).length;

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

  @override
  Widget build(BuildContext context) {
    final completedCount = _items.where((item) => item.isCompleted).length;
    final allCompleted = _isAllCompleted();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.title),
        backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
        actions: [
          IconButton(
            icon: Icon(
              _playMusic ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            onPressed: () {
              setState(() {
                _playMusic = !_playMusic;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_playMusic ? 'Music enabled' : 'Music disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
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
              Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '✨ ${widget.routine.title}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: $completedCount/${_items.length}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: completedCount / _items.length,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: CheckboxListTile(
                        title: Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 16,
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        value: item.isCompleted,
                        onChanged: (_) => _toggleItem(index),
                        activeColor: Theme.of(context).colorScheme.secondary,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  },
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
                            borderRadius: BorderRadius.circular(12),
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
                            borderRadius: BorderRadius.circular(12),
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