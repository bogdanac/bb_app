import 'dart:convert';

import 'package:bb_app/Routines/routine_edit_screen.dart';
import 'package:bb_app/Routines/routine_execution_screen.dart';
import 'package:bb_app/Routines/routine_reminder_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routine_data_models.dart';
import '../theme/app_colors.dart';
import '../Notifications/notification_service.dart';

// ROUTINES SCREEN - UPDATED WITH NOTIFICATION SETTINGS
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Routine> _routines = [];

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final routinesJson = prefs.getStringList('routines') ?? [];

    if (routinesJson.isEmpty) {
      // Default morning routine
      _routines = [
        Routine(
          id: '1',
          title: 'Morning Routine',
          items: [
            RoutineItem(id: '1', text: '☀️ Stretch and breathe', isCompleted: false),
            RoutineItem(id: '2', text: '💧 Drink a glass of water', isCompleted: false),
            RoutineItem(id: '3', text: '🧘 5 minutes meditation', isCompleted: false),
            RoutineItem(id: '4', text: '📝 Write 3 gratitudes', isCompleted: false),
          ],
        ),
      ];
      await _saveRoutines();
    } else {
      _routines = routinesJson
          .map((json) => Routine.fromJson(jsonDecode(json)))
          .toList();
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final routinesJson = _routines
        .map((routine) => jsonEncode(routine.toJson()))
        .toList();
    await prefs.setStringList('routines', routinesJson);
    
    // Update notification schedules
    final notificationService = NotificationService();
    for (final routine in _routines) {
      if (routine.reminderEnabled) {
        await notificationService.scheduleRoutineNotification(
          routine.id,
          routine.title,
          routine.reminderHour,
          routine.reminderMinute,
        );
      } else {
        await notificationService.cancelRoutineNotification(routine.id);
      }
    }
  }

  void _addRoutine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutineEditScreen(
          onSave: (routine) {
            setState(() {
              _routines.add(routine);
            });
            _saveRoutines();
          },
        ),
      ),
    );
  }

  void _editRoutine(Routine routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutineEditScreen(
          routine: routine,
          onSave: (updatedRoutine) {
            setState(() {
              final index = _routines.indexWhere((r) => r.id == routine.id);
              if (index != -1) {
                _routines[index] = updatedRoutine;
              }
            });
            _saveRoutines();
          },
        ),
      ),
    );
  }

  Future<void> _deleteRoutine(Routine routine) async {
    // Cancel the routine's notification first
    final notificationService = NotificationService();
    await notificationService.cancelRoutineNotification(routine.id);
    
    setState(() {
      _routines.removeWhere((r) => r.id == routine.id);
    });
    _saveRoutines();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Routine "${routine.title}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _routines.add(routine);
              });
              await _saveRoutines();
            },
          ),
        ),
      );
    }
  }

  void _startRoutine(Routine routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutineExecutionScreen(
          routine: routine,
          onCompleted: () {
            // Routine completed
          },
        ),
      ),
    );
  }

  void _openReminderSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutineReminderSettingsScreen(
          routines: _routines,
          onSave: (updatedRoutines) {
            setState(() {
              _routines = updatedRoutines;
            });
            _saveRoutines();
          },
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _openReminderSettings,
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Reminder Settings',
          ),
        ],
      ),
      body: _routines.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No routines yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Create your first routine to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Header with instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tap to edit • Swipe left to delete',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Routines list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _routines.length,
        itemBuilder: (context, index) {
          final routine = _routines[index];
          return Dismissible(
            key: ValueKey(routine.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text('Delete Routine'),
                    ],
                  ),
                  content: Text('Are you sure you want to delete "${routine.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ) ?? false;
            },
            onDismissed: (direction) {
              _deleteRoutine(routine);
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _editRoutine(routine),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              routine.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (routine.reminderEnabled) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.coral.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.coral.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active_rounded,
                                    color: AppColors.coral,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${routine.reminderHour.toString().padLeft(2, '0')}:${routine.reminderMinute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.coral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.edit_rounded,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${routine.items.length} steps',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startRoutine(routine),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start Routine'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.coral,
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
                  ),
                ),
              ),
            ),
          );
        },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoutine,
        backgroundColor: AppColors.successGreen,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}