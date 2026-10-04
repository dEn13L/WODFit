import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../widgets/program_visual_banner.dart';
import '../../../../core/utils/workout_date_formatter.dart';
import '../../../../core/utils/workout_progress_formatter.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../../domain/entities/training_program.dart';
import '../../../../domain/repositories/crossfit_workout_repository.dart';
import '../../../../domain/repositories/program_repository.dart';
import '../../../state/session_data_cache.dart';
import '../../../bloc/program/program_detail_cubit.dart';
import '../../../bloc/program/program_cubit.dart';
import '../../../widgets/app_state_view.dart';

class ProgramDetailScreen extends StatefulWidget {
  final String programId;

  const ProgramDetailScreen({super.key, required this.programId});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  late final ProgramDetailCubit _detailCubit;
  late final StreamSubscription<ProgramDetailState> _detailSubscription;
  bool _isLoading = true;
  String? _error;
  TrainingProgram? _program;
  List<ProgramMember> _members = [];
  List<CrossfitWorkout> _programWorkouts = [];
  Map<String, int> _workoutResultUserCount = {};

  @override
  void initState() {
    super.initState();
    _detailCubit = ProgramDetailCubit(
      programRepository: context.read<ProgramRepository>(),
      workoutRepository: context.read<CrossfitWorkoutRepository>(),
      cache: context.read<SessionDataCache>(),
    );
    _detailSubscription = _detailCubit.stream.listen(_applyDetailState);
    _loadData();
    _applyDetailState(_detailCubit.state);
  }

  void _applyDetailState(ProgramDetailState state) {
    if (!mounted) return;
    setState(() {
      _isLoading = state.isLoading;
      _error = state.error;
      if (state.data != null) {
        _program = state.data!.program;
        _members = state.data!.members;
        _programWorkouts = state.data!.workouts;
        _workoutResultUserCount = state.data!.resultCounts;
      }
    });
    if (state.refreshError != null &&
        ModalRoute.of(context)?.isCurrent == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.refreshError!)));
    }
  }

  Future<void> _loadData() => _detailCubit.load(widget.programId);

  @override
  void dispose() {
    _detailSubscription.cancel();
    _detailCubit.close();
    super.dispose();
  }

  void _applyReturnedWorkout(CrossfitWorkout? workout) {
    if (workout == null) return;
    setState(() {
      _programWorkouts = _programWorkouts
          .where((w) => w.id != workout.id)
          .toList();
      if (workout.assignedProgramIds.contains(widget.programId)) {
        _programWorkouts.add(workout);
      }
    });
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Код приглашения $code скопирован!'),
        backgroundColor: context.appTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editProgram() async {
    if (_program == null) return;
    final program = _program!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final nameController = TextEditingController(text: program.name);
    final descriptionController = TextEditingController(
      text: program.description,
    );
    ProgramKind selectedKind = program.kind;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Редактировать программу',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<ProgramKind>(
                    segments: const [
                      ButtonSegment(
                        value: ProgramKind.group,
                        label: Text('Группа'),
                        icon: Icon(Icons.groups, size: 18),
                      ),
                      ButtonSegment(
                        value: ProgramKind.personal,
                        label: Text('Персональная'),
                        icon: Icon(Icons.person, size: 18),
                      ),
                    ],
                    selected: {selectedKind},
                    onSelectionChanged: (val) {
                      setDialogState(() {
                        selectedKind = val.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Название программы',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите название';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Отмена',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogCtx).pop({
                    'name': nameController.text.trim(),
                    'kind': selectedKind,
                    'description': descriptionController.text.trim(),
                  });
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final success = await context.read<ProgramCubit>().updateProgram(
        programId: program.id,
        name: result['name'] as String,
        kind: result['kind'] as ProgramKind,
        description: result['description'] as String,
      );
      if (success && mounted) {
        final state = context.read<ProgramCubit>().state;
        if (state is ProgramLoaded) {
          final updated = state.programs.where((p) => p.id == program.id);
          if (updated.isNotEmpty) {
            setState(() => _program = updated.first);
          }
        }
      }
    }
  }

  Future<void> _deleteProgram() async {
    if (_program == null) return;
    final program = _program!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Удалить программу?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить программу "${program.name}"?\n\n'
          'Все участники будут исключены из программы. '
          'Назначения тренировок будут удалены, но сами тренировки сохранятся.',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Отмена',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
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
      await context.read<ProgramCubit>().deleteProgram(program.id);
      if (mounted) {
        context.pop();
      }
    }
  }

  Future<void> _removeMember(ProgramMember member) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;
    final name = member.userProfile?.fullName ?? 'Участник';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Исключить атлета?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы действительно хотите исключить "$name" из программы?',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Отмена',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.destructive,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Исключить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<ProgramRepository>().removeProgramMember(
          programId: widget.programId,
          userId: member.userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name исключен из программы'),
              backgroundColor: appTheme.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка исключения: $e'),
              backgroundColor: appTheme.destructive,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Программа')),
        body: const AppLoadingView(semanticLabel: 'Загрузка программы'),
      );
    }

    if (_error != null || _program == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Программа')),
        body: AppErrorView(
          message: _error ?? 'Программа не найдена',
          onRetry: _loadData,
        ),
      );
    }

    final program = _program!;
    final now = DateTime.now();

    final upcomingWorkouts =
        _programWorkouts
            .where(
              (w) =>
                  w.scheduledAt.toLocal().isAfter(now) ||
                  w.scheduledAt.toLocal().isAtSameMomentAs(now),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.scheduledAt.toLocal().compareTo(b.scheduledAt.toLocal()),
          );

    final pastWorkouts =
        _programWorkouts
            .where((w) => w.scheduledAt.toLocal().isBefore(now))
            .toList()
          ..sort(
            (a, b) =>
                b.scheduledAt.toLocal().compareTo(a.scheduledAt.toLocal()),
          );

    final memberCount = _members.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Программа'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'edit') {
                _editProgram();
              } else if (val == 'delete') {
                _deleteProgram();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Редактировать'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: appTheme.destructive,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Удалить',
                      style: TextStyle(color: appTheme.destructive),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: colorScheme.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProgramVisualBanner(
                    title: program.name,
                    subtitle:
                        '${program.kind.displayName} · Участников: $memberCount',
                    icon: program.kind == ProgramKind.personal
                        ? Icons.person
                        : Icons.groups,
                  ),
                  if (program.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      program.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Код приглашения',
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  program.inviteCode,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: AppTheme.resultFontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Скопировать код приглашения',
                            onPressed: () =>
                                _copyInviteCode(program.inviteCode),
                            icon: const Icon(Icons.copy_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final saved = await context.push<CrossfitWorkout>(
                          '/coach/workouts/create',
                          extra: {'initialProgramId': widget.programId},
                        );
                        if (mounted) {
                          _applyReturnedWorkout(saved);
                          _loadData();
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Новая тренировка'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Upcoming Workouts Section
                  Row(
                    children: [
                      Icon(
                        Icons.upcoming_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Предстоящие',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (upcomingWorkouts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text(
                        'Нет предстоящих тренировок для этой программы.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: upcomingWorkouts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final workout = upcomingWorkouts[index];
                        final completedCount =
                            _workoutResultUserCount[workout.id] ?? 0;
                        return _ProgramWorkoutCard(
                          workout: workout,
                          programId: widget.programId,
                          completedCount: completedCount,
                          totalMembers: memberCount,
                          onTap: () async {
                            final updated = await context.push<CrossfitWorkout>(
                              '/workout/${workout.id}',
                            );
                            if (mounted) {
                              _applyReturnedWorkout(updated);
                              _loadData();
                            }
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 28),

                  // Past Workouts Section
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Прошедшие',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (pastWorkouts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text(
                        'Нет прошедших тренировок.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pastWorkouts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final workout = pastWorkouts[index];
                        final completedCount =
                            _workoutResultUserCount[workout.id] ?? 0;
                        return _ProgramWorkoutCard(
                          workout: workout,
                          programId: widget.programId,
                          completedCount: completedCount,
                          totalMembers: memberCount,
                          onTap: () async {
                            final updated = await context.push<CrossfitWorkout>(
                              '/workout/${workout.id}',
                            );
                            if (mounted) {
                              _applyReturnedWorkout(updated);
                              _loadData();
                            }
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      key: PageStorageKey('program-members-${program.id}'),
                      leading: Icon(
                        Icons.people_alt_outlined,
                        color: colorScheme.primary,
                      ),
                      title: Text('Участники · $memberCount'),
                      childrenPadding: const EdgeInsets.all(12),
                      children: [
                        if (_members.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  theme.cardTheme.color ?? colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              'В программе пока нет участников. Отправьте атлетам код приглашения.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  theme.cardTheme.color ?? colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: ListView.separated(
                              key: const PageStorageKey('members-scroll'),
                              primary: false,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _members.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 56),
                              itemBuilder: (context, index) {
                                final member = _members[index];
                                final name =
                                    member.userProfile?.fullName ?? 'Атлет';
                                final email = member.userProfile?.email ?? '';
                                final joinedDate = DateFormat('dd.MM.yyyy')
                                    .format(member.joinedAt.toLocal());

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    foregroundColor: colorScheme.primary,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$email • Вступил: $joinedDate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.person_remove_outlined,
                                      size: 18,
                                      color: appTheme.destructive,
                                    ),
                                    tooltip: 'Исключить',
                                    onPressed: () => _removeMember(member),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramWorkoutCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final String programId;
  final int completedCount;
  final int totalMembers;
  final VoidCallback onTap;

  const _ProgramWorkoutCard({
    required this.workout,
    required this.programId,
    required this.completedCount,
    required this.totalMembers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;
    final isDraft = workout.status == WorkoutStatus.draft;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.nameForProgram(programId),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      WorkoutDateFormatter.formatList(workout.scheduledAt),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (isDraft) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: appTheme.draft.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Черновик',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: appTheme.draft,
                          ),
                        ),
                      ),
                    ] else if (totalMembers > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Заполнено ${WorkoutProgressFormatter.format(completedCount, totalMembers)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: AppTheme.resultFontFamily,
                          color: completedCount > 0
                              ? appTheme.success
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
