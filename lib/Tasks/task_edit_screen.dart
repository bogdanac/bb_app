import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'tasks_data_models.dart';
import '../shared/date_format_utils.dart';
import 'recurrence_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import '../shared/snackbar_utils.dart';

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
  DateTime? _scheduledDate; // For manually scheduled non-recurring tasks
  bool _hasUserModifiedScheduledDate = false; // Track if user has touched scheduled date
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
      _scheduledDate = task.scheduledDate;
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
      _currentTask = task;
      _hasUnsavedChanges = false;
      _showSaved = false;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savedTimer?.cancel();

    // Save immediately if there are unsaved changes when exiting
    if (_hasUnsavedChanges && _titleController.text.trim().isNotEmpty) {
      _autoSaveTask();
    }

    _titleController.dispose();
    super.dispose();
  }

  // Synchronous save for immediate persistence (used on back button)
  Future<void> _saveTaskImmediately() async {
    if (_titleController.text.trim().isEmpty) return;

    try {
      final task = Task(
        id: _currentTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: '',
        categoryIds: _selectedCategoryIds,
        deadline: _deadline,
        scheduledDate: _hasUserModifiedScheduledDate
            ? _scheduledDate
            : (_scheduledDate ?? (_currentTask == null ? _getScheduledDate() : _currentTask?.scheduledDate)),
        reminderTime: _reminderTime,
        isImportant: _isImportant,
        isPostponed: _scheduledDate != null,
        recurrence: _recurrence,
        isCompleted: _currentTask?.isCompleted ?? false,
        completedAt: _currentTask?.completedAt,
        createdAt: _currentTask?.createdAt ?? DateTime.now(),
      );

      // Call the onSave callback and wait if it returns a Future
      final result = widget.onSave(task);
      if (result is Future) {
        await result;
      }

      // Update current task reference after save
      _currentTask = task;
      _hasUnsavedChanges = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving task immediately: $e');
      }
    }
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

  void _autoSaveTask() {
    if (_titleController.text.trim().isEmpty) return;

    try {
      final task = Task(
        id: _currentTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: '',
        categoryIds: _selectedCategoryIds,
        deadline: _deadline,
        scheduledDate: _hasUserModifiedScheduledDate
            ? _scheduledDate
            : (_scheduledDate ?? (_currentTask == null ? _getScheduledDate() : _currentTask?.scheduledDate)),
        reminderTime: _reminderTime,
        isImportant: _isImportant,
        isPostponed: _scheduledDate != null, // User manually set scheduled date
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
        SnackBarUtils.showError(context, '⚠️ Error saving task: ${e.toString()}');
      }
    }
  }


  void _skipTask() async {
    if (_titleController.text.trim().isEmpty) return;

    DateTime? nextScheduledDate;

    // Calculate next scheduled date based on recurrence
    if (_recurrence != null) {
      final now = DateTime.now();

      // For menstrual cycle tasks, put on hold until appropriate phase
      if (_recurrence!.types.any((type) => [
        RecurrenceType.menstrualPhase,
        RecurrenceType.follicularPhase,
        RecurrenceType.ovulationPhase,
        RecurrenceType.earlyLutealPhase,
        RecurrenceType.lateLutealPhase
      ].contains(type))) {
        // For menstrual cycle tasks, don't set a specific date - they'll appear when appropriate phase comes
        nextScheduledDate = null;
      } else {
        // For regular recurring tasks, calculate next occurrence
        if (_recurrence!.types.contains(RecurrenceType.daily)) {
          nextScheduledDate = DateTime(now.year, now.month, now.day + 1);
        } else if (_recurrence!.types.contains(RecurrenceType.weekly)) {
          nextScheduledDate = DateTime(now.year, now.month, now.day + 7);
        } else if (_recurrence!.types.contains(RecurrenceType.monthly)) {
          nextScheduledDate = DateTime(now.year, now.month + 1, now.day);
        } else if (_recurrence!.types.contains(RecurrenceType.yearly)) {
          nextScheduledDate = DateTime(now.year + 1, now.month, now.day);
        } else {
          // For custom recurrence, skip by 1 day as default
          nextScheduledDate = DateTime(now.year, now.month, now.day + 1);
        }
      }
    } else {
      // Non-recurring task - skip by 1 day
      final now = DateTime.now();
      nextScheduledDate = DateTime(now.year, now.month, now.day + 1);
    }

    final task = Task(
      id: _currentTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: '',
      categoryIds: _selectedCategoryIds,
      deadline: _deadline,
      scheduledDate: nextScheduledDate,
      reminderTime: _reminderTime,
      isImportant: _isImportant,
      isPostponed: nextScheduledDate != null, // Mark as postponed if we calculated a new date
      recurrence: _recurrence,
      isCompleted: false,
      completedAt: null,
      createdAt: _currentTask?.createdAt ?? DateTime.now(),
    );

    // Show feedback
    if (mounted) {
      final skipMessage = nextScheduledDate != null
          ? '⏭️ Task "${task.title}" skipped until ${DateFormatUtils.formatShort(nextScheduledDate)}'
          : '⏭️ Task "${task.title}" skipped until next appropriate phase';

      SnackBarUtils.showCustom(context, skipMessage, backgroundColor: AppColors.lightCoral, duration: const Duration(seconds: 2));
    }

    // Save the task
    widget.onSave(task);

    // Small delay to ensure the snackbar shows and save completes
    await Future.delayed(const Duration(milliseconds: 500));

    // Close the dialog/screen after skipping the task
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  DateTime? _getScheduledDate() {
    // If the task already has a scheduled date, keep it
    if (_currentTask?.scheduledDate != null) {
      return _currentTask!.scheduledDate;
    }

    // If we have a recurrence, calculate the next scheduled date
    if (_recurrence != null) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Check if it's due today
      if (_recurrence!.isDueOn(todayDate, taskCreatedAt: _currentTask?.createdAt ?? DateTime.now())) {
        return todayDate;
      }

      // Optimize for common recurrence types
      if (_recurrence!.types.contains(RecurrenceType.daily)) {
        return todayDate.add(const Duration(days: 1));
      } else if (_recurrence!.types.contains(RecurrenceType.weekly)) {
        // For weekly, find the next matching weekday
        for (int i = 1; i <= 7; i++) {
          final checkDate = todayDate.add(Duration(days: i));
          if (_recurrence!.isDueOn(checkDate, taskCreatedAt: _currentTask?.createdAt ?? DateTime.now())) {
            return checkDate;
          }
        }
      } else if (_recurrence!.types.contains(RecurrenceType.monthly)) {
        // For monthly, calculate directly based on day of month
        final targetDay = _recurrence!.dayOfMonth ?? todayDate.day;
        var nextMonth = todayDate.month;
        var nextYear = todayDate.year;

        // Move to next month if we've passed the target day this month
        if (todayDate.day >= targetDay) {
          nextMonth++;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
        }

        // Clamp the day to the last day of the month if necessary
        final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;
        return DateTime(nextYear, nextMonth, actualDay);
      } else if (_recurrence!.types.contains(RecurrenceType.yearly)) {
        // For yearly, calculate directly
        final targetMonth = _recurrence!.interval; // For yearly, interval represents the month
        final targetDay = _recurrence!.dayOfMonth ?? todayDate.day;
        var nextYear = todayDate.year;

        // Move to next year if we've passed the target date this year
        final targetDate = DateTime(nextYear, targetMonth, targetDay);
        if (todayDate.isAfter(targetDate)) {
          nextYear++;
        }

        return DateTime(nextYear, targetMonth, targetDay);
      } else {
        // Fallback for custom or other recurrence types - limit search to 30 days
        for (int i = 1; i <= 30; i++) {
          final checkDate = todayDate.add(Duration(days: i));
          if (_recurrence!.isDueOn(checkDate, taskCreatedAt: _currentTask?.createdAt ?? DateTime.now())) {
            return checkDate;
          }
        }
      }
      
      // For weekly recurrence, find next occurrence
      if (_recurrence!.types.contains(RecurrenceType.weekly)) {
        // For weekly with intervals (e.g., every 4, 8, 12 weeks), search up to interval * 7 + 7 days
        // This ensures we find the next occurrence even for very long weekly intervals
        final maxDays = _recurrence!.interval > 1 ? (_recurrence!.interval * 7) + 7 : 7;
        for (int i = 1; i <= maxDays; i++) {
          final checkDate = todayDate.add(Duration(days: i));
          if (_recurrence!.isDueOn(checkDate, taskCreatedAt: _currentTask?.createdAt ?? DateTime.now())) {
            return checkDate;
          }
        }
      }
      
      // For daily recurrence, calculate next occurrence
      if (_recurrence!.types.contains(RecurrenceType.daily)) {
        // Check up to the interval + 1 days to find the next occurrence
        // For intervals like 2-3 days, this ensures we find the next occurrence
        // For long intervals (like 90 days), this also works properly
        final maxDays = _recurrence!.interval + 1;
        for (int i = 1; i <= maxDays; i++) {
          final checkDate = todayDate.add(Duration(days: i));
          if (_recurrence!.isDueOn(checkDate, taskCreatedAt: _currentTask?.createdAt ?? DateTime.now())) {
            return checkDate;
          }
        }
      }
      
      // Fallback: For any other recurrence types (menstrual phases, custom, etc.)
      // Search up to 1 year to find the next occurrence
      for (int i = 1; i <= 365; i++) {
        final checkDate = todayDate.add(Duration(days: i));
        if (_recurrence!.isDueOn(checkDate, taskCreatedAt: _currentTask?.createdAt ?? DateTime.now())) {
          return checkDate;
        }
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // We'll handle pop manually
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // Auto-save before leaving if there are unsaved changes
        if (!didPop && _hasUnsavedChanges && _titleController.text.trim().isNotEmpty) {
          // Save synchronously to ensure it completes before pop
          await _saveTaskImmediately();
        }
        // Now pop manually
        if (!didPop && mounted) {
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

            // Skip Task / Set Scheduled Day Section
            if (_recurrence != null) ...[
              // Skip Task Section (for recurring tasks)
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
                                'Skip Task',
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
                                    : 'Postpone to next occurrence',
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
            ] else ...[
              // Set Scheduled Day Section (for non-recurring tasks)
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
                                  'Set Scheduled Day',
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
            ],

            const SizedBox(height: 12),

            // Deadline Section (only for non-recurring tasks)
            if (_recurrence == null)
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

            // Only add spacing if deadline section was shown
            if (_recurrence == null) const SizedBox(height: 12),

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

            // Important Section
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
                            'Important',
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
                            'High priority',
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

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
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
        // If we set a recurrence and the task doesn't have a scheduled date,
        // set it to today if the recurrence makes the task due today
        if (recurrence != null && _currentTask?.scheduledDate == null) {
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          if (recurrence.isDueOn(todayDate, taskCreatedAt: _currentTask?.createdAt ?? DateTime.now())) {
          }
        }
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