import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../bloc/workout/crossfit_workout_cubit.dart';

class CoachAllWorkoutsScreen extends StatefulWidget {
  const CoachAllWorkoutsScreen({super.key});

  @override
  State<CoachAllWorkoutsScreen> createState() => _CoachAllWorkoutsScreenState();
}

class _CoachAllWorkoutsScreenState extends State<CoachAllWorkoutsScreen> {
  String _searchQuery = '';
  WorkoutStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  void _loadWorkouts() {
    context.read<CrossfitWorkoutCubit>().loadCoachWorkouts();
  }

  Future<void> _duplicateWorkout(String workoutId) async {
    final cubit = context.read<CrossfitWorkoutCubit>();
    await cubit.duplicateWorkout(workoutId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тренировка скопирована в черновики'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteWorkout(CrossfitWorkout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить тренировку?'),
        content: Text(
          'Вы уверены, что хотите удалить "${workout.title}"?\n'
          'Все связанные результаты атлетов и назначения будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final cubit = context.read<CrossfitWorkoutCubit>();
      await cubit.deleteWorkout(workout.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Тренировка удалена'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все тренировки'),
        actions: [
          IconButton(
            tooltip: 'Создать тренировку',
            icon: const Icon(Icons.add, color: AppColors.primaryNeon),
            onPressed: () async {
              await context.push('/coach/workouts/create');
              if (mounted) _loadWorkouts();
            },
          ),
        ],
      ),
      body: BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        builder: (context, state) {
          if (state is CrossfitWorkoutLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryNeon),
            );
          }

          if (state is CrossfitWorkoutError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadWorkouts,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is CrossfitWorkoutListLoaded) {
            var workouts = state.workouts;

            if (workouts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fitness_center_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'У вас пока нет тренировок',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Создайте свою первую тренировку и назначьте её программам.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await context.push('/coach/workouts/create');
                          if (mounted) _loadWorkouts();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Создать тренировку'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_statusFilter != null) {
              workouts = workouts.where((w) => w.status == _statusFilter).toList();
            }

            if (_searchQuery.trim().isNotEmpty) {
              final query = _searchQuery.toLowerCase().trim();
              workouts = workouts.where((w) {
                final matchTitle = w.title.toLowerCase().contains(query);
                final matchDesc = w.description.toLowerCase().contains(query);
                final matchPrograms = w.assignments.any((a) => (a.programName ?? '').toLowerCase().contains(query));
                return matchTitle || matchDesc || matchPrograms;
              }).toList();
            }

            return RefreshIndicator(
              onRefresh: () async => _loadWorkouts(),
              color: AppColors.primaryNeon,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Поиск тренировки...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Все'),
                          selected: _statusFilter == null,
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Опубликованные'),
                          selected: _statusFilter == WorkoutStatus.published,
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = WorkoutStatus.published;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Черновики'),
                          selected: _statusFilter == WorkoutStatus.draft,
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = WorkoutStatus.draft;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: workouts.isEmpty
                        ? const Center(
                            child: Text(
                              'Ничего не найдено',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: workouts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final workout = workouts[index];
                              return _CoachWorkoutItemCard(
                                workout: workout,
                                onTap: () async {
                                  await context.push('/workout/${workout.id}');
                                  if (mounted) _loadWorkouts();
                                },
                                onDuplicate: () => _duplicateWorkout(workout.id),
                                onDelete: () => _deleteWorkout(workout),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _CoachWorkoutItemCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _CoachWorkoutItemCard({
    required this.workout,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isDraft = workout.status == WorkoutStatus.draft;

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDraft
              ? Colors.amber.withValues(alpha: 0.3)
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              dateFormat.format(workout.scheduledAt),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDraft
                          ? Colors.amber.withValues(alpha: 0.2)
                          : AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDraft ? 'Черновик' : 'Опубликовано',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDraft ? Colors.amber : AppColors.success,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                    onSelected: (val) {
                      if (val == 'duplicate') {
                        onDuplicate();
                      } else if (val == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 18),
                            SizedBox(width: 8),
                            Text('Дублировать'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Удалить', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (workout.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  workout.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.layers_outlined, size: 14, color: AppColors.primaryNeon.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text(
                    'Частей: ${workout.parts.length}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  if (workout.assignments.isNotEmpty) ...[
                    const Icon(Icons.fitness_center, size: 14, color: AppColors.primaryNeon),
                    const SizedBox(width: 4),
                    Text(
                      workout.assignments.map((a) => a.programName ?? 'Программа').join(', '),
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryNeon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
