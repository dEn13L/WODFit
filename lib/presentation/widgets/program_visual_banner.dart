import 'package:flutter/material.dart';

/// Общая декоративная шапка программ; высота текста не ограничена.
class ProgramVisualBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;

  const ProgramVisualBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primaryContainer,
              colors.primary.withValues(alpha: 0.12),
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: colors.primary),
                      const SizedBox(height: 8),
                    ],
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ExcludeSemantics(
              child: Image.asset(
                'assets/images/program_equipment.webp',
                width: 88,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 88, height: 120),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
