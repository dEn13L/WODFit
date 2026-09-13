import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/group/group_cubit.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';

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
    context.read<GroupCubit>().loadClientGroups();
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
            const Text(
              'Личный кабинет атлета',
              style: TextStyle(fontSize: 12, color: AppColors.primaryNeon),
            ),
          ],
        ),
        actions: [
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Groups section & Join button
              BlocConsumer<GroupCubit, GroupState>(
                listener: (context, state) {
                  if (state is GroupLoaded && state.successMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.successMessage!),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                  if (state is GroupError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is GroupLoading) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator(color: AppColors.primaryNeon)),
                      ),
                    );
                  }

                  if (state is GroupLoaded) {
                    if (state.groups.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.primaryNeon),
                                SizedBox(width: 8),
                                Text(
                                  'Вы пока не состоите ни в одной группе',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Попросите у вашего тренера 6-значный код приглашения, чтобы видеть тренировки группы.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.group_add),
                              label: const Text('Вступить в группу по коду'),
                              onPressed: () async {
                                await context.push('/client/join-group');
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
                                  'Мои группы',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18, color: AppColors.primaryNeon),
                                  label: const Text('Вступить еще', style: TextStyle(color: AppColors.primaryNeon)),
                                  onPressed: () async {
                                    await context.push('/client/join-group');
                                    if (mounted) _loadData();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.groups.length,
                              separatorBuilder: (context, index) => const Divider(color: AppColors.surfaceLight, height: 12),
                              itemBuilder: (context, index) {
                                final group = state.groups[index];
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.groups, size: 20, color: AppColors.primaryNeon),
                                        const SizedBox(width: 10),
                                        Text(
                                          group.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final groupCubit = context.read<GroupCubit>();
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dCtx) => AlertDialog(
                                            backgroundColor: AppColors.surface,
                                            title: const Text('Выйти из группы?'),
                                            content: Text('Вы действительно хотите покинуть группу "${group.name}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(dCtx).pop(false),
                                                child: const Text('Отмена'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                onPressed: () => Navigator.of(dCtx).pop(true),
                                                child: const Text('Выйти'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await groupCubit.leaveGroup(group.id);
                                          if (mounted) _loadData();
                                        }
                                      },
                                      child: const Text('Выйти', style: TextStyle(color: AppColors.error, fontSize: 12)),
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
              const SizedBox(height: 24),
              Text(
                'Назначенные тренировки (WOD)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
                builder: (context, state) {
                  if (state is CrossfitWorkoutLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primaryNeon)),
                    );
                  }

                  if (state is CrossfitWorkoutError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30.0),
                        child: Column(
                          children: [
                            Text(state.message, style: const TextStyle(color: AppColors.error)),
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
                                const Icon(Icons.fitness_center_outlined, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                const Text(
                                  'Нет назначенных тренировок',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Когда тренер опубликует тренировку для вашей группы, она появится здесь.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                        return _WorkoutClientCard(
                          workout: workout,
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
}

class _WorkoutClientCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final VoidCallback onTap;

  const _WorkoutClientCard({
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');
    final dateStr = dateFormat.format(workout.scheduledAt);

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
                      workout.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                ],
              ),
              if (workout.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  workout.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: AppColors.primaryNeon),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Блоков: ${workout.parts.length}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
