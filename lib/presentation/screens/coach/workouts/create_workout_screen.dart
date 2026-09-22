import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../../domain/entities/training_program.dart';
import '../../../../domain/repositories/crossfit_workout_repository.dart';
import '../../../bloc/program/program_cubit.dart';
import '../../../bloc/workout/crossfit_workout_cubit.dart';
import '../../../bloc/workout_form/workout_form_cubit.dart';
import 'widgets/dashed_rrect.dart';
import 'widgets/workout_task_card.dart';

class CreateWorkoutScreen extends StatelessWidget {
  final CrossfitWorkout? workoutToEdit;
  final String? initialProgramId;
  final List<String>? initialProgramIds;

  const CreateWorkoutScreen({
    super.key,
    this.workoutToEdit,
    this.initialProgramId,
    this.initialProgramIds,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WorkoutFormCubit>(
      create: (ctx) => WorkoutFormCubit(
        workoutRepository: ctx.read<CrossfitWorkoutRepository>(),
        workoutToEdit: workoutToEdit,
        initialProgramId: initialProgramId,
        initialProgramIds: initialProgramIds,
      ),
      child: const _CreateWorkoutView(),
    );
  }
}

class _CreateWorkoutView extends StatefulWidget {
  const _CreateWorkoutView();

  @override
  State<_CreateWorkoutView> createState() => _CreateWorkoutViewState();
}

class _CreateWorkoutViewState extends State<_CreateWorkoutView> {
  late final TextEditingController _sessionNameController;
  bool _bannerShown = false;

  @override
  void initState() {
    super.initState();
    _sessionNameController = TextEditingController();
    context.read<ProgramCubit>().loadCoachPrograms();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  String _formatPluralTasks(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return '$count задание';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return '$count задания';
    } else {
      return '$count заданий';
    }
  }

  Future<void> _pickDate(BuildContext context, WorkoutFormCubit cubit, DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      final updated = DateTime(
        picked.year,
        picked.month,
        picked.day,
        initialDate.hour,
        initialDate.minute,
      );
      cubit.setDateTime(updated);
    }
  }

  Future<void> _pickTime(BuildContext context, WorkoutFormCubit cubit, DateTime initialDate) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (picked != null) {
      final updated = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        picked.hour,
        picked.minute,
      );
      cubit.setDateTime(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    return BlocConsumer<WorkoutFormCubit, WorkoutFormState>(
      listenWhen: (previous, current) =>
          previous.submitStatus != current.submitStatus ||
          (!previous.hasCachedDraft && current.hasCachedDraft),
      listener: (context, state) {
        if (state.hasCachedDraft && !_bannerShown && !state.isEditMode) {
          _bannerShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colorScheme.surfaceContainerHighest,
              content: Text(
                'Найден сохранённый черновик тренировки.',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              action: SnackBarAction(
                label: 'Восстановить',
                textColor: colorScheme.primary,
                onPressed: () {
                  context.read<WorkoutFormCubit>().restoreCachedDraft();
                  _sessionNameController.text =
                      context.read<WorkoutFormCubit>().state.sessionName;
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }

        if (state.submitStatus == WorkoutFormSubmitStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: appTheme.destructive,
            ),
          );
        } else if (state.submitStatus == WorkoutFormSubmitStatus.success) {
          context.read<CrossfitWorkoutCubit>().loadCoachWorkouts();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage ?? 'Успешно сохранено'),
              backgroundColor: appTheme.success,
            ),
          );
          context.pop();
        }
      },
      builder: (context, formState) {
        if (_sessionNameController.text != formState.sessionName &&
            _sessionNameController.text.isEmpty &&
            formState.sessionName.isNotEmpty) {
          _sessionNameController.text = formState.sessionName;
        }

        final cubit = context.read<WorkoutFormCubit>();
        final isSubmitting =
            formState.submitStatus == WorkoutFormSubmitStatus.loading;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: colorScheme.onSurface,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Text button "Черновик"
              TextButton.icon(
                onPressed: isSubmitting ? null : () => cubit.saveDraft(),
                icon: Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  'Черновик',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Capsule button "Опубликовать"
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () => cubit.publishWorkout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.publish,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Опубликовать',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: CustomScrollView(
                slivers: [
                  // Top section (Title, Programs, Date/Time, Session name, Tasks header)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 4. Header title
                          Text(
                            formState.isEditMode
                                ? 'Редактирование\nтренировки'
                                : 'Создание\nтренировки',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 5. Section "НАЗНАЧИТЬ ПРОГРАММАМ"
                          Text(
                            'НАЗНАЧИТЬ ПРОГРАММАМ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),

                          BlocBuilder<ProgramCubit, ProgramState>(
                            builder: (context, programState) {
                              final programs = programState is ProgramLoaded
                                  ? programState.programs
                                  : <TrainingProgram>[];

                              if (programs.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.cardTheme.color ?? colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    'У вас пока нет созданных программ. Тренировка сохранится в черновик.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: programs.map((program) {
                                  final isSelected = formState
                                      .selectedProgramIds
                                      .contains(program.id);

                                  return InkWell(
                                    onTap: () => cubit.toggleProgram(program.id),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colorScheme.primary.withValues(alpha: 0.15)
                                            : (theme.cardTheme.color ?? colorScheme.surface),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.outlineVariant,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            program.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // 6. Row 50/50: Date & Time
                          Row(
                            children: [
                              // Date field
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ДАТА',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _pickDate(
                                        context,
                                        cubit,
                                        formState.scheduledAt,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.cardTheme.color ?? colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: colorScheme.outlineVariant,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('dd.MM.yyyy')
                                                  .format(formState.scheduledAt),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Time field
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ВРЕМЯ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _pickTime(
                                        context,
                                        cubit,
                                        formState.scheduledAt,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.cardTheme.color ?? colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: colorScheme.outlineVariant,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('HH:mm')
                                                  .format(formState.scheduledAt),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            Icon(
                                              Icons.access_time,
                                              size: 18,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Session Name field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'УТОЧНЕНИЕ (НЕОБЯЗАТЕЛЬНО)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _sessionNameController,
                                maxLength: 40,
                                onChanged: (value) =>
                                    cubit.setSessionName(value),
                                decoration: const InputDecoration(
                                  hintText: 'например: Утро, Вечер, Сессия 1',
                                  counterText: '',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // 7. Section header: "ЗАДАНИЯ ТРЕНИРОВКИ" + Pill counter
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ЗАДАНИЯ ТРЕНИРОВКИ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatPluralTasks(formState.tasks.length),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 8. SliverReorderableList for Task Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverReorderableList(
                      itemCount: formState.tasks.length,
                      onReorderItem: (oldIndex, newIndex) {
                        cubit.reorderTasks(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final task = formState.tasks[index];
                        return WorkoutTaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          index: index,
                          onDelete: () => cubit.removeTask(task.id),
                          onTitleChanged: (title) =>
                              cubit.setTaskTitle(task.id, title),
                          onDescriptionChanged: (desc) =>
                              cubit.setTaskDescription(task.id, desc),
                        );
                      },
                    ),
                  ),

                  // 11. Add Task Button (Dashed border)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      child: InkWell(
                        onTap: () => cubit.addTask(),
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: DashedRRectPainter(
                            color: colorScheme.outlineVariant,
                            strokeWidth: 1.5,
                            radius: 16,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 24,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ДОБАВИТЬ ЗАДАНИЕ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
