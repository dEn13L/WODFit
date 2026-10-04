import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/workout_date_formatter.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../bloc/program/program_cubit.dart';
import '../../../bloc/workout/crossfit_workout_cubit.dart';
import '../../../widgets/app_state_view.dart';
import '../../../widgets/workout_calendar.dart';
import 'create_workout_screen.dart';

class CoachAllWorkoutsScreen extends StatefulWidget {
  const CoachAllWorkoutsScreen({super.key});

  @override
  State<CoachAllWorkoutsScreen> createState() => _CoachAllWorkoutsScreenState();
}

class _CoachAllWorkoutsScreenState extends State<CoachAllWorkoutsScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  DateTime _selectedDate = WorkoutDateFormatter.localDay(DateTime.now());
  String? _programFilter;
  WorkoutStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    await context.push(
      '/coach/workouts/create',
      extra: <String, dynamic>{
        'initialScheduledAt': _selectedDate,
        if (_programFilter != null) 'initialProgramId': _programFilter,
      },
    );
    if (mounted) await _loadWorkouts();
  }

  Future<void> _loadWorkouts() => Future.wait([
    context.read<CrossfitWorkoutCubit>().loadCoachWorkouts(),
    context.read<ProgramCubit>().loadCoachPrograms(),
  ]);

  Future<void> _duplicateWorkout(CrossfitWorkout workout) async {
    final saved = await CreateWorkoutScreen.openCopy(context, workout);
    if (saved != null && mounted) await _loadWorkouts();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Все тренировки'),
        actions: [
          IconButton(
            tooltip: 'Создать тренировку',
            icon: Icon(Icons.add, color: colorScheme.primary),
            onPressed: _openCreate,
          ),
        ],
      ),
      body: BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        builder: (context, state) {
          if (state is CrossfitWorkoutLoading) {
            return const AppLoadingView(semanticLabel: 'Загрузка тренировок');
          }

          if (state is CrossfitWorkoutError) {
            return AppErrorView(
              message: state.message,
              onRetry: () async => _loadWorkouts(),
            );
          }

          if (state is CrossfitWorkoutListLoaded) {
            final programState = context.watch<ProgramCubit>().state;
            final programs = <String, String>{
              if (programState is ProgramLoaded)
                for (final program in programState.programs)
                  program.id: program.name,
            };
            for (final workout in state.workouts) {
              for (final assignment in workout.assignments) {
                programs.putIfAbsent(
                  assignment.programId,
                  () => assignment.programName ?? 'Программа',
                );
              }
            }
            final programId = programs.containsKey(_programFilter)
                ? _programFilter
                : null;
            final query = _searchQuery.toLowerCase().trim();
            final visible = state.workouts
                .where(
                  (w) =>
                      (_statusFilter == null || w.status == _statusFilter) &&
                      (programId == null ||
                          w.assignedProgramIds.contains(programId)) &&
                      (query.isEmpty ||
                          w.title.toLowerCase().contains(query) ||
                          w.assignments.any(
                            (a) => (a.programName ?? '').toLowerCase().contains(
                              query,
                            ),
                          )),
                )
                .toList();
            final workouts =
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
              onRefresh: _loadWorkouts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по уточнению или программе',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Очистить поиск',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
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
                      ...programs.entries.map(
                        (p) => DropdownMenuItem(
                          value: p.key,
                          child: Text(p.value, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(
                      () => _programFilter = value == '' ? null : value,
                    ),
                  ),
                  if (programState is ProgramError)
                    TextButton(
                      onPressed: _loadWorkouts,
                      child: const Text('Повторить загрузку программ'),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Все'),
                        selected: _statusFilter == null,
                        onSelected: (_) => setState(() => _statusFilter = null),
                      ),
                      FilterChip(
                        label: const Text('Опубликованные'),
                        selected: _statusFilter == WorkoutStatus.published,
                        onSelected: (_) => setState(
                          () => _statusFilter = WorkoutStatus.published,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Черновики'),
                        selected: _statusFilter == WorkoutStatus.draft,
                        onSelected: (_) =>
                            setState(() => _statusFilter = WorkoutStatus.draft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.refreshError != null)
                    TextButton(
                      onPressed: _loadWorkouts,
                      child: Text('${state.refreshError} · Повторить'),
                    ),
                  WorkoutCalendar(
                    workouts: visible,
                    selectedDate: _selectedDate,
                    showDrafts: true,
                    monthView: true,
                    onDateSelected: (date) =>
                        setState(() => _selectedDate = date),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    WorkoutDateFormatter.formatCalendarDay(_selectedDate),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (workouts.isEmpty) ...[
                    const Text(
                      'На выбранный день тренировок нет с учётом фильтров.',
                    ),
                    TextButton.icon(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('Создать тренировку'),
                    ),
                  ],
                  for (final workout in workouts) ...[
                    _CoachWorkoutItemCard(
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
                        if (mounted) _loadWorkouts();
                      },
                      onDuplicate: () => _duplicateWorkout(workout),
                      onDelete: () => _deleteWorkout(workout),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                        borderRadius: BorderRadius.circular(10),
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
                    Flexible(child: Text(
                      workout.assignments.map((a) => a.programName ?? 'Программа').join(', '),
                      style: TextStyle(fontSize: 12, color: colorScheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
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
