import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import '../shared/date_format_utils.dart';
import 'menstrual_cycle_utils.dart';
import 'cycle_calorie_settings_screen.dart';
import 'intercourse_data_model.dart';
import 'intercourse_editor_dialog.dart';
import 'period_history_screen.dart';
import '../Tasks/task_service.dart';
import '../Tasks/tasks_data_models.dart';
import 'friends_tab_screen.dart';
import 'cycle_calculation_utils.dart';
import '../shared/snackbar_utils.dart';
import '../Services/firebase_backup_service.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> with TickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  // GlobalKey for FriendsTabScreen to access its methods
  final GlobalKey<FriendsTabScreenState> _friendsTabKey = GlobalKey<FriendsTabScreenState>();

  // State variables
  DateTime? _selectedDate;
  DateTime _calendarDate = DateTime.now();
  final PageController _pageController = PageController(initialPage: 1000);
  DateTime? _lastPeriodStart;
  DateTime? _lastPeriodEnd;
  int _averageCycleLength = 31;
  List<Map<String, DateTime>> _periodRanges = [];
  List<IntercourseRecord> _intercourseRecords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
    });
    _loadCycleData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // DATA PERSISTENCE METHODS
  Future<void> _loadCycleData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load last period dates
    final lastStartStr = prefs.getString('last_period_start');
    final lastEndStr = prefs.getString('last_period_end');

    if (lastStartStr != null) _lastPeriodStart = DateTime.parse(lastStartStr);
    if (lastEndStr != null) _lastPeriodEnd = DateTime.parse(lastEndStr);

    // Load average cycle length
    _averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;

    // Load period ranges
    final rangesStr = prefs.getStringList('period_ranges') ?? [];
    _periodRanges = rangesStr.map((range) {
      final parts = range.split('|');
      return {
        'start': DateTime.parse(parts[0]),
        'end': DateTime.parse(parts[1]),
      };
    }).toList();

    // Auto-end periods that exceed 7 days
    await _autoEndLongPeriods();

    // Recalculate average to ensure it's up to date with actual periods
    _calculateAverageCycleLength();

    await _loadIntercourseRecords();
    if (mounted) setState(() {});
  }

  Future<void> _loadIntercourseRecords() async {
    _intercourseRecords = await IntercourseService.loadIntercourseRecords();
  }

  Future<void> _autoEndLongPeriods() async {
    if (_lastPeriodStart == null || _lastPeriodEnd != null) return;
    
    final now = DateTime.now();
    final daysSinceStart = now.difference(_lastPeriodStart!).inDays;

    // Auto-end period after 5 days
    if (daysSinceStart >= 5) {
      final autoEndDate = _lastPeriodStart!.add(const Duration(days: 4)); // Day 5 = 4 days after start
      
      setState(() {
        _lastPeriodEnd = autoEndDate;
        
        // Add to period ranges
        _periodRanges.removeWhere((range) => _isSameDay(range['start']!, _lastPeriodStart!));
        _periodRanges.add({
          'start': _lastPeriodStart!,
          'end': autoEndDate,
        });
        _periodRanges.sort((a, b) => a['start']!.compareTo(b['start']!));
      });
      
      await _saveCycleData();
      await _calculateAverageCycleLength();
    }
  }

  Future<void> _saveCycleData() async {
    final prefs = await SharedPreferences.getInstance();

    // Save last period dates
    if (_lastPeriodStart != null) {
      await prefs.setString('last_period_start', _lastPeriodStart!.toIso8601String());
    } else {
      await prefs.remove('last_period_start');
    }

    if (_lastPeriodEnd != null) {
      await prefs.setString('last_period_end', _lastPeriodEnd!.toIso8601String());
    } else {
      await prefs.remove('last_period_end');
    }

    await prefs.setInt('average_cycle_length', _averageCycleLength);

    // Save period ranges
    final rangesStr = _periodRanges.map((range) {
      return '${range['start']!.toIso8601String()}|${range['end']!.toIso8601String()}';
    }).toList();
    await prefs.setStringList('period_ranges', rangesStr);

    // Backup to Firebase
    FirebaseBackupService.triggerBackup();

    // Schedule cycle notifications whenever data is updated
    await CycleCalculationUtils.rescheduleCycleNotifications();
  }

  Future<void> _recalculateMenstrualPhaseTasks() async {
    if (_lastPeriodStart == null) {
      SnackBarUtils.showInfo(context, 'No period data available to recalculate tasks');
      return;
    }

    final taskService = TaskService();
    final allTasks = await taskService.loadTasks();

    // Find tasks with menstrual cycle recurrence that have specific days
    final menstrualTasks = allTasks.where((task) {
      if (task.recurrence == null) return false;

      // Check if it's a menstrual cycle task
      final menstrualTypes = [
        RecurrenceType.menstrualPhase,
        RecurrenceType.follicularPhase,
        RecurrenceType.ovulationPhase,
        RecurrenceType.earlyLutealPhase,
        RecurrenceType.lateLutealPhase
      ];

      return task.recurrence!.types.any((type) => menstrualTypes.contains(type)) &&
             task.recurrence!.phaseDay != null;
    }).toList();

    if (menstrualTasks.isEmpty) return;

    bool tasksUpdated = false;

    for (final task in menstrualTasks) {
      final recurrence = task.recurrence!;
      DateTime? newScheduledDate;

      // Calculate phase start dates for this cycle
      final phaseStartDates = _calculatePhaseStartDates(_lastPeriodStart!, _averageCycleLength);

      for (final recurrenceType in recurrence.types) {
        DateTime? phaseStart;

        switch (recurrenceType) {
          case RecurrenceType.menstrualPhase:
            phaseStart = phaseStartDates['menstrual'];
            break;
          case RecurrenceType.follicularPhase:
            phaseStart = phaseStartDates['follicular'];
            break;
          case RecurrenceType.ovulationPhase:
            phaseStart = phaseStartDates['ovulation'];
            break;
          case RecurrenceType.earlyLutealPhase:
            phaseStart = phaseStartDates['earlyLuteal'];
            break;
          case RecurrenceType.lateLutealPhase:
            phaseStart = phaseStartDates['lateLuteal'];
            break;
          default:
            continue;
        }

        if (phaseStart != null && recurrence.phaseDay != null) {
          final dayInPhase = recurrence.phaseDay!;
          newScheduledDate = phaseStart.add(Duration(days: dayInPhase - 1)); // Day 1 = 0 days offset
          break; // Use first matching phase
        }
      }

      // Update task if we calculated a new date
      if (newScheduledDate != null) {
        final updatedTask = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          categoryIds: task.categoryIds,
          deadline: task.deadline,
          scheduledDate: newScheduledDate,
          reminderTime: task.reminderTime,
          isImportant: task.isImportant,
          recurrence: task.recurrence,
          isCompleted: task.isCompleted,
          completedAt: task.completedAt,
          createdAt: task.createdAt,
        );

        // Update in the list
        final taskIndex = allTasks.indexWhere((t) => t.id == task.id);
        if (taskIndex != -1) {
          allTasks[taskIndex] = updatedTask;
          tasksUpdated = true;
        }
      }
    }

    // Save updated tasks if any were changed
    if (tasksUpdated) {
      await taskService.saveTasks(allTasks);
      if (!mounted) return;
      final taskCount = menstrualTasks.length;
      SnackBarUtils.showSuccess(context, '✅ Recalculated $taskCount menstrual phase task${taskCount == 1 ? '' : 's'}');
    } else {
      if (!mounted) return;
      SnackBarUtils.showInfo(context, 'No menstrual phase tasks with specific days found');
    }
  }

  Map<String, DateTime> _calculatePhaseStartDates(DateTime periodStart, int averageCycleLength) {
    // Based on the phase logic from MenstrualCycleUtils.getPhaseFromCycleDays
    return {
      'menstrual': periodStart, // Day 1-5
      'follicular': periodStart.add(const Duration(days: 5)), // Day 6-11
      'ovulation': periodStart.add(const Duration(days: 11)), // Day 12-16
      'earlyLuteal': periodStart.add(const Duration(days: 16)), // Day 17 to (cycleLength - 7)
      'lateLuteal': periodStart.add(Duration(days: averageCycleLength - 7)), // Last 7 days of cycle
    };
  }

  Future<void> _startPeriodOnDate(DateTime date) async {
    // Auto-end current period if it's been more than 5 days
    if (_isCurrentlyOnPeriod() && _lastPeriodStart != null) {
      final daysSinceStart = DateTime.now().difference(_lastPeriodStart!).inDays;
      if (daysSinceStart >= 5) {
        // Auto-end on day 5
        final autoEndDate = _lastPeriodStart!.add(const Duration(days: 4)); // Day 5 = start + 4 days
        await _endPeriodOnDate(autoEndDate);
      } else {
        // End it on the day before the new period starts
        final endDate = date.subtract(const Duration(days: 1));
        await _endPeriodOnDate(endDate);
      }
    }

    setState(() {
      _lastPeriodStart = date;
      _lastPeriodEnd = null;
    });

    await _saveCycleData();

    // ALWAYS recalculate average when starting a new period
    await _calculateAverageCycleLength();

    // Recalculate menstrual phase tasks with specific days
    await _recalculateMenstrualPhaseTasks();

    if (!mounted) return;
    final dateStr = _isSameDay(date, DateTime.now()) ? 'today' : 'on ${DateFormatUtils.formatShort(date)}';
    SnackBarUtils.showSuccess(context, 'Period started $dateStr! End it manually when finished.');
  }

  Future<void> _endPeriodOnDate(DateTime date) async {
    if (_lastPeriodStart == null) return;

    setState(() {
      _lastPeriodEnd = date;

      // Add complete period to history
      _periodRanges.removeWhere((range) => _isSameDay(range['start']!, _lastPeriodStart!));
      _periodRanges.add({
        'start': _lastPeriodStart!,
        'end': date,
      });
      _periodRanges.sort((a, b) => a['start']!.compareTo(b['start']!));

      // Clear active period since it's now completed
      _lastPeriodStart = null;
      _lastPeriodEnd = null;
    });

    await _saveCycleData();
    await _calculateAverageCycleLength();
    if (!mounted) return;
    final dateStr = _isSameDay(date, DateTime.now()) ? 'today' : 'on ${DateFormatUtils.formatShort(date)}';
    SnackBarUtils.showSuccess(context, 'Period ended $dateStr successfully.');
  }

  Future<void> _calculateAverageCycleLength() async {
    // Reload fresh data from SharedPreferences to match what period_history_screen sees
    final prefs = await SharedPreferences.getInstance();

    // Load period ranges fresh from storage
    final rangesStr = prefs.getStringList('period_ranges') ?? [];
    final freshRanges = rangesStr.map((range) {
      final parts = range.split('|');
      return {
        'start': DateTime.parse(parts[0]),
        'end': DateTime.parse(parts[1]),
      };
    }).toList();

    // Load active period fresh from storage
    final lastStartStr = prefs.getString('last_period_start');
    final freshActivePeriod = lastStartStr != null ? DateTime.parse(lastStartStr) : null;

    // Sort oldest first
    freshRanges.sort((a, b) => a['start']!.compareTo(b['start']!));

    final calculatedAverage = await CycleCalculationUtils.calculateAverageCycleLength(
      periodRanges: freshRanges,
      currentActivePeriodStart: freshActivePeriod,
      defaultValue: 30,
    );

    setState(() {
      _averageCycleLength = calculatedAverage;
    });
    await prefs.setInt('average_cycle_length', _averageCycleLength);
  }


  // HELPER METHODS
  bool _isCurrentlyOnPeriod() {
    return MenstrualCycleUtils.isCurrentlyOnPeriod(_lastPeriodStart, _lastPeriodEnd);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isDateInPeriod(DateTime date) {
    // First check historical periods (completed periods)
    for (final range in _periodRanges) {
      if (date.isAfter(range['start']!.subtract(const Duration(days: 1))) &&
          date.isBefore(range['end']!.add(const Duration(days: 1)))) {
        return true;
      }
    }

    // Then check current active period (show 5 days including future days for THIS period only)
    if (_lastPeriodStart != null && _lastPeriodEnd == null) {
      final daysSinceStart = date.difference(_lastPeriodStart!).inDays;
      // Show up to 5 days from start date, including future days for current period
      return daysSinceStart >= 0 && daysSinceStart < 5;
    }

    return false;
  }

  bool _isOvulationDay(DateTime date) {
    // Check completed periods in _periodRanges
    for (final range in _periodRanges) {
      final daysSinceStart = date.difference(range['start']!).inDays;
      if (daysSinceStart >= 10 && daysSinceStart <= 14 && daysSinceStart != 13) {
        return true;
      }
    }
    
    // Check current period even if not ended
    if (_lastPeriodStart != null) {
      final daysSinceStart = date.difference(_lastPeriodStart!).inDays;
      if (daysSinceStart >= 10 && daysSinceStart <= 14 && daysSinceStart != 13) {
        return true;
      }
    }
    
    return false;
  }

  bool _isPeakOvulationDay(DateTime date) {
    // Check completed periods in _periodRanges
    for (final range in _periodRanges) {
      final daysSinceStart = date.difference(range['start']!).inDays;
      if (daysSinceStart == 13) return true;
    }
    
    // Check current period even if not ended
    if (_lastPeriodStart != null) {
      final daysSinceStart = date.difference(_lastPeriodStart!).inDays;
      if (daysSinceStart == 13) return true;
    }
    
    return false;
  }

  bool _isPredictedPeriodDate(DateTime date) {
    if (_lastPeriodStart == null) return false;

    final nextPeriodStart = _lastPeriodStart!.add(Duration(days: _averageCycleLength));
    final nextPeriodEnd = nextPeriodStart.add(const Duration(days: 4));

    return date.isAfter(nextPeriodStart.subtract(const Duration(days: 1))) &&
        date.isBefore(nextPeriodEnd.add(const Duration(days: 1)));
  }

  bool _hasIntercourseOnDate(DateTime date) {
    return _intercourseRecords.any((record) => _isSameDay(record.date, date));
  }

  double? _calculateAverageIntercourseInterval() {
    if (_intercourseRecords.length < 2) return null;
    
    // Sort records by date
    final sortedRecords = List<IntercourseRecord>.from(_intercourseRecords);
    sortedRecords.sort((a, b) => a.date.compareTo(b.date));
    
    final intervals = <int>[];
    for (int i = 1; i < sortedRecords.length; i++) {
      final interval = sortedRecords[i].date.difference(sortedRecords[i-1].date).inDays;
      if (interval > 0) {
        intervals.add(interval);
      }
    }
    
    if (intervals.isEmpty) return null;
    
    return intervals.reduce((a, b) => a + b) / intervals.length;
  }

  String _getCyclePhase() {
    return MenstrualCycleUtils.getCyclePhase(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength);
  }

  String _getCycleInfo() {
    return MenstrualCycleUtils.getCycleInfo(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength);
  }



  Color _getPhaseColor() {
    return MenstrualCycleUtils.getPhaseColor(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength).withValues(alpha: 0.8);
  }





  // INTERCOURSE MANAGEMENT
  Future<void> _addIntercourse(DateTime date) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => IntercourseEditorDialog(date: date),
    );

    if (result is IntercourseRecord) {
      await IntercourseService.addIntercourseRecord(result);
      await _loadIntercourseRecords();
      if (!mounted) return;
      setState(() {});
      SnackBarUtils.showCustom(context, 'Intercourse recorded for ${DateFormatUtils.formatShort(date)}', backgroundColor: AppColors.pink);
    }
  }

  Future<void> _editIntercourse(DateTime date) async {
    final existingRecords = await IntercourseService.getIntercourseForDate(date);
    if (existingRecords.isEmpty) return;

    final record = existingRecords.first; // For simplicity, edit the first one if multiple
    if (!mounted) return;
    
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => IntercourseEditorDialog(
        date: date,
        existingRecord: record,
      ),
    );

    if (result is IntercourseRecord) {
      await IntercourseService.updateIntercourseRecord(result);
      await _loadIntercourseRecords();
      if (!mounted) return;
      setState(() {});
      SnackBarUtils.showSuccess(context, 'Intercourse updated');
    } else if (result == 'delete') {
      await IntercourseService.deleteIntercourseRecord(record.id);
      await _loadIntercourseRecords();
    }
  }

  // UI BUILDING METHODS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle & Friends'),
        backgroundColor: AppColors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.pink.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _tabController.index == 0 ? AppColors.lightRed : AppColors.lime,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.white,
              unselectedLabelColor: _tabController.index == 0 ? AppColors.coral : AppColors.lightPurple,
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
                      Icon(Icons.favorite_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Cycle'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Friends'),
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
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.calendar_month_rounded),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PeriodHistoryScreen(),
                    ),
                  );
                  // Reload data when coming back from Period History
                  await _loadCycleData();
                  await _calculateAverageCycleLength();
                },
                tooltip: 'Period History',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.local_fire_department),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CycleCalorieSettingsScreen(),
                    ),
                  );
                },
                tooltip: 'Calorie Settings',
              ),
            ),
          ],
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Cycle tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentPhaseCard(),
                const SizedBox(height: 12),
                _buildCalendarCard(),
                const SizedBox(height: 12),
                _buildActionButtons(),
                if (_selectedDate != null) const SizedBox(height: 16),
                _buildStatisticsCard(),
              ],
            ),
          ),
          // Friends tab
          FriendsTabScreen(key: _friendsTabKey),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                _friendsTabKey.currentState?.addFriend();
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildCurrentPhaseCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusLarge,
          gradient: LinearGradient(
            colors: [
              _getPhaseColor().withValues(alpha: 0.3),
              _getPhaseColor().withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: _getPhaseColor(),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getCyclePhase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getPhaseColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCycleInfo(),
                        style: TextStyle(
                          fontSize: 14,
                          color: _getPhaseColor().withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildAnimatedPet(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPhaseBasedPet() {
    return MenstrualCycleUtils.getPhaseBasedPet(_lastPeriodStart, _lastPeriodEnd, _averageCycleLength);
  }

  Widget _buildAnimatedPet() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 20000), // Longer but still visible movement
        tween: Tween(begin: 0.0, end: 2 * pi),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 1.0 + (sin(value) * 0.1), // Gentle, subtle scaling
            child: Transform.rotate(
              angle: sin(value * 0.7) * 0.25 + cos(value * 1.4) * 0.1, // Playful wobbling with multiple rotations
              child: Transform.translate(
                offset: Offset(
                  sin(value * 1.8) * 2.5 + cos(value * 0.9) * 1.2, // More complex horizontal movement
                  cos(value * 1.1) * 1.8 + sin(value * 2.3) * 0.8, // Playful vertical bouncing
                ),
                child: Text(
                  _getPhaseBasedPet(),
                  style: const TextStyle(fontSize: 56), // Slightly bigger again
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final avgIntercourse = _calculateAverageIntercourseInterval();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined),
                const SizedBox(width: 12),
                const Text(
                  'Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Average Cycle',
                  '$_averageCycleLength days',
                  Icons.calendar_month_rounded,
                  AppColors.purple,
                ),
                _buildStatItem(
                  'Tracked Periods',
                  '${_periodRanges.length}',
                  Icons.timeline_rounded,
                  AppColors.successGreen,
                ),
              ],
            ),
            if (avgIntercourse != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatItem(
                    'Avg Days Between',
                    '${avgIntercourse.round()} days',
                    Icons.favorite,
                    AppColors.pink,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendar()
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Only show buttons when a day is selected in the calendar
    if (_selectedDate == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Only show Start Period and Intercourse buttons when NOT currently on period
        if (!_isCurrentlyOnPeriod()) ...[
          // Action buttons based on current state and selected date
          Row(
            children: [
              // Start Period button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startPeriodOnDate(_selectedDate!),
                  icon: const Icon(Icons.water_drop_rounded),
                  label: const Text('Start Period'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Add Intercourse button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addIntercourse(_selectedDate!),
                  icon: const Icon(Icons.favorite, size: 18),
                  label: const Text('Intercourse'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pink,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // Only show End Period button when currently on period
        if (_isCurrentlyOnPeriod())
          Row(
            children: [
              // End Period button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _endPeriodOnDate(_selectedDate!),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('End Period'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.normalCardBackground,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        _buildCalendarHeader(),
        const SizedBox(height: 16),
        _buildWeekdayHeaders(),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                final monthsFromBase = index - 1000;
                _calendarDate = DateTime(DateTime.now().year, DateTime.now().month + monthsFromBase, 1);
              });
              // Reload period data when changing calendar months to ensure historical periods are displayed
              _loadCycleData();
            },
            itemBuilder: (context, index) {
              final monthsFromBase = index - 1000;
              final monthDate = DateTime(DateTime.now().year, DateTime.now().month + monthsFromBase, 1);
              return _buildMonthGrid(monthDate);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      child: Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _calendarDate = DateTime.now();
              _pageController.animateToPage(
                1000,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          },
          child: Text(
            DateFormatUtils.formatMonthYear(_calendarDate),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map((day) => SizedBox(
        width: 40,
        child: Text(
          day,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.greyText,
          ),
        ),
      ))
          .toList(),
    );
  }

  Widget _buildMonthGrid(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;
    
    // Calculate the actual number of weeks needed
    final totalCells = (firstWeekday - 1) + daysInMonth;
    final weeksNeeded = (totalCells / 7).ceil();
    final actualItemCount = weeksNeeded * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: actualItemCount,
      itemBuilder: (context, index) {
        final dayNumber = index - firstWeekday + 2;

        if (dayNumber <= 0 || dayNumber > daysInMonth) {
          return const SizedBox();
        }

        final currentDate = DateTime(monthDate.year, monthDate.month, dayNumber);
        return _buildCalendarDay(currentDate, dayNumber);
      },
    );
  }

  Widget _buildCalendarDay(DateTime currentDate, int dayNumber) {
    final isSelected = _selectedDate != null && _isSameDay(_selectedDate!, currentDate);
    final isToday = _isSameDay(currentDate, DateTime.now());
    final isInPeriod = _isDateInPeriod(currentDate);
    final isOvulation = _isOvulationDay(currentDate);
    final isPeakOvulation = _isPeakOvulationDay(currentDate);
    final isPredicted = _isPredictedPeriodDate(currentDate);
    final hasIntercourse = _hasIntercourseOnDate(currentDate);

    Color? backgroundColor;
    Color? borderColor;

    if (isSelected) {
      backgroundColor = AppColors.purple;
    } else if (isInPeriod) {
      backgroundColor = AppColors.lightRed; // Lighter red for registered periods
    } else if (isPeakOvulation) {
      backgroundColor = AppColors.orange; // Bright orange for peak ovulation
    } else if (isOvulation) {
      backgroundColor = AppColors.orange.withValues(alpha: 0.7); // Light orange for ovulation window
    } else if (isPredicted) {
      backgroundColor = AppColors.lightRed.withValues(alpha: 0.7); // Faded red for predicted periods
    }
    
    // Always show today border if it's today, regardless of other states
    if (isToday) {
      borderColor = AppColors.white60; // More prominent color for today
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = currentDate;
        });
      },
      onLongPress: hasIntercourse ? () => _editIntercourse(currentDate) : null,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 2)
              : null,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                dayNumber.toString(),
                style: TextStyle(
                  color: backgroundColor != null ? AppColors.white : null,
                  fontWeight: isToday ? FontWeight.bold : null,
                ),
              ),
              if (hasIntercourse)
                Positioned(
                  top: 16,
                  bottom: 1,
                  left: 0,
                  right: 4,
                  child: Icon(
                    Icons.favorite,
                    size: 8,
                    color: backgroundColor != null ? AppColors.white : AppColors.pink,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.greyText),
        ),
      ],
    );
  }
}