import 'package:flutter/material.dart';

class AppColors {
  // Main Palette (Original)
  static const Color redPrimary = Color(0xFFF8455C);      // #f43148
  static const Color yellow = Color(0xFFFFC637);          // #f5b041 - More muted yellow
  static const Color orange = Color(0xFFFF755D);          // #f98834
  static const Color coral = Color(0xFFFF5A81);           // #fd6848
  static const Color purple = Color(0xFFBD3AA6);          // #bd3aa6
  static const Color pink = Color(0xFFFF48B4);            // #fb3380
  
  // Medium versions (keeping pure hues)
  static const Color lightRed = Color(0xFFFF7272);        // Pure f43148 hue, medium value
  static const Color lightYellow = Color(0xFFFFD36F);     // Pure ffd106 hue, medium value
  static const Color lightOrange = Color(0xFFFD9987);     // Pure f98834 hue, medium value
  static const Color lightCoral = Color(0xFFFA698B);      // Pure fd6848 hue, medium value
  static const Color lightPurple = Color(0xFFDF82C5);     // Pure bd3aa6 hue, medium value
  static const Color lightPink = Color(0xFFFD65C3);       // Pure fb3380 hue, medium value
  
  // Success/Error colors 
  static const Color successGreen = Color(0xFF4CAF50);    // Green for success states
  static const Color error = Color(0xFFFF3554);           // Softer red for errors (not the aggressive primary red)
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
  
  // Commonly used colors that should be consistent
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF); // Colors.white70 equivalent
  static const Color white54 = Color(0x8AFFFFFF); // Colors.white54 equivalent  
  static const Color white60 = Color(0x99FFFFFF); // Colors.white60 equivalent
  static const Color white24 = Color(0x3DFFFFFF); // Colors.white24 equivalent
  
  static const Color black = Color(0xFF000000);
  static const Color black87 = Color(0xDD000000); // Colors.black87 equivalent
  
  static const Color transparent = Color(0x00000000);
  
  // Grey variations for text and UI elements
  static const Color grey = Color(0xFF9E9E9E);
  static const Color grey300 = Color(0xFFE0E0E0);  
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.coral, // Changed from redPrimary to coral for less aggressive look
        secondary: AppColors.orange, // Changed from coral to orange
        tertiary: AppColors.purple,
        error: AppColors.error,
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkBackground,
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