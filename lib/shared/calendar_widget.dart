import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../Settings/app_customization_service.dart';
import 'date_format_utils.dart';

/// A reusable calendar widget with customizable day rendering.
///
/// Features:
/// - Configurable first day of week (Monday or Sunday)
/// - Month navigation with prev/next buttons
/// - Customizable day cell rendering via [dayBuilder]
/// - Optional tap handling via [onDayTap]
/// - Consistent styling across the app
class CalendarWidget extends StatefulWidget {
  /// The currently focused month
  final DateTime focusedMonth;

  /// Called when the user navigates to a different month
  final ValueChanged<DateTime>? onMonthChanged;

  /// Builder for rendering each day cell.
  /// Return null to show empty cell (for days outside the month).
  final Widget? Function(DateTime date)? dayBuilder;

  /// Called when a day is tapped
  final ValueChanged<DateTime>? onDayTap;

  /// Whether to allow navigating to future months
  final bool allowFutureMonths;

  /// Whether to show the month navigation header
  final bool showHeader;

  /// Minimum date that can be navigated to (earliest month)
  final DateTime? minDate;

  /// Cell aspect ratio (width / height)
  final double cellAspectRatio;

  /// Spacing between cells
  final double cellSpacing;

  /// Padding around the calendar
  final EdgeInsets padding;

  const CalendarWidget({
    super.key,
    required this.focusedMonth,
    this.onMonthChanged,
    this.dayBuilder,
    this.onDayTap,
    this.allowFutureMonths = false,
    this.showHeader = true,
    this.minDate,
    this.cellAspectRatio = 1.0,
    this.cellSpacing = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  int _firstDayOfWeek = 1; // 1 = Monday, 7 = Sunday

  @override
  void initState() {
    super.initState();
    _loadFirstDayOfWeek();
  }

  Future<void> _loadFirstDayOfWeek() async {
    final firstDay = await AppCustomizationService.getCalendarFirstDayOfWeek();
    if (mounted) {
      setState(() {
        _firstDayOfWeek = firstDay;
      });
    }
  }

  /// Get weekday headers based on first day of week setting
  List<String> get _weekdayHeaders {
    const mondayFirst = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const sundayFirst = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return _firstDayOfWeek == 1 ? mondayFirst : sundayFirst;
  }

  /// Calculate the starting offset for the grid based on first day of week
  int _getStartOffset(int firstWeekday) {
    if (_firstDayOfWeek == 1) {
      // Monday first: Monday=0, Tuesday=1, ..., Sunday=6
      return (firstWeekday - 1) % 7;
    } else {
      // Sunday first: Sunday=0, Monday=1, ..., Saturday=6
      return firstWeekday % 7;
    }
  }

  void _goToPreviousMonth() {
    final newMonth = DateTime(widget.focusedMonth.year, widget.focusedMonth.month - 1, 1);

    // Check minimum date constraint
    if (widget.minDate != null) {
      final minMonth = DateTime(widget.minDate!.year, widget.minDate!.month, 1);
      if (newMonth.isBefore(minMonth)) return;
    }

    widget.onMonthChanged?.call(newMonth);
  }

  void _goToNextMonth() {
    final newMonth = DateTime(widget.focusedMonth.year, widget.focusedMonth.month + 1, 1);

    // Check future month constraint
    if (!widget.allowFutureMonths) {
      final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      if (newMonth.isAfter(currentMonth)) return;
    }

    widget.onMonthChanged?.call(newMonth);
  }

  bool get _canGoToPreviousMonth {
    if (widget.minDate == null) return true;
    final prevMonth = DateTime(widget.focusedMonth.year, widget.focusedMonth.month - 1, 1);
    final minMonth = DateTime(widget.minDate!.year, widget.minDate!.month, 1);
    return !prevMonth.isBefore(minMonth);
  }

  bool get _canGoToNextMonth {
    if (widget.allowFutureMonths) return true;
    final nextMonth = DateTime(widget.focusedMonth.year, widget.focusedMonth.month + 1, 1);
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    return !nextMonth.isAfter(currentMonth);
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(widget.focusedMonth.year, widget.focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(widget.focusedMonth.year, widget.focusedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;
    final startOffset = _getStartOffset(firstWeekday);

    // Calculate total cells needed
    final totalCells = startOffset + daysInMonth;
    final weeksNeeded = (totalCells / 7).ceil();
    final actualItemCount = weeksNeeded * 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month navigation header
        if (widget.showHeader)
          Padding(
            padding: widget.padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _canGoToPreviousMonth ? _goToPreviousMonth : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: _canGoToPreviousMonth ? AppColors.greyText : AppColors.grey700,
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                Text(
                  DateFormatUtils.formatMonthYear(widget.focusedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _canGoToNextMonth ? _goToNextMonth : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: _canGoToNextMonth ? AppColors.greyText : AppColors.grey700,
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Weekday headers
        Padding(
          padding: widget.padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdayHeaders.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Calendar grid
        Padding(
          padding: widget.padding,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: widget.cellAspectRatio,
              mainAxisSpacing: widget.cellSpacing,
              crossAxisSpacing: widget.cellSpacing,
            ),
            itemCount: actualItemCount,
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;

              // Empty cell for days outside the month
              if (dayNumber <= 0 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final date = DateTime(widget.focusedMonth.year, widget.focusedMonth.month, dayNumber);

              // Use custom day builder if provided
              if (widget.dayBuilder != null) {
                final customCell = widget.dayBuilder!(date);
                if (customCell != null) {
                  if (widget.onDayTap != null) {
                    return GestureDetector(
                      onTap: () => widget.onDayTap!(date),
                      child: customCell,
                    );
                  }
                  return customCell;
                }
              }

              // Default day cell
              return _buildDefaultDayCell(date, dayNumber);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultDayCell(DateTime date, int dayNumber) {
    final isToday = _isSameDay(date, DateTime.now());

    return GestureDetector(
      onTap: widget.onDayTap != null ? () => widget.onDayTap!(date) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? AppColors.purple.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: AppColors.purple, width: 1) : null,
        ),
        child: Center(
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? AppColors.purple : AppColors.white,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
