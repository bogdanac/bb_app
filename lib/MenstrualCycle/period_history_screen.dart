import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../shared/date_picker_utils.dart';

class PeriodHistoryScreen extends StatefulWidget {
  const PeriodHistoryScreen({super.key});

  @override
  State<PeriodHistoryScreen> createState() => _PeriodHistoryScreenState();
}

class _PeriodHistoryScreenState extends State<PeriodHistoryScreen> {
  List<Map<String, dynamic>> _periodHistory = [];
  int _averageCycleLength = 31;

  @override
  void initState() {
    super.initState();
    _loadPeriodHistory();
  }

  Future<void> _loadPeriodHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Load period ranges
    final rangesStr = prefs.getStringList('period_ranges') ?? [];
    _periodHistory = rangesStr.map((range) {
      final parts = range.split('|');
      return {
        'start': DateTime.parse(parts[0]),
        'end': DateTime.parse(parts[1]),
      };
    }).toList();

    // Load average cycle length
    _averageCycleLength = prefs.getInt('average_cycle_length') ?? 31;

    // Sort by start date (most recent first)
    _periodHistory.sort((a, b) => b['start']!.compareTo(a['start']!));

    if (mounted) setState(() {});
  }

  Future<void> _savePeriodHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Save ALL period ranges
    final rangesStr = _periodHistory.map((range) {
      return '${range['start']!.toIso8601String()}|${range['end']!.toIso8601String()}';
    }).toList();
    await prefs.setStringList('period_ranges', rangesStr);

    // Recalculate average cycle length after saving
    _recalculateAverageCycleLength();
  }

  void _recalculateAverageCycleLength() async {
    final prefs = await SharedPreferences.getInstance();
    final cycles = <int>[];

    // Sort by start date (oldest first) for calculation
    final sortedHistory = List<Map<String, dynamic>>.from(_periodHistory);
    sortedHistory.sort((a, b) => a['start']!.compareTo(b['start']!));

    // Calculate cycles between consecutive periods
    for (int i = 1; i < sortedHistory.length; i++) {
      final cycleLength = sortedHistory[i]['start']!.difference(sortedHistory[i-1]['start']!).inDays;
      if (cycleLength > 15 && cycleLength < 45) {
        cycles.add(cycleLength);
      }
    }

    // Also include cycle from last period to current active period (if exists)
    final lastStartStr = prefs.getString('last_period_start');
    if (sortedHistory.isNotEmpty && lastStartStr != null) {
      final lastPeriodStart = DateTime.parse(lastStartStr);
      final lastCompletedPeriod = sortedHistory.last;

      final isDifferentPeriod = !(lastPeriodStart.year == lastCompletedPeriod['start']!.year &&
                                   lastPeriodStart.month == lastCompletedPeriod['start']!.month &&
                                   lastPeriodStart.day == lastCompletedPeriod['start']!.day);

      if (isDifferentPeriod) {
        final currentCycleLength = lastPeriodStart.difference(lastCompletedPeriod['start']!).inDays;
        if (currentCycleLength > 15 && currentCycleLength < 45) {
          cycles.add(currentCycleLength);
        }
      }
    }

    if (cycles.isNotEmpty) {
      final calculatedAverage = (cycles.reduce((a, b) => a + b) / cycles.length).round();
      _averageCycleLength = calculatedAverage > 0 ? calculatedAverage : 31;

      await prefs.setInt('average_cycle_length', _averageCycleLength);

      if (mounted) setState(() {});
    }
  }

  void _editPeriod(int index) {
    final period = _periodHistory[index];
    final startDate = period['start']!;
    final endDate = period['end']!;

    _showPeriodEditDialog(startDate, endDate, (newStart, newEnd) {
      setState(() {
        _periodHistory[index] = {
          'start': newStart,
          'end': newEnd,
        };
        // Re-sort after editing
        _periodHistory.sort((a, b) => b['start']!.compareTo(a['start']!));
      });
      _savePeriodHistory();
    });
  }

  Future<void> _showPeriodEditDialog(
    DateTime initialStart,
    DateTime initialEnd,
    Function(DateTime, DateTime) onSave,
  ) async {
    DateTime? selectedStart = initialStart;
    DateTime? selectedEnd = initialEnd;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: AppColors.pink, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Edit Period',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start date
              Card(
                color: AppColors.dialogCardBackground,
                child: ListTile(
                  leading: Icon(Icons.play_arrow_rounded, color: AppColors.pink),
                  title: const Text('Start Date', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(selectedStart!),
                    style: const TextStyle(color: AppColors.white70),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: AppColors.pink),
                  onTap: () async {
                    final date = await DatePickerUtils.showStyledDatePicker(
                      context: context,
                      initialDate: selectedStart!,
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() => selectedStart = date);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),

              // End date
              Card(
                color: AppColors.dialogCardBackground,
                child: ListTile(
                  leading: Icon(Icons.stop_rounded, color: AppColors.lightPink),
                  title: const Text('End Date', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(selectedEnd!),
                    style: const TextStyle(color: AppColors.white70),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: AppColors.lightPink),
                  onTap: () async {
                    final date = await DatePickerUtils.showStyledDatePicker(
                      context: context,
                      initialDate: selectedEnd!,
                      firstDate: selectedStart!,
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() => selectedEnd = date);
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Duration info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: AppColors.pink, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Duration: ${selectedEnd!.difference(selectedStart!).inDays + 1} days',
                      style: TextStyle(
                        color: AppColors.pink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.greyText)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                onSave(selectedStart!, selectedEnd!);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCycleDays(int index) {
    if (index >= _periodHistory.length - 1) return _averageCycleLength;

    final currentPeriod = _periodHistory[index];
    final previousPeriod = _periodHistory[index + 1];

    return currentPeriod['start']!.difference(previousPeriod['start']!).inDays;
  }

  Widget _buildPeriodCard(int index) {
    final period = _periodHistory[index];
    final startDate = period['start']!;
    final endDate = period['end']!;
    final duration = endDate.difference(startDate).inDays + 1;
    final cycleDays = _getCycleDays(index);
    final isRecent = startDate.isAfter(DateTime.now().subtract(const Duration(days: 90)));

    return Dismissible(
      key: Key('period_${startDate.millisecondsSinceEpoch}_$index'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.8},
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppColors.dialogBackground,
            title: Row(
              children: [
                Icon(Icons.warning_rounded, size: 48, color: AppColors.orange),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Delete Period Record',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Are you sure you want to delete this period record?',
                  style: TextStyle(color: AppColors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                  style: TextStyle(
                    color: AppColors.pink,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    color: AppColors.greyText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: AppColors.greyText)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deleteRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        setState(() {
          _periodHistory.removeAt(index);
        });
        _savePeriodHistory();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.deleteRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GestureDetector(
          onTap: () => _editPeriod(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: isRecent
                    ? [AppColors.pink.withValues(alpha: 0.1), AppColors.lightPink.withValues(alpha: 0.05)]
                    : [AppColors.greyText.withValues(alpha: 0.05), AppColors.greyText.withValues(alpha: 0.02)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.water_drop_rounded, color: AppColors.pink, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$duration days',
                          style: TextStyle(
                            color: AppColors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$cycleDays day cycle',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_periodHistory.isEmpty) return const SizedBox.shrink();

    final totalPeriods = _periodHistory.length;
    final avgDuration = _periodHistory.isEmpty
        ? 0.0
        : _periodHistory
            .map((p) => p['end']!.difference(p['start']!).inDays + 1)
            .reduce((a, b) => a + b) / totalPeriods;

    final avgCycle = _periodHistory.length < 2
        ? _averageCycleLength.toDouble()
        : _periodHistory
            .asMap()
            .entries
            .where((entry) => entry.key < _periodHistory.length - 1)
            .map((entry) => _getCycleDays(entry.key))
            .reduce((a, b) => a + b) / (_periodHistory.length - 1);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.pink.withValues(alpha: 0.2), AppColors.lightPink.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Total Periods',
            '$totalPeriods',
            Icons.water_drop_rounded,
            AppColors.pink,
          ),
          Container(width: 1, height: 40, color: AppColors.greyText),
          _buildSummaryItem(
            'Avg Duration',
            '${avgDuration.round()} days',
            Icons.timer_rounded,
            AppColors.lightPink,
          ),
          Container(width: 1, height: 40, color: AppColors.greyText),
          _buildSummaryItem(
            'Avg Cycle',
            '${avgCycle.round()} days',
            Icons.refresh_rounded,
            AppColors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
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
          style: TextStyle(
            fontSize: 12,
            color: AppColors.greyText,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: const Text('Period History', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _periodHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_rounded, size: 64, color: AppColors.greyText),
            const SizedBox(height: 16),
            Text(
              'No period history yet',
              style: TextStyle(fontSize: 18, color: AppColors.greyText, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking your cycle to see history here',
              style: TextStyle(color: AppColors.greyText),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Summary card
          _buildSummaryCard(),

          // History list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _periodHistory.length,
              itemBuilder: (context, index) => _buildPeriodCard(index),
            ),
          ),
        ],
      ),
    );
  }
}