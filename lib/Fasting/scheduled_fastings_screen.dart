import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'scheduled_fastings_service.dart';
import 'fasting_utils.dart';
import '../shared/date_picker_utils.dart';
import '../shared/snackbar_utils.dart';

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
        SnackBarUtils.showError(context, 'Error loading scheduled fastings: $e');
      }
    }
  }

  Future<void> _loadPreferredFastingDay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredFastingDay = prefs.getInt('preferred_fasting_day') ?? 5; // Default to Friday
    });
  }

  Future<void> _loadPreferredMonthlyFastingDay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredMonthlyFastingDay = prefs.getInt('preferred_monthly_fasting_day') ?? 25; // Default to 25th
    });
  }

  void _openFastingPreferencesScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FastingPreferencesScreen(
          initialWeeklyDay: _preferredFastingDay,
          initialMonthlyDay: _preferredMonthlyFastingDay,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadPreferredFastingDay();
      await _loadPreferredMonthlyFastingDay();
      await _loadScheduledFastings();
    }
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
          SnackBarUtils.showSuccess(context, '✅ Schedule fixed! Overlapping fasts have been resolved.');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          SnackBarUtils.showError(context, 'Error fixing schedule: $e');
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
          SnackBarUtils.showSuccess(context, 'Fast rescheduled to ${updatedFasting.formattedDate}');
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
        SnackBarUtils.showSuccess(context, 'Fast type changed to $selectedType');
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
        SnackBarUtils.showError(context, 'Fast deleted for ${fasting.formattedDate}');
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
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusMedium,
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
                            Text(
                              fasting.isEstimate ? 'Estimated (cycle-based)' : 'Auto-scheduled',
                              style: TextStyle(
                                fontSize: 11,
                                color: fasting.isEstimate ? AppColors.pink : AppColors.white54,
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
                        borderRadius: AppStyles.borderRadiusSmall,
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
                          borderRadius: AppStyles.borderRadiusSmall,
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
                          borderRadius: AppStyles.borderRadiusSmall,
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
                          borderRadius: AppStyles.borderRadiusSmall,
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
                          borderRadius: AppStyles.borderRadiusSmall,
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
            onPressed: _openFastingPreferencesScreen,
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
                        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: AppStyles.borderRadiusMedium,
                            color: AppColors.dialogCardBackground,
                          ),
                          child: InkWell(
                            onTap: _openFastingPreferencesScreen,
                            borderRadius: AppStyles.borderRadiusMedium,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange.withValues(alpha: 0.15),
                                      borderRadius: AppStyles.borderRadiusSmall,
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

/// Full screen for fasting preferences
class FastingPreferencesScreen extends StatefulWidget {
  final int initialWeeklyDay;
  final int initialMonthlyDay;

  const FastingPreferencesScreen({
    super.key,
    required this.initialWeeklyDay,
    required this.initialMonthlyDay,
  });

  @override
  State<FastingPreferencesScreen> createState() => _FastingPreferencesScreenState();
}

class _FastingPreferencesScreenState extends State<FastingPreferencesScreen> {
  late int _selectedWeeklyDay;
  late int _selectedMonthlyDay;
  late bool _useMenstrualScheduling;
  late String _selectedMenstrualPhase;
  late int _selectedPhaseDay;

  // Menstrual phases with their day ranges
  static const Map<String, int> _phaseDayLimits = {
    'Menstrual Phase': 5,
    'Follicular Phase': 6,
    'Ovulation Window': 5,
    'Early Luteal Phase': 5,
    'Late Luteal Phase': 7,
  };

  @override
  void initState() {
    super.initState();
    _selectedWeeklyDay = widget.initialWeeklyDay;
    _selectedMonthlyDay = widget.initialMonthlyDay;
    // Default to fixed day scheduling (not menstrual-based)
    _useMenstrualScheduling = false;
    _selectedMenstrualPhase = 'Late Luteal Phase';
    _selectedPhaseDay = 1;
    _loadMenstrualSettings();
  }

  Future<void> _loadMenstrualSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useMenstrualScheduling = prefs.getBool('fasting_use_menstrual_scheduling') ?? false;
      _selectedMenstrualPhase = prefs.getString('fasting_menstrual_phase') ?? 'Late Luteal Phase';
      _selectedPhaseDay = prefs.getInt('fasting_menstrual_phase_day') ?? 1;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('preferred_fasting_day', _selectedWeeklyDay);
    await prefs.setInt('preferred_monthly_fasting_day', _selectedMonthlyDay);
    await prefs.setBool('fasting_use_menstrual_scheduling', _useMenstrualScheduling);
    await prefs.setString('fasting_menstrual_phase', _selectedMenstrualPhase);
    await prefs.setInt('fasting_menstrual_phase_day', _selectedPhaseDay);

    // Regenerate schedule with new settings
    await ScheduledFastingsService.regenerateSchedule();

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
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
        title: const Text('Fasting Preferences'),
        actions: [
          TextButton(
            onPressed: _savePreferences,
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Long Fasts Schedule Explanation Card
            _buildExplanationCard(),

            const SizedBox(height: 24),

            // Weekly Fasting Day Section
            _buildWeeklyDaySection(),

            const SizedBox(height: 24),

            // Long Fasts Scheduling Mode Toggle
            _buildSchedulingModeToggle(),

            const SizedBox(height: 16),

            // Fixed Day or Menstrual Phase selector based on toggle
            if (_useMenstrualScheduling)
              _buildMenstrualPhaseSelector()
            else
              _buildFixedDaySelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusMedium,
          gradient: LinearGradient(
            colors: [
              AppColors.purple.withValues(alpha: 0.15),
              AppColors.pink.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.purple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Recommended Long Fasts Schedule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScheduleItem(
              '36h Monthly',
              'Once per month for metabolic reset',
              AppColors.orange,
            ),
            const SizedBox(height: 8),
            _buildScheduleItem(
              '48h Quarterly',
              'Every 3 months for deeper autophagy',
              AppColors.purple,
            ),
            const SizedBox(height: 8),
            _buildScheduleItem(
              '72h (3-day)',
              'Twice per year for maximum cellular renewal',
              AppColors.pink,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dialogCardBackground,
                borderRadius: AppStyles.borderRadiusSmall,
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Long fasts are scheduled on the day you choose below. You can pick a fixed day of the month or sync with your menstrual cycle.',
                      style: TextStyle(fontSize: 12, color: AppColors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String title, String description, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: const TextStyle(
                    color: AppColors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyDaySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusMedium,
          color: AppColors.dialogCardBackground,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Fasting Day',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose your preferred day for 24-hour weekly fasts:',
              style: TextStyle(fontSize: 13, color: AppColors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayNumber = index + 1;
                final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index];
                final isSelected = dayNumber == _selectedWeeklyDay;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWeeklyDay = dayNumber;
                                          });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.orange : AppColors.dialogBackground,
                      borderRadius: AppStyles.borderRadiusSmall,
                      border: Border.all(
                        color: isSelected ? AppColors.orange : AppColors.greyText.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingModeToggle() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusMedium,
          color: AppColors.dialogCardBackground,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Long Fasts Scheduling',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how to schedule your monthly, quarterly, and semi-annual longer fasts:',
              style: TextStyle(fontSize: 13, color: AppColors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _useMenstrualScheduling = false;
                                              });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_useMenstrualScheduling
                            ? AppColors.purple
                            : AppColors.dialogBackground,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: !_useMenstrualScheduling
                              ? AppColors.purple
                              : AppColors.greyText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: !_useMenstrualScheduling ? Colors.white : AppColors.white54,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fixed Day',
                            style: TextStyle(
                              fontWeight: !_useMenstrualScheduling ? FontWeight.bold : FontWeight.normal,
                              color: !_useMenstrualScheduling ? Colors.white : AppColors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _useMenstrualScheduling = true;
                                              });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _useMenstrualScheduling
                            ? AppColors.pink
                            : AppColors.dialogBackground,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: _useMenstrualScheduling
                              ? AppColors.pink
                              : AppColors.greyText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: _useMenstrualScheduling ? Colors.white : AppColors.white54,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Menstrual Cycle',
                            style: TextStyle(
                              fontWeight: _useMenstrualScheduling ? FontWeight.bold : FontWeight.normal,
                              color: _useMenstrualScheduling ? Colors.white : AppColors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedDaySelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusMedium,
          color: AppColors.dialogCardBackground,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.purple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Day of Month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Currently set to: $_selectedMonthlyDay${_getOrdinalSuffix(_selectedMonthlyDay)} of each month',
              style: const TextStyle(fontSize: 13, color: AppColors.white70),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: 31,
                itemBuilder: (context, index) {
                  final dayNumber = index + 1;
                  final isSelected = dayNumber == _selectedMonthlyDay;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMonthlyDay = dayNumber;
                                              });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.purple : AppColors.dialogBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? AppColors.purple : AppColors.greyText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dayNumber.toString(),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                            fontSize: 12,
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
    );
  }

  Widget _buildMenstrualPhaseSelector() {
    final maxDays = _phaseDayLimits[_selectedMenstrualPhase] ?? 5;
    // Ensure selected day doesn't exceed max for current phase
    if (_selectedPhaseDay > maxDays) {
      _selectedPhaseDay = maxDays;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: AppStyles.borderRadiusMedium,
          color: AppColors.dialogCardBackground,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppColors.pink, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Menstrual Phase & Day',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Long fasts will be scheduled on a specific day of the selected menstrual phase. Dates will be estimated and recalculated when you start a new period.',
              style: TextStyle(fontSize: 12, color: AppColors.white70),
            ),
            const SizedBox(height: 16),

            // Phase selector
            const Text(
              'Select Phase:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _phaseDayLimits.keys.map((phase) {
                final isSelected = phase == _selectedMenstrualPhase;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMenstrualPhase = phase;
                      // Reset day if it exceeds new phase limit
                      final newMax = _phaseDayLimits[phase] ?? 5;
                      if (_selectedPhaseDay > newMax) {
                        _selectedPhaseDay = 1;
                      }
                                          });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.pink : AppColors.dialogBackground,
                      borderRadius: AppStyles.borderRadiusSmall,
                      border: Border.all(
                        color: isSelected ? AppColors.pink : AppColors.greyText.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      phase,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Day within phase selector
            Text(
              'Select Day within $_selectedMenstrualPhase:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(maxDays, (index) {
                final dayNumber = index + 1;
                final isSelected = dayNumber == _selectedPhaseDay;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPhaseDay = dayNumber;
                                          });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.pink : AppColors.dialogBackground,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected ? AppColors.pink : AppColors.greyText.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Day $dayNumber',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // Info box about estimates
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusSmall,
                border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.pink, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scheduled for Day $_selectedPhaseDay of $_selectedMenstrualPhase. Dates will show as estimates until your next period starts.',
                      style: const TextStyle(fontSize: 11, color: AppColors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}