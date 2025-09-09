import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TimePickerUtils {
  /// Shows a styled time picker with consistent theming across the app
  /// This is the "airy" version from the tasks module
  static Future<TimeOfDay?> showStyledTimePicker({
    required BuildContext context,
    TimeOfDay? initialTime,
  }) async {
    final currentTime = initialTime ?? TimeOfDay.now();
    
    return showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.coral,
            ),
            timePickerTheme: TimePickerThemeData(
              dialHandColor: AppColors.coral,
              dialBackgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteColor: Theme.of(context).colorScheme.surface,
              hourMinuteTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodColor: Theme.of(context).colorScheme.surface,
              entryModeIconColor: AppColors.coral,
              helpTextStyle: TextStyle(
                fontSize: 16, 
                color: Theme.of(context).colorScheme.onSurface,
              ),
              hourMinuteTextStyle: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              dayPeriodTextStyle: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.coral,
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // Make the time picker larger by increasing text scale for better "airy" feel
              textScaler: const TextScaler.linear(1.2),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}