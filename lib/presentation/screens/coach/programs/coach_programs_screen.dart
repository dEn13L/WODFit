import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/training_program.dart';
import '../../../bloc/program/program_cubit.dart';

class CoachProgramsScreen extends StatefulWidget {
  const CoachProgramsScreen({super.key});

  @override
  State<CoachProgramsScreen> createState() => _CoachProgramsScreenState();
}

class _CoachProgramsScreenState extends State<CoachProgramsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProgramCubit>().loadCoachPrograms();
  }

  void _copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Код приглашения $text скопирован!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editProgram(TrainingProgram program) async {
    final nameController = TextEditingController(text: program.name);
    final descriptionController = TextEditingController(text: program.description);
    ProgramKind selectedKind = program.kind;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Редактировать программу'),
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
                      hintText: 'например, Утренняя группа 08:00',
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
                      hintText: 'Цели, график...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Отмена'),
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
      context.read<ProgramCubit>().updateProgram(
            programId: program.id,
            name: result['name'] as String,
            kind: result['kind'] as ProgramKind,
            description: result['description'] as String,
          );
    }
  }

  Future<void> _deleteProgram(TrainingProgram program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить программу?'),
        content: Text(
          'Вы уверены, что хотите удалить программу "${program.name}"?\n\n'
          'Все участники будут исключены из программы. '
          'Назначения тренировок для этой программы будут удалены, но сами тренировки сохранятся в вашем профиле.',
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
      context.read<ProgramCubit>().deleteProgram(program.id);
    }
  }

  void _showMembersSheet(TrainingProgram program) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _ProgramMembersSheet(
        program: program,
        onMemberChanged: () {
          context.read<ProgramCubit>().loadCoachPrograms();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Программы'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/coach/programs/create');
          if (context.mounted) {
            context.read<ProgramCubit>().loadCoachPrograms();
          }
        },
        backgroundColor: AppColors.primaryNeon,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Создать программу', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: BlocConsumer<ProgramCubit, ProgramState>(
        listener: (context, state) {
          if (state is ProgramLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (state is ProgramError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProgramLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryNeon),
            );
          }

          if (state is ProgramError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<ProgramCubit>().loadCoachPrograms(),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ProgramLoaded) {
            final programs = state.programs;

            if (programs.isEmpty) {
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
                        'У вас пока нет программ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Создайте персональную или групповую программу тренировок, чтобы назначать комплексы и отслеживать результаты атлетов.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/coach/programs/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Создать первую программу'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => context.read<ProgramCubit>().loadCoachPrograms(),
              color: AppColors.primaryNeon,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: programs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final program = programs[index];
                  final dateFormat = DateFormat('dd.MM.yyyy');

                  return Card(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: program.kind == ProgramKind.personal
                            ? Colors.purpleAccent.withValues(alpha: 0.3)
                            : AppColors.primaryNeon.withValues(alpha: 0.2),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await context.push('/coach/programs/${program.id}');
                        if (context.mounted) {
                          context.read<ProgramCubit>().loadCoachPrograms();
                        }
                      },
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
                                  color: program.kind == ProgramKind.personal
                                      ? Colors.purpleAccent.withValues(alpha: 0.15)
                                      : AppColors.primaryNeon.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  program.kind == ProgramKind.personal ? Icons.person : Icons.groups,
                                  color: program.kind == ProgramKind.personal
                                      ? Colors.purpleAccent
                                      : AppColors.primaryNeon,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            program.name,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: program.kind == ProgramKind.personal
                                                ? Colors.purpleAccent.withValues(alpha: 0.2)
                                                : AppColors.primaryNeon.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            program.kind.displayName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: program.kind == ProgramKind.personal
                                                  ? Colors.purpleAccent
                                                  : AppColors.primaryNeon,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Создана: ${dateFormat.format(program.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                color: AppColors.surfaceLight,
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _editProgram(program);
                                  } else if (val == 'members') {
                                    _showMembersSheet(program);
                                  } else if (val == 'delete') {
                                    _deleteProgram(program);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'members',
                                    child: Row(
                                      children: [
                                        Icon(Icons.people_outline, size: 18, color: AppColors.primaryNeon),
                                        SizedBox(width: 8),
                                        Text('Участники'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                                        SizedBox(width: 8),
                                        Text('Редактировать'),
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
                          if (program.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              program.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Инвайт-код:',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  program.inviteCode,
                                  style: const TextStyle(
                                    color: AppColors.primaryNeon,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () => _copyToClipboard(program.inviteCode, context),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy, size: 14, color: AppColors.primaryNeon),
                                        SizedBox(width: 4),
                                        Text(
                                          'Скопировать',
                                          style: TextStyle(color: AppColors.primaryNeon, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Участников: ${program.memberCount}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showMembersSheet(program),
                                icon: const Icon(Icons.people, size: 16),
                                label: const Text('Список атлетов'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryNeon,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProgramMembersSheet extends StatefulWidget {
  final TrainingProgram program;
  final VoidCallback onMemberChanged;

  const _ProgramMembersSheet({
    required this.program,
    required this.onMemberChanged,
  });

  @override
  State<_ProgramMembersSheet> createState() => _ProgramMembersSheetState();
}

class _ProgramMembersSheetState extends State<_ProgramMembersSheet> {
  bool _isLoading = true;
  String? _error;
  List<ProgramMember> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await context.read<ProgramCubit>().getProgramMembers(widget.program.id);
      if (mounted) {
        setState(() {
          _members = list;
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

  Future<void> _removeMember(ProgramMember member) async {
    final name = member.profile?.fullName ?? member.userId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Исключить атлета?'),
        content: Text('Вы действительно хотите исключить $name из программы "${widget.program.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Исключить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<ProgramCubit>().removeProgramMember(widget.program.id, member.userId);
        widget.onMemberChanged();
        _loadMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при исключении: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Участники программы: ${widget.program.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: const TextStyle(color: AppColors.error)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _loadMembers, child: const Text('Повторить')),
                            ],
                          ),
                        )
                      : _members.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_outline, size: 48, color: AppColors.textSecondary),
                                  const SizedBox(height: 8),
                                  const Text('В программе пока нет участников'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Код для вступления: ${widget.program.inviteCode}',
                                    style: const TextStyle(
                                      color: AppColors.primaryNeon,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: _members.length,
                              separatorBuilder: (context, index) => const Divider(color: AppColors.surfaceLight),
                              itemBuilder: (context, index) {
                                final member = _members[index];
                                final profile = member.profile;
                                final name = profile?.fullName ?? 'Атлет';
                                final email = profile?.email ?? member.userId;
                                final joinedStr = DateFormat('dd.MM.yyyy').format(member.joinedAt);

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.surfaceLight,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                      style: const TextStyle(
                                        color: AppColors.primaryNeon,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$email • Вступил(а) $joinedStr',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                    onPressed: () => _removeMember(member),
                                    tooltip: 'Исключить из программы',
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
