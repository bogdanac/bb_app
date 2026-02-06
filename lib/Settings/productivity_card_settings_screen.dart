import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'app_customization_service.dart';

class ProductivityCardSettingsScreen extends StatefulWidget {
  const ProductivityCardSettingsScreen({super.key});

  @override
  State<ProductivityCardSettingsScreen> createState() =>
      _ProductivityCardSettingsScreenState();
}

class _ProductivityCardSettingsScreenState
    extends State<ProductivityCardSettingsScreen> {
  bool _isEnabled = true;
  Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  int _startHour = 0;
  int _endHour = 24;
  bool _isLoading = true;

  static const List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled =
        await AppCustomizationService.isCardVisible(AppCustomizationService.cardProductivity);
    final days = await AppCustomizationService.getProductivityDays();
    final (start, end) = await AppCustomizationService.getProductivityHours();

    if (mounted) {
      setState(() {
        _isEnabled = isEnabled;
        _selectedDays = days;
        _startHour = start;
        _endHour = end;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _isEnabled = value);
    await AppCustomizationService.setCardVisible(
        AppCustomizationService.cardProductivity, value);
  }

  Future<void> _toggleDay(int day) async {
    setState(() {
      if (_selectedDays.contains(day)) {
        // Don't allow removing all days
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
      }
    });
    await AppCustomizationService.setProductivityDays(_selectedDays);
  }

  Future<void> _setStartHour(int hour) async {
    if (hour >= _endHour) return; // Start must be before end
    setState(() => _startHour = hour);
    await AppCustomizationService.setProductivityHours(_startHour, _endHour);
  }

  Future<void> _setEndHour(int hour) async {
    if (hour <= _startHour) return; // End must be after start
    setState(() => _endHour = hour);
    await AppCustomizationService.setProductivityHours(_startHour, _endHour);
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour == 24) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productivity Card'),
        backgroundColor: AppColors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master toggle
                  Container(
                    decoration: AppStyles.cardDecoration(),
                    child: SwitchListTile(
                      title: const Text(
                        'Show Productivity Card',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Display productivity timer on home screen',
                      ),
                      value: _isEnabled,
                      onChanged: _toggleEnabled,
                      activeTrackColor: AppColors.purple.withValues(alpha: 0.5),
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.purple;
                        }
                        return null;
                      }),
                    ),
                  ),

                  if (_isEnabled) ...[
                    const SizedBox(height: 24),

                    // Schedule section header
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'VISIBILITY SCHEDULE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey300,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Day selector
                    Container(
                      decoration: AppStyles.cardDecoration(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Days of the Week',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Card will appear on selected days',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey300,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (index) {
                              final day = index + 1; // 1=Monday, 7=Sunday
                              final isSelected = _selectedDays.contains(day);
                              return GestureDetector(
                                onTap: () => _toggleDay(day),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.purple
                                        : AppColors.grey300.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _dayLabels[index],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.grey300,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Time range selector
                    Container(
                      decoration: AppStyles.cardDecoration(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time Range',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Card will appear during these hours',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey300,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Start time
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.grey300,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildTimeDropdown(
                                      value: _startHour,
                                      maxValue: _endHour - 1,
                                      onChanged: _setStartHour,
                                      isStart: true,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.grey300,
                                  size: 20,
                                ),
                              ),
                              // End time
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.grey300,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildTimeDropdown(
                                      value: _endHour,
                                      minValue: _startHour + 1,
                                      onChanged: _setEndHour,
                                      isStart: false,
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

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The productivity card will only appear on home during the scheduled times. On desktop, it\'s always visible.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTimeDropdown({
    required int value,
    int minValue = 0,
    int maxValue = 24,
    required Function(int) onChanged,
    required bool isStart,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey300.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.grey300),
          items: List.generate(
            isStart ? 24 : 25, // Start: 0-23, End: 1-24
            (index) {
              final hour = isStart ? index : index + 1;
              if (hour < minValue || hour > maxValue) return null;
              return DropdownMenuItem(
                value: hour,
                child: Text(
                  _formatHour(hour),
                  style: const TextStyle(fontSize: 14),
                ),
              );
            },
          ).whereType<DropdownMenuItem<int>>().toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
