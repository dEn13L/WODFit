import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';
import '../../widgets/app_state_view.dart';
import '../coach/workouts/create_workout_screen.dart';
import 'result_input/part_result_input_modal.dart';
import 'result_sync_status_view.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId);
  }

  void _showResultDialog(WorkoutPart part, PartResult? existingResult) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return PartResultInputModal(
          workoutId: widget.workoutId,
          part: part,
          initialResult: existingResult,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isCoach = authState is Authenticated && authState.user.isCoach;

    if (isCoach) {
      return _CoachWorkoutDetailView(workoutId: widget.workoutId);
    }

    return _ClientWorkoutDetailView(
      workoutId: widget.workoutId,
      showResultDialog: _showResultDialog,
    );
  }
}

class _CoachWorkoutDetailView extends StatelessWidget {
  final String workoutId;

  const _CoachWorkoutDetailView({required this.workoutId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    return BlocConsumer<CrossfitWorkoutCubit, CrossfitWorkoutState>(
      listener: (context, state) {
        if (state is CrossfitWorkoutError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: appTheme.destructive,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is CrossfitWorkoutLoading) {
          return Scaffold(
            body: const AppLoadingView(semanticLabel: 'Загрузка тренировки'),
          );
        }

        if (state is CrossfitWorkoutDetailLoaded) {
          final workout = state.workout;

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20, color: colorScheme.onSurface),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  tooltip: 'Редактировать',
                  icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => CreateWorkoutScreen(workoutToEdit: workout),
                      ),
                    );
                    if (context.mounted) {
                      context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(workout.id);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Дублировать',
                  icon: Icon(Icons.copy_outlined, color: colorScheme.onSurface),
                  onPressed: () async {
                    final cubit = context.read<CrossfitWorkoutCubit>();
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await cubit.duplicateWorkout(workout.id);
                    if (ok && context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Text('Тренировка продублирована'),
                          backgroundColor: appTheme.success,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Удалить',
                  icon: Icon(Icons.delete_outline, color: appTheme.destructive),
                  onPressed: () async {
                    final cubit = context.read<CrossfitWorkoutCubit>();
                    final messenger = ScaffoldMessenger.of(context);
                    final router = GoRouter.of(context);

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(
                          'Удалить тренировку?',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'Вы действительно хотите удалить тренировку "${WorkoutDateFormatter.formatList(workout.scheduledAt, workout.title)}"?\n\n'
                          'Все данные тренировки, назначения и внесенные результаты участников будут безвозвратно удалены.',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(false),
                            child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appTheme.destructive,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(dCtx).pop(true),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final ok = await cubit.deleteWorkout(workout.id);
                      if (ok && context.mounted) {
                        router.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Тренировка удалена'),
                            backgroundColor: appTheme.success,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Date + Draft badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          WorkoutDateFormatter.formatDay(workout.scheduledAt),
                          style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ) ??
                              TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ),
                      if (workout.status == WorkoutStatus.draft) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: appTheme.draft.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: appTheme.draft),
                          ),
                          child: Text(
                            'Черновик',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: appTheme.draft,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row 2: Time
                  Text(
                    WorkoutDateFormatter.formatTime(workout.scheduledAt),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  // Row 3: Session note / title
                  if (workout.title.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      workout.title.trim(),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Label: ЗАДАНИЯ ТРЕНИРОВКИ
                  Text(
                    'ЗАДАНИЯ ТРЕНИРОВКИ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  // Assigned programs chips under label
                  if (workout.assignments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: workout.assignments.map((a) {
                        final programTitle = a.programName ?? 'Программа';
                        return InkWell(
                          onTap: () => context.push('/coach/programs/${a.programId}'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Text(
                              programTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Tasks list
                  if (workout.parts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Center(
                        child: Text(
                          'В этой тренировке пока нет заданий',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...workout.parts.map((part) {
                      final taskTitle = part.title.trim().isNotEmpty
                          ? part.title.trim()
                          : (part.type?.displayName ?? 'Задание');

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color ?? colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),
                  // Button: Результаты участников
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () => context.push('/workout/${workout.id}/results'),
                      child: const Text(
                        'Результаты участников',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: colorScheme.onSurface),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Text('Тренировка не найдена', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
        );
      },
    );
  }
}

class _ClientWorkoutDetailView extends StatelessWidget {
  final String workoutId;
  final void Function(WorkoutPart part, PartResult? existingResult) showResultDialog;

  const _ClientWorkoutDetailView({
    required this.workoutId,
    required this.showResultDialog,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Результаты атлетов',
            icon: Icon(Icons.leaderboard_outlined, color: colorScheme.primary),
            onPressed: () => context.push('/workout/$workoutId/results'),
          ),
        ],
      ),
      body: BlocConsumer<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        listener: (context, state) {
          if (state is CrossfitWorkoutError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: appTheme.destructive,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CrossfitWorkoutLoading) {
            return const AppLoadingView(semanticLabel: 'Загрузка тренировки');
          }

          if (state is CrossfitWorkoutDetailLoaded) {
            final workout = state.workout;
            final userResultsMap = {
              for (final res in state.userResults) res.partId: res,
            };

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workout Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  WorkoutDateFormatter.formatDetail(workout.scheduledAt, workout.title),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              if (workout.status == WorkoutStatus.draft) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: appTheme.draft.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: appTheme.draft),
                                  ),
                                  child: Text(
                                    'Черновик',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: appTheme.draft,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (workout.assignments.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Назначено программам:',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: workout.assignments.map((a) {
                                return Chip(
                                  label: Text(a.programName ?? 'Программа', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Задания тренировки (${workout.parts.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: const Text('Результаты'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => context.push('/workout/${workout.id}/results'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Parts list
                  if (workout.parts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('В этой тренировке пока нет заданий')),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workout.parts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final part = workout.parts[index];
                        final userResult = userResultsMap[part.id];
                        final taskTitle = part.title.trim().isNotEmpty
                            ? part.title.trim()
                            : (part.type?.displayName ?? 'Задание');

                        return Card(
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
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                // Athlete's result section
                                if (userResult != null) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.check_circle, size: 16, color: appTheme.success),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Ваш результат: ${userResult.formattedScore}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Режим: ${userResult.status.displayName}',
                                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                            ),
                                            if (userResult.syncStatus != ResultSyncStatus.synced) ...[
                                              const SizedBox(height: 2),
                                              ResultSyncStatusView(
                                                status: userResult.syncStatus,
                                                onRetry: () => showResultDialog(part, userResult),
                                              ),
                                            ],
                                            if (userResult.note.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Заметка: ${userResult.note}',
                                                style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 12, fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Изменить'),
                                        onPressed: () => showResultDialog(part, userResult),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Результат не внесен',
                                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add_task, size: 16),
                                        label: const Text('Записать результат'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => showResultDialog(part, null),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }

          if (state is CrossfitWorkoutError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(workoutId),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
