import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/workout.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;

  const WorkoutCard({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.surfaceLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getColorForType(workout.type).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForType(workout.type),
              color: _getColorForType(workout.type),
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  workout.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
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
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: AppColors.accentOrange,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${workout.caloriesBurned} ккал',
                    style: const TextStyle(
                      color: AppColors.accentOrange,
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

  Color _getColorForType(WorkoutType type) {
    switch (type) {
      case WorkoutType.crossfit:
        return AppColors.primaryNeon;
      case WorkoutType.strength:
        return AppColors.accentOrange;
      case WorkoutType.cardio:
        return AppColors.accentCyan;
      case WorkoutType.hiit:
        return Colors.purpleAccent;
      case WorkoutType.mobility:
        return AppColors.success;
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
