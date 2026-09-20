import 'package:flutter/material.dart';

class WorkoutFormColors {
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF06B6D4);
  static const Color publishButton = Color(0xFFEF4444);
  static const Color draftButton = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF06B6D4);
  static const Color text = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color hint = Color(0xFF94A3B8);
  static const Color chipBackground = Color(0xFFFFFFFF);
  static const Color deleteIcon = Color(0xFFCBD5E1);
}

final ThemeData workoutFormTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: WorkoutFormColors.background,
  cardColor: WorkoutFormColors.card,
  primaryColor: WorkoutFormColors.primary,
  colorScheme: const ColorScheme.light(
    primary: WorkoutFormColors.primary,
    surface: WorkoutFormColors.card,
    onSurface: WorkoutFormColors.text,
    outline: WorkoutFormColors.border,
  ),
  dividerColor: WorkoutFormColors.border,
  appBarTheme: const AppBarTheme(
    backgroundColor: WorkoutFormColors.background,
    elevation: 0,
    scrolledUnderElevation: 0,
    iconTheme: IconThemeData(color: WorkoutFormColors.text),
    titleTextStyle: TextStyle(
      color: WorkoutFormColors.text,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(color: WorkoutFormColors.hint, fontSize: 14),
    labelStyle: const TextStyle(color: WorkoutFormColors.textMuted, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: WorkoutFormColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: WorkoutFormColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: WorkoutFormColors.borderFocused, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: WorkoutFormColors.publishButton),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: WorkoutFormColors.publishButton, width: 1.5),
    ),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      color: WorkoutFormColors.text,
      fontWeight: FontWeight.bold,
    ),
    bodyLarge: TextStyle(color: WorkoutFormColors.text),
    bodyMedium: TextStyle(color: WorkoutFormColors.text),
  ),
);
