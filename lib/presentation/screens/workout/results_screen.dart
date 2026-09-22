import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/workout_date_formatter.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

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
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
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
              color: colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      WorkoutDateFormatter.formatDetail(workout.scheduledAt, workout.title),
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Результаты участников по заданиям тренировки:',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
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
                          final taskTitle = part.title.trim().isNotEmpty
                              ? part.title.trim()
                              : (part.type?.displayName ?? 'Задание');

                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    taskTitle,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (part.description.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      part.description.trim(),
                                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.4),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (partResults.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                      child: Center(
                                        child: Text(
                                          'Пока никто не внес результат по этому заданию',
                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: partResults.length,
                                      separatorBuilder: (context, index) => Divider(color: colorScheme.outlineVariant, height: 16),
                                      itemBuilder: (context, rIndex) {
                                        final result = partResults[rIndex];
                                        final athleteName = result.userProfile?.fullName ?? 'Атлет';

                                        Color statusColor;
                                        switch (result.status) {
                                          case ResultStatus.done:
                                            statusColor = appTheme.success;
                                            break;
                                          case ResultStatus.scaled:
                                            statusColor = appTheme.warning;
                                            break;
                                          case ResultStatus.notDone:
                                            statusColor = appTheme.destructive;
                                            break;
                                        }

                                        return Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: colorScheme.surfaceContainerHighest,
                                              child: Text(
                                                athleteName.isNotEmpty ? athleteName[0].toUpperCase() : 'A',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
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
                                                  Text(
                                                    'Результат: ${result.formattedScore}',
                                                    style: TextStyle(
                                                      color: colorScheme.onSurface,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (result.note.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '«${result.note}»',
                                                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    dateFormat.format(result.createdAt.toLocal()),
                                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
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
                    Icon(Icons.error_outline, size: 56, color: appTheme.destructive),
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
