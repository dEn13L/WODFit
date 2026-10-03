import 'package:flutter/material.dart';

/// Компактное приветствие: графика не оттесняет расписание с первого экрана.
class CoachWelcomeBanner extends StatelessWidget {
  static const assetPath = 'assets/images/coach_equipment.webp';
  final String? name;

  const CoachWelcomeBanner({super.key, this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final firstName = name?.trim().split(RegExp(r'\s+')).firstOrNull;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName == null || firstName.isEmpty
                        ? 'Хорошей тренировки!'
                        : 'Привет, $firstName',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ваши тренировки на сегодня',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  assetPath,
                  width: 80,
                  height: 72,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
