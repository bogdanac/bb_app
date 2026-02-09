import 'package:flutter/material.dart';
import 'chore_data_models.dart';
import 'chore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/time_picker_utils.dart';

class ChoreSettingsScreen extends StatefulWidget {
  const ChoreSettingsScreen({super.key});

  @override
  State<ChoreSettingsScreen> createState() => _ChoreSettingsScreenState();
}

class _ChoreSettingsScreenState extends State<ChoreSettingsScreen> {
  ChoreSettings? _settings;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  final List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final settings = await ChoreService.loadSettings();
    final stats = await ChoreService.getStats();

    setState(() {
      _settings = settings;
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_settings != null) {
      await ChoreService.saveSettings(_settings!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    }
  }

  Future<void> _pickNotificationTime() async {
    if (_settings == null) return;

    final picked = await TimePickerUtils.showStyledTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings!.notificationHour,
        minute: _settings!.notificationMinute,
      ),
    );

    if (picked != null) {
      setState(() {
        _settings = _settings!.copyWith(
          notificationHour: picked.hour,
          notificationMinute: picked.minute,
        );
      });
      await _saveSettings();
    }
  }

  void _toggleDay(int dayNumber) {
    if (_settings == null) return;

    setState(() {
      final days = Set<int>.from(_settings!.preferredCleaningDays);
      if (days.contains(dayNumber)) {
        days.remove(dayNumber);
      } else {
        days.add(dayNumber);
      }
      _settings = _settings!.copyWith(preferredCleaningDays: days);
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null || _stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chores Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preferred Cleaning Days Section
          Text(
            'Preferred Cleaning Days',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Select days when you have time for cleaning. The home card will only appear on these days.',
            style: TextStyle(color: AppColors.greyText, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Day selector chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final dayNumber = index + 1; // 1 = Monday, 7 = Sunday
              final isSelected =
                  _settings!.preferredCleaningDays.contains(dayNumber);

              return FilterChip(
                label: Text(_dayNames[index]),
                selected: isSelected,
                onSelected: (_) => _toggleDay(dayNumber),
                selectedColor: AppColors.waterBlue.withValues(alpha: 0.3),
                checkmarkColor: AppColors.waterBlue,
              );
            }),
          ),

          const SizedBox(height: 32),

          // Notifications Section
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Get reminders for overdue chores'),
            value: _settings!.notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _settings =
                    _settings!.copyWith(notificationsEnabled: value);
              });
              _saveSettings();
            },
          ),

          if (_settings!.notificationsEnabled) ...[
            ListTile(
              title: const Text('Notification Time'),
              subtitle: Text(_formatTime()),
              trailing: const Icon(Icons.access_time),
              onTap: _pickNotificationTime,
            ),
          ],

          const SizedBox(height: 32),

          // Statistics Section
          Text(
            'Statistics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          _buildStatCard(
            'Total Chores',
            _stats!['totalChores'].toString(),
            Icons.cleaning_services_rounded,
            AppColors.waterBlue,
          ),

          _buildStatCard(
            'Average Condition',
            '${(_stats!['avgCondition'] * 100).round()}%',
            Icons.percent_rounded,
            _getConditionColor(_stats!['avgCondition']),
          ),

          _buildStatCard(
            'Total Completions',
            _stats!['totalCompletions'].toString(),
            Icons.check_circle_rounded,
            AppColors.successGreen,
          ),

          _buildStatCard(
            'Overdue',
            _stats!['overdueCount'].toString(),
            Icons.warning_rounded,
            _stats!['overdueCount'] > 0 ? Colors.red : AppColors.greyText,
          ),

          _buildStatCard(
            'Critical',
            _stats!['criticalCount'].toString(),
            Icons.priority_high_rounded,
            _stats!['criticalCount'] > 0 ? Colors.orange : AppColors.greyText,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime() {
    final hour = _settings!.notificationHour;
    final minute = _settings!.notificationMinute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  Color _getConditionColor(double condition) {
    if (condition >= 0.7) return Colors.green;
    if (condition >= 0.4) return Colors.orange;
    return Colors.red;
  }
}
