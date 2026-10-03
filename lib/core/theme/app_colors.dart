import 'package:flutter/material.dart';

class AppColors {
  // Dark theme colors
  static const Color background = Color(0xFF0C0F12);
  static const Color surface = Color(0xFF171C21);
  static const Color surfaceLight = Color(0xFF252C33);

  // Shared cyan hue, adapted to each theme's contrast.
  static const Color darkPrimary = Color(0xFF22D3EE);
  static const Color darkOnPrimary = Color(0xFF082F49);
  static const Color darkPrimaryContainer = Color(0xFF16343D);
  static const Color darkBorder = Color(0xFF303942);

  // Text (Dark)
  static const Color textPrimary = Color(0xFFF2F5F7);
  static const Color textSecondary = Color(0xFFB4BDC7);
  static const Color textMuted = Color(0xFF98A2AD);

  // Status (Shared)
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Light theme tokens
  static const Color lightBackground = Color(0xFFF8FAFC); // soft light slate
  static const Color lightSurface = Color(0xFFFFFFFF); // pure white
  static const Color lightSurfaceVariant = Color(
    0xFFF1F5F9,
  ); // light grey for cards/containers
  static const Color lightPrimary = Color(0xFF0E7490);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFE0F2FE);
  static const Color lightTextPrimary = Color(0xFF0F172A); // dark charcoal
  static const Color lightTextSecondary = Color(0xFF475569); // medium grey
  static const Color lightTextMuted = Color(0xFF475569); // readable hint text
  static const Color lightBorder = Color(0xFFCBD5E1); // light grey borders
  static const Color lightDivider = Color(0xFFCBD5E1);
}
