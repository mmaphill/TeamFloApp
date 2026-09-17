import 'package:flutter/material.dart';
import 'colors.dart';

class AppThemes {
  // Dark Theme (default)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.darkText,
      elevation: 0,
    ),
    cardColor: AppColors.darkSurface,
    canvasColor: AppColors.darkBg,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.success,
      surface: AppColors.darkSurface,
      error: AppColors.primary,
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
        borderSide: BorderSide(color: AppColors.primary),
      ),
      hintStyle: TextStyle(color: AppColors.darkText.withAlpha(150)),
    ),
    dialogBackgroundColor: AppColors.darkSurface,
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkText.withAlpha(150),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.darkSurfaceVariant,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withAlpha(100),
      valueIndicatorColor: AppColors.primary,
    ),
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightText,
      elevation: 1,
    ),
    cardColor: AppColors.lightSurface,
    canvasColor: AppColors.lightBg,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.success,
      surface: AppColors.lightSurface,
      error: AppColors.primary,
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
        borderSide: BorderSide(color: AppColors.primary),
      ),
      hintStyle: TextStyle(color: AppColors.lightText.withAlpha(100)),
    ),
    dialogBackgroundColor: AppColors.lightSurface,
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightText.withAlpha(100),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.lightSurfaceVariant,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withAlpha(100),
      valueIndicatorColor: AppColors.primary,
    ),
  );
}