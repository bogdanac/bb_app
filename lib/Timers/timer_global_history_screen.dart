import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_format_utils.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';

class TimerGlobalHistoryScreen extends StatefulWidget {
  const TimerGlobalHistoryScreen({super.key});

  @override
  State<TimerGlobalHistoryScreen> createState() => _TimerGlobalHistoryScreenState();
}

class _TimerGlobalHistoryScreenState extends State<TimerGlobalHistoryScreen> {
  Map<String, Duration> _dailyTotals = {};
  Duration _grandTotal = Duration.zero;
  Duration _focusTotal = Duration.zero;
  int _totalDays = 0;
  bool _isLoading = true;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  Map<String, Duration> _selectedDayBreakdown = {};
  List<TimerSession> _selectedDaySessions = [];
  Map<String, String> _activityNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dailyTotals = await TimerService.getGlobalDailyTotals();
    final grandTotal = await TimerService.getGlobalGrandTotal();
    final focusTotal = await TimerService.getTotalFocusTime();
    final activities = await TimerService.loadActivities();

    if (mounted) {
      setState(() {
        _dailyTotals = dailyTotals;
        _grandTotal = grandTotal;
        _focusTotal = focusTotal;
        _totalDays = dailyTotals.length;
        // Include both user activities and built-in productivity session names
        _activityNames = {
          for (var a in activities) a.id: a.name,
          'productivity_pomodoro': 'Pomodoro Focus',
          'productivity_countdown': 'Countdown Timer',
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSelectedDayData(DateTime date) async {
    final breakdown = await TimerService.getActivityBreakdownForDate(date);
    final sessions = await TimerService.getSessionsForDate(date);

    if (mounted) {
      setState(() {
        _selectedDayBreakdown = breakdown;
        _selectedDaySessions = sessions;
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes == 0 && d.inSeconds > 0) {
      return '${d.inSeconds}s';
    }
    return '${minutes}m';
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Color _getIntensityColor(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) return Colors.transparent;
    if (minutes < 30) return AppColors.purple.withValues(alpha: 0.25);
    if (minutes < 60) return AppColors.purple.withValues(alpha: 0.45);
    if (minutes < 120) return AppColors.purple.withValues(alpha: 0.65);
    return AppColors.purple.withValues(alpha: 0.85);
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startOffset = (firstDayOfMonth.weekday - 1) % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canGoForward = DateTime(_focusedMonth.year, _focusedMonth.month + 1)
        .isBefore(DateTime(now.year, now.month + 1));

    return Container(
      decoration: AppStyles.cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                    _selectedDate = null;
                    _selectedDayBreakdown = {};
                    _selectedDaySessions = [];
                  });
                },
                icon: const Icon(Icons.chevron_left),
                color: AppColors.grey200,
              ),
              Text(
                DateFormatUtils.formatMonthYear(_focusedMonth),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: canGoForward
                    ? () {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                          _selectedDate = null;
                          _selectedDayBreakdown = {};
                          _selectedDaySessions = [];
                        });
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: canGoForward ? AppColors.grey200 : AppColors.grey700,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            color: AppColors.grey300,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox.shrink();
              }
              final day = index - startOffset + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final dateKeyStr = _dateKey(date);
              final duration = _dailyTotals[dateKeyStr] ?? Duration.zero;
              final isToday = date == today;
              final isFuture = date.isAfter(today);
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == date.year &&
                  _selectedDate!.month == date.month &&
                  _selectedDate!.day == date.day;
              final hasData = duration.inSeconds > 0;

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        setState(() {
                          _selectedDate = date;
                        });
                        _loadSelectedDayData(date);
                      },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hasData ? _getIntensityColor(duration) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: AppColors.purple, width: 2)
                        : isToday
                            ? Border.all(color: AppColors.purple.withValues(alpha: 0.5), width: 1.5)
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isFuture
                            ? AppColors.grey700
                            : isSelected
                                ? AppColors.purple
                                : AppColors.white,
                        fontSize: 13,
                        fontWeight: isToday || isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('< 30m', AppColors.purple.withValues(alpha: 0.25)),
          const SizedBox(width: 12),
          _buildLegendItem('< 1h', AppColors.purple.withValues(alpha: 0.45)),
          const SizedBox(width: 12),
          _buildLegendItem('< 2h', AppColors.purple.withValues(alpha: 0.65)),
          const SizedBox(width: 12),
          _buildLegendItem('2h+', AppColors.purple.withValues(alpha: 0.85)),
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
        Text(label, style: TextStyle(color: AppColors.grey300, fontSize: 11)),
      ],
    );
  }

  Widget _buildSelectedDayDetails() {
    if (_selectedDate == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Tap a day to see activity breakdown',
            style: TextStyle(color: AppColors.greyText, fontSize: 13),
          ),
        ),
      );
    }

    final key = _dateKey(_selectedDate!);
    final totalDuration = _dailyTotals[key] ?? Duration.zero;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: AppStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: AppColors.purple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormatUtils.formatFullDate(_selectedDate!),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDuration(totalDuration),
                    style: TextStyle(
                      color: AppColors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedDayBreakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No time recorded',
                style: TextStyle(color: AppColors.greyText),
              ),
            )
          else ...[
            // Activity breakdown
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By Activity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._selectedDayBreakdown.entries.map((entry) {
                    final percentage = totalDuration.inSeconds > 0
                        ? entry.value.inSeconds / totalDuration.inSeconds
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                _formatDuration(entry.value),
                                style: TextStyle(
                                  color: AppColors.purple,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: AppColors.grey700,
                              valueColor: AlwaysStoppedAnimation(AppColors.purple),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Individual sessions
            if (_selectedDaySessions.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sessions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedDaySessions.map((session) {
                      final activityName = _activityNames[session.activityId] ?? 'Unknown';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 16, color: AppColors.purple),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activityName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    DateFormat('HH:mm').format(session.startTime),
                                    style: TextStyle(fontSize: 11, color: AppColors.greyText),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatDuration(session.duration),
                              style: TextStyle(
                                color: AppColors.purple,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Activities'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Activities'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grand total card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration(),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Total Time',
                              style: TextStyle(color: AppColors.grey200, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_grandTotal),
                              style: TextStyle(
                                color: AppColors.purple,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 45,
                        color: AppColors.grey700,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Focus Time',
                              style: TextStyle(color: AppColors.grey200, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_focusTotal),
                              style: TextStyle(
                                color: AppColors.orange,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 45,
                        color: AppColors.grey700,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Days',
                              style: TextStyle(color: AppColors.grey200, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_totalDays',
                              style: TextStyle(
                                color: AppColors.purple,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_focusTotal.inSeconds > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Focus: Pomodoro + Countdown sessions',
                      style: TextStyle(color: AppColors.grey300, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Calendar
            _buildCalendar(),
            _buildLegend(),
            _buildSelectedDayDetails(),
          ],
        ),
      ),
    );
  }
}
