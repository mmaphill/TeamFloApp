import 'package:flutter/material.dart';

class AppColors {
  // Logo Colors
  static const Color primary = Color (0xFFEA2327);
  static const Color dark = Color(0xFF0A0000);
  static const Color light = Color(0xFFFCF7FA);

  // Derived Colors
  static const Color surface = Color(0xFF1E1E1E); // Dark surface
  static const Color surfaceVariant = Color(0xFF2C2C2C); // Slightly lighter dark
  static const Color onSurface = light; // Light text on dark
  static const Color error = primary;
  static const Color success = Color(0xFF66BB6A);
  static const Color background = dark;
  static const Color onPrimary = Colors.white;
  static const Color onDark = light;
}