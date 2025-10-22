import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import 'cycle_calculation_utils.dart';
import '../shared/date_format_utils.dart';
import '../shared/dialog_utils.dart';

class PeriodHistoryScreen extends StatefulWidget {
  const PeriodHistoryScreen({super.key});

  @override
  State<PeriodHistoryScreen> createState() => _PeriodHistoryScreenState();
}

class _PeriodHistoryScreenState extends State<PeriodHistoryScreen> {
  List<Map<String, dynamic>> _periodHistory = [];
  int _averageCycleLength = 31;
  DateTime? _lastPeriodStart;

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

    // Load current active period
    final lastStartStr = prefs.getString('last_period_start');
    if (lastStartStr != null) _lastPeriodStart = DateTime.parse(lastStartStr);

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

    // Reschedule cycle notifications with updated data
    await CycleCalculationUtils.rescheduleCycleNotifications();
  }

  void _recalculateAverageCycleLength() async {
    final prefs = await SharedPreferences.getInstance();

    // Sort by start date (oldest first) for calculation
    final sortedHistory = List<Map<String, dynamic>>.from(_periodHistory);
    sortedHistory.sort((a, b) => a['start']!.compareTo(b['start']!));

    // Use the centralized calculation utility
    final calculatedAverage = await CycleCalculationUtils.calculateAverageCycleLength(
      periodRanges: sortedHistory,
      currentActivePeriodStart: _lastPeriodStart,
      defaultValue: 30,
    );

    _averageCycleLength = calculatedAverage;
    await prefs.setInt('average_cycle_length', _averageCycleLength);
    if (mounted) setState(() {});
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
          shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
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
                    DateFormatUtils.formatLong(selectedStart!),
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
                    DateFormatUtils.formatLong(selectedEnd!),
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
                  borderRadius: AppStyles.borderRadiusSmall,
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
                shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCycleDays(int index) {
    // For the oldest period, show 30 as placeholder
    if (index >= _periodHistory.length - 1) return 30;

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
        return await DialogUtils.showDeleteConfirmation(
          context,
          title: 'Șterge înregistrare perioadă',
          itemName: '${DateFormatUtils.formatLong(startDate)} - ${DateFormatUtils.formatLong(endDate)}',
          customMessage: 'Sigur vrei să ștergi această înregistrare? Această acțiune nu poate fi anulată.',
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
          borderRadius: AppStyles.borderRadiusMedium,
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
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
        child: GestureDetector(
          onTap: () => _editPeriod(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppStyles.borderRadiusMedium,
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
                          '${DateFormatUtils.formatShort(startDate)} - ${DateFormatUtils.formatLong(endDate)}',
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

    // Use the same centralized average that was calculated and stored
    final avgCycle = _averageCycleLength.toDouble();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.pink.withValues(alpha: 0.2), AppColors.lightPink.withValues(alpha: 0.1)],
        ),
        borderRadius: AppStyles.borderRadiusMedium,
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