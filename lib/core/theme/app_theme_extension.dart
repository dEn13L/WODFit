import 'package:flutter/material.dart';
import 'app_colors.dart';

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
    destructive: AppColors.error,
    draft: AppColors.warning,
    success: AppColors.success,
    warning: AppColors.warning,
    timeChipBackground: AppColors.darkPrimaryContainer,
    publish: AppColors.error,
  );

  static const light = AppThemeExtension(
    destructive: AppColors.error,
    draft: AppColors.warning,
    success: AppColors.success,
    warning: AppColors.warning,
    timeChipBackground: AppColors.lightPrimaryContainer,
    publish: AppColors.error,
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
