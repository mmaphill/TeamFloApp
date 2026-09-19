import 'package:flutter/material.dart';

class AppColors {
  // Logo Colors (used in both modes)
  static const Color primary = Color(0xFFEA2327);
  static const Color success = Color(0xFF66BB6A);

  // Dark Mode
  static const Color darkBg = Color(0xFF0A0000);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkText = Color(0xFFFCF7FA);

  // Light Mode
  static const Color lightBg = Color(0xFFFCF7FA);
  static const Color lightSurface = Color(0xFFF5F0F5);
  static const Color lightSurfaceVariant = Color(0xFFEDE8ED);
  static const Color lightText = Color(0xFF0A0000);

  // Tagging others
  static const Color mention = Color(0xFF42A5F5);

  // Deprecated (kept for reference during migration)
  @deprecated
  static const Color dark = darkBg;
  @deprecated
  static const Color light = darkText;
  @deprecated
  static const Color surface = darkSurface;
  @deprecated
  static const Color surfaceVariant = darkSurfaceVariant;
  @deprecated
  static const Color onSurface = darkText;
  @deprecated
  static const Color background = darkBg;
  @deprecated
  static const Color onPrimary = Colors.white;
  @deprecated
  static const Color onDark = darkText;
  @deprecated
  static const Color error = primary;
}