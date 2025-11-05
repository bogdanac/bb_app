import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'food_tracking_service.dart';
import 'food_tracking_data_models.dart';
import 'food_tracking_goal_history_screen.dart';
import '../shared/date_picker_utils.dart';
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
  Map<String, List<FoodEntry>> _groupedEntries = {};
  List<Map<String, dynamic>> _periodHistory = [];
  bool _showPeriodHistory = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final entries = await FoodTrackingService.getAllEntries();
    final periodHistory = await FoodTrackingService.getPeriodHistory();
    _groupedEntries = _groupEntriesByDate(entries);
    setState(() {
      _entries = entries;
      _periodHistory = periodHistory;
      _isLoading = false;
    });
  }

  Map<String, List<FoodEntry>> _groupEntriesByDate(List<FoodEntry> entries) {
    final groups = <String, List<FoodEntry>>{};
    for (final entry in entries) {
      final dateKey = _formatDate(entry.timestamp);
      groups[dateKey] ??= [];
      groups[dateKey]!.add(entry);
    }
    return groups;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    final confirmed = await DialogUtils.showDeleteConfirmation(
      context,
      title: 'Șterge înregistrare',
      itemName: '${entry.type.name} food',
      customMessage: 'Sigur vrei să ștergi această înregistrare?',
    );

    if (confirmed == true) {
      await FoodTrackingService.deleteEntry(entry.id);
      HapticFeedback.lightImpact();
      await _loadEntries();
    }
  }

  Future<void> _showChangeDateDialog(FoodEntry entry) async {
    final selectedDate = await DatePickerUtils.showStyledDatePicker(
      context: context,
      initialDate: entry.timestamp,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (selectedDate != null) {
      await _changeEntryDate(entry, selectedDate);
    }
  }

  Future<void> _changeEntryDate(FoodEntry entry, DateTime newDate) async {
    // Create new entry with updated timestamp but keep same time
    final newTimestamp = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      entry.timestamp.hour,
      entry.timestamp.minute,
    );

    final newEntry = FoodEntry(
      id: '', // Will get new ID
      type: entry.type,
      timestamp: newTimestamp,
    );

    // Delete old entry and add new one
    await FoodTrackingService.deleteEntry(entry.id);
    await FoodTrackingService.addEntry(newEntry);

    HapticFeedback.mediumImpact();
    await _loadEntries();

    if (mounted) {
      final dateString = _formatDate(newTimestamp);
      SnackBarUtils.showSuccess(context, 'Food entry moved to $dateString');
    }
  }

  Future<void> _moveEntryToDate(FoodEntry entry, String targetDateKey) async {
    // Parse the target date
    DateTime targetDate;
    final now = DateTime.now();

    if (targetDateKey == 'Today') {
      targetDate = now;
    } else if (targetDateKey == 'Yesterday') {
      targetDate = now.subtract(const Duration(days: 1));
    } else {
      // Parse format "dd/mm/yyyy"
      final parts = targetDateKey.split('/');
      if (parts.length == 3) {
        targetDate = DateTime(
          int.parse(parts[2]), // year
          int.parse(parts[1]), // month
          int.parse(parts[0]), // day
          entry.timestamp.hour,
          entry.timestamp.minute,
        );
      } else {
        return; // Invalid date format
      }
    }

    // Create new entry with updated timestamp
    final newEntry = FoodEntry(
      id: '', // Will get new ID
      type: entry.type,
      timestamp: targetDate,
    );

    // Delete old entry and add new one
    await FoodTrackingService.deleteEntry(entry.id);
    await FoodTrackingService.addEntry(newEntry);

    HapticFeedback.mediumImpact();
    await _loadEntries();

    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Food entry moved to $targetDateKey');
    }
  }

  Widget _buildEntryTile(FoodEntry entry) {
    final isHealthy = entry.type == FoodType.healthy;
    final color = isHealthy ? AppColors.successGreen : AppColors.orange;
    final icon = isHealthy ? Icons.restaurant : Icons.fastfood;

    return LongPressDraggable<FoodEntry>(
      data: entry,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        elevation: 8,
        borderRadius: AppStyles.borderRadiusMedium,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.normalCardBackground,
            borderRadius: AppStyles.borderRadiusMedium,
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isHealthy ? 'Healthy Food' : 'Processed Food',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    Text(
                      _formatTime(entry.timestamp),
                      style: const TextStyle(color: AppColors.greyText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            title: Text(
              isHealthy ? 'Healthy Food' : 'Processed Food',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            subtitle: Text(_formatTime(entry.timestamp)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showChangeDateDialog(entry),
                  icon: const Icon(Icons.edit_calendar),
                  color: AppColors.waterBlue.withValues(alpha: 0.7),
                  tooltip: 'Change Date',
                ),
                IconButton(
                  onPressed: () => _deleteEntry(entry),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.deleteRed.withValues(alpha: 0.7),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color),
          ),
          title: Text(
            isHealthy ? 'Healthy Food' : 'Processed Food',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          subtitle: Text(_formatTime(entry.timestamp)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showChangeDateDialog(entry),
                icon: const Icon(Icons.edit_calendar),
                color: AppColors.waterBlue.withValues(alpha: 0.7),
                tooltip: 'Change Date',
              ),
              IconButton(
                onPressed: () => _deleteEntry(entry),
                icon: const Icon(Icons.delete_outline),
                color: AppColors.deleteRed.withValues(alpha: 0.7),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyStatsSection() {
    if (_periodHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: ExpansionTile(
            initiallyExpanded: _showPeriodHistory,
            onExpansionChanged: (expanded) {
              setState(() => _showPeriodHistory = expanded);
            },
            title: const Text(
              'Period History',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${_periodHistory.length} periods completed'),
            children: [
              ..._periodHistory.map((period) => _buildPeriodTile(period)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodTile(Map<String, dynamic> period) {
    final percentage = period['percentage'] as int;
    final healthy = period['healthy'] as int;
    final processed = period['processed'] as int;
    final periodLabel = period['periodLabel'] as String;
    final frequency = period['frequency'] as String;

    Color statusColor;
    if (percentage >= 80) {
      statusColor = AppColors.successGreen;
    } else if (percentage >= 60) {
      statusColor = AppColors.orange;
    } else {
      statusColor = AppColors.red;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Text(
          '$percentage%',
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(periodLabel),
      subtitle: Text('$healthy healthy, $processed processed • ${frequency == "monthly" ? "Monthly" : "Weekly"}'),
      trailing: Container(
        width: 60,
        height: 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: AppColors.orange.withValues(alpha: 0.3),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: percentage / 100,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: statusColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaySection(String date, List<FoodEntry> entries) {
    final healthyCount = entries.where((e) => e.type == FoodType.healthy).length;
    final processedCount = entries.where((e) => e.type == FoodType.processed).length;
    final total = healthyCount + processedCount;
    final healthyPercentage = total > 0 ? (healthyCount / total * 100).round() : 0;

    return DragTarget<FoodEntry>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final entry = details.data;
        // Don't move if dropping on the same date
        final entryDateKey = _formatDate(entry.timestamp);
        if (entryDateKey != date) {
          _moveEntryToDate(entry, date);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isBeingDraggedOver = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: isBeingDraggedOver
                ? AppColors.successGreen.withValues(alpha: 0.1)
                : null,
            border: isBeingDraggedOver
                ? Border.all(color: AppColors.successGreen, width: 2)
                : null,
            borderRadius: isBeingDraggedOver ? AppStyles.borderRadiusSmall : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(top: 16),
                color: isBeingDraggedOver
                    ? AppColors.successGreen.withValues(alpha: 0.2)
                    : AppColors.normalCardBackground.withValues(alpha: 0.3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isBeingDraggedOver) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.successGreen,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    if (total > 0)
                      Text(
                        '$healthyPercentage% healthy ($healthyCount/$total)',
                        style: TextStyle(
                          fontSize: 14,
                          color: healthyPercentage >= 80
                              ? AppColors.successGreen
                              : healthyPercentage >= 60
                                  ? AppColors.orange
                                  : AppColors.red,
                        ),
                      ),
                  ],
                ),
              ),
              ...entries.map(_buildEntryTile),
              if (isBeingDraggedOver)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: AppStyles.borderRadiusSmall,
                    border: Border.all(
                      color: AppColors.successGreen.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: AppColors.successGreen,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Drop here to move to this date',
                        style: TextStyle(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food History'),
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
          if (_entries.isNotEmpty)
            IconButton(
              onPressed: () {
                DialogUtils.showInfo(
                  context,
                  title: 'Food Tracking Tips',
                  message: 'Track your food intake to maintain a healthy balance:\n\n'
                      '• Aim for 80% healthy foods\n'
                      '• Limit processed foods to 20%\n'
                      '• Counts reset monthly (configurable in settings)\n'
                      '• Swipe or tap delete to remove entries',
                  buttonText: 'Got it',
                );
              },
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
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
              : ListView(
                  children: [
                    _buildWeeklyStatsSection(),
                    ..._groupedEntries.entries
                        .map((entry) => _buildDaySection(entry.key, entry.value)),
                  ],
                ),
    );
  }
}