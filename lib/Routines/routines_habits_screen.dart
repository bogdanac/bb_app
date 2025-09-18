import 'package:bb_app/Routines/routine_edit_screen.dart';
import 'package:bb_app/Routines/routine_execution_screen.dart';
import 'package:bb_app/Routines/routine_reminder_settings_screen.dart';
import 'package:bb_app/Habits/habit_edit_screen.dart';
import 'package:bb_app/Habits/habit_statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:bb_app/Routines/routine_data_models.dart';
import 'package:bb_app/Habits/habit_data_models.dart';
import '../theme/app_colors.dart';
import 'routine_service.dart';
import 'routine_progress_service.dart';
import 'routine_widget_service.dart';
import '../Habits/habit_service.dart';
import '../Notifications/notification_service.dart';

class RoutinesHabitsScreen extends StatefulWidget {
  const RoutinesHabitsScreen({super.key});

  @override
  State<RoutinesHabitsScreen> createState() => _RoutinesHabitsScreenState();
}

class _RoutinesHabitsScreenState extends State<RoutinesHabitsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Routine> _routines = [];
  List<Habit> _habits = [];
  bool _isLoading = true;
  String? _inProgressRoutineId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes to update app bar actions
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _routines = await RoutineService.loadRoutines();
    _habits = await HabitService.loadHabits();
    
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

  // Routine methods
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Routine "${routine.title}" duplicated'),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${routine.title} set as active for today'),
          backgroundColor: AppColors.lightGreen,
          duration: const Duration(seconds: 2),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${routine.title} started'),
          backgroundColor: AppColors.lightGreen,
          duration: const Duration(seconds: 2),
        ),
      );
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

  // Habit methods
  void _addHabit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitEditScreen(
          onSave: (habit) async {
            await HabitService.addHabit(habit);
            _loadData();
          },
        ),
      ),
    );
  }

  void _editHabit(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitEditScreen(
          habit: habit,
          onSave: (updatedHabit) async {
            await HabitService.updateHabit(updatedHabit);
            _loadData();
          },
        ),
      ),
    );
  }

  Future<void> _deleteHabit(Habit habit) async {
    await HabitService.deleteHabit(habit.id);
    _loadData();
  }

  Future<void> _toggleHabitActive(Habit habit) async {
    habit.isActive = !habit.isActive;
    await HabitService.updateHabit(habit);
    _loadData();
  }

  void _viewStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitStatisticsScreen(habits: _habits),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Routines & Habits'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines & Habits'),
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _tabController.index == 0 ? AppColors.yellow : AppColors.orange,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.white,
              unselectedLabelColor: _tabController.index == 0 ? AppColors.lightYellow : AppColors.lightOrange,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Routines'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Habits'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (_tabController.index == 0) ...[
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
          ] else ...[
            if (_habits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: _viewStatistics,
                  icon: const Icon(Icons.analytics_outlined),
                  tooltip: 'Statistics',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: _addHabit,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add Habit',
              ),
            ),
          ],
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            child: _buildRoutinesTab(),
          ),
          RefreshIndicator(
            onRefresh: _loadData,
            child: _buildHabitsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutinesTab() {
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

  Widget _buildHabitsTab() {
    if (_habits.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology_rounded, size: 64, color: AppColors.greyText),
                SizedBox(height: 16),
                Text(
                  'No habits yet',
                  style: TextStyle(fontSize: 18, color: AppColors.greyText),
                ),
                Text(
                  'Create your first habit to get started',
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
                  'Tap to edit • Swipe left to delete • Toggle switch to activate',
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
            itemCount: _habits.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final habit = _habits.removeAt(oldIndex);
                _habits.insert(newIndex, habit);
              });
              // Note: Habits don't have a specific save order method like routines
            },
            itemBuilder: (context, index) {
              final habit = _habits[index];
              return _buildHabitCard(habit, index);
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
      dismissThresholds: const {DismissDirection.endToStart: 0.8},
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.lightYellow,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text('Delete Routine'),
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
                  backgroundColor: AppColors.lightYellow,
                  foregroundColor: AppColors.white,
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
          color: AppColors.deleteRed,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_rounded,
              color: AppColors.white,
              size: 32,
            ),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
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
                          borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(8),
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
                                borderRadius: BorderRadius.circular(8),
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
  }

  Widget _buildHabitCard(Habit habit, int index) {
    final isCompletedToday = habit.isCompletedToday();
    final streak = habit.getStreak();

    return Dismissible(
      key: ValueKey(habit.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.8},
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.lightYellow,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text('Delete Habit'),
              ],
            ),
            content: Text('Are you sure you want to delete "${habit.name}"? This will permanently remove all tracking data.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightYellow,
                  foregroundColor: AppColors.white,
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
        _deleteHabit(habit);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.deleteRed,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_rounded,
              color: AppColors.white,
              size: 32,
            ),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        key: ValueKey('habit_${habit.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _editHabit(habit),
          borderRadius: BorderRadius.circular(12),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: habit.isActive ? null : AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cycle ${habit.currentCycle} • ${habit.getCurrentCycleProgress()}/21 days',
                            style: TextStyle(
                              color: habit.isActive ? AppColors.orange : AppColors.greyText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: habit.isActive,
                      onChanged: (value) => _toggleHabitActive(habit),
                      activeThumbColor: AppColors.orange,
                    ),
                  ],
                ),
                if (habit.isActive) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompletedToday ? AppColors.orange.withValues(alpha: 0.1) : AppColors.greyText,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompletedToday ? AppColors.orange.withValues(alpha: 0.3) : AppColors.greyText,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompletedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isCompletedToday ? AppColors.orange : AppColors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCompletedToday ? 'Completed Today' : 'Not Done Today',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isCompletedToday ? AppColors.orange : AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.greyText,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                color: AppColors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$streak day${streak == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}