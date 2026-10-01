import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';
import 'participant_result_card.dart';
import 'results_filter_panel.dart';
import 'results_matrix.dart';
import 'results_matrix_table.dart';

class ResultsScreen extends StatefulWidget {
  final String workoutId;

  const ResultsScreen({super.key, required this.workoutId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  ResultsFilter _filter = ResultsFilter.all;

  @override
  void initState() {
    super.initState();
    context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId);
  }

  Future<void> _reload() =>
      context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты участников'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        builder: (context, state) {
          if (state is CrossfitWorkoutLoading || state is CrossfitWorkoutInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CrossfitWorkoutError) {
            return _ErrorState(message: state.message, onRetry: _reload);
          }
          if (state is! CrossfitWorkoutDetailLoaded) {
            return const SizedBox.shrink();
          }

          final workout = state.workout;
          if (workout.parts.isEmpty) {
            return _EmptyState(
              icon: Icons.fitness_center_outlined,
              title: 'В тренировке нет заданий',
              description: 'Добавьте задания, чтобы появилась матрица выполнения.',
              onRefresh: _reload,
            );
          }
          if (state.participants.isEmpty) {
            return _EmptyState(
              icon: Icons.people_outline,
              title: 'Нет участников',
              description: 'В назначенных программах пока нет участников.',
              onRefresh: _reload,
            );
          }

          final matrix = buildResultsMatrix(
            parts: workout.parts,
            participants: state.participants,
            results: state.allResults,
          );
          final filteredRows = matrix.filtered(_filter);

          return RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1000;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WorkoutDateFormatter.formatDetail(
                              workout.scheduledAt,
                              workout.title,
                            ),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ResultsFilterPanel(
                            matrix: matrix,
                            selected: _filter,
                            onChanged: (filter) => setState(() => _filter = filter),
                          ),
                          if (state.allResults.isEmpty) ...[
                            const SizedBox(height: 16),
                            const _NoResultsNotice(),
                          ],
                          const SizedBox(height: 16),
                          if (filteredRows.isEmpty)
                            const _NoFilteredParticipants()
                          else if (isWide)
                            ResultsMatrixTable(rows: filteredRows, matrix: matrix)
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredRows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => ParticipantResultCard(
                                row: filteredRows[index],
                                parts: matrix.parts,
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NoResultsNotice extends StatelessWidget {
  const _NoResultsNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Участники пока не внесли результаты.',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _NoFilteredParticipants extends StatelessWidget {
  const _NoFilteredParticipants();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'В этой категории нет участников',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Future<void> Function() onRefresh;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: context.appTheme.destructive),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
