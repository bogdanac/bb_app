import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'food_tracking_service.dart';
import 'food_tracking_data_models.dart';

class FoodTrackingHistoryScreen extends StatefulWidget {
  const FoodTrackingHistoryScreen({super.key});

  @override
  State<FoodTrackingHistoryScreen> createState() => _FoodTrackingHistoryScreenState();
}

class _FoodTrackingHistoryScreenState extends State<FoodTrackingHistoryScreen> {
  List<FoodEntry> _entries = [];
  bool _isLoading = true;
  Map<String, List<FoodEntry>> _groupedEntries = {};
  List<Map<String, dynamic>> _weeklyStats = [];
  bool _showWeeklyStats = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final entries = await FoodTrackingService.getAllEntries();
    final weeklyStats = await FoodTrackingService.getAllWeeklyStats();
    _groupedEntries = _groupEntriesByDate(entries);
    setState(() {
      _entries = entries;
      _weeklyStats = weeklyStats;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Are you sure you want to delete this ${entry.type.name} food entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redPrimary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FoodTrackingService.deleteEntry(entry.id);
      HapticFeedback.lightImpact();
      await _loadEntries();
    }
  }

  Widget _buildEntryTile(FoodEntry entry) {
    final isHealthy = entry.type == FoodType.healthy;
    final color = isHealthy ? AppColors.successGreen : AppColors.orange;
    final icon = isHealthy ? Icons.restaurant : Icons.fastfood;

    return Card(
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
        trailing: IconButton(
          onPressed: () => _deleteEntry(entry),
          icon: const Icon(Icons.delete_outline),
          color: AppColors.redPrimary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildWeeklyStatsSection() {
    if (_weeklyStats.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: ExpansionTile(
            initiallyExpanded: _showWeeklyStats,
            onExpansionChanged: (expanded) {
              setState(() => _showWeeklyStats = expanded);
            },
            title: const Text(
              'Weekly Statistics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${_weeklyStats.length} weeks of data'),
            children: [
              ..._weeklyStats.map((week) => _buildWeeklyStatTile(week)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyStatTile(Map<String, dynamic> week) {
    final healthyPercentage = week['healthyPercentage'] as int;
    final healthy = week['healthy'] as int;
    final processed = week['processed'] as int;
    final weekLabel = week['weekLabel'] as String;

    Color statusColor;
    if (healthyPercentage >= 80) {
      statusColor = AppColors.successGreen;
    } else if (healthyPercentage >= 60) {
      statusColor = AppColors.orange;
    } else {
      statusColor = AppColors.redPrimary;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Text(
          '$healthyPercentage%',
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(weekLabel),
      subtitle: Text('$healthy healthy, $processed processed'),
      trailing: Container(
        width: 60,
        height: 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: AppColors.orange.withValues(alpha: 0.3),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: healthyPercentage / 100,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(top: 16),
          color: AppColors.darkSurface.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                            : AppColors.redPrimary,
                  ),
                ),
            ],
          ),
        ),
        ...entries.map(_buildEntryTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food History'),
        backgroundColor: AppColors.successGreen.withValues(alpha: 0.2),
        actions: [
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Food Tracking Tips'),
                    content: const Text(
                      'Track your food intake to maintain a healthy balance:\n\n'
                      '• Aim for 80% healthy foods\n'
                      '• Limit processed foods to 20%\n'
                      '• Counts reset weekly\n'
                      '• Swipe or tap delete to remove entries',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.info_outline),
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