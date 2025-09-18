// fasting_history_screen.dart - Enhanced cu buton de delete
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'fast_edit_dialog.dart';
import 'fasting_notifier.dart';
import '../theme/app_colors.dart';

class FastingHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> history;

  const FastingHistoryScreen({super.key, required this.history});

  @override
  State<FastingHistoryScreen> createState() => _FastingHistoryScreenState();
}

class _FastingHistoryScreenState extends State<FastingHistoryScreen> {
  List<Map<String, dynamic>> _editableHistory = [];
  final FastingNotifier _notifier = FastingNotifier();

  @override
  void initState() {
    super.initState();
    _editableHistory = List.from(widget.history);
  }

  void _editFast(int index) {
    final fast = _editableHistory[index];
    final startTime = DateTime.parse(fast['startTime']);
    final endTime = DateTime.parse(fast['endTime']);

    showDialog(
      context: context,
      builder: (context) => FastEditDialog(
        startTime: startTime,
        endTime: endTime,
        onSave: (newStart, newEnd) {
          setState(() {
            _editableHistory[index]['startTime'] = newStart.toIso8601String();
            _editableHistory[index]['endTime'] = newEnd.toIso8601String();
            _editableHistory[index]['actualDuration'] = newEnd.difference(newStart).inMinutes;
          });
          _saveHistory();
        },
      ),
    );
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStr = _editableHistory.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('fasting_history', historyStr);

    // Notify other components that history has changed
    _notifier.notifyFastingStateChanged();
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Widget _buildFastCard(int index) {
    final fast = _editableHistory[index];
    final startTime = DateTime.parse(fast['startTime']);
    final endTime = DateTime.parse(fast['endTime']);
    final actualDuration = fast['actualDuration'] as int;
    final plannedDuration = fast['plannedDuration'] as int;
    final isCompleted = actualDuration >= plannedDuration * 0.8;
    final completionPercentage = (actualDuration / plannedDuration * 100).round();

    return Dismissible(
      key: Key('fast_${fast['startTime']}_$index'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.8},
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deleting
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Fast'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_rounded,
                  size: 48,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete this ${fast['type'] ?? 'Fast'}?',
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
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        setState(() {
          _editableHistory.removeAt(index);
        });
        _saveHistory();
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
            Icon(Icons.delete_rounded, color: AppColors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: AppColors.white, fontSize: 12)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GestureDetector(
          onTap: () => _editFast(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: isCompleted
                    ? [AppColors.successGreen.withValues(alpha: 0.1), AppColors.successGreen.withValues(alpha: 0.05)]
                    : [AppColors.orange.withValues(alpha: 0.1), AppColors.orange.withValues(alpha: 0.05)],
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      fast['type'] ?? 'Fast',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (completionPercentage != 100) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.lightGreen : AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completionPercentage%',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.pastelGreen),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Started: ${DateFormat('MMM dd, yyyy HH:mm').format(startTime)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.stop_rounded, size: 16, color: AppColors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Ended: ${DateFormat('MMM dd, yyyy HH:mm').format(endTime)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer_rounded, size: 16, color: AppColors.waterBlue),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${_formatDuration(actualDuration)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: null,
              isThreeLine: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasting History'),
        backgroundColor: AppColors.transparent,
        actions: [],
      ),
      body: _editableHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded, size: 64, color: AppColors.greyText),
            const SizedBox(height: 16),
            Text(
              'No fasting history yet',
              style: TextStyle(fontSize: 18, color: AppColors.greyText, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first fast to see it here',
              style: TextStyle(color: AppColors.greyText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Start Fasting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pastelGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.waterBlue.withValues(alpha: 0.2), AppColors.waterBlue.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Fasts',
                  '${_editableHistory.length}',
                  Icons.flag_rounded,
                  AppColors.waterBlue,
                ),
                Container(width: 1, height: 40, color: AppColors.greyText),
                _buildSummaryItem(
                  'Success Rate',
                  '${(_editableHistory.where((f) => (f['actualDuration'] as int) >= (f['plannedDuration'] as int) * 0.8).length / _editableHistory.length * 100).round()}%',
                  Icons.trending_up_rounded,
                  AppColors.lightGreen,
                ),
              ],
            ),
          ),

          // History list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _editableHistory.length,
              itemBuilder: (context, index) => _buildFastCard(index),
            ),
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

}