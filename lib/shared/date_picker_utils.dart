import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'time_picker_utils.dart';

class DatePickerUtils {
  /// Shows a styled date picker with bigger dates for easier selection
  /// For date and time selection, use showStyledDateTimePicker instead
  static Future<DateTime?> showStyledDatePicker({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    bool autoTransitionToTime = false,
  }) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime.now(),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ro', 'RO'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.coral,
              onPrimary: Colors.white,
              surface: AppColors.dialogCardBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.dialogBackground,
              surfaceTintColor: Colors.transparent,
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.dialogBackground,
              headerBackgroundColor: AppColors.normalCardBackground,
              headerForegroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                side: const BorderSide(color: Colors.white, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.coral,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.95),
            ),
            child: child!,
          ),
        );
      },
    );

    return selectedDate;
  }

  /// Shows date picker followed by time picker with back button support
  static Future<DateTime?> showStyledDateTimePicker({
    required BuildContext context,
    DateTime? initialDateTime,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    // First, show date picker
    final selectedDate = await showStyledDatePicker(
      context: context,
      initialDate: initialDateTime ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selectedDate == null) return null;
    if (!context.mounted) return null;

    // Now automatically show time picker
    final selectedTime = await TimePickerUtils.showStyledTimePicker(
      context: context,
      initialTime: initialDateTime != null
          ? TimeOfDay.fromDateTime(initialDateTime)
          : TimeOfDay.now(),
    );

    if (selectedTime == null) {
      return null;
    }

    // Combine date and time
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }
}