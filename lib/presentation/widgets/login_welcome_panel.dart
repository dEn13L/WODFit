import 'package:flutter/material.dart';

import 'home_welcome_banner.dart';

/// Декоративный баннер входа использует графику и цвета главного экрана.
class LoginWelcomePanel extends StatelessWidget {
  final bool wide;

  const LoginWelcomePanel({super.key, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final copy = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fitness_center, color: colors.primary, size: 28),
          const SizedBox(height: 12),
          Text(
            'WOD FIT',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Каждая тренировка —\nшаг вперёд',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
            ),
          ),
          if (wide) ...[
            const SizedBox(height: 12),
            Text(
              'Ваши программы, календарь и результаты в одном месте',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
    final illustration = ExcludeSemantics(
      child: Image.asset(
        HomeWelcomeBanner.clientAsset,
        width: wide ? 200 : 112,
        height: wide ? 320 : 224,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, _, _) =>
            SizedBox(width: wide ? 200 : 112, height: wide ? 320 : 224),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer,
              colors.primary.withValues(alpha: 0.12),
            ],
          ),
        ),
        child: wide
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, illustration],
              )
            : Row(
                children: [
                  Expanded(child: copy),
                  illustration,
                ],
              ),
      ),
    );
  }
}
