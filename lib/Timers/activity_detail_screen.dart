import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/dialog_utils.dart';
import '../shared/snackbar_utils.dart';
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
  Duration _weeklyTotal = Duration.zero;
  Duration _monthlyTotal = Duration.zero;
  bool _isLoading = true;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<TimerSession> _selectedDaySessions = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final dailyTotals = await TimerService.getDailyTotals(widget.activity.id);
    final grandTotal = await TimerService.getGrandTotal(widget.activity.id);
    final weeklyTotal = await TimerService.getWeeklyTotal(widget.activity.id);
    final monthlyTotal = await TimerService.getMonthlyTotal(widget.activity.id);
    if (mounted) {
      setState(() {
        _dailyTotals = dailyTotals;
        _grandTotal = grandTotal;
        _weeklyTotal = weeklyTotal;
        _monthlyTotal = monthlyTotal;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSelectedDaySessions() async {
    if (_selectedDate == null) return;
    final allSessions = await TimerService.getSessionsForActivity(widget.activity.id);
    final daySessions = allSessions.where((s) {
      return s.startTime.year == _selectedDate!.year &&
          s.startTime.month == _selectedDate!.month &&
          s.startTime.day == _selectedDate!.day;
    }).toList();
    if (mounted) {
      setState(() {
        _selectedDaySessions = daySessions;
      });
    }
  }

  Future<void> _deleteSession(TimerSession session) async {
    final confirmed = await DialogUtils.showDeleteConfirmation(
      context,
      title: 'Delete Session',
      itemName: 'this session',
      customMessage: 'Delete ${_formatDuration(session.duration)} session from ${DateFormat('HH:mm').format(session.startTime)}?',
    );
    if (confirmed == true) {
      await TimerService.deleteSession(session.id);
      HapticFeedback.lightImpact();
      await _loadHistory();
      await _loadSelectedDaySessions();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Session deleted');
      }
    }
  }

  Future<void> _editSessionDuration(TimerSession session) async {
    int hours = session.duration.inHours;
    int minutes = session.duration.inMinutes.remainder(60);

    final result = await showDialog<Duration>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Session from ${DateFormat('HH:mm').format(session.startTime)}',
                style: TextStyle(color: AppColors.greyText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hours
                  Column(
                    children: [
                      IconButton(
                        onPressed: () => setDialogState(() => hours++),
                        icon: const Icon(Icons.arrow_drop_up),
                      ),
                      Text(
                        '$hours',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purple,
                        ),
                      ),
                      IconButton(
                        onPressed: hours > 0 ? () => setDialogState(() => hours--) : null,
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                      Text('hours', style: TextStyle(color: AppColors.greyText, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Text(':', style: TextStyle(fontSize: 32, color: AppColors.greyText)),
                  const SizedBox(width: 20),
                  // Minutes
                  Column(
                    children: [
                      IconButton(
                        onPressed: () => setDialogState(() => minutes = (minutes + 5) % 60),
                        icon: const Icon(Icons.arrow_drop_up),
                      ),
                      Text(
                        minutes.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purple,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => minutes = minutes > 0 ? minutes - 5 : 55),
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                      Text('mins', style: TextStyle(color: AppColors.greyText, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (hours > 0 || minutes > 0)
                  ? () => Navigator.pop(context, Duration(hours: hours, minutes: minutes))
                  : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await TimerService.updateSessionDuration(session.id, result);
      HapticFeedback.lightImpact();
      await _loadHistory();
      await _loadSelectedDaySessions();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Duration updated');
      }
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
                        _loadSelectedDaySessions();
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
      decoration: AppStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateKey(key),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer, color: AppColors.purple, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      duration.inSeconds > 0 ? _formatDuration(duration) : 'No time recorded',
                      style: TextStyle(
                        color: duration.inSeconds > 0 ? AppColors.purple : AppColors.grey300,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Individual sessions list
          if (_selectedDaySessions.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sessions',
                    style: TextStyle(fontSize: 12, color: AppColors.greyText, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ..._selectedDaySessions.map((session) => Container(
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
                        Text(
                          DateFormat('HH:mm').format(session.startTime),
                          style: TextStyle(fontSize: 13, color: AppColors.greyText),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(session.duration),
                          style: TextStyle(
                            color: AppColors.purple,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _editSessionDuration(session),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: AppColors.waterBlue,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _deleteSession(session),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppColors.deleteRed.withValues(alpha: 0.7),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
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
                  // Stats cards
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppStyles.cardDecoration(),
                    child: Column(
                      children: [
                        // Grand total (larger)
                        Text(
                          'Total Time',
                          style: TextStyle(color: AppColors.grey200, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(_grandTotal),
                          style: TextStyle(
                            color: AppColors.purple,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_dailyTotals.isNotEmpty) ...[
                          Text(
                            '${_dailyTotals.length} day${_dailyTotals.length == 1 ? '' : 's'} tracked',
                            style: TextStyle(color: AppColors.grey300, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        // Weekly and Monthly totals
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'This Week',
                                    style: TextStyle(color: AppColors.grey300, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDuration(_weeklyTotal),
                                    style: TextStyle(
                                      color: AppColors.purple,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.grey700,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'This Month',
                                    style: TextStyle(color: AppColors.grey300, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDuration(_monthlyTotal),
                                    style: TextStyle(
                                      color: AppColors.purple,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
