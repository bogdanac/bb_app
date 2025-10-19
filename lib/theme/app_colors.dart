import 'package:flutter/material.dart';

class AppColors {
  // Main Palette (Original)
  static const Color red = Color(0xFFF8455C);
  static const Color yellow = Color(0xFFFFC637);
  static const Color orange = Color(0xFFFF755D);
  static const Color coral = Color(0xFFFF5A81);
  static const Color purple = Color(0xE4E33B95);
  static const Color pink = Color(0xFFFF48B4);
  static const Color lime = Color(0xDA92F451);

  static const Color lightRed = Color(0xFFFF7272);
  static const Color lightYellow = Color(0xFFFFD36F);
  static const Color lightOrange = Color(0xFFFD9987);
  static const Color lightCoral = Color(0xFFFA698B);
  static const Color lightPurple = Color(0xFFE891C0);
  static const Color lightPink = Color(0xFFFD65C3);

  // Success/Error colors 
  static const Color successGreen = Color(0xFF4CAF50);    // Green for success states
  static const Color error = Color(0xFFFF3554);           // Softer red for errors (not the aggressive primary red)
  static const Color deleteRed = Color(0xFFFF0000);       // Pure red for delete actions
  static const Color warning = Color(0xFFF98834);         // Using orange for warning
  static const Color info = Color(0xFFBD3AA6);            // Using purple for info
  
  // Special cases where blue/green are necessary
  static const Color waterBlue = Color(0xFF4A90E2);       // Only for water drop icon
  static const Color success = Color(0xFF4CAF50);         // Standard green for success
  
  // Green variations (for success states only - darker but fully saturated)
  static const Color pastelGreen = Color(0xFF2E7D32);     // Much darker vibrant green, fully opaque
  static const Color lightGreen = Color(0xFF388E3C);      // Medium dark vibrant green, fully opaque
  
  // Commonly used colors that should be consistent
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF); // Colors.white70 equivalent
  static const Color white54 = Color(0x8AFFFFFF); // Colors.white54 equivalent  
  static const Color white60 = Color(0x99FFFFFF); // Colors.white60 equivalent
  static const Color white24 = Color(0x3DFFFFFF); // Colors.white24 equivalent
  
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
  
  // Grey variations for text and UI elements
  static const Color grey100 = Color(0xFFC3C2C2);
  static const Color grey200 = Color(0xFFA3A3A3);
  static const Color grey300 = Color(0xFF7A7A7A);

  static const Color grey700 = Color(0xFF323232);
  static const Color grey800 = Color(0xFF292929);
  static const Color grey900 = Color(0xFF232323);
  
  // Background colors for consistent UI
  static const Color greyText = grey200;
  static const Color appBackground = grey900;              // Navbar, app background - almost black
  static const Color homeCardBackground = grey800;         // Home screen cards
  static const Color normalCardBackground = grey700;       // Normal cards
  static const Color dialogBackground = grey900;           // Dialog backgrounds
  static const Color dialogCardBackground = grey800;       // Cards in dialogs grey99 with greyText borders
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.appBackground,
      cardColor: AppColors.normalCardBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.coral, // Changed from redPrimary to coral for less aggressive look
        secondary: AppColors.orange, // Changed from coral to orange
        tertiary: AppColors.purple,
        error: AppColors.error,
        surface: AppColors.normalCardBackground,
        surfaceContainerHighest: AppColors.normalCardBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white, // White text on orange
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
      ),
      // Custom navbar - no theme needed
    );
  }
}