import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'timer_data_models.dart';
import 'timer_service.dart';
import 'add_manual_time_dialog.dart';

class ActivityDetailScreen extends StatefulWidget {
  final Activity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  Map<String, Duration> _dailyTotals = {};
  Duration _grandTotal = Duration.zero;
  bool _isLoading = true;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final dailyTotals = await TimerService.getDailyTotals(widget.activity.id);
    final grandTotal = await TimerService.getGrandTotal(widget.activity.id);
    if (mounted) {
      setState(() {
        _dailyTotals = dailyTotals;
        _grandTotal = grandTotal;
        _isLoading = false;
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

  String _formatDateKey(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) return 'Today';
      if (dateOnly == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      }
      return DateFormat('EEEE, MMM d, y').format(date);
    } catch (_) {
      return dateKey;
    }
  }

  // --- Calendar color based on time spent ---
  Color _getIntensityColor(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) return Colors.transparent;
    if (minutes < 30) return AppColors.purple.withValues(alpha: 0.25);
    if (minutes < 60) return AppColors.purple.withValues(alpha: 0.45);
    if (minutes < 120) return AppColors.purple.withValues(alpha: 0.65);
    return AppColors.purple.withValues(alpha: 0.85);
  }

  // --- Calendar widget ---
  Widget _buildCalendar() {
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
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
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month - 1);
                    _selectedDate = null;
                  });
                },
                icon: const Icon(Icons.chevron_left),
                color: AppColors.grey200,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: canGoForward
                    ? () {
                        setState(() {
                          _focusedMonth = DateTime(
                              _focusedMonth.year, _focusedMonth.month + 1);
                          _selectedDate = null;
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
              final date = DateTime(
                  _focusedMonth.year, _focusedMonth.month, day);
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
                      },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hasData
                        ? _getIntensityColor(duration)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: AppColors.purple, width: 2)
                        : isToday
                            ? Border.all(
                                color:
                                    AppColors.purple.withValues(alpha: 0.5),
                                width: 1.5)
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
                        fontWeight:
                            isToday || isSelected ? FontWeight.bold : null,
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

  // --- Legend ---
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

  // --- Selected day details ---
  Widget _buildSelectedDayDetails() {
    if (_selectedDate == null) return const SizedBox.shrink();

    final key = _dateKey(_selectedDate!);
    final duration = _dailyTotals[key] ?? Duration.zero;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDateKey(key),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer, color: AppColors.purple, size: 18),
              const SizedBox(width: 8),
              Text(
                duration.inSeconds > 0
                    ? _formatDuration(duration)
                    : 'No time recorded',
                style: TextStyle(
                  color: duration.inSeconds > 0
                      ? AppColors.purple
                      : AppColors.grey300,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.name),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add manual time',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AddManualTimeDialog(
                activityId: widget.activity.id,
                onAdded: _loadHistory,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        Text(
                          'Total Time',
                          style: TextStyle(
                            color: AppColors.grey200,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_grandTotal),
                          style: TextStyle(
                            color: AppColors.purple,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_dailyTotals.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_dailyTotals.length} day${_dailyTotals.length == 1 ? '' : 's'} tracked',
                            style: TextStyle(
                              color: AppColors.grey300,
                              fontSize: 13,
                            ),
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

                  const SizedBox(height: 20),

                  // Daily breakdown list
                  if (_dailyTotals.isNotEmpty) ...[
                    Text(
                      'History',
                      style: AppStyles.headingSmall,
                    ),
                    const SizedBox(height: 12),
                    ..._dailyTotals.entries.map((entry) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: AppStyles.cardDecoration(),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDateKey(entry.key),
                                style: const TextStyle(fontSize: 15),
                              ),
                              Text(
                                _formatDuration(entry.value),
                                style: TextStyle(
                                  color: AppColors.purple,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          children: [
                            Icon(Icons.history,
                                size: 48, color: AppColors.grey300),
                            const SizedBox(height: 12),
                            Text(
                              'No sessions recorded yet',
                              style: TextStyle(
                                  color: AppColors.grey200, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AddManualTimeDialog(
                                  activityId: widget.activity.id,
                                  onAdded: _loadHistory,
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Manual Time'),
                              style: AppStyles.elevatedButtonStyle(
                                  backgroundColor: AppColors.purple),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
