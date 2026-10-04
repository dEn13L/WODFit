import 'package:flutter/material.dart';

/// Декоративная графика занимает только баннер, а текст растёт со шрифтом.
class HomeWelcomeBanner extends StatelessWidget {
  static const coachAsset = 'assets/images/coach_athlete.webp';
  static const clientAsset = 'assets/images/client_athlete.webp';

  final String? name;
  final String headline;
  final String subtitle;
  final String assetPath;

  const HomeWelcomeBanner({
    super.key,
    this.name,
    required this.headline,
    required this.subtitle,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final firstName = name?.trim().split(RegExp(r'\s+')).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          firstName == null || firstName.isEmpty
              ? 'Хорошей тренировки!'
              : 'Привет, $firstName',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primaryContainer,
                  colors.primary.withValues(alpha: 0.16),
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headline,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ExcludeSemantics(
                      child: Image.asset(
                        assetPath,
                        width: compact ? 88 : 128,
                        height: 144,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stackTrace) => SizedBox(
                          width: compact ? 88 : 128,
                          height: 144,
                          child: Icon(
                            Icons.fitness_center,
                            size: 40,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
