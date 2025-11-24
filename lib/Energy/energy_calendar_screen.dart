import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_format_utils.dart';
import 'energy_settings_model.dart';
import 'energy_service.dart';

class EnergyCalendarScreen extends StatefulWidget {
  const EnergyCalendarScreen({super.key});

  @override
  State<EnergyCalendarScreen> createState() => _EnergyCalendarScreenState();
}

class _EnergyCalendarScreenState extends State<EnergyCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  DailyEnergyRecord? _selectedDayRecord;
  Map<DateTime, DailyEnergyRecord> _energyHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadEnergyHistory();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEnergyHistory() async {
    // Load records for the focused month plus surrounding months
    final startDate = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    final endDate = DateTime(_focusedMonth.year, _focusedMonth.month + 2, 0);

    final records = await EnergyService.getHistory(
      startDate: startDate,
      endDate: endDate,
    );

    _energyHistory = {};
    for (final record in records) {
      final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
      _energyHistory[dateKey] = record;
    }
  }

  Future<void> _selectDate(DateTime date) async {
    final dateKey = DateTime(date.year, date.month, date.day);
    final record = await EnergyService.getRecordForDate(date);

    setState(() {
      _selectedDate = dateKey;
      _selectedDayRecord = record;
    });
  }

  Color _getCompletionColor(EnergyCompletionLevel level) {
    switch (level) {
      case EnergyCompletionLevel.low:
        return AppColors.successGreen;
      case EnergyCompletionLevel.moderate:
        return AppColors.yellow;
      case EnergyCompletionLevel.high:
        return AppColors.orange;
      case EnergyCompletionLevel.over:
        return AppColors.coral;
    }
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // Calculate the starting day (Monday = 1)
    final startOffset = (firstWeekday - 1) % 7;

    return Column(
      children: [
        // Month navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () async {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                    _selectedDate = null;
                    _selectedDayRecord = null;
                  });
                  await _loadEnergyHistory();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.greyText,
              ),
              Text(
                DateFormatUtils.formatMonthYear(_focusedMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _focusedMonth.isBefore(DateTime.now().subtract(const Duration(days: 28)))
                    ? () async {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                          _selectedDate = null;
                          _selectedDayRecord = null;
                        });
                        await _loadEnergyHistory();
                        if (mounted) setState(() {});
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.greyText,
              ),
            ],
          ),
        ),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox(); // Empty cell before first day
              }

              final day = index - startOffset + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final dateKey = DateTime(date.year, date.month, date.day);
              final isToday = dateKey.year == DateTime.now().year &&
                  dateKey.month == DateTime.now().month &&
                  dateKey.day == DateTime.now().day;
              final isSelected = _selectedDate != null &&
                  dateKey.year == _selectedDate!.year &&
                  dateKey.month == _selectedDate!.month &&
                  dateKey.day == _selectedDate!.day;
              final record = _energyHistory[dateKey];
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture ? null : () => _selectDate(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.coral.withValues(alpha: 0.3)
                        : isToday
                            ? AppColors.waterBlue.withValues(alpha: 0.2)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: AppColors.waterBlue, width: 2)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isFuture
                                  ? AppColors.greyText.withValues(alpha: 0.5)
                                  : isToday
                                      ? AppColors.waterBlue
                                      : Colors.white,
                            ),
                          ),
                          if (record != null)
                            Container(
                              width: 24,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _getCompletionColor(record.completionLevel),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                      // Energy number indicator
                      if (record != null)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: _getCompletionColor(record.completionLevel),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${record.energyConsumed}',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayDetails() {
    if (_selectedDate == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Tap a date to see energy details',
            style: TextStyle(
              color: AppColors.greyText,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final record = _selectedDayRecord;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(color: AppColors.normalCardBackground),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.coral,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormatUtils.formatLong(_selectedDate!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (record == null) ...[
              const SizedBox(height: 16),
              Text(
                'No energy data recorded for this day',
                style: TextStyle(color: AppColors.greyText),
              ),
            ] else ...[
              const SizedBox(height: 16),

              // Phase and cycle day
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightPink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      record.menstrualPhase,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightPink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Day ${record.cycleDayNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Battery & Flow summary
              Row(
                children: [
                  Expanded(
                    child: _buildEnergyStat(
                      'Battery',
                      '${record.startingBattery}% → ${record.currentBattery}%',
                      record.batteryChange >= 0
                          ? AppColors.successGreen
                          : AppColors.coral,
                    ),
                  ),
                  Expanded(
                    child: _buildEnergyStat(
                      'Flow',
                      '${record.flowPoints}/${record.flowGoal}',
                      record.isGoalMet
                          ? AppColors.successGreen
                          : _getCompletionColor(record.completionLevel),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Achievement badges
              Row(
                children: [
                  if (record.isGoalMet)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.successGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Goal Met',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (record.isGoalMet) const SizedBox(width: 8),
                  if (record.isPR)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: AppColors.purple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Personal Record!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Progress bar
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (record.completionPercentage / 100).clamp(0, 1),
                  backgroundColor: AppColors.greyText.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(_getCompletionColor(record.completionLevel)),
                  minHeight: 8,
                ),
              ),

              // Entries breakdown
              if (record.entries.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Completed Items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.greyText,
                  ),
                ),
                const SizedBox(height: 8),
                ...record.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        entry.sourceType == EnergySourceType.task
                            ? Icons.check_circle_rounded
                            : Icons.repeat_rounded,
                        size: 16,
                        color: entry.sourceType == EnergySourceType.task
                            ? AppColors.successGreen
                            : AppColors.purple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.energyLevel < 0
                              ? AppColors.coral.withValues(alpha: 0.2)
                              : AppColors.successGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.energyLevel < 0
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 12,
                              color: entry.energyLevel < 0
                                  ? AppColors.coral
                                  : AppColors.successGreen,
                            ),
                            Text(
                              '${entry.energyLevel > 0 ? '+' : ''}${entry.energyLevel}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: entry.energyLevel < 0
                                    ? AppColors.coral
                                    : AppColors.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
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

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Low', AppColors.successGreen),
          _buildLegendItem('Moderate', AppColors.yellow),
          _buildLegendItem('High', AppColors.orange),
          _buildLegendItem('Over', AppColors.coral),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.greyText,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.2),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.purple,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Battery & Flow tracking shows how tasks affect your energy and productivity',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Energy History'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy History'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCalendar(),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 8),
            _buildInfoCard(),
            _buildSelectedDayDetails(),
          ],
        ),
      ),
    );
  }
}
