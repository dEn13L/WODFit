import 'package:flutter/material.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color destructive;
  final Color draft;
  final Color success;
  final Color warning;
  final Color timeChipBackground;
  final Color publish;

  const AppThemeExtension({
    required this.destructive,
    required this.draft,
    required this.success,
    required this.warning,
    required this.timeChipBackground,
    required this.publish,
  });

  static const dark = AppThemeExtension(
    destructive: Color(0xFFEF4444),
    draft: Color(0xFFF59E0B),
    success: Color(0xFF00E676),
    warning: Color(0xFFF59E0B),
    timeChipBackground: Color(0x33CCFF00),
    publish: Color(0xFFEF4444),
  );

  static const light = AppThemeExtension(
    destructive: Color(0xFFEF4444),
    draft: Color(0xFFF59E0B),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    timeChipBackground: Color(0x1F06B6D4),
    publish: Color(0xFFEF4444),
  );

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? destructive,
    Color? draft,
    Color? success,
    Color? warning,
    Color? timeChipBackground,
    Color? publish,
  }) {
    return AppThemeExtension(
      destructive: destructive ?? this.destructive,
      draft: draft ?? this.draft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      timeChipBackground: timeChipBackground ?? this.timeChipBackground,
      publish: publish ?? this.publish,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      destructive: Color.lerp(destructive, other.destructive, t) ?? destructive,
      draft: Color.lerp(draft, other.draft, t) ?? draft,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      timeChipBackground: Color.lerp(timeChipBackground, other.timeChipBackground, t) ?? timeChipBackground,
      publish: Color.lerp(publish, other.publish, t) ?? publish,
    );
  }
}

extension AppThemeExtensionGetter on BuildContext {
  AppThemeExtension get appTheme =>
      Theme.of(this).extension<AppThemeExtension>() ?? AppThemeExtension.dark;
}
