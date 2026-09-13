import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/entities/part_result.dart';
import '../../bloc/group/group_cubit.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedGroupId; // null means 'All groups'
  bool _sortAscending = false; // false = newest first, true = oldest first

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<CrossfitWorkoutCubit>().loadClientWorkouts();
    context.read<GroupCubit>().loadClientGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История тренировок'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryNeon,
          labelColor: AppColors.primaryNeon,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Прошедшие'),
            Tab(icon: Icon(Icons.upcoming), text: 'Будущие'),
          ],
        ),
      ),
      body: BlocBuilder<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        builder: (context, workoutState) {
          final groupState = context.watch<GroupCubit>().state;
          final groups = groupState is GroupLoaded ? groupState.groups : <Group>[];

          if (workoutState is CrossfitWorkoutLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryNeon),
            );
          }

          if (workoutState is CrossfitWorkoutError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      workoutState.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
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

          if (workoutState is CrossfitWorkoutListLoaded) {
            final allWorkouts = workoutState.workouts;
            final userResults = workoutState.userResults;
            final now = DateTime.now();

            // Split into past and future
            final pastWorkouts = allWorkouts.where((w) => w.scheduledAt.isBefore(now)).toList();
            final futureWorkouts = allWorkouts.where((w) => !w.scheduledAt.isBefore(now)).toList();

            return Column(
              children: [
                _buildFiltersBar(groups),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWorkoutList(
                        workouts: pastWorkouts,
                        userResults: userResults,
                        isPast: true,
                      ),
                      _buildWorkoutList(
                        workouts: futureWorkouts,
                        userResults: userResults,
                        isPast: false,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildFiltersBar(List<Group> groups) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceLight, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Group selector
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _selectedGroupId,
                      hint: const Text(
                        'Все группы',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                      dropdownColor: AppColors.surface,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryNeon),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все группы', style: TextStyle(fontSize: 13)),
                        ),
                        ...groups.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g.id,
                            child: Text(
                              g.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedGroupId = val;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Sort toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: AppColors.primaryNeon,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortAscending ? 'Сначала старые' : 'Сначала новые',
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutList({
    required List<CrossfitWorkout> workouts,
    required List<PartResult> userResults,
    required bool isPast,
  }) {
    // Filter by group if selected
    var filtered = workouts;
    if (_selectedGroupId != null) {
      filtered = filtered.where((w) => w.assignments.any((a) => a.groupId == _selectedGroupId)).toList();
    }

    // Sort by date
    filtered.sort((a, b) {
      return _sortAscending ? a.scheduledAt.compareTo(b.scheduledAt) : b.scheduledAt.compareTo(a.scheduledAt);
    });

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _loadData(),
        color: AppColors.primaryNeon,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPast ? Icons.history_toggle_off : Icons.event_available,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedGroupId != null
                      ? 'В выбранной группе нет ${isPast ? 'прошедших' : 'предстоящих'} тренировок'
                      : (isPast ? 'Нет прошедших тренировок' : 'Нет запланированных тренировок'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  isPast
                      ? 'Здесь будут отображаться завершенные тренировки и ваши результаты.'
                      : 'Когда тренер назначит новую тренировку, она появится здесь.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      color: AppColors.primaryNeon,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final workout = filtered[index];
          final workoutResults = userResults.where((r) => r.workoutId == workout.id).toList();

          return _HistoryWorkoutCard(
            workout: workout,
            userResults: workoutResults,
            isPast: isPast,
            onRefreshNeeded: _loadData,
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
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');
    final dateStr = dateFormat.format(workout.scheduledAt);

    final completedCount = workout.parts.where((p) {
      final res = userResults.where((r) => r.partId == p.id);
      return res.isNotEmpty && res.first.status == ResultStatus.done;
    }).length;
    final totalParts = workout.parts.length;
    final hasAnyResult = userResults.isNotEmpty;

    return Card(
      elevation: 2,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.event, size: 14, color: AppColors.primaryNeon),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                if (isPast) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedCount == totalParts && totalParts > 0
                          ? AppColors.success.withValues(alpha: 0.15)
                          : hasAnyResult
                              ? AppColors.primaryNeon.withValues(alpha: 0.15)
                              : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: completedCount == totalParts && totalParts > 0
                            ? AppColors.success
                            : hasAnyResult
                                ? AppColors.primaryNeon
                                : AppColors.surfaceLight,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      completedCount == totalParts && totalParts > 0
                          ? 'Завершено ($completedCount/$totalParts)'
                          : hasAnyResult
                              ? 'Частично ($completedCount/$totalParts)'
                              : 'Нет результатов',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: completedCount == totalParts && totalParts > 0
                            ? AppColors.success
                            : hasAnyResult
                                ? AppColors.primaryNeon
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryNeon, width: 1),
                    ),
                    child: const Text(
                      'Предстоящая',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNeon,
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
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          a.groupName ?? 'Группа',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: AppColors.surfaceLight, height: 1),
            const SizedBox(height: 12),

            // Workout Parts with User Results
            const Text(
              'Части тренировки:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),

            if (workout.parts.isEmpty)
              const Text(
                'В тренировке пока нет частей',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: result != null ? AppColors.primaryNeon.withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                part.type.displayName,
                                style: const TextStyle(fontSize: 10, color: AppColors.primaryNeon, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                part.title,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (part.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            part.description,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : result.status == ResultStatus.scaled
                                          ? Colors.orange.withValues(alpha: 0.2)
                                          : AppColors.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  result.status.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: result.status == ResultStatus.done
                                        ? AppColors.success
                                        : result.status == ResultStatus.scaled
                                            ? Colors.orange
                                            : AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Результат: ${result.formattedScore}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNeon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (result.note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Заметка: ${result.note}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Результат не внесен',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              InkWell(
                                onTap: () async {
                                  await context.push('/workout/${workout.id}');
                                  onRefreshNeeded();
                                },
                                child: const Text(
                                  'Внести результат →',
                                  style: TextStyle(fontSize: 11, color: AppColors.primaryNeon, fontWeight: FontWeight.bold),
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
                    label: const Text('Результаты группы', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.primaryNeon),
                      foregroundColor: AppColors.primaryNeon,
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
