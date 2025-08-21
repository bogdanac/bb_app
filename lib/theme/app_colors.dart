import 'package:flutter/material.dart';

class AppColors {
  // Main Palette (Original)
  static const Color redPrimary = Color(0xFFF43148);      // #f43148
  static const Color yellow = Color(0xFFFFD106);          // #ffd106  
  static const Color orange = Color(0xFFF98834);          // #f98834
  static const Color coral = Color(0xFFFD6848);           // #fd6848
  static const Color purple = Color(0xFFBD3AA6);          // #bd3aa6
  static const Color pink = Color(0xFFFB3380);            // #fb3380
  
  // Dark but Pure Versions (keeping the EXACT hue and saturation from your palette)
  static const Color pastelRed = Color(0xFFA0253D);       // Pure f43148 hue, just darker value
  static const Color pastelYellow = Color(0xFFB3940B);    // Pure ffd106 hue, just darker value
  static const Color pastelOrange = Color(0xFFA05A1C);    // Pure f98834 hue, just darker value
  static const Color pastelCoral = Color(0xFFA0422C);     // Pure fd6848 hue, just darker value
  static const Color pastelPurple = Color(0xFF7D2969);    // Pure bd3aa6 hue, just darker value
  static const Color pastelPink = Color(0xFF9F1F53);      // Pure fb3380 hue, just darker value
  
  // Medium versions (keeping pure hues)
  static const Color lightRed = Color(0xFFB53045);        // Pure f43148 hue, medium value
  static const Color lightYellow = Color(0xFFCCA50C);     // Pure ffd106 hue, medium value  
  static const Color lightOrange = Color(0xFFB56621);     // Pure f98834 hue, medium value
  static const Color lightCoral = Color(0xFFB54D32);      // Pure fd6848 hue, medium value
  static const Color lightPurple = Color(0xFF8F3175);     // Pure bd3aa6 hue, medium value
  static const Color lightPink = Color(0xFFB3255F);       // Pure fb3380 hue, medium value
  
  // Success/Error colors 
  static const Color successGreen = Color(0xFF4CAF50);    // Green for success states
  static const Color error = Color(0xFFF43148);           // Using red for error
  static const Color warning = Color(0xFFF98834);         // Using orange for warning
  static const Color info = Color(0xFFBD3AA6);            // Using purple for info
  
  // Special cases where blue/green are necessary
  static const Color waterBlue = Color(0xFF4A90E2);       // Only for water drop icon
  static const Color success = Color(0xFF4CAF50);         // Standard green for success
  
  // Green variations (for success states only - darker but fully saturated)
  static const Color pastelGreen = Color(0xFF2E7D32);     // Much darker vibrant green, fully opaque
  static const Color lightGreen = Color(0xFF388E3C);      // Medium dark vibrant green, fully opaque
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color darkSurface = Color(0xFF2D2D2D);
  static const Color darkCard = Color(0xFF363636);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.redPrimary,
        secondary: AppColors.coral, // Changed from yellow to coral
        tertiary: AppColors.orange,
        error: AppColors.error,
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white, // White text on coral
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