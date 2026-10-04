import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../core/utils/workout_progress_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/training_program.dart';
import '../../../domain/entities/part_result.dart';
import '../../widgets/workout_calendar.dart';
import '../../widgets/app_state_view.dart';
import '../../bloc/program/program_cubit.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  DateTime _selectedDate = WorkoutDateFormatter.localDay(DateTime.now());
  String? _selectedProgramId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() => Future.wait([
    context.read<CrossfitWorkoutCubit>().loadClientWorkouts(),
    context.read<ProgramCubit>().loadClientPrograms(),
  ]);

  @override
  Widget build(BuildContext context) {
    final programState = context.watch<ProgramCubit>().state;
    final programs = programState is ProgramLoaded
        ? programState.programs
        : <TrainingProgram>[];
    final programId = programs.any((p) => p.id == _selectedProgramId)
        ? _selectedProgramId
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Все тренировки')),
      body: BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        builder: (context, state) {
          if (state is CrossfitWorkoutError) {
            return AppErrorView(message: state.message, onRetry: _loadData);
          }
          if (state is! CrossfitWorkoutListLoaded) {
            return const AppLoadingView(semanticLabel: 'Загрузка тренировок');
          }
          final visible = state.workouts
              .where(
                (w) =>
                    w.status == WorkoutStatus.published &&
                    (programId == null ||
                        w.assignedProgramIds.contains(programId)),
              )
              .toList();
          final dayWorkouts =
              visible
                  .where(
                    (w) => WorkoutDateFormatter.sameDay(
                      w.scheduledAt,
                      _selectedDate,
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(programId),
                  initialValue: programId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Программа'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Все программы'),
                    ),
                    ...programs.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _selectedProgramId = value == '' ? null : value,
                  ),
                ),
                const SizedBox(height: 12),
                if (programState is ProgramError)
                  TextButton(
                    onPressed: _loadData,
                    child: const Text('Повторить загрузку программ'),
                  ),
                if (state.refreshError != null)
                  TextButton(
                    onPressed: _loadData,
                    child: Text('${state.refreshError} · Повторить'),
                  ),
                WorkoutCalendar(
                  workouts: visible,
                  selectedDate: _selectedDate,
                  monthView: true,
                  onDateSelected: (date) =>
                      setState(() => _selectedDate = date),
                ),
                const SizedBox(height: 16),
                Text(
                  WorkoutDateFormatter.formatCalendarDay(_selectedDate),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (dayWorkouts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'На выбранный день тренировок нет. Выберите другую дату.',
                    ),
                  ),
                for (final workout in dayWorkouts) ...[
                  _HistoryWorkoutCard(
                    workout: workout,
                    userResults: state.userResults
                        .where((r) => r.workoutId == workout.id)
                        .toList(),
                    isPast: workout.scheduledAt.isBefore(DateTime.now()),
                    onRefreshNeeded: _loadData,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryWorkoutCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final List<PartResult> userResults;
  final bool isPast;
  final VoidCallback onRefreshNeeded;

  const _HistoryWorkoutCard({
    required this.workout,
    required this.userResults,
    required this.isPast,
    required this.onRefreshNeeded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    final completedCount = workout.parts.where((p) {
      final res = userResults.where((r) => r.partId == p.id);
      return res.isNotEmpty && res.first.status == ResultStatus.done;
    }).length;
    final totalParts = workout.parts.length;
    final hasAnyResult = userResults.isNotEmpty;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${workout.nameForProgram()}\n${WorkoutDateFormatter.formatList(workout.scheduledAt)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                if (isPast) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedCount == totalParts && totalParts > 0
                          ? appTheme.success.withValues(alpha: 0.15)
                          : hasAnyResult
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: completedCount == totalParts && totalParts > 0
                            ? appTheme.success
                            : hasAnyResult
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      completedCount == totalParts && totalParts > 0
                          ? 'Завершено (${WorkoutProgressFormatter.format(completedCount, totalParts)})'
                          : hasAnyResult
                              ? 'Частично (${WorkoutProgressFormatter.format(completedCount, totalParts)})'
                              : 'Нет результатов',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: completedCount == totalParts && totalParts > 0
                            ? appTheme.success
                            : hasAnyResult
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.primary, width: 1),
                    ),
                    child: Text(
                      'Предстоящая',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (workout.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                workout.description,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],

            if (workout.assignments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: workout.assignments.map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center, size: 12, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          a.programName ?? 'Программа',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 12),

            // Workout Parts with User Results
            Text(
              'Задания:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),

            if (workout.parts.isEmpty)
              Text(
                'В тренировке пока нет заданий',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workout.parts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final part = workout.parts[index];
                  final result = userResults.where((r) => r.partId == part.id).firstOrNull;
                  final taskTitle = part.title.trim().isNotEmpty
                      ? part.title.trim()
                      : (part.type?.displayName ?? 'Задание');

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: result != null ? colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          taskTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (part.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            part.description.trim(),
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Client Result display
                        if (result != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: result.status == ResultStatus.done
                                      ? appTheme.success.withValues(alpha: 0.2)
                                      : result.status == ResultStatus.scaled
                                          ? appTheme.warning.withValues(alpha: 0.2)
                                          : appTheme.destructive.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  result.status.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: result.status == ResultStatus.done
                                        ? appTheme.success
                                        : result.status == ResultStatus.scaled
                                            ? appTheme.warning
                                            : appTheme.destructive,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Результат: ${result.formattedScore}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (result.note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Заметка: ${result.note}',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Результат не внесен',
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                              ),
                              InkWell(
                                onTap: () async {
                                  await context.push('/workout/${workout.id}');
                                  onRefreshNeeded();
                                },
                                child: Text(
                                  'Внести результат →',
                                  style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),

            // Bottom Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.people_outline, size: 16),
                    label: const Text('Результаты участников', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: colorScheme.primary),
                      foregroundColor: colorScheme.primary,
                    ),
                    onPressed: () {
                      context.push('/workout/${workout.id}/results');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Открыть', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () async {
                      await context.push('/workout/${workout.id}');
                      onRefreshNeeded();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
