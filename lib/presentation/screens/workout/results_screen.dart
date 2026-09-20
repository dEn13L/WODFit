import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';

class ResultsScreen extends StatefulWidget {
  final String workoutId;

  const ResultsScreen({
    super.key,
    required this.workoutId,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты программы'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        builder: (context, state) {
          if (state is CrossfitWorkoutLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
          }

          if (state is CrossfitWorkoutDetailLoaded) {
            final workout = state.workout;
            final allResults = state.allResults;

            final Map<String, List<PartResult>> resultsByPart = {};
            for (final res in allResults) {
              resultsByPart.putIfAbsent(res.partId, () => []).add(res);
            }

            return RefreshIndicator(
              onRefresh: () async => context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId),
              color: AppColors.primaryNeon,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      WorkoutDateFormatter.formatDetail(workout.scheduledAt, workout.title),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Результаты участников по блокам тренировки:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (workout.parts.isEmpty)
                      const Center(child: Text('В тренировке пока нет заданий'))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: workout.parts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final part = workout.parts[index];
                          final partResults = resultsByPart[part.id] ?? [];

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          part.type.displayName,
                                          style: const TextStyle(
                                            color: AppColors.primaryNeon,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryNeon.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          part.scoreType.displayName,
                                          style: const TextStyle(
                                            color: AppColors.primaryNeon,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Блок ${index + 1}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  if (part.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      part.description,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (partResults.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12.0),
                                      child: Center(
                                        child: Text(
                                          'Пока никто не внес результат по этому блоку',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: partResults.length,
                                      separatorBuilder: (context, index) => const Divider(color: AppColors.surfaceLight, height: 16),
                                      itemBuilder: (context, rIndex) {
                                        final result = partResults[rIndex];
                                        final athleteName = result.userProfile?.fullName ?? 'Атлет';

                                        Color statusColor;
                                        switch (result.status) {
                                          case ResultStatus.done:
                                            statusColor = AppColors.success;
                                            break;
                                          case ResultStatus.scaled:
                                            statusColor = AppColors.accentOrange;
                                            break;
                                          case ResultStatus.notDone:
                                            statusColor = AppColors.error;
                                            break;
                                        }

                                        return Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: AppColors.surfaceLight,
                                              child: Text(
                                                athleteName.isNotEmpty ? athleteName[0].toUpperCase() : 'A',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNeon),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        athleteName,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: statusColor.withValues(alpha: 0.2),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          result.status.displayName,
                                                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (part.scoreType != WorkoutScoreType.none || result.scoreText.isNotEmpty)
                                                    Text(
                                                      'Результат: ${result.formattedScore}',
                                                      style: const TextStyle(
                                                        color: AppColors.textPrimary,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  if (result.weightKg != null ||
                                                      result.rounds != null ||
                                                      result.reps != null ||
                                                      result.distanceM != null ||
                                                      result.calories != null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      [
                                                        if (result.weightKg != null) 'Вес: ${result.weightKg} кг',
                                                        if (result.rounds != null) 'Раунды: ${result.rounds}',
                                                        if (result.reps != null) 'Повторы: ${result.reps}',
                                                        if (result.distanceM != null) 'Дистанция: ${result.distanceM!.truncateToDouble() == result.distanceM ? result.distanceM!.toInt() : result.distanceM} м',
                                                        if (result.calories != null) 'Калории: ${result.calories} кал',
                                                      ].join(' • '),
                                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                    ),
                                                  ],
                                                  if (result.note.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '«${result.note}»',
                                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    dateFormat.format(result.createdAt.toLocal()),
                                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          }

          if (state is CrossfitWorkoutError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить попытку'),
                      onPressed: () => context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
