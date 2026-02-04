import 'package:bb_app/Routines/routine_edit_screen.dart';
import 'package:bb_app/Routines/routine_execution_screen.dart';
import 'package:bb_app/Routines/routine_reminder_settings_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:bb_app/Routines/routine_data_models.dart';
import 'package:bb_app/theme/app_colors.dart';
import 'package:bb_app/theme/app_styles.dart';
import 'package:bb_app/shared/snackbar_utils.dart';
import 'package:bb_app/Routines/routine_service.dart';
import 'package:bb_app/Routines/routine_progress_service.dart';
import 'package:bb_app/Routines/routine_widget_service.dart';
import 'package:bb_app/Notifications/notification_service.dart';

class RoutinesScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const RoutinesScreen({super.key, this.onOpenDrawer});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Routine> _routines = [];
  bool _isLoading = true;
  String? _inProgressRoutineId;

  // Hold state tracking
  bool _isHoldingForRoutineDelete = false;
  String? _holdingRoutineId;
  Timer? _routineHoldTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _routineHoldTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _routines = await RoutineService.loadRoutines();

    // Use unified method to determine which routine should show Continue button
    final activeRoutine = await RoutineService.getCurrentActiveRoutine(_routines);
    if (activeRoutine != null) {
      final progress = await RoutineProgressService.loadRoutineProgress(activeRoutine.id);
      if (progress != null) {
        // This routine has progress today, consider it in-progress
        final completedSteps = List<bool>.from(progress['completedSteps'] ?? []);
        final allCompleted = completedSteps.isNotEmpty && completedSteps.every((step) => step);

        if (!allCompleted) {
          _inProgressRoutineId = activeRoutine.id;
        }
      }
    }

    // Save routines if we got the default ones (first time)
    if (_routines.length == 1 && _routines.first.id == '1') {
      await RoutineService.saveRoutines(_routines);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRoutines() async {
    await RoutineService.saveRoutines(_routines);
  }

  void _startRoutineHoldTimer(Routine routine) {
    // Cancel any existing timer to prevent duplicates
    _routineHoldTimer?.cancel();

    setState(() {
      _holdingRoutineId = routine.id;
      _isHoldingForRoutineDelete = true;
    });

    _routineHoldTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isHoldingForRoutineDelete && _holdingRoutineId == routine.id) {
        _deleteRoutine(routine);
        _cancelRoutineHoldTimer();
      }
    });
  }

  void _cancelRoutineHoldTimer() {
    _routineHoldTimer?.cancel();
    _routineHoldTimer = null;
    if (mounted) {
      setState(() {
        _isHoldingForRoutineDelete = false;
        _holdingRoutineId = null;
      });
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

  void _duplicateRoutine(Routine routine) {
    final duplicatedRoutine = Routine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${routine.title} (Copy)',
      items: routine.items.map((item) => RoutineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + item.id,
        text: item.text,
        isCompleted: false,
        isSkipped: false,
      )).toList(),
      reminderEnabled: false,
      reminderHour: routine.reminderHour,
      reminderMinute: routine.reminderMinute,
      activeDays: Set<int>.from(routine.activeDays),
    );

    setState(() {
      _routines.add(duplicatedRoutine);
    });
    _saveRoutines();

    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Routine "${routine.title}" duplicated');
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final notificationService = NotificationService();
    await notificationService.cancelRoutineNotification(routine.id);

    setState(() {
      _routines.removeWhere((r) => r.id == routine.id);
    });
    _saveRoutines();
  }

  Future<void> _setAsActiveForToday(Routine routine) async {
    // Clear any in-progress routine first
    await RoutineProgressService.clearInProgressStatus();

    // Clear progress for all other routines to ensure no Continue buttons remain
    for (final r in _routines) {
      if (r.id != routine.id) {
        await RoutineProgressService.clearRoutineProgress(r.id);
      }
    }

    // Mark the routine as in-progress and create initial progress
    await RoutineProgressService.markRoutineInProgress(routine.id);

    // Create initial progress with all steps uncompleted
    final initialItems = routine.items.map((item) => RoutineItem(
      id: item.id,
      text: item.text,
      isCompleted: false,
      isSkipped: false,
    )).toList();

    await RoutineProgressService.saveRoutineProgress(
      routineId: routine.id,
      currentStepIndex: 0,
      items: initialItems,
    );

    // Update UI state
    _inProgressRoutineId = routine.id;

    // Update widget
    await RoutineWidgetService.updateWidget();

    // Trigger UI rebuild
    if (mounted) {
      setState(() {});

      SnackBarUtils.showSuccess(context, '${routine.title} set as active for today');
    }
  }

  void _startRoutine(Routine routine) async {
    // Clear any previous in-progress routine
    await RoutineProgressService.clearInProgressStatus();

    // Clear progress for all other routines to ensure no Continue buttons remain
    for (final r in _routines) {
      if (r.id != routine.id) {
        await RoutineProgressService.clearRoutineProgress(r.id);
      }
    }

    // Mark the new routine as in progress
    await RoutineProgressService.markRoutineInProgress(routine.id);

    setState(() {
      _inProgressRoutineId = routine.id;
    });

    // Update widget to show the routine is in progress
    await RoutineWidgetService.updateWidget();

    if (mounted) {
      SnackBarUtils.showSuccess(context, '${routine.title} started');
    }
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
    final drawerLeading = widget.onOpenDrawer != null
        ? IconButton(icon: const Icon(Icons.menu_rounded), onPressed: widget.onOpenDrawer)
        : null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: drawerLeading,
          title: const Text('Routines'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: drawerLeading,
        title: const Text('Routines'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _openReminderSettings,
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Reminder Settings',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: _addRoutine,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Routine',
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _buildRoutinesContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutinesContent() {
    if (_routines.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.greyText),
                SizedBox(height: 16),
                Text(
                  'No routines yet',
                  style: TextStyle(fontSize: 18, color: AppColors.greyText),
                ),
                Text(
                  'Create your first routine to get started',
                  style: TextStyle(color: AppColors.greyText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Tap to edit • Long press for options',
                  style: TextStyle(
                    color: AppColors.greyText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _routines.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final routine = _routines.removeAt(oldIndex);
                _routines.insert(newIndex, routine);
              });
              _saveRoutines();
            },
            itemBuilder: (context, index) {
              final routine = _routines[index];
              return _buildRoutineCard(routine, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineCard(Routine routine, int index) {
    return Dismissible(
      key: ValueKey(routine.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.7},
      confirmDismiss: (direction) async {
        return false; // Never auto-dismiss, require manual hold confirmation
      },
      onUpdate: (details) {
        final threshold = 0.7;
        final reachedThreshold = details.progress >= threshold;

        // When threshold reached, start hold detection
        if (reachedThreshold && _holdingRoutineId != routine.id) {
          _startRoutineHoldTimer(routine);
        } else if (!reachedThreshold && _holdingRoutineId == routine.id) {
          _cancelRoutineHoldTimer();
        }
      },
      onDismissed: (direction) {
        _deleteRoutine(routine);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: (_isHoldingForRoutineDelete && _holdingRoutineId == routine.id)
              ? AppColors.deleteRed
              : AppColors.deleteRed.withValues(alpha: 0.8),
          borderRadius: AppStyles.borderRadiusMedium,
          boxShadow: (_isHoldingForRoutineDelete && _holdingRoutineId == routine.id) ? [
            BoxShadow(
              color: AppColors.deleteRed.withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 0,
            )
          ] : null,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              (_isHoldingForRoutineDelete && _holdingRoutineId == routine.id)
                  ? Icons.timer_rounded
                  : Icons.delete_rounded,
              color: AppColors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              (_isHoldingForRoutineDelete && _holdingRoutineId == routine.id)
                  ? 'Hold to Delete'
                  : 'Delete',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        key: ValueKey('routine_${routine.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppStyles.borderRadiusMedium,
        ),
        child: InkWell(
          onTap: () => _editRoutine(routine),
          borderRadius: AppStyles.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.drag_handle_rounded, color: AppColors.greyText),
                    const SizedBox(width: 8),
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
                          color: AppColors.yellow.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusMedium,
                          border: Border.all(
                            color: AppColors.yellow.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              color: AppColors.yellow,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${routine.reminderHour.toString().padLeft(2, '0')}:${routine.reminderMinute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.yellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'duplicate') {
                          _duplicateRoutine(routine);
                        } else if (value == 'delete') {
                          _deleteRoutine(routine);
                        } else if (value == 'set_active') {
                          _setAsActiveForToday(routine);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'set_active',
                          child: Row(
                            children: [
                              Icon(Icons.today_rounded, size: 18, color: AppColors.lightGreen),
                              const SizedBox(width: 8),
                              Text('Set as Active', style: TextStyle(color: AppColors.lightGreen)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 18, color: AppColors.lightYellow),
                              SizedBox(width: 8),
                              Text('Duplicate', style: TextStyle(color: AppColors.lightYellow)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.lightRed),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: AppColors.lightRed)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${routine.items.length} steps',
                      style: const TextStyle(color: AppColors.greyText),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: routine.isActiveToday()
                            ? AppColors.orange.withValues(alpha: 0.15)
                            : AppColors.yellow.withValues(alpha: 0.1),
                        borderRadius: AppStyles.borderRadiusSmall,
                        border: Border.all(
                          color: routine.isActiveToday()
                              ? AppColors.orange.withValues(alpha: 0.4)
                              : AppColors.yellow.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        routine.getActiveDaysText(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: routine.isActiveToday()
                              ? AppColors.orange
                              : AppColors.yellow,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _inProgressRoutineId == routine.id
                        ? InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoutineExecutionScreen(
                                    routine: routine,
                                    onCompleted: () async {
                                      await RoutineProgressService.clearInProgressStatus();
                                      _loadData();
                                    },
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(alpha: 0.2),
                                borderRadius: AppStyles.borderRadiusSmall,
                                border: Border.all(
                                  color: AppColors.successGreen.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.autorenew_rounded,
                                    color: AppColors.yellow,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Continue',
                                    style: TextStyle(
                                      color: AppColors.yellow,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _startRoutine(routine),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start Routine'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.borderRadiusSmall,
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
  }
}
