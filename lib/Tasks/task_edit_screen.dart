import 'package:flutter/material.dart';
import 'dart:async';
import 'tasks_data_models.dart';
import '../shared/date_format_utils.dart';
import 'recurrence_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../shared/snackbar_utils.dart';
import 'task_service.dart';
import 'task_builder.dart';
import '../shared/error_logger.dart';
import '../Energy/flow_calculator.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final List<TaskCategory> categories;
  final List<String>? initialCategoryIds;
  final Function(Task, {bool isAutoSave}) onSave;

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
  DateTime? _scheduledDate; // For manually scheduled non-recurring tasks
  bool _hasUserModifiedScheduledDate = false; // Track if user has touched scheduled date
  bool _isImportant = false;
  TaskRecurrence? _recurrence;
  Timer? _saveTimer;
  Timer? _savedTimer;
  bool _hasUnsavedChanges = false;
  bool _showSaved = false;
  Task? _currentTask; // Track the current task to prevent duplicates
  int _energyLevel = -1; // Energy level of the task (-5 to +5, default -1 = slightly draining)

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
      _scheduledDate = task.scheduledDate;
      _isImportant = task.isImportant;
      _recurrence = task.recurrence;
      _energyLevel = task.energyLevel;
    } else if (widget.initialCategoryIds != null) {
      // Pre-fill categories for new tasks
      _selectedCategoryIds = List.from(widget.initialCategoryIds!);
    }

    // Add listeners for auto-save
    _titleController.addListener(_onFieldChanged);
  }

  @override
  void didUpdateWidget(TaskEditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cancel any pending auto-save during hot reload to prevent data loss
    _saveTimer?.cancel();
    _savedTimer?.cancel();

    // Re-initialize state from widget.task if it changed during hot reload
    if (widget.task != oldWidget.task && widget.task != null) {
      final task = widget.task!;
      _titleController.text = task.title;
      _selectedCategoryIds = List.from(task.categoryIds);
      _deadline = task.deadline;
      _reminderTime = task.reminderTime;
      _scheduledDate = task.scheduledDate;
      _isImportant = task.isImportant;
      _recurrence = task.recurrence;
      _energyLevel = task.energyLevel;
      _currentTask = task;
      _hasUnsavedChanges = false;
      _showSaved = false;
    }
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
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_hasUnsavedChanges && _titleController.text.trim().isNotEmpty) {
        _autoSaveTask();
      }
    });
  }

  Future<void> _autoSaveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    try {
      final task = TaskBuilder.buildFromEditScreen(
        currentTaskId: _currentTask?.id,
        title: _titleController.text.trim(),
        categoryIds: _selectedCategoryIds,
        deadline: _deadline,
        scheduledDate: _scheduledDate,
        reminderTime: _reminderTime,
        isImportant: _isImportant,
        isPostponed: _scheduledDate != null,
        recurrence: _recurrence,
        hasUserModifiedScheduledDate: _hasUserModifiedScheduledDate,
        currentTask: _currentTask,
        preserveCompletionStatus: true,
        energyLevel: _energyLevel,
      );

      // Pass isAutoSave flag to skip expensive operations
      widget.onSave(task, isAutoSave: true);

      // Update current task reference after first save to prevent duplicates
      _currentTask = task;

      // Only update state if widget is still mounted
      if (mounted) {
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
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'TaskEditScreen._autoSaveTask',
        error: 'Error saving task: $e',
        stackTrace: stackTrace.toString(),
        context: {'isAutoSave': true},
      );
      if (mounted) {
        SnackBarUtils.showError(context, '⚠️ Error saving task: ${e.toString()}');
      }
    }
  }

  bool _isMenstrualCycleTask(TaskRecurrence recurrence) {
    final menstrualTypes = [
      RecurrenceType.menstrualPhase,
      RecurrenceType.follicularPhase,
      RecurrenceType.ovulationPhase,
      RecurrenceType.earlyLutealPhase,
      RecurrenceType.lateLutealPhase,
      RecurrenceType.menstrualStartDay,
      RecurrenceType.ovulationPeakDay,
    ];

    return recurrence.types.any((type) => menstrualTypes.contains(type)) ||
           recurrence.types.any((type) => type == RecurrenceType.custom &&
                                          (recurrence.interval <= -100 || recurrence.interval == -1));
  }

  void _skipTask() async {
    if (_titleController.text.trim().isEmpty) {
      return;
    }

    // Capture context and navigator before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Build the task with current state
      final task = TaskBuilder.buildFromEditScreen(
        currentTaskId: _currentTask?.id,
        title: _titleController.text.trim(),
        categoryIds: _selectedCategoryIds,
        deadline: _deadline,
        scheduledDate: _scheduledDate,
        reminderTime: _reminderTime,
        isImportant: _isImportant,
        isPostponed: _currentTask?.isPostponed ?? false,
        recurrence: _recurrence,
        hasUserModifiedScheduledDate: _hasUserModifiedScheduledDate,
        currentTask: _currentTask,
        preserveCompletionStatus: false,
        energyLevel: _energyLevel,
      );

      final taskService = TaskService();

      // First, ensure the task exists in the list (if it's a new task being created and skipped)
      final allTasks = await taskService.loadTasks();
      final existingIndex = allTasks.indexWhere((t) => t.id == task.id);

      if (existingIndex == -1) {
        // New task - add it first
        allTasks.add(task);
        await taskService.saveTasks(allTasks);
      }

      // Skip to next occurrence using TaskService
      final skippedTask = await taskService.skipToNextOccurrence(task);

      // Generate context-aware message
      String message;
      if (skippedTask == null) {
        message = '⏭️ Task "${task.title}" skipped';
      } else {
        final isMenstrualTask = skippedTask.recurrence != null &&
            _isMenstrualCycleTask(skippedTask.recurrence!);

        if (isMenstrualTask) {
          message = '⏭️ "${task.title}" postponed to next menstrual cycle';
        } else if (skippedTask.scheduledDate != null) {
          final nextDate = DateFormatUtils.formatShort(skippedTask.scheduledDate!);
          message = '⏭️ "${task.title}" skipped to $nextDate';
        } else {
          message = '⏭️ "${task.title}" skipped to next occurrence';
        }
      }

      // Close loading dialog
      navigator.pop();

      // Close screen and return success message
      navigator.pop(message);
    } catch (e) {
      // Close loading dialog
      navigator.pop();

      // Show error using captured scaffoldMessenger
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to skip task: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,  // Intercept back button to save first
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // Save to disk before allowing navigation
          if (_titleController.text.trim().isNotEmpty) {
            try {
              final task = TaskBuilder.buildFromEditScreen(
                currentTaskId: _currentTask?.id,
                title: _titleController.text.trim(),
                categoryIds: _selectedCategoryIds,
                deadline: _deadline,
                scheduledDate: _scheduledDate,
                reminderTime: _reminderTime,
                isImportant: _isImportant,
                isPostponed: _scheduledDate != null,
                recurrence: _recurrence,
                hasUserModifiedScheduledDate: _hasUserModifiedScheduledDate,
                currentTask: _currentTask,
                preserveCompletionStatus: true,
                energyLevel: _energyLevel,
              );

              // Save to disk with isAutoSave: false
              widget.onSave(task, isAutoSave: false);

              // Wait a brief moment for save to complete
              await Future.delayed(const Duration(milliseconds: 50));
            } catch (e, stackTrace) {
              await ErrorLogger.logError(
                source: 'TaskEditScreen.onPopInvokedWithResult',
                error: 'Error saving task on exit: $e',
                stackTrace: stackTrace.toString(),
              );
            }
          }

          // Cancel any pending timers
          _saveTimer?.cancel();
          _savedTimer?.cancel();

          // Now allow navigation
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.dialogBackground,
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
                    const Icon(
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

            // Set Scheduled Day Section (ALWAYS VISIBLE)
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: _scheduledDate != null
                      ? AppColors.successGreen.withValues(alpha: 0.1)
                      : AppColors.greyText,
                ),
              ),
              child: InkWell(
                onTap: _selectScheduledDate,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_scheduledDate != null
                              ? AppColors.successGreen.withValues(alpha: 0.3)
                              : AppColors.greyText).withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: _scheduledDate != null
                              ? AppColors.successGreen
                              : AppColors.greyText,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectScheduledDate,
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _recurrence != null ? 'Reschedule This Occurrence' : 'Set Scheduled Day',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.greyText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _scheduledDate != null
                                    ? DateFormatUtils.formatFullDate(_scheduledDate!)
                                    : _recurrence != null
                                        ? 'Override when to do this occurrence'
                                        : 'Choose when to do this task',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.greyText,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_scheduledDate != null)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _scheduledDate = null;
                              _hasUserModifiedScheduledDate = true;
                            });
                            _onFieldChanged();
                          },
                          icon: const Icon(Icons.clear_rounded),
                          color: AppColors.greyText,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Skip Task Section (ONLY FOR RECURRING TASKS)
            if (_recurrence != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _titleController.text.trim().isEmpty
                      ? AppColors.dialogBackground
                      : AppColors.lightCoral.withValues(alpha: 0.03),
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: _titleController.text.trim().isEmpty
                        ? AppColors.greyText
                        : AppColors.lightCoral.withValues(alpha: 0.1),
                  ),
                ),
                child: InkWell(
                  onTap: _titleController.text.trim().isEmpty ? null : _skipTask,
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_titleController.text.trim().isEmpty
                                ? AppColors.greyText
                                : AppColors.lightCoral).withValues(alpha: 0.1),
                            borderRadius: AppStyles.borderRadiusMedium,
                          ),
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: _titleController.text.trim().isEmpty
                                ? AppColors.greyText
                                : AppColors.lightCoral,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Skip to Next Occurrence',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.greyText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _recurrence!.types.any((type) => [
                                  RecurrenceType.menstrualPhase,
                                  RecurrenceType.follicularPhase,
                                  RecurrenceType.ovulationPhase,
                                  RecurrenceType.earlyLutealPhase,
                                  RecurrenceType.lateLutealPhase
                                ].contains(type))
                                    ? 'Put on hold until next appropriate phase'
                                    : 'Advance to the next scheduled recurrence',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.white24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 1.2,
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: _titleController.text.trim().isEmpty
                                ? AppColors.greyText
                                : AppColors.lightCoral,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Deadline Section (only for non-recurring tasks)
            if (_recurrence == null) ...[
              const SizedBox(height: 12),
              Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: _deadline != null 
                      ? AppColors.lightCoral.withValues(alpha: 0.1)
                      : AppColors.greyText,
                ),
              ),
              child: InkWell(
                onTap: _selectDeadline,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_deadline != null 
                              ? AppColors.lightCoral.withValues(alpha: 0.3)
                              : AppColors.greyText).withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                        child: Icon(
                          Icons.event_rounded,
                          color: _deadline != null 
                              ? AppColors.lightCoral
                              : AppColors.greyText,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _deadline != null
                                  ? DateFormatUtils.formatFullDate(_deadline!)
                                  : 'Optional',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                                fontWeight: FontWeight.normal,
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
                          color: AppColors.greyText,
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.greyText,
                        ),
                    ],
                  ),
                ),
              ),
            ),
              const SizedBox(height: 12),
            ],

            // Reminder Time Section (only for non-recurring tasks)
            if (_recurrence == null)
              Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: _reminderTime != null 
                      ? AppColors.lightCoral.withValues(alpha: 0.1)
                      : AppColors.greyText,
                ),
              ),
              child: InkWell(
                onTap: _selectReminderTime,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_reminderTime != null 
                              ? AppColors.lightCoral
                              : AppColors.greyText).withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                        child: Icon(
                          Icons.notifications_rounded,
                          color: _reminderTime != null 
                              ? AppColors.lightCoral
                              : AppColors.greyText,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _reminderTime != null
                                  ? _formatReminderDateTime(_reminderTime!) // Always show full date/time
                                  : 'Optional',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                                fontWeight: FontWeight.normal,
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
                          color: AppColors.greyText,
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.greyText,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Only add spacing if reminder section was shown
            if (_recurrence == null) const SizedBox(height: 12),

            // Priority Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: _isImportant
                      ? AppColors.coral.withValues(alpha: 0.3)
                      : AppColors.greyText,
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
                            : AppColors.greyText).withValues(alpha: 0.1),
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: _isImportant
                            ? AppColors.coral
                            : AppColors.greyText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Priority',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _isImportant
                                  ? AppColors.lightCoral
                                  : AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mark as high priority',
                            style: TextStyle(
                              fontSize: 14,
                              color: _isImportant
                                  ? AppColors.coral
                                  : AppColors.greyText,
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

            const SizedBox(height: 16),

            // Task Title Section
            TextField(
              controller: _titleController,
              minLines: 1,
              maxLines: null,
              decoration: InputDecoration(
                labelText: 'Task Title',
                hintText: 'What do you need to do?',
                border: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                  borderSide: BorderSide(color: AppColors.greyText),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppStyles.borderRadiusMedium,
                  borderSide: BorderSide(color: AppColors.lightCoral, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Categories Section
            if (widget.categories.isNotEmpty) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.dialogBackground.withValues(alpha: 0.08),
                  borderRadius: AppStyles.borderRadiusLarge,
                  border: Border.all(
                    color: _selectedCategoryIds.isNotEmpty 
                        ? AppColors.lightCoral.withValues(alpha: 0.1)
                        : AppColors.greyText,
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
                            shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
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

            // Recurrence Section
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: _recurrence != null 
                      ? AppColors.lightCoral.withValues(alpha: 0.1)
                      : AppColors.greyText,
                ),
              ),
              child: InkWell(
                onTap: _selectRecurrence,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_recurrence != null 
                              ? AppColors.lightCoral
                              : AppColors.greyText).withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusMedium,
                        ),
                        child: Icon(
                          Icons.repeat_rounded,
                          color: _recurrence != null 
                              ? AppColors.lightCoral
                              : AppColors.greyText,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _recurrence != null
                                  ? _recurrence!.getDisplayText()
                                  : 'Optional',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_recurrence != null)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _recurrence = null;
                            });
                            _onFieldChanged();
                          },
                          icon: const Icon(Icons.clear_rounded),
                          color: AppColors.greyText,
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.greyText,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Energy Level Section (-5 to +5 scale)
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogBackground.withValues(alpha: 0.08),
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: _energyLevel != -1
                      ? _getEnergyColor(_energyLevel).withValues(alpha: 0.3)
                      : AppColors.greyText,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_energyLevel != -1
                            ? _getEnergyColor(_energyLevel)
                            : AppColors.greyText).withValues(alpha: 0.1),
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                      child: Icon(
                        _energyLevel < 0 ? Icons.battery_3_bar_rounded : Icons.battery_charging_full_rounded,
                        color: _energyLevel != -1
                            ? _getEnergyColor(_energyLevel)
                            : AppColors.greyText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Energy',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _getEnergyColor(_energyLevel),
                              inactiveTrackColor: AppColors.greyText.withValues(alpha: 0.2),
                              thumbColor: _getEnergyColor(_energyLevel),
                              overlayColor: _getEnergyColor(_energyLevel).withValues(alpha: 0.2),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            ),
                            child: Slider(
                              value: _energyLevel.toDouble(),
                              min: -5,
                              max: 5,
                              divisions: 10,
                              onChanged: (value) {
                                setState(() => _energyLevel = value.round());
                                _onFieldChanged();
                              },
                            ),
                          ),
                          Text(
                            _getEnergyDescription(_energyLevel),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: _energyLevel != -1 ? _getEnergyColor(_energyLevel) : AppColors.greyText,
                            ),
                          ),
                        ],
                      ),
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

  Color _getEnergyColor(int level) {
    // -5 to +5 scale: negative = draining (red), positive = charging (green)
    if (level <= -4) return AppColors.coral;
    if (level <= -2) return AppColors.orange;
    if (level < 0) return AppColors.yellow;
    if (level == 0) return AppColors.greyText;
    if (level <= 2) return AppColors.lightGreen;
    return AppColors.successGreen;
  }

  String _getEnergyDescription(int level) {
    switch (level) {
      case -5: return 'Exhausting (-50%)';
      case -4: return 'Very draining (-40%)';
      case -3: return 'Draining (-30%)';
      case -2: return 'Moderate effort (-20%)';
      case -1: return 'Light effort (-10%)';
      case 0: return 'Neutral (0%)';
      case 1: return 'Relaxing (+10%)';
      case 2: return 'Refreshing (+20%)';
      case 3: return 'Energizing (+30%)';
      case 4: return 'Very energizing (+40%)';
      case 5: return 'Restorative (+50%)';
      default: return 'Unknown';
    }
  }

  void _selectDeadline() async {
    final date = await DatePickerUtils.showStyledDatePicker(
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
    final selectedDateTime = await DatePickerUtils.showStyledDateTimePicker(
      context: context,
      initialDateTime: _reminderTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // Allow yesterday for flexibility
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (selectedDateTime != null) {
      setState(() {
        _reminderTime = selectedDateTime;
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
    
    final timeStr = DateFormatUtils.formatTime24(reminderTime);
    
    if (reminderDate.isAtSameMomentAs(today)) {
      return 'Today at $timeStr';
    } else if (reminderDate.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow at $timeStr';
    } else if (reminderDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday at $timeStr';
    } else {
      // Show date for other days
      final dateStr = DateFormatUtils.formatShort(reminderTime);
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
        // Clear manually set scheduled date and deadline when setting recurrence
        if (recurrence != null) {
          _scheduledDate = null;
          _hasUserModifiedScheduledDate = true;
          _deadline = null; // Deadlines don't make sense for recurring tasks
          // Keep _reminderTime - recurring tasks CAN have reminders!
        }
      });
      _onFieldChanged();
    }
  }

  void _selectScheduledDate() async {
    final date = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _scheduledDate = date;
        _hasUserModifiedScheduledDate = true;
      });
      _onFieldChanged();
    }
  }

}