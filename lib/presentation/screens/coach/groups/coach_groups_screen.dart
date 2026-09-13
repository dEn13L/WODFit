import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/group.dart';
import '../../../bloc/group/group_cubit.dart';

class CoachGroupsScreen extends StatefulWidget {
  const CoachGroupsScreen({super.key});

  @override
  State<CoachGroupsScreen> createState() => _CoachGroupsScreenState();
}

class _CoachGroupsScreenState extends State<CoachGroupsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GroupCubit>().loadCoachGroups();
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

  Future<void> _editGroupName(Group group) async {
    final controller = TextEditingController(text: group.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Переименовать группу'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Название группы',
              hintText: 'Например, Утренняя группа 08:00',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите название';
              }
              return null;
            },
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
                Navigator.of(dialogCtx).pop(controller.text.trim());
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      context.read<GroupCubit>().updateGroupName(group.id, result);
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить группу?'),
        content: Text(
          'Вы уверены, что хотите удалить группу "${group.name}"?\n\n'
          'Все участники будут исключены из группы. '
          'Назначения тренировок для этой группы будут удалены, но сами тренировки сохранятся в вашем профиле.',
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
      context.read<GroupCubit>().deleteGroup(group.id);
    }
  }

  Future<void> _showMembersModal(Group group) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => _GroupMembersSheet(group: group),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои группы'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<GroupCubit, GroupState>(
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
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
          }

          if (state is GroupError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                      onPressed: () => context.read<GroupCubit>().loadCoachGroups(),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is GroupLoaded) {
            if (state.groups.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups_outlined, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'У вас еще нет созданных групп',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Создайте группу, чтобы получить уникальный код приглашения для клиентов.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Создать группу'),
                        onPressed: () => context.push('/coach/groups/create'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => context.read<GroupCubit>().loadCoachGroups(),
              color: AppColors.primaryNeon,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.groups.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = state.groups[index];
                  return Card(
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
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editGroupName(group);
                                  } else if (value == 'members') {
                                    _showMembersModal(group);
                                  } else if (value == 'delete') {
                                    _deleteGroup(group);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Переименовать'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'members',
                                    child: Row(
                                      children: [
                                        Icon(Icons.people_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text('Участники группы'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('Удалить группу', style: TextStyle(color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showMembersModal(group),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people, size: 16, color: AppColors.primaryNeon),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${group.memberCount} участников • Нажмите для просмотра',
                                    style: const TextStyle(color: AppColors.primaryNeon, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'КОД ПРИГЛАШЕНИЯ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      group.inviteCode,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        letterSpacing: 3,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryNeon,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppColors.primaryNeon),
                                  tooltip: 'Скопировать код',
                                  onPressed: () => _copyToClipboard(group.inviteCode, context),
                                ),
                              ],
                            ),
                          ),
                        ],
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryNeon,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Новая группа', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/coach/groups/create'),
      ),
    );
  }
}

class _GroupMembersSheet extends StatefulWidget {
  final Group group;

  const _GroupMembersSheet({required this.group});

  @override
  State<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<_GroupMembersSheet> {
  List<GroupMember>? _members;
  bool _isLoading = true;
  String? _error;

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
      final members = await context.read<GroupCubit>().getGroupMembers(widget.group.id);
      if (mounted) {
        setState(() {
          _members = members;
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

  Future<void> _removeMember(GroupMember member) async {
    final name = member.profile?.fullName ?? 'участника';
    final groupCubit = context.read<GroupCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Исключить из группы?'),
        content: Text('Вы действительно хотите исключить $name из группы "${widget.group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Исключить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await groupCubit.removeGroupMember(widget.group.id, member.userId);
        messenger.showSnackBar(
          SnackBar(
            content: Text('$name успешно исключен из группы'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadMembers();
        // Also refresh coach groups to update count
        groupCubit.loadCoachGroups();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Участники группы',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.group.name,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadMembers,
                  ),
                ],
              ),
              const Divider(color: AppColors.surfaceLight, height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                                const SizedBox(height: 8),
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadMembers, child: const Text('Повторить')),
                              ],
                            ),
                          )
                        : _members == null || _members!.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.person_outline, size: 56, color: AppColors.textSecondary),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'В этой группе пока нет атлетов',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Поделитесь кодом ${widget.group.inviteCode} с вашими клиентами.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: _members!.length,
                                separatorBuilder: (context, index) => const Divider(color: AppColors.surfaceLight, height: 1),
                                itemBuilder: (context, index) {
                                  final member = _members![index];
                                  final name = member.profile?.fullName ?? 'Атлет';
                                  final email = member.profile?.email ?? '';

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.surfaceLight,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                        style: const TextStyle(color: AppColors.primaryNeon, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      '$email • В группе с ${dateFormat.format(member.joinedAt)}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                      tooltip: 'Исключить',
                                      onPressed: () => _removeMember(member),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
