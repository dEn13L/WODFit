import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/program/program_cubit.dart';
import '../../bloc/theme/theme_cubit.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';
import '../../../domain/entities/training_program.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<CrossfitWorkoutCubit>().loadClientWorkouts();
    context.read<ProgramCubit>().loadClientPrograms();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.fullName ?? 'Атлет',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Личный кабинет атлета',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        actions: [
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              final isLight = themeMode == ThemeMode.light;
              return IconButton(
                tooltip: isLight ? 'Тёмная тема' : 'Светлая тема',
                icon: Icon(isLight ? Icons.dark_mode : Icons.light_mode),
                onPressed: () => context.read<ThemeCubit>().toggleTheme(),
              );
            },
          ),
          IconButton(
            tooltip: 'История тренировок',
            icon: const Icon(Icons.history),
            onPressed: () async {
              await context.push('/client/history');
              if (mounted) _loadData();
            },
          ),
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(const SignOutRequested());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Programs section & Join button
              BlocConsumer<ProgramCubit, ProgramState>(
                listener: (context, state) {
                  if (state is ProgramLoaded && state.successMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.successMessage!),
                        backgroundColor: context.appTheme.success,
                      ),
                    );
                  }
                  if (state is ProgramError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: context.appTheme.destructive,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  final theme = Theme.of(context);
                  final colorScheme = theme.colorScheme;
                  final appTheme = context.appTheme;

                  if (state is ProgramLoading) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                      ),
                    );
                  }

                  if (state is ProgramLoaded) {
                    if (state.programs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color ?? colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Вы пока не состоите ни в одной программе',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Попросите у вашего тренера 6-значный код приглашения, чтобы видеть тренировки программы.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.fitness_center),
                              label: const Text('Вступить в программу по коду'),
                              onPressed: () async {
                                await context.push('/client/join-program');
                                if (mounted) _loadData();
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Мои программы',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                TextButton.icon(
                                  icon: Icon(Icons.add, size: 18, color: colorScheme.primary),
                                  label: Text('Вступить еще', style: TextStyle(color: colorScheme.primary)),
                                  onPressed: () async {
                                    await context.push('/client/join-program');
                                    if (mounted) _loadData();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.programs.length,
                              separatorBuilder: (context, index) => const Divider(height: 12),
                              itemBuilder: (context, index) {
                                final program = state.programs[index];
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          program.kind == ProgramKind.personal ? Icons.person : Icons.groups,
                                          size: 20,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          program.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            program.kind.displayName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final programCubit = context.read<ProgramCubit>();
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dCtx) => AlertDialog(
                                            backgroundColor: colorScheme.surface,
                                            title: const Text('Выйти из программы?'),
                                            content: Text('Вы действительно хотите покинуть программу "${program.name}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(dCtx).pop(false),
                                                child: const Text('Отмена'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: appTheme.destructive,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => Navigator.of(dCtx).pop(true),
                                                child: const Text('Выйти'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await programCubit.leaveProgram(program.id);
                                          if (mounted) _loadData();
                                        }
                                      },
                                      child: Text('Выйти', style: TextStyle(color: appTheme.destructive, fontSize: 12)),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 16),

              // Quick Actions Bar: History button
              InkWell(
                onTap: () async {
                  await context.push('/client/history');
                  if (mounted) _loadData();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.history, color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'История и результаты тренировок',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Просмотр прошедших WOD и фильтрация',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recent Results Section
              BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
                builder: (context, state) {
                  if (state is CrossfitWorkoutListLoaded) {
                    return _buildRecentResultsSection(context, state);
                  }
                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 24),

              // Assigned Workouts Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Назначенные тренировки (WOD)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () async {
                      await context.push('/client/history');
                      if (mounted) _loadData();
                    },
                    child: Text('Все →', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
                builder: (context, state) {
                  final colorScheme = Theme.of(context).colorScheme;
                  final appTheme = context.appTheme;

                  if (state is CrossfitWorkoutLoading) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                    );
                  }

                  if (state is CrossfitWorkoutError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30.0),
                        child: Column(
                          children: [
                            Text(state.message, style: TextStyle(color: appTheme.destructive)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is CrossfitWorkoutListLoaded) {
                    if (state.workouts.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.fitness_center_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Нет назначенных тренировок',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Когда тренер опубликует тренировку для вашей программы, она появится здесь.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.workouts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final workout = state.workouts[index];
                        final workoutResults = state.userResults.where((r) => r.workoutId == workout.id).toList();

                        return _WorkoutClientCard(
                          workout: workout,
                          userResults: workoutResults,
                          onTap: () async {
                            await context.push('/workout/${workout.id}');
                            if (mounted) _loadData();
                          },
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentResultsSection(BuildContext context, CrossfitWorkoutListLoaded state) {
    final colorScheme = Theme.of(context).colorScheme;
    final workouts = state.workouts;
    final userResults = state.userResults;

    // Filter workouts where user has recorded results, or past workouts, up to 5
    final workoutsWithResults = workouts
        .where((w) => userResults.any((r) => r.workoutId == w.id))
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Последние результаты',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (workoutsWithResults.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await context.push('/client/history');
                  if (mounted) _loadData();
                },
                child: Text('Вся история', style: TextStyle(color: colorScheme.primary, fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (workoutsWithResults.isEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined, color: colorScheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Нет сохраненных результатов',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Откройте тренировку и зафиксируйте свои показатели!',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workoutsWithResults.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final workout = workoutsWithResults[index];
              final results = userResults.where((r) => r.workoutId == workout.id).toList();

              return InkWell(
                onTap: () async {
                  await context.push('/workout/${workout.id}');
                  if (mounted) _loadData();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        WorkoutDateFormatter.formatList(workout.scheduledAt, workout.title),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Parts results summary
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: workout.parts.map((p) {
                          final res = results.where((r) => r.partId == p.id).firstOrNull;
                          if (res == null) return const SizedBox.shrink();

                          final taskTitle = p.title.trim().isNotEmpty
                              ? p.title.trim()
                              : (p.type?.displayName ?? 'Задание');

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$taskTitle: ',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                                Text(
                                  res.formattedScore,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).where((w) => w is! SizedBox).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WorkoutClientCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final List<PartResult> userResults;
  final VoidCallback onTap;

  const _WorkoutClientCard({
    required this.workout,
    required this.userResults,
    required this.onTap,
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

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      WorkoutDateFormatter.formatList(workout.scheduledAt, workout.title),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurfaceVariant),
                ],
              ),
              if (workout.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  workout.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (workout.parts.isNotEmpty && userResults.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (completedCount == workout.parts.length ? appTheme.success : colorScheme.primary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$completedCount/${workout.parts.length} готово',
                        style: TextStyle(
                          color: completedCount == workout.parts.length ? appTheme.success : colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        workout.workoutTypesSummary,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
