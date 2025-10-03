import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import 'scheduled_fastings_service.dart';
import 'fasting_utils.dart';
import '../shared/date_picker_utils.dart';

class ScheduledFastingsScreen extends StatefulWidget {
  const ScheduledFastingsScreen({super.key});

  @override
  State<ScheduledFastingsScreen> createState() => _ScheduledFastingsScreenState();
}

class _ScheduledFastingsScreenState extends State<ScheduledFastingsScreen> {
  List<ScheduledFasting> _scheduledFastings = [];
  bool _isLoading = true;
  int _preferredFastingDay = 5; // Default to Friday (1=Monday, 7=Sunday)
  int _preferredMonthlyFastingDay = 25; // Default to 25th (1-31)

  @override
  void initState() {
    super.initState();
    _loadScheduledFastings();
    _loadPreferredFastingDay();
    _loadPreferredMonthlyFastingDay();
  }

  Future<void> _loadScheduledFastings() async {
    setState(() => _isLoading = true);
    try {
      // Get all scheduled fastings and filter to include the last 3 days + next 2 months
      final allFastings = await ScheduledFastingsService.getScheduledFastings();
      final now = DateTime.now();
      final threeDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 3));
      final twoMonthsFromNow = DateTime(now.year, now.month + 2, now.day);

      final fastings = allFastings
          .where((f) {
            final isInRange = f.date.isAfter(threeDaysAgo.subtract(const Duration(days: 1))) &&
                             f.date.isBefore(twoMonthsFromNow.add(const Duration(days: 1)));
            return isInRange;
          })
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _scheduledFastings = fastings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading scheduled fastings: $e')),
        );
      }
    }
  }

  Future<void> _loadPreferredFastingDay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredFastingDay = prefs.getInt('preferred_fasting_day') ?? 5; // Default to Friday
    });
  }

  Future<void> _savePreferredFastingDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('preferred_fasting_day', day);

    setState(() {
      _preferredFastingDay = day;
    });

    // Regenerate the fasting schedule with new preferred day
    await ScheduledFastingsService.regenerateSchedule();
  }

  Future<void> _loadPreferredMonthlyFastingDay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredMonthlyFastingDay = prefs.getInt('preferred_monthly_fasting_day') ?? 25; // Default to 25th
    });
  }

  Future<void> _savePreferredMonthlyFastingDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('preferred_monthly_fasting_day', day);

    setState(() {
      _preferredMonthlyFastingDay = day;
    });

    // Regenerate the fasting schedule with new preferred monthly day
    await ScheduledFastingsService.regenerateSchedule();
  }

  void _showFastingPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) => _FastingPreferencesDialog(
        initialWeeklyDay: _preferredFastingDay,
        initialMonthlyDay: _preferredMonthlyFastingDay,
        onSave: (weeklyDay, monthlyDay) async {
          bool changed = false;
          if (weeklyDay != _preferredFastingDay) {
            await _savePreferredFastingDay(weeklyDay);
            changed = true;
          }
          if (monthlyDay != _preferredMonthlyFastingDay) {
            await _savePreferredMonthlyFastingDay(monthlyDay);
            changed = true;
          }

          if (changed && mounted) {
            await _loadScheduledFastings();
          }
        },
      ),
    );
  }

  String _getDayName(int dayNumber) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[dayNumber - 1]; // dayNumber is 1-7, array is 0-6
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) {
      return 'th';
    }
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Future<void> _regenerateSchedule() async {
    final shouldRegenerate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: const Text(
          'Fix Overlapping Fasts',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will regenerate all auto-scheduled fasts to fix overlapping issues. Your manually added fasts will be preserved.\n\nContinue?',
          style: TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('Fix Schedule'),
          ),
        ],
      ),
    );

    if (shouldRegenerate == true) {
      setState(() => _isLoading = true);
      try {
        await ScheduledFastingsService.regenerateSchedule();
        await _loadScheduledFastings();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Schedule fixed! Overlapping fasts have been resolved.'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fixing schedule: $e'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showRescheduleDialog(ScheduledFasting fasting) async {
    try {
      final DateTime? newDate = await DatePickerUtils.showStyledDatePicker(
        context: context,
        initialDate: fasting.date,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (newDate != null && mounted) {
        final updatedFasting = fasting.copyWith(
          date: newDate,
          isAutoGenerated: false, // Mark as manually modified
        );

        await ScheduledFastingsService.updateScheduledFasting(updatedFasting);
        await _loadScheduledFastings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fast rescheduled to ${updatedFasting.formattedDate}'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      // Silently handle errors - user will see if reschedule failed by the UI not updating
    }
  }

  Future<void> _showFastTypeDialog(ScheduledFasting fasting) async {
    final List<String> fastTypes = [
      '24h weekly wast',
      '36h monthly fast', 
      '48h quarterly fast',
      '3-day water fast',
    ];

    final selectedType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: const Text(
          'Change Fast Type',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fastTypes.map((type) => ListTile(
            title: Text(
              type,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              FastingUtils.formatDuration(FastingUtils.getFastDuration(type)),
              style: const TextStyle(color: AppColors.white54),
            ),
            leading: Icon(
              type == fasting.fastType ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: AppColors.coral,
            ),
            onTap: () => Navigator.pop(context, type),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.white54)),
          ),
        ],
      ),
    );

    if (selectedType != null && selectedType != fasting.fastType) {
      final updatedFasting = fasting.copyWith(
        fastType: selectedType,
        isAutoGenerated: false,
      );
      
      await ScheduledFastingsService.updateScheduledFasting(updatedFasting);
      await _loadScheduledFastings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fast type changed to $selectedType'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _deleteFasting(ScheduledFasting fasting) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: const Text(
          'Delete Scheduled Fast',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete the ${fasting.shortFastType} fast scheduled for ${fasting.formattedDate}?',
          style: const TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await ScheduledFastingsService.deleteScheduledFasting(fasting.id);
      await _loadScheduledFastings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fast deleted for ${fasting.formattedDate}'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFastingEnabled(ScheduledFasting fasting) async {
    final updatedFasting = fasting.copyWith(
      isEnabled: !fasting.isEnabled,
    );
    
    await ScheduledFastingsService.updateScheduledFasting(updatedFasting);
    await _loadScheduledFastings();
  }

  Widget _buildFastingCard(ScheduledFasting fasting) {
    final now = DateTime.now();
    final isToday = fasting.date.year == now.year && 
                   fasting.date.month == now.month && 
                   fasting.date.day == now.day;
    final isPast = fasting.date.isBefore(now);
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isPast 
              ? AppColors.greyText.withValues(alpha: 0.05)
              : isToday 
                  ? AppColors.coral.withValues(alpha: 0.08)
                  : AppColors.dialogCardBackground,
          border: isToday 
              ? Border.all(color: AppColors.coral.withValues(alpha: 0.3))
              : null,
        ),
        child: Opacity(
          opacity: fasting.isEnabled ? 1.0 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Date and day
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isToday) ...[
                                Icon(
                                  Icons.today_rounded,
                                  size: 16,
                                  color: AppColors.coral,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                fasting.formattedDate,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? AppColors.coral : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (fasting.isAutoGenerated)
                            const Text(
                              'Auto-scheduled',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.white54,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Fast type
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getFastTypeColor(fasting.fastType).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getFastTypeColor(fasting.fastType).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        fasting.shortFastType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getFastTypeColor(fasting.fastType),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Duration
                Text(
                  'Duration: ${FastingUtils.formatDuration(fasting.duration)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.white70,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    // Enable/Disable toggle
                    InkWell(
                      onTap: () => _toggleFastingEnabled(fasting),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: fasting.isEnabled 
                              ? AppColors.successGreen.withValues(alpha: 0.15)
                              : AppColors.greyText.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              fasting.isEnabled ? Icons.check_circle : Icons.pause_circle,
                              size: 16,
                              color: fasting.isEnabled ? AppColors.successGreen : AppColors.white54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              fasting.isEnabled ? 'Active' : 'Disabled',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: fasting.isEnabled ? AppColors.successGreen : AppColors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Reschedule button
                    InkWell(
                      onTap: () => _showRescheduleDialog(fasting),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 16, color: AppColors.purple),
                            SizedBox(width: 6),
                            Text(
                              'Reschedule',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Change type button
                    InkWell(
                      onTap: () => _showFastTypeDialog(fasting),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz, size: 16, color: AppColors.orange),
                            SizedBox(width: 6),
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Delete button
                    InkWell(
                      onTap: () => _deleteFasting(fasting),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getFastTypeColor(String fastType) {
    switch (fastType) {
      case '24h weekly wast':
        return AppColors.coral;
      case '36h monthly fast':
        return AppColors.orange;
      case '48h quarterly fast':
        return AppColors.purple;
      case '3-day water fast':
        return AppColors.pink;
      default:
        return AppColors.coral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        backgroundColor: AppColors.dialogBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scheduled Fastings'),
        actions: [
          IconButton(
            onPressed: _showFastingPreferencesDialog,
            icon: const Icon(Icons.settings),
            tooltip: 'Fasting Preferences',
          ),
          IconButton(
            onPressed: _regenerateSchedule,
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Fix Overlapping Fasts',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.coral),
            )
          : _scheduledFastings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 64,
                        color: AppColors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No scheduled fastings found',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.white70,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your fasting schedule will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white54,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadScheduledFastings,
                  color: AppColors.coral,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Preferences Summary Card
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.dialogCardBackground,
                          ),
                          child: InkWell(
                            onTap: _showFastingPreferencesDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.settings,
                                      color: AppColors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Fasting Preferences',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Weekly: ${_getDayName(_preferredFastingDay)} • Monthly: $_preferredMonthlyFastingDay${_getOrdinalSuffix(_preferredMonthlyFastingDay)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.white54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Text(
                        'Recent & Upcoming (${_scheduledFastings.length} fasts)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._scheduledFastings.map(_buildFastingCard),
                    ],
                  ),
                ),
    );
  }
}

class _FastingPreferencesDialog extends StatefulWidget {
  final int initialWeeklyDay;
  final int initialMonthlyDay;
  final Function(int weeklyDay, int monthlyDay) onSave;

  const _FastingPreferencesDialog({
    required this.initialWeeklyDay,
    required this.initialMonthlyDay,
    required this.onSave,
  });

  @override
  State<_FastingPreferencesDialog> createState() => _FastingPreferencesDialogState();
}

class _FastingPreferencesDialogState extends State<_FastingPreferencesDialog> {
  late int selectedWeeklyDay;
  late int selectedMonthlyDay;

  @override
  void initState() {
    super.initState();
    selectedWeeklyDay = widget.initialWeeklyDay;
    selectedMonthlyDay = widget.initialMonthlyDay;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      title: const Text(
        'Fasting Preferences',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Fasting Day Section
            const Text(
              'Weekly Fasting Day',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your preferred day for 24-hour weekly fasts:',
              style: TextStyle(fontSize: 14, color: AppColors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayNumber = index + 1;
                final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index];
                final isSelected = dayNumber == selectedWeeklyDay;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedWeeklyDay = dayNumber;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.orange
                          : AppColors.dialogCardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.orange
                            : AppColors.greyText.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Monthly Fasting Day Section
            const Text(
              'Monthly Fasting Day',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your preferred day of the month for longer fasts:',
              style: TextStyle(fontSize: 14, color: AppColors.white70),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              width: double.maxFinite,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 31,
                itemBuilder: (context, index) {
                  final dayNumber = index + 1;
                  final isSelected = dayNumber == selectedMonthlyDay;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedMonthlyDay = dayNumber;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.purple
                            : AppColors.dialogCardBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.purple
                              : AppColors.greyText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dayNumber.toString(),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.white54)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSave(selectedWeeklyDay, selectedMonthlyDay);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.coral),
          child: const Text('Save'),
        ),
      ],
    );
  }
}