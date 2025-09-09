import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import '../Notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'menstrual_cycle_utils.dart';
import 'cycle_calorie_settings_screen.dart';
import 'intercourse_data_model.dart';
import 'intercourse_editor_dialog.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
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
    _loadCycleData();
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

    await _loadIntercourseRecords();
    if (mounted) setState(() {});
  }

  Future<void> _loadIntercourseRecords() async {
    _intercourseRecords = await IntercourseService.loadIntercourseRecords();
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
    
    // Schedule cycle notifications whenever data is updated
    await _scheduleCycleNotifications();
  }

  Future<void> _startPeriodOnDate(DateTime date) async {
    // End current period if active
    if (_isCurrentlyOnPeriod()) {
      await _endPeriodOnDate(date);
    }

    setState(() {
      _lastPeriodStart = date;
      _lastPeriodEnd = null;
    });

    await _saveCycleData();
    _calculateAverageCycleLength();
    final dateStr = _isSameDay(date, DateTime.now()) ? 'today' : 'on ${DateFormat('MMM d').format(date)}';
    _showSnackBar('Period started $dateStr! End it manually when finished.', AppColors.successGreen);
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
    });

    await _saveCycleData();
    _calculateAverageCycleLength();
    final dateStr = _isSameDay(date, DateTime.now()) ? 'today' : 'on ${DateFormat('MMM d').format(date)}';
    _showSnackBar('Period ended $dateStr successfully.', AppColors.successGreen);
  }

  void _calculateAverageCycleLength() {
    if (_periodRanges.length < 2) return;

    final cycles = <int>[];
    for (int i = 1; i < _periodRanges.length; i++) {
      final cycleLength = _periodRanges[i]['start']!.difference(_periodRanges[i-1]['start']!).inDays;
      if (cycleLength > 15 && cycleLength < 45) {
        cycles.add(cycleLength);
      }
    }

    if (cycles.isNotEmpty) {
      final calculatedAverage = (cycles.reduce((a, b) => a + b) / cycles.length).round();
      setState(() {
        _averageCycleLength = calculatedAverage > 0 ? calculatedAverage : 31;
      });
      _saveCycleData();
    }
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
    // Check current active period
    if (_isCurrentlyOnPeriod()) {
      final daysSinceStart = date.difference(_lastPeriodStart!).inDays;
      return daysSinceStart >= 0 && daysSinceStart < 5 && !date.isAfter(DateTime.now());
    }

    // Check historical periods
    for (final range in _periodRanges) {
      if (date.isAfter(range['start']!.subtract(const Duration(days: 1))) &&
          date.isBefore(range['end']!.add(const Duration(days: 1)))) {
        return true;
      }
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // PERIOD HISTORY MANAGEMENT
  void _showPeriodHistory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPeriodHistorySheet(),
    );
  }

  Widget _buildPeriodHistorySheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Period History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_periodRanges.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No completed periods recorded yet',
                style: TextStyle(color: AppColors.grey),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _periodRanges.length,
                itemBuilder: (context, index) => _buildPeriodHistoryItem(index),
              ),
            ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodHistoryItem(int index) {
    final range = _periodRanges[index];
    final start = range['start']!;
    final end = range['end']!;
    final duration = end.difference(start).inDays + 1;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.error,
          child: Text(
            duration.toString(),
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('$duration days'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editPeriod(index);
            } else if (value == 'delete') {
              _deletePeriod(index);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editPeriod(int index) async {
    final range = _periodRanges[index];
    DateTime? newStart = range['start'];
    DateTime? newEnd = range['end'];

    final result = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (context) => _buildEditPeriodDialog(newStart!, newEnd!),
    );

    if (result != null) {
      setState(() {
        _periodRanges[index] = {
          'start': result['start']!,
          'end': result['end']!,
        };

        // Update last period if this was the most recent
        if (_lastPeriodStart != null && _isSameDay(_lastPeriodStart!, range['start']!)) {
          _lastPeriodStart = result['start']!;
          _lastPeriodEnd = result['end']!;
        }
      });

      await _saveCycleData();
      _calculateAverageCycleLength();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildEditPeriodDialog(DateTime initialStart, DateTime initialEnd) {
    DateTime newStart = initialStart;
    DateTime newEnd = initialEnd;

    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('MMM d, y').format(newStart)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: newStart,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setDialogState(() => newStart = date);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop),
              title: const Text('End Date'),
              subtitle: Text(DateFormat('MMM d, y').format(newEnd)),
              onTap: () async {
                final maxEnd = newStart.add(const Duration(days: 4));
                final date = await showDatePicker(
                  context: context,
                  initialDate: newEnd,
                  firstDate: newStart,
                  lastDate: maxEnd.isAfter(DateTime.now()) ? DateTime.now() : maxEnd,
                );
                if (date != null) {
                  setDialogState(() => newEnd = date);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Period duration limited to 5 days maximum',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grey600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'start': newStart,
                'end': newEnd,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deletePeriod(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Period'),
        content: const Text('Are you sure you want to delete this period record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final range = _periodRanges[index];

      setState(() {
        _periodRanges.removeAt(index);

        // Update last period if this was the most recent
        if (_lastPeriodStart != null && _isSameDay(_lastPeriodStart!, range['start']!)) {
          if (_periodRanges.isNotEmpty) {
            final mostRecent = _periodRanges.last;
            _lastPeriodStart = mostRecent['start']!;
            _lastPeriodEnd = mostRecent['end']!;
          } else {
            _lastPeriodStart = null;
            _lastPeriodEnd = null;
          }
        }
      });

      await _saveCycleData();
      _calculateAverageCycleLength();
      if (mounted) {
        Navigator.pop(context);
      }
    }
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
      setState(() {});
      _showSnackBar('Intercourse recorded for ${DateFormat('MMM d').format(date)}', AppColors.pink);
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
      setState(() {});
      _showSnackBar('Intercourse updated', AppColors.successGreen);
    } else if (result == 'delete') {
      await IntercourseService.deleteIntercourseRecord(record.id);
      await _loadIntercourseRecords();
      setState(() {});
      _showSnackBar('Intercourse deleted', AppColors.grey600);
    }
  }

  // UI BUILDING METHODS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Tracking'),
        backgroundColor: AppColors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: _showPeriodHistory,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentPhaseCard(),
            const SizedBox(height: 16),
            _buildCalendarCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            if (_selectedDate != null) const SizedBox(height: 16),
            _buildStatisticsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPhaseCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.only(right: 16),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 2000),
        tween: Tween(begin: 0.0, end: 2 * pi),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 1.0 + (sin(value) * 0.2),
            child: Transform.rotate(
              angle: sin(value * 0.5) * 0.15,
              child: Text(
                _getPhaseBasedPet(),
                style: const TextStyle(fontSize: 50),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: const Text(
          'Statistics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.analytics_outlined),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
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
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // End Period button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isCurrentlyOnPeriod() ? () => _endPeriodOnDate(_selectedDate!) : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('End Period'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCurrentlyOnPeriod() ? AppColors.grey600 : AppColors.grey300,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
            DateFormat('MMMM yy').format(_calendarDate),
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
            color: AppColors.grey,
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
      backgroundColor = AppColors.orange.withValues(alpha: 0.6); // Light orange for ovulation window
    } else if (isPredicted) {
      backgroundColor = AppColors.lightRed;
    } else if (isToday) {
      borderColor = AppColors.purple;
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

  Future<void> _scheduleCycleNotifications() async {
    if (_lastPeriodStart == null) return;

    final now = DateTime.now();
    final notificationService = NotificationService();

    try {
      // Cancel existing cycle notifications first to avoid duplicates
      await notificationService.flutterLocalNotificationsPlugin.cancel(1001);
      await notificationService.flutterLocalNotificationsPlugin.cancel(1002);
      // Schedule ovulation notification (day before ovulation = day 13)
      final ovulationDate = _lastPeriodStart!.add(const Duration(days: 13));
      final ovulationNotificationDate = ovulationDate.subtract(const Duration(days: 1));
      
      if (ovulationNotificationDate.isAfter(now)) {
        await notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
          1001, // Unique ID for ovulation notification
          'Ovulation Tomorrow! 🥚',
          'Your ovulation window is starting tomorrow. Time to pay attention to your body!',
          tz.TZDateTime.from(ovulationNotificationDate, tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'cycle_reminders',
              'Cycle Reminders',
              channelDescription: 'Important menstrual cycle reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      // Schedule menstruation notification (day before expected period)
      final nextPeriodDate = _lastPeriodStart!.add(Duration(days: _averageCycleLength));
      final menstruationNotificationDate = nextPeriodDate.subtract(const Duration(days: 1));
      
      if (menstruationNotificationDate.isAfter(now)) {
        await notificationService.flutterLocalNotificationsPlugin.zonedSchedule(
          1002, // Unique ID for menstruation notification
          'Period Expected Tomorrow 🩸',
          'Your period is expected to start tomorrow. Make sure you\'re prepared!',
          tz.TZDateTime.from(menstruationNotificationDate, tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'cycle_reminders',
              'Cycle Reminders',
              channelDescription: 'Important menstrual cycle reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
      debugPrint('Cycle notifications scheduled successfully');
    } catch (e) {
      debugPrint('Error scheduling cycle notifications: $e');
    }
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
          style: const TextStyle(fontSize: 14, color: AppColors.grey),
        ),
      ],
    );
  }
}