import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/workout_date_formatter.dart';
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
        SnackBar(
          content: const Text('Тренировка скопирована в черновики'),
          backgroundColor: context.appTheme.success,
        ),
      );
    }
  }

  Future<void> _deleteWorkout(CrossfitWorkout workout) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colorScheme.surface,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.destructive,
              foregroundColor: Colors.white,
            ),
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
          SnackBar(
            content: const Text('Тренировка удалена'),
            backgroundColor: appTheme.destructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Все тренировки'),
        actions: [
          IconButton(
            tooltip: 'Создать тренировку',
            icon: Icon(Icons.add, color: colorScheme.primary),
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
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          if (state is CrossfitWorkoutError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: appTheme.destructive, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appTheme.destructive),
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
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'У вас пока нет тренировок',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Создайте свою первую тренировку и назначьте её программам.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
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
              color: colorScheme.primary,
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
                        ? Center(
                            child: Text(
                              'Ничего не найдено',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;
    final isDraft = workout.status == WorkoutStatus.draft;

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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: appTheme.draft.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
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
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
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
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: appTheme.destructive),
                            const SizedBox(width: 8),
                            Text('Удалить', style: TextStyle(color: appTheme.destructive)),
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
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.fitness_center_outlined, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      workout.workoutTypesSummary,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (workout.assignments.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.groups_outlined, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      workout.assignments.map((a) => a.programName ?? 'Программа').join(', '),
                      style: TextStyle(fontSize: 12, color: colorScheme.primary),
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
