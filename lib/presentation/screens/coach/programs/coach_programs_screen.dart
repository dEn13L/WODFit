import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../domain/entities/training_program.dart';
import '../../../bloc/program/program_cubit.dart';
import '../../../widgets/app_state_view.dart';
import '../../../widgets/program_visual_banner.dart';

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

  Future<void> _createProgram() async {
    await context.push('/coach/programs/create');
    if (mounted) context.read<ProgramCubit>().loadCoachPrograms();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Программы'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<ProgramCubit, ProgramState>(
        listener: (context, state) {
          final message = state is ProgramError
              ? state.message
              : state is ProgramLoaded
              ? state.refreshError ?? state.successMessage
              : null;
          if (message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor:
                    state is ProgramError ||
                        (state is ProgramLoaded && state.refreshError != null)
                    ? context.appTheme.destructive
                    : context.appTheme.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProgramError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<ProgramCubit>().loadCoachPrograms(),
            );
          }
          if (state is! ProgramLoaded) {
            return const AppLoadingView(semanticLabel: 'Загрузка программ');
          }
          final programs = state.programs;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxContentWidth,
              ),
              child: RefreshIndicator(
                onRefresh: () =>
                    context.read<ProgramCubit>().loadCoachPrograms(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: programs.isEmpty ? 2 : programs.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ProgramVisualBanner(
                            title: 'Тренируйте вместе',
                            subtitle: 'Все программы под рукой',
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _createProgram,
                            icon: const Icon(Icons.add),
                            label: const Text('Создать программу'),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                    if (programs.isEmpty) {
                      return const AppEmptyView(
                        icon: Icons.fitness_center_outlined,
                        title: 'У вас пока нет программ',
                        description: 'Создайте программу, чтобы назначать тренировки и отслеживать результаты атлетов.',
                      );
                    }
                    final program = programs[index - 1];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await context.push('/coach/programs/${program.id}');
                          if (context.mounted) {
                            context.read<ProgramCubit>().loadCoachPrograms();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  program.kind == ProgramKind.personal
                                      ? Icons.person
                                      : Icons.groups,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      program.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${program.kind.displayName} · Участников: ${program.memberCount}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (program.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        program.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
