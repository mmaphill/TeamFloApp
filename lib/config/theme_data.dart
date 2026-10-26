import 'package:flutter/material.dart';
import 'colors.dart';

/// PHASE 1 STEP 6: themes are built from the gym's main color.
/// Gyms with no primaryColor set get Team Flo red (AppColors.primary),
/// so Team Flo looks exactly the same as before.
class AppThemes {
  // Kept so any older code that uses AppThemes.darkTheme / lightTheme
  // still works. Both use the default (Team Flo) color.
  static ThemeData get darkTheme => dark();
  static ThemeData get lightTheme => light();

  // Dark Theme (default)
  static ThemeData dark([Color primary = AppColors.primary]) => ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.darkText,
      elevation: 0,
    ),
    cardColor: AppColors.darkSurface,
    canvasColor: AppColors.darkBg,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: AppColors.success,
      surface: AppColors.darkSurface,
      error: AppColors.primary, // errors stay red whatever the gym color
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkText,
      onError: Colors.white,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: AppColors.darkText),
      bodySmall: TextStyle(color: AppColors.darkText.withAlpha(200)),
      labelMedium: TextStyle(color: AppColors.darkText),
      titleMedium: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.darkSurfaceVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.darkSurfaceVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary),
      ),
      hintStyle: TextStyle(color: AppColors.darkText.withAlpha(150)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.darkText.withAlpha(150),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: primary,
      inactiveTrackColor: AppColors.darkSurfaceVariant,
      thumbColor: primary,
      overlayColor: primary.withAlpha(100),
      valueIndicatorColor: primary,
    ), dialogTheme: DialogThemeData(backgroundColor: AppColors.darkSurface),
  );

  // Light Theme
  static ThemeData light([Color primary = AppColors.primary]) => ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: AppColors.lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightText,
      elevation: 1,
    ),
    cardColor: AppColors.lightSurface,
    canvasColor: AppColors.lightBg,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: AppColors.success,
      surface: AppColors.lightSurface,
      error: AppColors.primary, // errors stay red whatever the gym color
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightText,
      onError: Colors.white,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: AppColors.lightText),
      bodySmall: TextStyle(color: AppColors.lightText.withAlpha(150)),
      labelMedium: TextStyle(color: AppColors.lightText),
      titleMedium: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.lightSurfaceVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.lightSurfaceVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary),
      ),
      hintStyle: TextStyle(color: AppColors.lightText.withAlpha(100)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.lightText.withAlpha(100),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: primary,
      inactiveTrackColor: AppColors.lightSurfaceVariant,
      thumbColor: primary,
      overlayColor: primary.withAlpha(100),
      valueIndicatorColor: primary,
    ), dialogTheme: DialogThemeData(backgroundColor: AppColors.lightSurface),
  );
}