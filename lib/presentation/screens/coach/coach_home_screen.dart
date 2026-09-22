import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/training_program.dart';
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

  void _loadData() {
    context.read<CrossfitWorkoutCubit>().loadCoachWorkouts();
    context.read<ProgramCubit>().loadCoachPrograms();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;

    final workoutState = context.watch<CrossfitWorkoutCubit>().state;
    final programState = context.watch<ProgramCubit>().state;

    final isLoading = workoutState is CrossfitWorkoutLoading || programState is ProgramLoading;

    final allWorkouts = workoutState is CrossfitWorkoutListLoaded
        ? workoutState.workouts
        : (workoutState is CrossfitWorkoutDetailLoaded
            ? [workoutState.workout]
            : <CrossfitWorkout>[]);
    final allPrograms = programState is ProgramLoaded ? programState.programs : <TrainingProgram>[];

    final now = DateTime.now();
    final todayWorkouts = allWorkouts.where((w) {
      final scheduled = w.scheduledAt.toLocal();
      return scheduled.year == now.year &&
          scheduled.month == now.month &&
          scheduled.day == now.day;
    }).toList()
      ..sort((a, b) => b.scheduledAt.toLocal().compareTo(a.scheduledAt.toLocal()));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.fullName ?? 'Тренер',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Панель тренера',
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
            tooltip: 'Все тренировки',
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () async {
              await context.push('/coach/workouts');
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
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Actions Block
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            label: const Text(
                              'Новая тренировка',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              await context.push('/coach/workouts/create');
                              if (mounted) _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              Icons.group_add_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            label: Text(
                              'Новая программа',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              await context.push('/coach/programs/create');
                              if (mounted) _loadData();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Block "Сегодня"
                    Row(
                      children: [
                        Icon(Icons.today, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Сегодня',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('dd.MM.yyyy').format(now),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (workoutState is CrossfitWorkoutError)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: context.appTheme.destructive),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                workoutState.message,
                                style: TextStyle(color: context.appTheme.destructive, fontSize: 13),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 36,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                              'Запланируйте тренировку на сегодня кнопкой «Новая тренировка».',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todayWorkouts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final workout = todayWorkouts[index];
                          return _TodayWorkoutCard(
                            workout: workout,
                            onTap: () async {
                              await context.push('/workout/${workout.id}');
                              if (mounted) _loadData();
                            },
                          );
                        },
                      ),

                    const SizedBox(height: 28),

                    // Block "Программы"
                    Row(
                      children: [
                        Icon(Icons.fitness_center_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Программы',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Создать программу',
                          icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                          onPressed: () async {
                            await context.push('/coach/programs/create');
                            if (mounted) _loadData();
                          },
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await context.push('/coach/workouts');
                            if (mounted) _loadData();
                          },
                          icon: const Icon(Icons.list, size: 16),
                          label: const Text('Все тренировки'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (programState is ProgramError)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: context.appTheme.destructive),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                programState.message,
                                style: TextStyle(color: context.appTheme.destructive, fontSize: 13),
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
                          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_work_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                        itemCount: allPrograms.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final program = allPrograms[index];
                          final programWorkouts = allWorkouts
                              .where((w) => w.assignedProgramIds.contains(program.id))
                              .toList();

                          final upcoming = programWorkouts
                              .where((w) => w.scheduledAt.toLocal().isAfter(now) || w.scheduledAt.toLocal().isAtSameMomentAs(now))
                              .toList()
                            ..sort((a, b) => a.scheduledAt.toLocal().compareTo(b.scheduledAt.toLocal()));

                          final DateTime? nearestDate = upcoming.isNotEmpty ? upcoming.first.scheduledAt : null;

                          return _CoachProgramDashboardCard(
                            program: program,
                            workoutCount: programWorkouts.length,
                            nearestWorkoutDate: nearestDate,
                            onTap: () async {
                              await context.push('/coach/programs/${program.id}');
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

class _TodayWorkoutCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final VoidCallback onTap;

  const _TodayWorkoutCard({
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;
    final isDraft = workout.status == WorkoutStatus.draft;
    final timeStr = WorkoutDateFormatter.formatTime(workout.scheduledAt);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      WorkoutDateFormatter.formatTodayTomorrow(workout.scheduledAt, workout.title),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${workout.workoutTypesSummary}${workout.assignments.isNotEmpty ? ' • ${workout.assignments.map((a) => a.programName ?? 'Программа').join(', ')}' : ''}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isDraft) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: appTheme.draft.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: appTheme.draft.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Черновик',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: appTheme.draft,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachProgramDashboardCard extends StatelessWidget {
  final TrainingProgram program;
  final int workoutCount;
  final DateTime? nearestWorkoutDate;
  final VoidCallback onTap;

  const _CoachProgramDashboardCard({
    required this.program,
    required this.workoutCount,
    required this.nearestWorkoutDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPersonal = program.kind == ProgramKind.personal;
    final nearestDateText = nearestWorkoutDate != null
        ? DateFormat('dd.MM HH:mm').format(nearestWorkoutDate!.toLocal())
        : 'Нет запланированных';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPersonal ? Icons.person : Icons.groups,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      program.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      program.kind.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Members count
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${program.memberCount} участников',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Workout count
                  Row(
                    children: [
                      Icon(Icons.fitness_center, size: 13, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$workoutCount тренировок',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Ближайшая: $nearestDateText',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: nearestWorkoutDate != null ? FontWeight.w600 : FontWeight.normal,
                      color: nearestWorkoutDate != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
