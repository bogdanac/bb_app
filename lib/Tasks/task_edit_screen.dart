import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'tasks_data_models.dart';
import 'recurrence_dialog.dart';
import '../theme/app_colors.dart';
import '../shared/time_picker_utils.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final List<TaskCategory> categories;
  final List<String>? initialCategoryIds;
  final Function(Task) onSave;

  const TaskEditScreen({
    super.key,
    this.task,
    required this.categories,
    this.initialCategoryIds,
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
  Timer? _savedTimer;
  bool _hasUnsavedChanges = false;
  bool _showSaved = false;
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
    } else if (widget.initialCategoryIds != null) {
      // Pre-fill categories for new tasks
      _selectedCategoryIds = List.from(widget.initialCategoryIds!);
    }
    
    // Add listeners for auto-save
    _titleController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savedTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _hasUnsavedChanges = true;
    _showSaved = false; // Hide saved indicator when user makes changes
    _scheduleAutoSave();
    // Trigger rebuild to update Complete button state
    setState(() {});
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
    
    try {
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
        _showSaved = true;
      });

      // Hide the "saved" indicator after 2 seconds
      _savedTimer?.cancel();
      _savedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showSaved = false;
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving task: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error saving task: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _completeTask() async {
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
      isCompleted: true,
      completedAt: DateTime.now(),
      createdAt: _currentTask?.createdAt ?? DateTime.now(),
    );

    // Show success feedback before closing
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Task "${task.title}" completed!'),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Save the task
    widget.onSave(task);
    
    // Small delay to ensure the snackbar shows and save completes
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Close the dialog/screen after completing the task
    if (mounted) {
      Navigator.of(context).pop();
    }
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
            )
          else if (_showSaved)
            Container(
              margin: const EdgeInsets.only(right: 24),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saved',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.successGreen,
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
            // Complete Task Section
            Container(
              decoration: BoxDecoration(
                color: _titleController.text.trim().isEmpty 
                    ? AppColors.grey.withValues(alpha: 0.2)
                    : AppColors.successGreen.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _titleController.text.trim().isEmpty 
                      ? Colors.grey.withValues(alpha: 0.2)
                      : AppColors.successGreen.withValues(alpha: 0.15),
                ),
              ),
              child: InkWell(
                onTap: _titleController.text.trim().isEmpty ? null : _completeTask,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_titleController.text.trim().isEmpty 
                              ? Colors.grey 
                              : AppColors.successGreen).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: _titleController.text.trim().isEmpty 
                              ? Colors.grey 
                              : AppColors.successGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete Task',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _titleController.text.trim().isEmpty 
                                    ? Colors.grey
                                    : AppColors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mark as finished',
                              style: TextStyle(
                                fontSize: 14,
                                color: _titleController.text.trim().isEmpty 
                                    ? Colors.grey
                                    : AppColors.successGreen,
                                fontWeight: _titleController.text.trim().isEmpty 
                                    ? FontWeight.normal 
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: false,
                          onChanged: _titleController.text.trim().isEmpty 
                              ? null 
                              : (_) => _completeTask(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          activeColor: AppColors.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Deadline Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _deadline != null 
                      ? AppColors.lightCoral.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: _selectDeadline,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_deadline != null 
                              ? AppColors.lightCoral.withValues(alpha: 0.3)
                              : Colors.grey).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.event_rounded,
                          color: _deadline != null 
                              ? AppColors.lightCoral
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deadline',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _deadline != null 
                                    ? AppColors.lightCoral
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _deadline != null
                                  ? DateFormat('EEEE, MMMM dd').format(_deadline!)
                                  : 'Optional',
                              style: TextStyle(
                                fontSize: 14,
                                color: _deadline != null 
                                    ? AppColors.lightCoral
                                    : Colors.grey,
                                fontWeight: _deadline != null ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_deadline != null)
                        IconButton(
                          onPressed: () {
                            setState(() => _deadline = null);
                            _onFieldChanged();
                          },
                          icon: const Icon(Icons.clear_rounded),
                          color: Colors.grey,
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Recurrence Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _recurrence != null 
                      ? AppColors.lightCoral.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: _selectRecurrence,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_recurrence != null 
                              ? AppColors.lightCoral
                              : Colors.grey).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.repeat_rounded,
                          color: _recurrence != null 
                              ? AppColors.lightCoral
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recurrence',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _recurrence != null 
                                    ? AppColors.lightCoral
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _recurrence != null
                                  ? _recurrence!.getDisplayText()
                                  : 'Optional',
                              style: TextStyle(
                                fontSize: 14,
                                color: _recurrence != null 
                                    ? AppColors.lightCoral
                                    : Colors.grey,
                                fontWeight: _recurrence != null ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_recurrence != null)
                        IconButton(
                          onPressed: () {
                            setState(() => _recurrence = null);
                            _onFieldChanged();
                          },
                          icon: const Icon(Icons.clear_rounded),
                          color: Colors.grey,
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (_recurrence != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.lightCoral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.lightCoral.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.lightCoral,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This task will repeat according to the schedule',
                        style: TextStyle(
                          color: AppColors.lightCoral,
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
                  borderSide: BorderSide(color: AppColors.lightCoral, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),


            // Categories
            if (widget.categories.isNotEmpty) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedCategoryIds.isNotEmpty 
                        ? AppColors.lightCoral.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 4,
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
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

            // Reminder Time Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _reminderTime != null 
                      ? AppColors.lightCoral.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: _selectReminderTime,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_reminderTime != null 
                              ? AppColors.lightCoral
                              : Colors.grey).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_rounded,
                          color: _reminderTime != null 
                              ? AppColors.lightCoral
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reminder Time',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _reminderTime != null 
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _reminderTime != null
                                  ? _formatReminderDateTime(_reminderTime!)
                                  : 'Optional',
                              style: TextStyle(
                                fontSize: 14,
                                color: _reminderTime != null 
                                    ? AppColors.lightCoral
                                    : Colors.grey,
                                fontWeight: _reminderTime != null ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_reminderTime != null)
                        IconButton(
                          onPressed: () {
                            setState(() => _reminderTime = null);
                            _onFieldChanged();
                          },
                          icon: const Icon(Icons.clear_rounded),
                          color: Colors.grey,
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),

            // Important Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isImportant 
                      ? AppColors.coral.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_isImportant 
                            ? AppColors.coral
                            : Colors.grey).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: _isImportant 
                            ? AppColors.coral 
                            : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _isImportant 
                                  ? AppColors.lightCoral
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'High priority',
                            style: TextStyle(
                              fontSize: 14,
                              color: _isImportant 
                                  ? AppColors.coral
                                  : Colors.grey,
                              fontWeight: _isImportant ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isImportant,
                      onChanged: (value) {
                        setState(() => _isImportant = value);
                        _onFieldChanged();
                      },
                      activeTrackColor: AppColors.lightCoral.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.lightCoral,
                    ),
                  ],
                ),
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
    // First, select the date
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // Allow yesterday for flexibility
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) return;
    if (!mounted) return;

    // Then, select the time
    final selectedTime = await TimePickerUtils.showStyledTimePicker(
      context: context,
      initialTime: _reminderTime != null
          ? TimeOfDay.fromDateTime(_reminderTime!)
          : TimeOfDay.now(),
    );
    if (selectedTime != null) {
      setState(() {
        _reminderTime = DateTime(
          selectedDate.year, 
          selectedDate.month, 
          selectedDate.day, 
          selectedTime.hour, 
          selectedTime.minute
        );
      });
      _onFieldChanged();
    }
  }

  String _formatReminderDateTime(DateTime reminderTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(reminderTime.year, reminderTime.month, reminderTime.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    
    final timeStr = DateFormat('HH:mm').format(reminderTime);
    
    if (reminderDate.isAtSameMomentAs(today)) {
      return 'Today at $timeStr';
    } else if (reminderDate.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow at $timeStr';
    } else if (reminderDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday at $timeStr';
    } else {
      // Show date for other days
      final dateStr = DateFormat('MMM dd').format(reminderTime);
      return '$dateStr at $timeStr';
    }
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