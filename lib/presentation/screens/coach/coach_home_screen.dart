import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/training_program.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/program/program_cubit.dart';
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
            const Text(
              'Панель тренера',
              style: TextStyle(fontSize: 12, color: AppColors.primaryNeon),
            ),
          ],
        ),
        actions: [
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
        color: AppColors.primaryNeon,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryNeon),
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
                          child: _QuickActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'Новая тренировка',
                            color: AppColors.primaryNeon,
                            textColor: Colors.black,
                            onTap: () async {
                              await context.push('/coach/workouts/create');
                              if (mounted) _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.group_add_outlined,
                            label: 'Новая программа',
                            color: AppColors.surface,
                            textColor: AppColors.textPrimary,
                            onTap: () async {
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
                        const Icon(Icons.today, size: 20, color: AppColors.primaryNeon),
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                workoutState.message,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 36,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Сегодня тренировок нет',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Запланируйте тренировку на сегодня кнопкой «Новая тренировка».',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                        const Icon(Icons.fitness_center_outlined, size: 20, color: AppColors.primaryNeon),
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
                          icon: const Icon(Icons.add, color: AppColors.primaryNeon),
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
                            foregroundColor: AppColors.primaryNeon,
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                programState.message,
                                style: const TextStyle(color: AppColors.error, fontSize: 13),
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_work_outlined,
                              size: 40,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'У вас пока нет программ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Создайте групповую или персональную программу для назначения тренировок атлетам.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await context.push('/coach/programs/create');
                                if (mounted) _loadData();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Создать программу'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNeon,
                                foregroundColor: Colors.black,
                              ),
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
    final isDraft = workout.status == WorkoutStatus.draft;
    final timeStr = WorkoutDateFormatter.formatTime(workout.scheduledAt);

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDraft
              ? Colors.amber.withValues(alpha: 0.3)
              : AppColors.primaryNeon.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNeon,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${workout.workoutTypesSummary}${workout.assignments.isNotEmpty ? ' • ${workout.assignments.map((a) => a.programName ?? 'Программа').join(', ')}' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Черновик',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
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
    final isPersonal = program.kind == ProgramKind.personal;
    final nearestDateText = nearestWorkoutDate != null
        ? DateFormat('dd.MM HH:mm').format(nearestWorkoutDate!.toLocal())
        : 'Нет запланированных';

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPersonal
              ? Colors.purpleAccent.withValues(alpha: 0.3)
              : AppColors.primaryNeon.withValues(alpha: 0.2),
        ),
      ),
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
                      color: isPersonal
                          ? Colors.purpleAccent.withValues(alpha: 0.15)
                          : AppColors.primaryNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPersonal ? Icons.person : Icons.groups,
                      color: isPersonal ? Colors.purpleAccent : AppColors.primaryNeon,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      program.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPersonal
                          ? Colors.purpleAccent.withValues(alpha: 0.2)
                          : AppColors.primaryNeon.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      program.kind.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPersonal ? Colors.purpleAccent : AppColors.primaryNeon,
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
                      const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${program.memberCount} участников',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Workout count
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '$workoutCount тренировок',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 14, color: AppColors.primaryNeon),
                  const SizedBox(width: 4),
                  Text(
                    'Ближайшая: $nearestDateText',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: nearestWorkoutDate != null ? FontWeight.w600 : FontWeight.normal,
                      color: nearestWorkoutDate != null ? AppColors.primaryNeon : AppColors.textSecondary,
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
