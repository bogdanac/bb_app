import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized app styles for consistent UI across the app
class AppStyles {
  // ===== Border Radius =====
  static const borderRadiusSmall = BorderRadius.all(Radius.circular(8));
  static const borderRadiusMedium = BorderRadius.all(Radius.circular(12));
  static const borderRadiusLarge = BorderRadius.all(Radius.circular(16));
  static const borderRadiusXLarge = BorderRadius.all(Radius.circular(20));

  // Individual radius values (for when you need just the number)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // ===== Shadows =====
  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static final cardShadowHeavy = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ===== Padding & Spacing =====
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingLarge = 16.0;
  static const double paddingXLarge = 20.0;
  static const double paddingXXLarge = 24.0;

  static const edgeInsetsSmall = EdgeInsets.all(paddingSmall);
  static const edgeInsetsMedium = EdgeInsets.all(paddingMedium);
  static const edgeInsetsLarge = EdgeInsets.all(paddingLarge);
  static const edgeInsetsXLarge = EdgeInsets.all(paddingXLarge);

  // ===== Common Card Decoration =====
  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
    color: color ?? AppColors.normalCardBackground,
    borderRadius: borderRadiusMedium,
    boxShadow: cardShadow,
  );

  static BoxDecoration cardDecorationWithBorder({
    Color? color,
    Color? borderColor,
    double borderWidth = 1.0,
  }) => BoxDecoration(
    color: color ?? AppColors.normalCardBackground,
    borderRadius: borderRadiusMedium,
    border: Border.all(
      color: borderColor ?? AppColors.greyText.withValues(alpha: 0.3),
      width: borderWidth,
    ),
    boxShadow: cardShadow,
  );

  // ===== Text Styles =====
  static const headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    color: Colors.white,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    color: Colors.white,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.white70,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.greyText,
  );

  // ===== Button Styles =====
  static ButtonStyle elevatedButtonStyle({Color? backgroundColor}) => ElevatedButton.styleFrom(
    backgroundColor: backgroundColor ?? AppColors.coral,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  static ButtonStyle outlinedButtonStyle({Color? borderColor}) => OutlinedButton.styleFrom(
    foregroundColor: borderColor ?? AppColors.coral,
    side: BorderSide(color: borderColor ?? AppColors.coral),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  static ButtonStyle textButtonStyle({Color? color}) => TextButton.styleFrom(
    foregroundColor: color ?? AppColors.coral,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );

  // ===== Input Decoration =====
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.normalCardBackground,
    border: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: BorderSide(color: AppColors.greyText.withValues(alpha: 0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: BorderSide(color: AppColors.greyText.withValues(alpha: 0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: const BorderSide(color: AppColors.coral, width: 2),
    ),
    labelStyle: const TextStyle(color: AppColors.white70),
    hintStyle: const TextStyle(color: AppColors.greyText),
  );

  // ===== Dividers =====
  static const dividerThin = Divider(
    color: AppColors.greyText,
    thickness: 0.5,
    height: 1,
  );

  static const dividerMedium = Divider(
    color: AppColors.greyText,
    thickness: 1,
    height: 1,
  );

  // ===== Common Transitions =====
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationNormal = Duration(milliseconds: 300);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);

  static const Curve animationCurve = Curves.easeInOut;
}
