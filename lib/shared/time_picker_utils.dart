import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TimePickerUtils {
  /// Shows a styled time picker with consistent theming across the app
  /// This is the "airy" version from the tasks module
  static Future<TimeOfDay?> showStyledTimePicker({
    required BuildContext context,
    TimeOfDay? initialTime,
    bool showBackButton = false,
    Future<DateTime?> Function()? onBackPressed,
  }) async {
    final currentTime = initialTime ?? TimeOfDay.now();
    
    if (showBackButton && onBackPressed != null) {
      // Use the regular time picker with special cancel button handling
      final result = await showTimePicker(
        context: context,
        initialTime: currentTime,
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.coral,
                surface: AppColors.dialogCardBackground,
                onSurface: Colors.white,
                surfaceContainerHighest: AppColors.normalCardBackground,
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: AppColors.dialogBackground,
                surfaceTintColor: Colors.transparent,
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: AppColors.dialogBackground,
                dialHandColor: AppColors.coral,
                dialBackgroundColor: AppColors.normalCardBackground,
                hourMinuteColor: AppColors.dialogCardBackground,
                hourMinuteTextColor: Colors.white,
                dayPeriodTextColor: Colors.white,
                dayPeriodColor: AppColors.dialogCardBackground,
                entryModeIconColor: AppColors.coral,
                helpTextStyle: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
                hourMinuteTextStyle: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                dayPeriodTextStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                cancelButtonStyle: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  side: const BorderSide(color: Colors.white, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.1),
              ),
              child: child!,
            ),
          );
        },
      );


      return result;
    }

    return showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.coral,
              surface: AppColors.dialogCardBackground,
              onSurface: Colors.white,
              surfaceContainerHighest: AppColors.normalCardBackground,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.dialogBackground,
              surfaceTintColor: Colors.transparent,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.dialogBackground,
              dialHandColor: AppColors.coral,
              dialBackgroundColor: AppColors.normalCardBackground,
              hourMinuteColor: AppColors.dialogCardBackground,
              hourMinuteTextColor: Colors.white,
              dayPeriodTextColor: Colors.white,
              dayPeriodColor: AppColors.dialogCardBackground,
              entryModeIconColor: AppColors.coral,
              helpTextStyle: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              hourMinuteTextStyle: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              dayPeriodTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                side: const BorderSide(color: Colors.white, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.2),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}