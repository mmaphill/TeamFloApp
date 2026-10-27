import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // no instances

  // Logo Colors (used in both modes)
  static const Color primary = Color(0xFFEA2327);  // Default brand color
  static const Color primaryLight = Color(0xFFFFB2B3); // soft pink for selected nav items
  static const Color onPrimary = Color(0xFFFFFFFF); // text/icons that sit on top of the primary color

  // Status colors (same in both modes)
  static const Color success = Color(0xFF66BB6A); // green
  static const Color error = Color(0xFFE53935); // red - delete, logout, errors
  static const Color warning = Color(0xFFFF9800); // orange - pending, needs review
  static const Color info = Color(0xFF2196F3); // blue - links, neutral info
  static const Color neutral = Color(0xFF9E9E9E); // grey - "no data", disabled
  static const Color gold = Color(0xFFFFC107); // yellow - trophies/awards

  // Tagging others
  static const Color mention = Color(0xFF42A5F5);

  // Dark Mode
  static const Color darkBg = Color(0xFF0A0000);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkSurfaceHigh = Color(0xFF3A3A3A);
  static const Color darkText = Color(0xFFFCF7FA);
  static const Color darkBorder = Color(0xFF424242);

  // Light Mode
  static const Color lightBg = Color(0xFFFCF7FA);
  static const Color lightSurface = Color(0xFFF5F0F5);
  static const Color lightSurfaceVariant = Color(0xFFEDE8ED);
  static const Color lightSurfaceHigh = Color(0xFFE0DAE0);
  static const Color lightText = Color(0xFF0A0000);
  static const Color lightBorder = Color(0xFFD6D0D6);

  // Media Screens (photo viewer, video player, photo crop)
  static const Color mediaBackground = Color(0xFF000000);
  static const Color mediaPanel = Color(0xFF1A1A1A);
  static const Color mediaAppBar = Color(0xFF2A2A2A);
  static const Color mediaForeground = Color(0xFFFFFFFF);
  static const Color mediaForegroundMuted = Color(0xB3FFFFFF); // white 70%
  static const Color mediaBorder = Color(0x4DFFFFFF); // white 30%
  static const Color mediaInactive = Color(0xFF616161);
  static const Color mediaButtonBg = Color(0x8A000000); // black 54%
  static const Color mediaScrim = Color(0x42000000); // black 26%
  static const Color cropMask = Color(0x80000000); // black 50%

  static const Color transparent = Color(0x00000000); // use when no color is required

  static const Color shadow = Color(0x4D000000); // black 30%

  // 3rd party colors
  static const Color instagram = Color(0xFFE4405F);

  // Belt Colors
  static const Color beltWhite = Color(0xFFFFFFFF);
  static const Color beltGrey = Color(0xFF9E9E9E);
  static const Color beltYellow = Color(0xFFFBC02D);
  static const Color beltOrange = Color(0xFFF57C00);
  static const Color beltGreen = Color(0xFF388E3C);
  static const Color beltBlue = Color(0xFF1976D2);
  static const Color beltPurple = Color(0xFF7B1FA2);
  static const Color beltBrown = Color(0xFF6D4C41);
  static const Color beltBlack = Color(0xFF000000);

  // Returns belt color for a rank name
  static Color beltColor(String rank) {
    final r = rank.toLowerCase();
    if (r.contains('black')) return beltBlack;
    if (r.contains('brown')) return beltBrown;
    if (r.contains('purple')) return beltPurple;
    if (r.contains('blue')) return beltBlue;
    if (r.contains('green')) return beltGreen;
    if (r.contains('orange')) return beltOrange;
    if (r.contains('yellow')) return beltYellow;
    if (r.contains('grey') || r.contains('gray')) return beltGrey;
    return beltWhite;
  }

  static const Color chartWinSubmission = success;
  static const Color chartWinPoints = info;
  static const Color chartWinDecision = warning;
  static const Color chartLossSubmission = error;
  static const Color chartLossPoints = Color(0xFF607D8B); // blue grey
  static const Color chartLossDecision = Color(0xFFFF5722); // deep orange
  static const Color chartNoGi = Color(0xFF607D8B); // blue grey
  static const Color chartOther = neutral;

  // Default avatar circle color when a member has no photo.
  static const Color avatarDefault = info;

  /// Builds an opaque color from a stored int like 0xEA2327.
  /// Used for gym brand colors saved in Firestore.
  static Color fromRgb(int rgb) => Color(0xFF000000 | rgb);
}

// Changing colors between light and dark modes
class AppPalette {
  final bool isDark;
  final Color primary;

  const AppPalette._({required this.isDark, required this.primary});

  factory AppPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    return AppPalette._(
      isDark: theme.brightness == Brightness.dark,
      primary: theme.colorScheme.primary,
    );
  }

  // Backgrounds
  // Screen background
  Color get background => isDark ? AppColors.darkBg : AppColors.lightBg;

  // Cards, sheets, appbar
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;

  // Text fields, chips, inner boxes on a card
  Color get surfaceVariant => isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;

  // Raised objects (popups, bottom nav bar, secondary buttons)
  Color get surfaceHigh => isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh;

  // App bar background
  Color get appBar => isDark ? AppColors.darkBg : AppColors.lightSurface;

  // Text
  // Main text and icons
  Color get text => isDark ? AppColors.darkText : AppColors.lightText;

  // secondary text (timestamps, captions, labels)
  Color get textMuted => text.withValues(alpha: isDark ? 0.65 : 0.6);

  // Hints, disabled text, unselected nav icons
  Color get textFaint => text.withValues(alpha: isDark ? 0.45 : 0.4);

  // Lines
  // Borders and dividers
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;

  // Brand helpers
  // Light tint of the brand color for selected backgrounds
  Color get primaryTint => primary.withValues(alpha: isDark ? 0.25 : 0.15);

  // Selected item in the bottom nav bar when there is no brand color
  Color get navSelected => isDark ? AppColors.primaryLight : primary;

  // Text/icons on top of primary
  Color get onPrimary => AppColors.onPrimary;

  // Status Banners
  // Background error message box
  Color get errorContainer => AppColors.error.withValues(alpha: isDark ? 0.25 : 0.12);

  // Text inside error message box
  Color get onErrorContainer => isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB71C1C);

  // background warning box
  Color get warningContainer => AppColors.warning.withValues(alpha: 0.15);
}

// Allos any widget
extension AppColorsContext on BuildContext {
  AppPalette get colors => AppPalette.of(this);
}