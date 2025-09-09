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

  void _deleteFast(int index) {
    final fast = _editableHistory[index];
    final fastType = fast['type'] ?? 'Fast';

    showDialog(
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
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete this $fastType?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete(index);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.lightCoral),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performDelete(int index) {
    setState(() {
      _editableHistory.removeAt(index);
    });
    _saveHistory();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fast deleted successfully'),
        backgroundColor: AppColors.lightGreen,
        duration: Duration(seconds: 2),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isCompleted
                ? [AppColors.successGreen.withValues(alpha: 0.1), AppColors.successGreen.withValues(alpha: 0.05)]
                : [Colors.orange.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.05)],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: isCompleted ? AppColors.lightGreen : Colors.orange,
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.schedule_rounded,
              color: Colors.white,
            ),
          ),
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
                    color: isCompleted ? AppColors.lightGreen : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completionPercentage%',
                    style: const TextStyle(
                      color: Colors.white,
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
                  Icon(Icons.stop_rounded, size: 16, color: Colors.red),
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
                  Icon(Icons.timer_rounded, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Duration: ${_formatDuration(actualDuration)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editFast(index);
              } else if (value == 'delete') {
                _deleteFast(index);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, size: 20, color: AppColors.lightCoral),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.lightCoral)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.more_vert_rounded, size: 20),
            ),
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasting History'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_editableHistory.isNotEmpty) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear_all') {
                  _showClearAllDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded, size: 20, color: AppColors.lightCoral),
                      SizedBox(width: 8),
                      Text('Clear All', style: TextStyle(color: AppColors.lightCoral)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _editableHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No fasting history yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first fast to see it here',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Start Fasting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pastelGreen,
                foregroundColor: Colors.white,
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
                colors: [Colors.blue.withValues(alpha: 0.2), Colors.purple.withValues(alpha: 0.2)],
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
                  Colors.blue,
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
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
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_rounded,
              size: 48,
              color: AppColors.lightCoral,
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to delete ALL fasting history?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This will permanently delete ${_editableHistory.length} fasting records. This action cannot be undone.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _editableHistory.clear();
              });
              _saveHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All fasting history cleared'),
                  backgroundColor: AppColors.lightCoral,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.lightCoral),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}