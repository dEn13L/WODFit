import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/core/theme/app_theme_extension.dart';

void main() {
  double contrast(Color foreground, Color background) {
    final lighter = foreground.computeLuminance() > background.computeLuminance()
        ? foreground.computeLuminance()
        : background.computeLuminance();
    final darker = foreground.computeLuminance() > background.computeLuminance()
        ? background.computeLuminance()
        : foreground.computeLuminance();
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('themes keep readable primary actions and body text', () {
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      expect(
        contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(theme.colorScheme.onSurfaceVariant, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    }

    expect(
      contrast(
        AppTheme.darkTheme.colorScheme.onPrimary,
        AppTheme.darkTheme.colorScheme.primary,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(AppTheme.lightTheme.colorScheme.primary, const Color(0xFF06B6D4));
    expect(AppTheme.lightTheme.colorScheme.onPrimary, Colors.white);
  });

  test('themes share component geometry and semantic colors', () {
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      final extension = theme.extension<AppThemeExtension>()!;
      final button = theme.elevatedButtonTheme.style!;

      expect(button.minimumSize!.resolve({}), const Size(64, 52));
      expect(button.shape!.resolve({}), isA<StadiumBorder>());
      expect(extension.destructive, const Color(0xFFEF4444));
      expect(extension.warning, const Color(0xFFF59E0B));
      expect(extension.success, const Color(0xFF34D399));
    }
  });
}
