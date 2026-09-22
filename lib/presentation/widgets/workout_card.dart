import 'package:flutter/material.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../domain/entities/workout.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;

  const WorkoutCard({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    final typeColor = _getColorForType(workout.type, colorScheme, appTheme);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForType(workout.type),
              color: typeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  workout.description,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${workout.duration.inMinutes} мин',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${workout.caloriesBurned} ккал',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorForType(WorkoutType type, ColorScheme colorScheme, AppThemeExtension appTheme) {
    switch (type) {
      case WorkoutType.crossfit:
        return colorScheme.primary;
      case WorkoutType.strength:
        return colorScheme.secondary;
      case WorkoutType.cardio:
        return colorScheme.primary;
      case WorkoutType.hiit:
        return Colors.purpleAccent;
      case WorkoutType.mobility:
        return appTheme.success;
    }
  }

  IconData _getIconForType(WorkoutType type) {
    switch (type) {
      case WorkoutType.crossfit:
        return Icons.fitness_center_rounded;
      case WorkoutType.strength:
        return Icons.sports_gymnastics_rounded;
      case WorkoutType.cardio:
        return Icons.directions_run_rounded;
      case WorkoutType.hiit:
        return Icons.bolt_rounded;
      case WorkoutType.mobility:
        return Icons.self_improvement_rounded;
    }
  }
}
