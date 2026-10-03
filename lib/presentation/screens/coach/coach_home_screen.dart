import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/training_program.dart';
import 'widgets/coach_welcome_banner.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/program/program_cubit.dart';
import '../../bloc/theme/theme_cubit.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';

class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  State<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() => Future.wait([
    context.read<CrossfitWorkoutCubit>().loadCoachWorkouts(),
    context.read<ProgramCubit>().loadCoachPrograms(),
  ]);

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;

    final workoutState = context.watch<CrossfitWorkoutCubit>().state;
    final programState = context.watch<ProgramCubit>().state;

    final isLoading =
        workoutState is CrossfitWorkoutLoading ||
        programState is ProgramLoading;

    final allWorkouts = workoutState is CrossfitWorkoutListLoaded
        ? workoutState.workouts
        : (workoutState is CrossfitWorkoutDetailLoaded
              ? [workoutState.workout]
              : <CrossfitWorkout>[]);
    final allPrograms = programState is ProgramLoaded
        ? programState.programs
        : <TrainingProgram>[];

    final now = DateTime.now();
    final todayWorkouts = allWorkouts.where((w) {
      final scheduled = w.scheduledAt.toLocal();
      return scheduled.year == now.year &&
          scheduled.month == now.month &&
          scheduled.day == now.day;
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final nearestDates = <String, DateTime>{};
    for (final workout in allWorkouts) {
      if (workout.scheduledAt.isBefore(now)) continue;
      for (final programId in workout.assignedProgramIds) {
        final previous = nearestDates[programId];
        if (previous == null || workout.scheduledAt.isBefore(previous)) {
          nearestDates[programId] = workout.scheduledAt;
        }
      }
    }
    final sortedPrograms = List<TrainingProgram>.of(allPrograms)
      ..sort((a, b) {
        final aDate = nearestDates[a.id];
        final bDate = nearestDates[b.id];
        if (aDate == null && bDate == null) return a.name.compareTo(b.name);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final order = aDate.compareTo(bDate);
        return order != 0 ? order : a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WodFit',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Панель тренера',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
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
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoachWelcomeBanner(name: user?.fullName),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text(
                          'Создать тренировку',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          await context.push('/coach/workouts/create');
                          if (mounted) _loadData();
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    _HomeSectionHeader(
                      icon: Icons.today,
                      title: 'Сегодня',
                      linkLabel: 'Все тренировки',
                      onPressed: () async {
                        await context.push('/coach/workouts');
                        if (mounted) _loadData();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (workoutState is CrossfitWorkoutError)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).cardTheme.color ??
                              Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: context.appTheme.destructive,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                workoutState.message,
                                style: TextStyle(
                                  color: context.appTheme.destructive,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadData,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                    else if (todayWorkouts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).cardTheme.color ??
                              Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 36,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Сегодня тренировок нет',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Запланируйте тренировку на сегодня кнопкой «Создать тренировку».',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todayWorkouts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final workout = todayWorkouts[index];
                          return _TodayWorkoutCard(
                            workout: workout,
                            onTap: () async {
                              if (workout.status == WorkoutStatus.draft) {
                                await context.push(
                                  '/coach/workouts/create',
                                  extra: workout,
                                );
                              } else {
                                await context.push('/workout/${workout.id}');
                              }
                              if (mounted) _loadData();
                            },
                          );
                        },
                      ),

                    const SizedBox(height: 28),

                    _HomeSectionHeader(
                      icon: Icons.fitness_center_outlined,
                      title: 'Программы',
                      linkLabel: 'Все программы',
                      onPressed: () async {
                        await context.push('/coach/programs');
                        if (mounted) _loadData();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (programState is ProgramError)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).cardTheme.color ??
                              Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: context.appTheme.destructive,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                programState.message,
                                style: TextStyle(
                                  color: context.appTheme.destructive,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadData,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                    else if (allPrograms.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).cardTheme.color ??
                              Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_work_outlined,
                              size: 40,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'У вас пока нет программ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Создайте групповую или персональную программу для назначения тренировок атлетам.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await context.push('/coach/programs/create');
                                if (mounted) _loadData();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Создать программу'),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedPrograms.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final program = sortedPrograms[index];
                          return _CoachProgramDashboardCard(
                            program: program,
                            nearestWorkoutDate: nearestDates[program.id],
                            onTap: () async {
                              await context.push(
                                '/coach/programs/${program.id}',
                              );
                              if (mounted) _loadData();
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String linkLabel;
  final VoidCallback onPressed;

  const _HomeSectionHeader({
    required this.icon,
    required this.title,
    required this.linkLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.list, size: 16),
              label: Text(linkLabel),
              style: TextButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayWorkoutCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final VoidCallback onTap;

  const _TodayWorkoutCard({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;
    final isDraft = workout.status == WorkoutStatus.draft;
    final timeStr = WorkoutDateFormatter.formatTime(workout.scheduledAt);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: appTheme.timeChipBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      WorkoutDateFormatter.formatTodayTomorrow(
                        workout.scheduledAt,
                        workout.title,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      workout.assignments.isEmpty
                          ? 'Без программы'
                          : workout.assignments
                                .map((a) => a.programName ?? 'Программа')
                                .join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDraft) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: appTheme.draft.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Черновик',
                              style: TextStyle(
                                fontSize: 12,
                                color: appTheme.draft,
                              ),
                            ),
                          ),
                          Text(
                            'Продолжить',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachProgramDashboardCard extends StatelessWidget {
  final TrainingProgram program;
  final DateTime? nearestWorkoutDate;
  final VoidCallback onTap;

  const _CoachProgramDashboardCard({
    required this.program,
    required this.nearestWorkoutDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isPersonal = program.kind == ProgramKind.personal;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    CoachWelcomeBanner.assetPath,
                    width: 56,
                    height: 64,
                    fit: BoxFit.cover,
                    alignment: isPersonal
                        ? Alignment.centerRight
                        : Alignment.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isPersonal
                              ? Icons.person_outline
                              : Icons.groups_outlined,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isPersonal
                                ? 'Персональная программа'
                                : 'Групповая программа',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (nearestWorkoutDate != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              WorkoutDateFormatter.formatTodayTomorrow(
                                nearestWorkoutDate!,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
