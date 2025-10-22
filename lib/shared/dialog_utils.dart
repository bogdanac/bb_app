import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

/// Centralized dialog utilities for consistent dialogs across the app
class DialogUtils {
  /// Show a simple confirmation dialog with Yes/No buttons
  ///
  /// Returns true if user confirmed, false if cancelled, null if dismissed
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Da', // Yes in Romanian
    String cancelText = 'Nu', // No in Romanian
    Color? confirmColor,
    bool isDangerous = false,
  }) async {
    if (!context.mounted) return null;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
        title: Text(
          title,
          style: AppStyles.headingSmall,
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: const TextStyle(color: AppColors.greyText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor ?? (isDangerous ? AppColors.deleteRed : AppColors.coral),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show a simple info/alert dialog with OK button
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    Widget? icon,
  }) async {
    if (!context.mounted) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
        title: Row(
          children: [
            if (icon != null) ...[
              icon,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: AppStyles.headingSmall,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              buttonText,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
  }

  /// Show an error dialog
  static Future<void> showError(
    BuildContext context, {
    String title = 'Eroare',
    required String message,
    String buttonText = 'OK',
  }) async {
    return showInfo(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      icon: const Icon(Icons.error_outline, color: AppColors.error, size: 28),
    );
  }

  /// Show a success dialog
  static Future<void> showSuccess(
    BuildContext context, {
    String title = 'Succes',
    required String message,
    String buttonText = 'OK',
  }) async {
    return showInfo(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      icon: const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 28),
    );
  }

  /// Show a warning dialog
  static Future<void> showWarning(
    BuildContext context, {
    String title = 'Atenție',
    required String message,
    String buttonText = 'OK',
  }) async {
    return showInfo(
      context,
      title: title,
      message: message,
      buttonText: buttonText,
      icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 28),
    );
  }

  /// Show a delete confirmation dialog
  static Future<bool?> showDeleteConfirmation(
    BuildContext context, {
    String title = 'Confirmare ștergere',
    required String itemName,
    String? customMessage,
  }) async {
    final message = customMessage ?? 'Sigur vrei să ștergi "$itemName"? Această acțiune nu poate fi anulată.';

    return showConfirmation(
      context,
      title: title,
      message: message,
      confirmText: 'Șterge',
      cancelText: 'Anulează',
      isDangerous: true,
    );
  }

  /// Show a custom dialog with multiple action buttons
  static Future<T?> showCustom<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    required List<DialogAction<T>> actions,
    Widget? icon,
    bool barrierDismissible = true,
  }) async {
    if (!context.mounted) return null;

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
        title: Row(
          children: [
            if (icon != null) ...[
              icon,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: AppStyles.headingSmall,
              ),
            ),
          ],
        ),
        content: content,
        actions: actions.map((action) {
          return TextButton(
            onPressed: () => Navigator.of(context).pop(action.value),
            child: Text(
              action.label,
              style: TextStyle(
                color: action.color ?? AppColors.coral,
                fontWeight: action.isDefault ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Show a loading dialog (must be dismissed manually with Navigator.pop)
  static void showLoading(
    BuildContext context, {
    String message = 'Se încarcă...',
  }) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.coral),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: AppColors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a text input dialog
  static Future<String?> showTextInput(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String confirmText = 'OK',
    String cancelText = 'Anulează',
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) async {
    if (!context.mounted) return null;

    final controller = TextEditingController(text: initialValue);
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
          title: Text(title, style: AppStyles.headingSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message != null) ...[
                Text(
                  message,
                  style: const TextStyle(color: AppColors.white70),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: maxLength,
                keyboardType: keyboardType,
                style: const TextStyle(color: Colors.white),
                decoration: AppStyles.inputDecoration(
                  hintText: hintText,
                ).copyWith(
                  errorText: errorText,
                ),
                onChanged: (value) {
                  if (validator != null) {
                    setState(() {
                      errorText = validator(value);
                    });
                  }
                },
                onSubmitted: (value) {
                  if (validator == null || validator(value) == null) {
                    Navigator.of(context).pop(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                cancelText,
                style: const TextStyle(color: AppColors.greyText),
              ),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text;
                if (validator == null || validator(value) == null) {
                  Navigator.of(context).pop(value);
                } else {
                  setState(() {
                    errorText = validator(value);
                  });
                }
              },
              child: Text(
                confirmText,
                style: const TextStyle(color: AppColors.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a choice dialog with multiple options
  static Future<T?> showChoice<T>(
    BuildContext context, {
    required String title,
    String? message,
    required List<ChoiceOption<T>> options,
    String? cancelText,
  }) async {
    if (!context.mounted) return null;

    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
        title: Text(title, style: AppStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(
                message,
                style: const TextStyle(color: AppColors.white70),
              ),
              const SizedBox(height: 16),
            ],
            ...options.map((option) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: option.icon,
              title: Text(
                option.label,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: option.description != null
                  ? Text(
                      option.description!,
                      style: const TextStyle(color: AppColors.white70, fontSize: 12),
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(option.value),
            )),
          ],
        ),
        actions: cancelText != null
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    cancelText,
                    style: const TextStyle(color: AppColors.greyText),
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Model for dialog action button
class DialogAction<T> {
  final String label;
  final T value;
  final Color? color;
  final bool isDefault;

  const DialogAction({
    required this.label,
    required this.value,
    this.color,
    this.isDefault = false,
  });
}

/// Model for choice option
class ChoiceOption<T> {
  final String label;
  final String? description;
  final T value;
  final Widget? icon;

  const ChoiceOption({
    required this.label,
    required this.value,
    this.description,
    this.icon,
  });
}
