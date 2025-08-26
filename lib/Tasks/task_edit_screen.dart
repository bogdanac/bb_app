import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'tasks_data_models.dart';
import 'recurrence_dialog.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final List<TaskCategory> categories;
  final Function(Task) onSave;

  const TaskEditScreen({
    super.key,
    this.task,
    required this.categories,
    required this.onSave,
  });

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _titleController = TextEditingController();
  List<String> _selectedCategoryIds = [];
  DateTime? _deadline;
  DateTime? _reminderTime;
  bool _isImportant = false;
  TaskRecurrence? _recurrence;
  Timer? _saveTimer;
  bool _hasUnsavedChanges = false;
  Task? _currentTask; // Track the current task to prevent duplicates

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task; // Initialize current task reference
    if (widget.task != null) {
      final task = widget.task!;
      _titleController.text = task.title;
      _selectedCategoryIds = List.from(task.categoryIds);
      _deadline = task.deadline;
      _reminderTime = task.reminderTime;
      _isImportant = task.isImportant;
      _recurrence = task.recurrence;
    }
    
    // Add listeners for auto-save
    _titleController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _hasUnsavedChanges = true;
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (_hasUnsavedChanges && _titleController.text.trim().isNotEmpty) {
        _autoSaveTask();
      }
    });
  }

  void _autoSaveTask() {
    if (_titleController.text.trim().isEmpty) return;
    
    final task = Task(
      id: _currentTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: '',
      categoryIds: _selectedCategoryIds,
      deadline: _deadline,
      reminderTime: _reminderTime,
      isImportant: _isImportant,
      recurrence: _recurrence,
      isCompleted: _currentTask?.isCompleted ?? false,
      completedAt: _currentTask?.completedAt,
      createdAt: _currentTask?.createdAt ?? DateTime.now(),
    );

    widget.onSave(task);
    
    // Update current task reference after first save to prevent duplicates
    _currentTask = task;
    
    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // Auto-save before leaving if there are unsaved changes
        if (_hasUnsavedChanges && _titleController.text.trim().isNotEmpty) {
          _autoSaveTask();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_hasUnsavedChanges)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Saving...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP - Advanced/optional features (hard to reach)
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.event_rounded,
                        color: _deadline != null ? Theme.of(context).primaryColor : Colors.grey,
                        size: 20,
                      ),
                      title: const Text('Deadline', style: TextStyle(fontSize: 14)),
                      subtitle: _deadline != null
                          ? Text(DateFormat('MMM dd').format(_deadline!), style: const TextStyle(fontSize: 12))
                          : const Text('Optional', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: _deadline != null
                          ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() => _deadline = null);
                          _onFieldChanged();
                        },
                      )
                          : const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: _selectDeadline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.repeat_rounded,
                        color: _recurrence != null ? Theme.of(context).primaryColor : Colors.grey,
                        size: 20,
                      ),
                      title: const Text('Recurrence', style: TextStyle(fontSize: 14)),
                      subtitle: _recurrence != null
                          ? Text(_recurrence!.getDisplayText(), style: const TextStyle(fontSize: 12))
                          : const Text('Optional', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: _recurrence != null
                          ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() => _recurrence = null);
                          _onFieldChanged();
                        },
                      )
                          : const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: _selectRecurrence,
                    ),
                  ),
                ),
              ],
            ),

            if (_recurrence != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This task will repeat according to the schedule',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),

            // MIDDLE - Essential content
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Task Title',
                hintText: 'What do you need to do?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
              autofocus: true,
            ),
            const SizedBox(height: 16),


            // Categories
            if (widget.categories.isNotEmpty) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category_rounded, color: Theme.of(context).primaryColor, size: 18),
                          const SizedBox(width: 8),
                          const Text('Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.categories.map((category) {
                          final isSelected = _selectedCategoryIds.contains(category.id);
                          return FilterChip(
                            label: Text(category.name),
                            selected: isSelected,
                            backgroundColor: category.color.withValues(alpha: 0.1),
                            selectedColor: category.color.withValues(alpha: 0.3),
                            checkmarkColor: category.color,
                            side: BorderSide(color: category.color.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategoryIds.add(category.id);
                                } else {
                                  _selectedCategoryIds.remove(category.id);
                                }
                              });
                              _onFieldChanged();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // BOTTOM - Thumb-reachable zone (most frequently used)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  Icons.notifications_rounded,
                  color: _reminderTime != null ? Theme.of(context).primaryColor : Colors.grey,
                ),
                title: const Text('Reminder Time'),
                subtitle: _reminderTime != null
                    ? Text(DateFormat('HH:mm').format(_reminderTime!))
                    : const Text('Set a reminder to get notified'),
                trailing: _reminderTime != null
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    setState(() => _reminderTime = null);
                    _onFieldChanged();
                  },
                )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _selectReminderTime,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                title: const Text('Important'),
                subtitle: const Text('Mark this task as high priority'),
                value: _isImportant,
                onChanged: (value) {
                  setState(() => _isImportant = value);
                  _onFieldChanged();
                },
                secondary: Icon(
                  Icons.star_rounded,
                  color: _isImportant ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                activeThumbColor: Theme.of(context).primaryColor,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  void _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _deadline = date);
      _onFieldChanged();
    }
  }

  void _selectReminderTime() async {
    final selectedTime = await _showFriendlyTimePicker();
    if (selectedTime != null) {
      final now = DateTime.now();
      setState(() {
        _reminderTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
      });
      _onFieldChanged();
    }
  }

  Future<TimeOfDay?> _showFriendlyTimePicker() async {
    final currentTime = TimeOfDay.now();
    
    return showDialog<TimeOfDay?>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set Reminder Time',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Quick presets
                const Text(
                  'Quick Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTimeChip('In 5 min', currentTime.replacing(
                      hour: (currentTime.hour + (currentTime.minute + 5) ~/ 60) % 24,
                      minute: (currentTime.minute + 5) % 60,
                    )),
                    _buildTimeChip('In 15 min', currentTime.replacing(
                      hour: (currentTime.hour + (currentTime.minute + 15) ~/ 60) % 24,
                      minute: (currentTime.minute + 15) % 60,
                    )),
                    _buildTimeChip('In 30 min', currentTime.replacing(
                      hour: (currentTime.hour + (currentTime.minute + 30) ~/ 60) % 24,
                      minute: (currentTime.minute + 30) % 60,
                    )),
                    _buildTimeChip('In 1 hour', currentTime.replacing(
                      hour: (currentTime.hour + 1) % 24,
                      minute: currentTime.minute,
                    )),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                
                // Common times
                const Text(
                  'Popular Times',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTimeChip('09:00', const TimeOfDay(hour: 9, minute: 0)),
                    _buildTimeChip('12:00', const TimeOfDay(hour: 12, minute: 0)),
                    _buildTimeChip('14:00', const TimeOfDay(hour: 14, minute: 0)),
                    _buildTimeChip('17:00', const TimeOfDay(hour: 17, minute: 0)),
                    _buildTimeChip('20:00', const TimeOfDay(hour: 20, minute: 0)),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                
                // Custom time button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _reminderTime != null
                                ? TimeOfDay.fromDateTime(_reminderTime!)
                                : TimeOfDay.now(),
                            builder: (BuildContext context, Widget? child) {
                              return MediaQuery(
                                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              );
                            },
                          );
                          if (time != null && mounted) {
                            navigator.pop(time);
                          }
                        },
                        icon: const Icon(Icons.schedule_rounded),
                        label: const Text('Custom Time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeChip(String label, TimeOfDay time) {
    return ActionChip(
      label: Text(label),
      onPressed: () => Navigator.pop(context, time),
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      side: BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      ),
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _selectRecurrence() async {
    final recurrence = await showDialog<TaskRecurrence?>(
      context: context,
      builder: (context) => RecurrenceDialog(
        initialRecurrence: _recurrence,
      ),
    );

    if (recurrence != _recurrence) {
      setState(() {
        _recurrence = recurrence;
      });
      _onFieldChanged();
    }
  }

}