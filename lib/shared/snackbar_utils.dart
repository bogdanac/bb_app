import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Centralized SnackBar utilities for consistent messaging across the app
class SnackBarUtils {
  /// Show a success message with green background
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successGreen,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show an error message with red background
  static void showError(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show an info message with grey/neutral background
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.greyText,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  /// Show a warning message with orange background
  static void showWarning(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show a loading message (useful for long operations)
  static void showLoading(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.purple,
        duration: const Duration(days: 365), // Long duration, must be manually dismissed
      ),
    );
  }

  /// Hide the currently showing SnackBar
  static void hide(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Show a custom SnackBar with specific color
  static void showCustom(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    Duration? duration,
    Widget? icon,
  }) {
    if (!context.mounted) return;

    Widget content = Text(message);
    if (icon != null) {
      content = Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}
