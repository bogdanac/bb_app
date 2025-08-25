import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import '../Notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({Key? key}) : super(key: key);

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  // State variables
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarDate = DateTime.now();
  DateTime? _lastPeriodStart;
  DateTime? _lastPeriodEnd;
  int _averageCycleLength = 31;
  List<Map<String, DateTime>> _periodRanges = [];

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

    if (mounted) setState(() {});
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

  // PERIOD MANAGEMENT METHODS
  Future<void> _startPeriod() async {
    // End current period if active
    if (_isCurrentlyOnPeriod()) {
      await _endPeriod();
    }

    setState(() {
      _lastPeriodStart = _selectedDate;
      _lastPeriodEnd = null;
    });

    await _saveCycleData();
    _calculateAverageCycleLength();
    _showSnackBar('Period started! End it manually when finished.', AppColors.successGreen); // Keep green for success
  }

  Future<void> _endPeriod() async {
    if (_lastPeriodStart == null) return;

    setState(() {
      _lastPeriodEnd = _selectedDate;

      // Add complete period to history
      _periodRanges.removeWhere((range) => _isSameDay(range['start']!, _lastPeriodStart!));
      _periodRanges.add({
        'start': _lastPeriodStart!,
        'end': _selectedDate,
      });
      _periodRanges.sort((a, b) => a['start']!.compareTo(b['start']!));
    });

    await _saveCycleData();
    _calculateAverageCycleLength();
    _showSnackBar('Period ended successfully.', AppColors.successGreen); // Keep green for success
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
    return _lastPeriodStart != null && _lastPeriodEnd == null;
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

  String _getCyclePhase() {
    if (_lastPeriodStart == null) return "No data available";

    final now = DateTime.now();
    final daysSinceStart = now.difference(_lastPeriodStart!).inDays;

    if (_isCurrentlyOnPeriod()) {
      return "Menstruation (Day ${daysSinceStart + 1})";
    }

    if (_lastPeriodEnd != null) {
      final daysSinceEnd = now.difference(_lastPeriodEnd!).inDays;
      final totalCycleDays = _lastPeriodEnd!.difference(_lastPeriodStart!).inDays + daysSinceEnd + 1;

      return _getPhaseFromCycleDays(totalCycleDays);
    } else {
      return _getPhaseFromCycleDays(daysSinceStart);
    }
  }

  String _getCycleInfo() {
    if (_lastPeriodStart == null) return "Track your first period to begin";

    final now = DateTime.now();
    final nextPeriodStart = _lastPeriodStart!.add(Duration(days: _averageCycleLength));
    final daysUntilPeriod = nextPeriodStart.difference(now).inDays;

    // Period expected today or overdue
    if (daysUntilPeriod <= 0) {
      if (daysUntilPeriod == 0) {
        return "Period expected today! 🩸";
      } else {
        final daysOverdue = -daysUntilPeriod;
        return "Period is $daysOverdue days overdue";
      }
    }

    // Pre-period warnings (1-6 days) with personalized messages
    if (daysUntilPeriod <= 6) {
      final messages = {
        1: "Period expected tomorrow! Take care of yourself 💝",
        2: "Period in 2 days. Rest and stay comfortable 🛋️",
        3: "Period in 3 days. Listen to your body 🤗",
        4: "Period in 4 days. Symptoms may begin 😌",
        5: "Period in 5 days. Stay hydrated 💧",
        6: "Period in 6 days. Self-care time 🌸"
      };
      return messages[daysUntilPeriod] ?? "$daysUntilPeriod days until period";
    }

    // Current period info
    if (_isCurrentlyOnPeriod()) {
      final currentDay = now.difference(_lastPeriodStart!).inDays + 1;
      return "Day $currentDay of period";
    }

    // Cycle day info with ovulation focus
    final daysSinceStart = now.difference(_lastPeriodStart!).inDays + 1;

    if (daysSinceStart <= 11) {
      return "Back in the game";
    } else if (daysSinceStart <= 15) {
      final ovulationDay = 14;
      final daysToOvulation = ovulationDay - daysSinceStart;

      if (daysToOvulation == 0) {
        return "Ovulation day! 🥚";
      } else if (daysToOvulation == 1) {
        return "Ovulation tomorrow";
      } else if (daysToOvulation == -1) {
        return "Ovulation was yesterday";
      } else {
        return "Ovulation window";
      }
    } else {
      if (daysUntilPeriod <= 3) {
        return "$daysUntilPeriod days until next period";
      }
      return "Just keep swimming";
    }
  }

  String _getPhaseFromCycleDays(int cycleDays) {
    if (cycleDays <= 13) {
      return "Follicular Phase";
    } else if (cycleDays <= 16) {
      return "Ovulation";
    } else {
      final lutealDay = cycleDays - 16;
      final expectedLutealLength = _averageCycleLength - 16;

      if (lutealDay <= expectedLutealLength / 3) {
        return "Early Luteal Phase";
      } else if (lutealDay <= (expectedLutealLength * 2) / 3) {
        return "Middle Luteal Phase";
      } else {
        return "Late Luteal Phase";
      }
    }
  }

  String _getExtraDetails() {
    if (_lastPeriodStart == null) return "";

    final nextPeriodStart = _lastPeriodStart!.add(Duration(days: _averageCycleLength));
    final daysUntilPeriod = nextPeriodStart.difference(DateTime.now()).inDays;

    if (daysUntilPeriod <= 6 && daysUntilPeriod >= 0) {
      final messages = {
        0: "Period expected today! 🩸",
        1: "Period expected tomorrow! Take care of yourself 💝",
        2: "Period in 2 days. Rest and stay comfortable 🛋️",
        3: "Period in 3 days. Listen to your body 🤗",
        4: "Period in 4 days. Symptoms may begin, be gentle with yourself 😌",
        5: "Period in 5 days. Take it easy 🌸",
        6: "Period in 6 days. Stay hydrated and rest well 💧",
      };
      return messages[daysUntilPeriod] ?? "";
    }

    return "";
  }

  Color _getPhaseColor() {
    final phase = _getCyclePhase();
    if (phase.startsWith("Menstruation")) return Color(0xFFF43148).withOpacity(0.8);
    if (phase == "Follicular Phase") return AppColors.successGreen; // Green for growth phase
    if (phase == "Ovulation") return Color(0xFFF98834).withOpacity(0.8);
    if (phase.contains("Early Luteal")) return Color(0xFFBD3AA6).withOpacity(0.6);
    if (phase.contains("Middle Luteal")) return Color(0xFFBD3AA6).withOpacity(0.8);
    if (phase.contains("Late Luteal")) return Color(0xFFBD3AA6);
    if (phase.contains("Luteal")) return Color(0xFFBD3AA6).withOpacity(0.8);
    return Colors.grey;
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
                style: TextStyle(color: Colors.grey),
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
          backgroundColor: Colors.red.shade300,
          child: Text(
            duration.toString(),
            style: const TextStyle(
              color: Colors.white,
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
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
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
      Navigator.pop(context);
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
                  color: Colors.grey.shade600,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      Navigator.pop(context);
    }
  }

  // UI BUILDING METHODS
  @override
  Widget build(BuildContext context) {
    final extraDetails = _getExtraDetails();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Tracking'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showPeriodHistory,
            tooltip: 'Period History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentPhaseCard(extraDetails),
            const SizedBox(height: 16),
            _buildCalendarCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 16),
            _buildStatisticsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPhaseCard(String extraDetails) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              _getPhaseColor().withOpacity(0.3),
              _getPhaseColor().withOpacity(0.1),
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
                          color: _getPhaseColor().withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildAnimatedPet(),
              ],
            ),
            if (extraDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        extraDetails,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPhaseBasedPet() {
    final phase = _getCyclePhase();
    
    if (phase.startsWith("Menstruation")) return '🐾'; // Tired/resting pet
    if (phase == "Follicular Phase") return '😸'; // Growing/playful pet  
    if (phase == "Ovulation") return '🦋'; // Beautiful/fertile butterfly
    if (phase.contains("Early Luteal")) return '🐰'; // Energetic bunny
    if (phase.contains("Middle Luteal")) return '🦊'; // Wise fox
    if (phase.contains("Late Luteal")) return '🐻'; // Sleepy bear
    if (phase.contains("Luteal")) return '🐰'; // Default bunny
    
    return '😸'; // Default cat
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Average Cycle',
                  '$_averageCycleLength days',
                  Icons.calendar_month_rounded,
                  AppColors.purple, // Purple instead of blue
                ),
                _buildStatItem(
                  'Tracked Periods',
                  '${_periodRanges.length}',
                  Icons.timeline_rounded,
                  AppColors.successGreen, // Green for success
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
    if (_isCurrentlyOnPeriod()) {
      final currentDay = DateTime.now().difference(_lastPeriodStart!).inDays + 1;
      return Column(
        children: [
          if (currentDay < 5)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Day $currentDay of 5 - Period will auto-end after day 5',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _endPeriod,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('End Period'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.35, // Even narrower - about 1/3 screen width
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _startPeriod,
            icon: const Icon(Icons.water_drop_rounded),
            label: const Text('Start Period', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_calendarDate.year, _calendarDate.month, 1);
    final lastDayOfMonth = DateTime(_calendarDate.year, _calendarDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    return Column(
      children: [
        _buildCalendarHeader(),
        const SizedBox(height: 24),
        _buildWeekdayHeaders(),
        const SizedBox(height: 8),
        _buildCalendarGrid(firstWeekday, daysInMonth),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _calendarDate = DateTime(_calendarDate.year, _calendarDate.month - 1, 1);
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white70,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.chevron_left, size: 24),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _calendarDate = DateTime.now();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                DateFormat('MMMM yy').format(_calendarDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _calendarDate = DateTime(_calendarDate.year, _calendarDate.month + 1, 1);
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white70,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.chevron_right, size: 24),
          ),
        ],
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
            color: Colors.grey,
          ),
        ),
      ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(int firstWeekday, int daysInMonth) {
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

        final currentDate = DateTime(_calendarDate.year, _calendarDate.month, dayNumber);
        return _buildCalendarDay(currentDate, dayNumber);
      },
    );
  }

  Widget _buildCalendarDay(DateTime currentDate, int dayNumber) {
    final isSelected = _isSameDay(_selectedDate, currentDate);
    final isToday = _isSameDay(currentDate, DateTime.now());
    final isInPeriod = _isDateInPeriod(currentDate);
    final isOvulation = _isOvulationDay(currentDate);
    final isPeakOvulation = _isPeakOvulationDay(currentDate);
    final isPredicted = _isPredictedPeriodDate(currentDate);

    Color? backgroundColor;
    Color? borderColor;

    if (isSelected) {
      backgroundColor = Colors.blue.shade500;
    } else if (isInPeriod) {
      backgroundColor = Colors.red.shade400;
    } else if (isPeakOvulation) {
      backgroundColor = Colors.orange.shade600;
    } else if (isOvulation) {
      backgroundColor = Colors.orange.shade300;
    } else if (isPredicted) {
      backgroundColor = Colors.red.shade200;
    } else if (isToday) {
      borderColor = Colors.blue.shade300;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = currentDate;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 2)
              : null,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            dayNumber.toString(),
            style: TextStyle(
              color: backgroundColor != null ? Colors.white : null,
              fontWeight: isToday ? FontWeight.bold : null,
            ),
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

  // Cancel cycle notifications (can be called when needed)
  Future<void> _cancelCycleNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.flutterLocalNotificationsPlugin.cancel(1001);
      await notificationService.flutterLocalNotificationsPlugin.cancel(1002);
      debugPrint('Cycle notifications cancelled');
    } catch (e) {
      debugPrint('Error cancelling cycle notifications: $e');
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
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}