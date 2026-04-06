import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_format_utils.dart';
import '../shared/calendar_widget.dart';
import 'food_tracking_service.dart';
import 'food_tracking_data_models.dart';
import 'food_tracking_goal_history_screen.dart';
import 'food_tracking_settings_screen.dart';
import '../MenstrualCycle/cycle_calorie_settings_screen.dart';
import '../shared/snackbar_utils.dart';
import '../shared/dialog_utils.dart';

class FoodTrackingHistoryScreen extends StatefulWidget {
  const FoodTrackingHistoryScreen({super.key});

  @override
  State<FoodTrackingHistoryScreen> createState() => _FoodTrackingHistoryScreenState();
}

class _FoodTrackingHistoryScreenState extends State<FoodTrackingHistoryScreen> {
  List<FoodEntry> _entries = [];
  bool _isLoading = true;
  Map<DateTime, List<FoodEntry>> _entriesByDate = {};
  Map<DateTime, Map<String, int>> _dailySummaries = {};
  bool _calorieTrackerEnabled = false;

  // Calendar state
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final entries = await FoodTrackingService.getAllEntries();
    final dailySummaries = await FoodTrackingService.getDailySummaries();
    final calorieEnabled = await FoodTrackingService.getCalorieTrackerEnabled();
    _entriesByDate = _groupEntriesByDate(entries);

    // Auto-select today if it has entries, otherwise most recent day with entries
    DateTime? dateToSelect;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (_entriesByDate.containsKey(today)) {
      dateToSelect = today;
    } else if (_entriesByDate.isNotEmpty) {
      dateToSelect = _entriesByDate.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    }

    setState(() {
      _entries = entries;
      _dailySummaries = dailySummaries;
      _calorieTrackerEnabled = calorieEnabled;
      _selectedDate = dateToSelect;
      _isLoading = false;
    });
  }

  Map<DateTime, List<FoodEntry>> _groupEntriesByDate(List<FoodEntry> entries) {
    final groups = <DateTime, List<FoodEntry>>{};
    for (final entry in entries) {
      final dateKey = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      groups[dateKey] ??= [];
      groups[dateKey]!.add(entry);
    }
    // Sort entries within each day by time
    for (final list in groups.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    return groups;
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _addEntry(FoodType type, {DateTime? forDate}) async {
    HapticFeedback.lightImpact();
    final targetDate = forDate ?? DateTime.now();
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime(targetDate.year, targetDate.month, targetDate.day,
          DateTime.now().hour, DateTime.now().minute),
    );
    await FoodTrackingService.addEntry(entry);
    await _loadEntries();

    // Keep the selected date on the date we just added to
    final selectedDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    setState(() {
      _selectedDate = selectedDay;
      _focusedMonth = DateTime(selectedDay.year, selectedDay.month, 1);
    });

    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        type == FoodType.healthy ? 'Healthy food added' : 'Processed food added',
      );
    }
  }

  void _showAddFoodBottomSheet({DateTime? forDate}) {
    final isToday = forDate == null ||
        DateFormatUtils.isSameDay(forDate, DateTime.now());
    final dateLabel = isToday ? 'today' : DateFormatUtils.formatFullDate(forDate);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.greyText.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Add Food Entry — $dateLabel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildAddButton(
                    label: 'Healthy',
                    icon: Icons.restaurant,
                    color: AppColors.successGreen,
                    onTap: () {
                      Navigator.pop(context);
                      _addEntry(FoodType.healthy, forDate: forDate);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAddButton(
                    label: 'Processed',
                    icon: Icons.fastfood,
                    color: AppColors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _addEntry(FoodType.processed, forDate: forDate);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.borderRadiusMedium,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: AppStyles.borderRadiusMedium,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    final confirmed = await DialogUtils.showDeleteConfirmation(
      context,
      title: 'Delete Entry',
      itemName: '${entry.type.name} food',
      customMessage: 'Are you sure you want to delete this entry?',
    );

    if (confirmed == true) {
      await FoodTrackingService.deleteEntry(entry.id);
      HapticFeedback.lightImpact();
      await _loadEntries();
    }
  }

  Future<void> _moveEntryToDate(FoodEntry entry, DateTime targetDate) async {
    // Don't move if same day
    final entryDate = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
    if (entryDate == targetDate) return;

    // Create new entry with updated timestamp but keep same time
    final newTimestamp = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      entry.timestamp.hour,
      entry.timestamp.minute,
    );

    final newEntry = FoodEntry(
      id: '',
      type: entry.type,
      timestamp: newTimestamp,
    );

    await FoodTrackingService.deleteEntry(entry.id);
    await FoodTrackingService.addEntry(newEntry);

    HapticFeedback.mediumImpact();
    await _loadEntries();

    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Moved to ${DateFormatUtils.formatShort(targetDate)}');
    }
  }

  Color _getDayColor(DateTime date) {
    final entries = _entriesByDate[date];
    int healthyCount;
    int total;

    if (entries != null && entries.isNotEmpty) {
      healthyCount = entries.where((e) => e.type == FoodType.healthy).length;
      total = entries.length;
    } else {
      // Check daily summaries for past data
      final summary = _dailySummaries[date];
      if (summary == null) return Colors.transparent;
      healthyCount = summary['healthy'] ?? 0;
      total = healthyCount + (summary['processed'] ?? 0);
      if (total == 0) return Colors.transparent;
    }

    final percentage = (healthyCount / total * 100).round();

    if (percentage >= 80) return AppColors.successGreen;
    if (percentage >= 60) return AppColors.yellow;
    if (percentage >= 40) return AppColors.orange;
    return AppColors.coral;
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        CalendarWidget(
          focusedMonth: _focusedMonth,
          onMonthChanged: (newMonth) {
            setState(() {
              _focusedMonth = newMonth;
            });
          },
          dayBuilder: (date) => _buildDayCell(date),
          allowFutureMonths: true,
          maxFutureMonths: 3,
          cellAspectRatio: 1.2,
          cellSpacing: 2.0,
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('80%+', AppColors.successGreen),
              _buildLegendItem('60%+', AppColors.yellow),
              _buildLegendItem('40%+', AppColors.orange),
              _buildLegendItem('<40%', AppColors.coral),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isToday = DateFormatUtils.isSameDay(date, DateTime.now());
    final isSelected = _selectedDate != null && DateFormatUtils.isSameDay(date, _selectedDate!);
    final dayColor = _getDayColor(date);
    final entries = _entriesByDate[date] ?? [];
    final summary = _dailySummaries[date];
    final hasEntries = entries.isNotEmpty || (summary != null && (summary['healthy']! + summary['processed']!) > 0);
    final displayCount = entries.isNotEmpty ? entries.length : (summary != null ? summary['healthy']! + summary['processed']! : 0);

    return DragTarget<FoodEntry>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _moveEntryToDate(details.data, date);
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            decoration: BoxDecoration(
              color: isDropTarget
                  ? AppColors.successGreen.withValues(alpha: 0.3)
                  : isToday
                      ? AppColors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: AppColors.waterBlue, width: 1.5)
                  : isDropTarget
                      ? Border.all(color: AppColors.successGreen, width: 2)
                      : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isToday
                        ? AppColors.waterBlue
                        : Colors.white,
                  ),
                ),
                if (hasEntries)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 16,
                          height: 3,
                          decoration: BoxDecoration(
                            color: dayColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$displayCount',
                          style: TextStyle(
                            fontSize: 8,
                            color: dayColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButtons({required DateTime forDate}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _addEntry(FoodType.healthy, forDate: forDate),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Healthy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _addEntry(FoodType.processed, forDate: forDate),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Processed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDaySection() {
    if (_selectedDate == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Tap a day to view or add entries',
            style: TextStyle(color: AppColors.greyText, fontSize: 13),
          ),
        ),
      );
    }

    final entries = _entriesByDate[_selectedDate!] ?? [];
    final summary = _dailySummaries[_selectedDate!];

    if (entries.isEmpty && summary != null && (summary['healthy']! + summary['processed']!) > 0) {
      // Show archived summary for past days
      final sHealthy = summary['healthy']!;
      final sProcessed = summary['processed']!;
      final sTotal = sHealthy + sProcessed;
      final sPercentage = sTotal > 0 ? (sHealthy / sTotal * 100).round() : 0;
      final statusColor = sPercentage >= 80
          ? AppColors.successGreen
          : sPercentage >= 60
              ? AppColors.yellow
              : AppColors.orange;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.normalCardBackground,
              borderRadius: AppStyles.borderRadiusMedium,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormatUtils.formatFullDate(_selectedDate!),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$sPercentage% healthy',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant, size: 14, color: AppColors.successGreen),
                const SizedBox(width: 4),
                Text('$sHealthy healthy', style: const TextStyle(color: AppColors.successGreen, fontSize: 13)),
                const SizedBox(width: 16),
                Icon(Icons.fastfood, size: 14, color: AppColors.orange),
                const SizedBox(width: 4),
                Text('$sProcessed processed', style: const TextStyle(color: AppColors.orange, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Archived period data',
            style: TextStyle(color: AppColors.greyText.withValues(alpha: 0.6), fontSize: 11),
          ),
          _buildQuickAddButtons(forDate: _selectedDate!),
        ],
      );
    }

    if (entries.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            'No entries for ${DateFormatUtils.formatFullDate(_selectedDate!)}',
            style: TextStyle(color: AppColors.greyText, fontSize: 13),
          ),
          _buildQuickAddButtons(forDate: _selectedDate!),
        ],
      );
    }

    final healthyCount = entries.where((e) => e.type == FoodType.healthy).length;
    final processedCount = entries.where((e) => e.type == FoodType.processed).length;
    final total = healthyCount + processedCount;
    final healthyPercentage = total > 0 ? (healthyCount / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Day header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.normalCardBackground,
            borderRadius: AppStyles.borderRadiusMedium,
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: AppColors.successGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormatUtils.formatFullDate(_selectedDate!),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: healthyPercentage >= 80
                      ? AppColors.successGreen.withValues(alpha: 0.2)
                      : healthyPercentage >= 60
                          ? AppColors.yellow.withValues(alpha: 0.2)
                          : AppColors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$healthyPercentage% healthy',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: healthyPercentage >= 80
                        ? AppColors.successGreen
                        : healthyPercentage >= 60
                            ? AppColors.yellow
                            : AppColors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Entry list
        ...entries.map((entry) => _buildCompactEntryTile(entry)),

        // Quick-add buttons always visible
        _buildQuickAddButtons(forDate: _selectedDate!),
      ],
    );
  }

  Widget _buildCompactEntryTile(FoodEntry entry) {
    final isHealthy = entry.type == FoodType.healthy;
    final color = isHealthy ? AppColors.successGreen : AppColors.orange;
    final icon = isHealthy ? Icons.restaurant : Icons.fastfood;
    // Match the tile width so feedback stays directly under the thumb
    final tileWidth = MediaQuery.of(context).size.width - 32;

    return LongPressDraggable<FoodEntry>(
      data: entry,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        elevation: 8,
        borderRadius: AppStyles.borderRadiusSmall,
        child: SizedBox(
          width: tileWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.normalCardBackground,
              borderRadius: AppStyles.borderRadiusSmall,
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  isHealthy ? 'Healthy' : 'Processed',
                  style: TextStyle(fontWeight: FontWeight.w500, color: color, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildEntryRow(entry, color, icon, isHealthy),
      ),
      child: _buildEntryRow(entry, color, icon, isHealthy),
    );
  }

  Widget _buildEntryRow(FoodEntry entry, Color color, IconData icon, bool isHealthy) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Healthy Food' : 'Processed Food',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatTime(entry.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator, color: AppColors.greyText.withValues(alpha: 0.5), size: 18),
          IconButton(
            onPressed: () => _deleteEntry(entry),
            icon: const Icon(Icons.close, size: 16),
            color: AppColors.deleteRed.withValues(alpha: 0.6),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }


  Widget _buildCalorieSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: AppColors.orange, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Calorie Tracker',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          if (_calorieTrackerEnabled)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CycleCalorieSettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              tooltip: 'Phase Calorie Settings',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          Switch(
            value: _calorieTrackerEnabled,
            onChanged: (value) async {
              await FoodTrackingService.setCalorieTrackerEnabled(value);
              setState(() {
                _calorieTrackerEnabled = value;
              });
            },
            activeTrackColor: AppColors.orange,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Tracking'),
        backgroundColor: AppColors.successGreen.withValues(alpha: 0.2),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FoodTrackingGoalHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.emoji_events_rounded),
            tooltip: 'Goal Achievement History',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FoodTrackingSettingsScreen(),
                ),
              ).then((_) => _loadEntries());
            },
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Food Tracking Settings',
          ),
          if (_entries.isNotEmpty)
            IconButton(
              onPressed: () {
                DialogUtils.showInfo(
                  context,
                  title: 'Food Tracking Tips',
                  message: 'Track your food intake to maintain a healthy balance:\n\n'
                      '• Aim for 80% healthy foods\n'
                      '• Long-press and drag entries to move them to another day\n'
                      '• Tap a day in the calendar to see its entries\n'
                      '• Colors show healthy food percentage',
                  buttonText: 'Got it',
                );
              },
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodBottomSheet(forDate: _selectedDate),
        backgroundColor: AppColors.successGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty && _dailySummaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 64,
                        color: AppColors.white54,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No food entries yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start tracking your food intake from the main screen',
                        style: TextStyle(color: AppColors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCalendar(),
                      const Divider(height: 1),
                      _buildCalorieSection(),
                      const Divider(height: 1),
                      _buildSelectedDaySection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}
