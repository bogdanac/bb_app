import 'package:flutter/material.dart';
import 'routine_data_models.dart';
import '../theme/app_colors.dart';
import '../Notifications/notification_service.dart';

class RoutineReminderSettingsScreen extends StatefulWidget {
  final List<Routine> routines;
  final Function(List<Routine>) onSave;

  const RoutineReminderSettingsScreen({
    super.key,
    required this.routines,
    required this.onSave,
  });

  @override
  State<RoutineReminderSettingsScreen> createState() => _RoutineReminderSettingsScreenState();
}

class _RoutineReminderSettingsScreenState extends State<RoutineReminderSettingsScreen> {
  late List<Routine> _routines;

  @override
  void initState() {
    super.initState();
    _routines = widget.routines.map((routine) => Routine(
      id: routine.id,
      title: routine.title,
      items: routine.items,
      reminderEnabled: routine.reminderEnabled,
      reminderHour: routine.reminderHour,
      reminderMinute: routine.reminderMinute,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Reminders'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _routines.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No routines to set reminders for',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Create routines first to enable reminders',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _routines.length,
              itemBuilder: (context, index) {
                final routine = _routines[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                            Switch(
                              value: routine.reminderEnabled,
                              onChanged: (value) {
                                setState(() {
                                  routine.reminderEnabled = value;
                                });
                              },
                              activeThumbColor: AppColors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${routine.items.length} steps',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (routine.reminderEnabled) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: AppColors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Reminder Time:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _selectTime(routine),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.orange.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '${routine.reminderHour.toString().padLeft(2, '0')}:${routine.reminderMinute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _selectTime(Routine routine) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: routine.reminderHour,
        minute: routine.reminderMinute,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.orange,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        routine.reminderHour = picked.hour;
        routine.reminderMinute = picked.minute;
      });
    }
  }

  void _saveSettings() async {
    // Update notification schedules
    final notificationService = NotificationService();
    
    for (final routine in _routines) {
      if (routine.reminderEnabled) {
        await _scheduleRoutineNotification(routine, notificationService);
      } else {
        await _cancelRoutineNotification(routine, notificationService);
      }
    }

    widget.onSave(_routines);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _scheduleRoutineNotification(Routine routine, NotificationService notificationService) async {
    try {
      await notificationService.scheduleRoutineNotification(
        routine.id,
        routine.title,
        routine.reminderHour,
        routine.reminderMinute,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule reminder for "${routine.title}"'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _cancelRoutineNotification(Routine routine, NotificationService notificationService) async {
    await notificationService.cancelRoutineNotification(routine.id);
  }
}