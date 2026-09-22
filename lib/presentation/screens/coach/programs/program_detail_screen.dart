import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/workout_date_formatter.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../../domain/entities/training_program.dart';
import '../../../../domain/repositories/crossfit_workout_repository.dart';
import '../../../../domain/repositories/program_repository.dart';
import '../../../bloc/program/program_cubit.dart';

class ProgramDetailScreen extends StatefulWidget {
  final String programId;

  const ProgramDetailScreen({
    super.key,
    required this.programId,
  });

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _isLoading = true;
  String? _error;
  TrainingProgram? _program;
  List<ProgramMember> _members = [];
  List<CrossfitWorkout> _programWorkouts = [];
  Map<String, int> _workoutResultUserCount = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final programRepo = context.read<ProgramRepository>();
      final workoutRepo = context.read<CrossfitWorkoutRepository>();

      final allPrograms = await programRepo.getCoachPrograms();
      final program = allPrograms.firstWhere(
        (p) => p.id == widget.programId,
        orElse: () => throw Exception('Программа не найдена'),
      );

      final members = await programRepo.getProgramMembers(widget.programId);
      final allCoachWorkouts = await workoutRepo.getCoachWorkouts();

      final programWorkouts = allCoachWorkouts
          .where((w) => w.assignedProgramIds.contains(widget.programId))
          .toList();

      final Map<String, int> resultCounts = {};
      await Future.wait(
        programWorkouts.map((workout) async {
          try {
            final results = await workoutRepo.getWorkoutResults(workout.id);
            final uniqueUsers = results.map((r) => r.userId).toSet();
            resultCounts[workout.id] = uniqueUsers.length;
          } catch (_) {
            resultCounts[workout.id] = 0;
          }
        }),
      );

      if (mounted) {
        setState(() {
          _program = program;
          _members = members;
          _programWorkouts = programWorkouts;
          _workoutResultUserCount = resultCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
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
    final descriptionController = TextEditingController(text: program.description);
    ProgramKind selectedKind = program.kind;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text('Редактировать программу', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
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
                    decoration: const InputDecoration(
                      labelText: 'Описание',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
      if (success) {
        _loadData();
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
        title: Text('Удалить программу?', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'Вы уверены, что хотите удалить программу "${program.name}"?\n\n'
          'Все участники будут исключены из программы. '
          'Назначения тренировок будут удалены, но сами тренировки сохранятся.',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appTheme.destructive, foregroundColor: Colors.white),
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
        title: Text('Исключить атлета?', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Вы действительно хотите исключить "$name" из программы?', style: TextStyle(color: colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appTheme.destructive, foregroundColor: Colors.white),
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
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_error != null || _program == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Программа')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: appTheme.destructive, size: 48),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Программа не найдена',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: appTheme.destructive),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final program = _program!;
    final now = DateTime.now();

    final upcomingWorkouts = _programWorkouts
        .where((w) => w.scheduledAt.toLocal().isAfter(now) || w.scheduledAt.toLocal().isAtSameMomentAs(now))
        .toList()
      ..sort((a, b) => a.scheduledAt.toLocal().compareTo(b.scheduledAt.toLocal()));

    final pastWorkouts = _programWorkouts
        .where((w) => w.scheduledAt.toLocal().isBefore(now))
        .toList()
      ..sort((a, b) => b.scheduledAt.toLocal().compareTo(a.scheduledAt.toLocal()));

    final memberCount = _members.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            program.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            program.kind.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (program.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        program.description,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Invite code
                    InkWell(
                      onTap: () => _copyInviteCode(program.inviteCode),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vpn_key_outlined, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Код приглашения: ',
                              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                            ),
                            Text(
                              program.inviteCode,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.copy, size: 16, color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.push(
                      '/coach/workouts/create',
                      extra: {'initialProgramId': widget.programId},
                    );
                    if (mounted) _loadData();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Новая тренировка'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Members Section
              Row(
                children: [
                  Icon(Icons.people_alt_outlined, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Участники ($memberCount)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_members.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    'В программе пока нет участников. Отправьте атлетам код приглашения.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final name = member.userProfile?.fullName ?? 'Атлет';
                      final email = member.userProfile?.email ?? '';
                      final joinedDate = DateFormat('dd.MM.yyyy').format(member.joinedAt.toLocal());

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.primary,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '$email • Вступил: $joinedDate',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.person_remove_outlined, size: 18, color: appTheme.destructive),
                          tooltip: 'Исключить',
                          onPressed: () => _removeMember(member),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 28),

              // Upcoming Workouts Section
              Row(
                children: [
                  Icon(Icons.upcoming_outlined, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Предстоящие (${upcomingWorkouts.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcomingWorkouts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final workout = upcomingWorkouts[index];
                    final completedCount = _workoutResultUserCount[workout.id] ?? 0;
                    return _ProgramWorkoutCard(
                      workout: workout,
                      completedCount: completedCount,
                      totalMembers: memberCount,
                      onTap: () async {
                        await context.push('/workout/${workout.id}');
                        if (mounted) _loadData();
                      },
                    );
                  },
                ),

              const SizedBox(height: 28),

              // Past Workouts Section
              Row(
                children: [
                  Icon(Icons.history, size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Прошедшие (${pastWorkouts.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pastWorkouts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final workout = pastWorkouts[index];
                    final completedCount = _workoutResultUserCount[workout.id] ?? 0;
                    return _ProgramWorkoutCard(
                      workout: workout,
                      completedCount: completedCount,
                      totalMembers: memberCount,
                      onTap: () async {
                        await context.push('/workout/${workout.id}');
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

class _ProgramWorkoutCard extends StatelessWidget {
  final CrossfitWorkout workout;
  final int completedCount;
  final int totalMembers;
  final VoidCallback onTap;

  const _ProgramWorkoutCard({
    required this.workout,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workout.workoutTypesSummary,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: completedCount > 0
                          ? appTheme.success.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: completedCount > 0 ? appTheme.success : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Заполнено $completedCount/$totalMembers',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: completedCount > 0 ? appTheme.success : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
