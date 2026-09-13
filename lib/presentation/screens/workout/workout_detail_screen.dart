import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;

  const WorkoutDetailScreen({
    super.key,
    required this.workoutId,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId);
  }

  void _showResultDialog(WorkoutPart part, PartResult? existingResult) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return _PartResultInputModal(
          workoutId: widget.workoutId,
          part: part,
          initialResult: existingResult,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isCoach = authState is Authenticated && authState.user.isCoach;
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Результаты группы',
            icon: const Icon(Icons.leaderboard_outlined, color: AppColors.primaryNeon),
            onPressed: () => context.push('/workout/${widget.workoutId}/results'),
          ),
        ],
      ),
      body: BlocConsumer<CrossfitWorkoutCubit, CrossfitWorkoutState>(
        listener: (context, state) {
          if (state is CrossfitWorkoutError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CrossfitWorkoutLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
          }

          if (state is CrossfitWorkoutDetailLoaded) {
            final workout = state.workout;
            final userResultsMap = {
              for (final res in state.userResults) res.partId: res,
            };

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workout Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  workout.title,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: AppColors.primaryNeon,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: workout.isPublished
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : AppColors.accentOrange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: workout.isPublished ? AppColors.success : AppColors.accentOrange,
                                  ),
                                ),
                                child: Text(
                                  workout.status.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: workout.isPublished ? AppColors.success : AppColors.accentOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.event, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                dateFormat.format(workout.scheduledAt),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                          if (workout.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              workout.description,
                              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                            ),
                          ],
                          if (workout.assignments.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Назначено группам:',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: workout.assignments.map((a) {
                                return Chip(
                                  label: Text(a.groupName ?? 'Группа', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: AppColors.surfaceLight,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ],
                          if (isCoach && !workout.isPublished) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.publish),
                                label: const Text('Опубликовать для атлетов'),
                                onPressed: () {
                                  context.read<CrossfitWorkoutCubit>().publishWorkout(workout.id);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Части тренировки (${workout.parts.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: const Text('Результаты'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryNeon,
                          side: const BorderSide(color: AppColors.primaryNeon),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => context.push('/workout/${workout.id}/results'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Parts list
                  if (workout.parts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('В этой тренировке пока нет частей')),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workout.parts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final part = workout.parts[index];
                        final userResult = userResultsMap[part.id];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        part.type.displayName,
                                        style: const TextStyle(
                                          color: AppColors.primaryNeon,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Часть ${index + 1}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  part.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (part.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      part.description,
                                      style: const TextStyle(fontSize: 14, height: 1.4),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(color: AppColors.surfaceLight),
                                const SizedBox(height: 8),
                                // Athlete's result section
                                if (userResult != null) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Ваш результат: ${userResult.scoreText}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Режим: ${userResult.status.displayName}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                          if (userResult.note.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Заметка: ${userResult.note}',
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ],
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Изменить'),
                                        onPressed: () => _showResultDialog(part, userResult),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Результат не внесен',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add_task, size: 16),
                                        label: const Text('Записать результат'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => _showResultDialog(part, null),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
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

class _PartResultInputModal extends StatefulWidget {
  final String workoutId;
  final WorkoutPart part;
  final PartResult? initialResult;

  const _PartResultInputModal({
    required this.workoutId,
    required this.part,
    this.initialResult,
  });

  @override
  State<_PartResultInputModal> createState() => _PartResultInputModalState();
}

class _PartResultInputModalState extends State<_PartResultInputModal> {
  final _formKey = GlobalKey<FormState>();
  late ResultStatus _status;
  late TextEditingController _scoreController;
  late TextEditingController _noteController;
  late TextEditingController _weightController;
  late TextEditingController _roundsController;
  late TextEditingController _repsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialResult?.status ?? ResultStatus.done;
    _scoreController = TextEditingController(text: widget.initialResult?.scoreText ?? '');
    _noteController = TextEditingController(text: widget.initialResult?.note ?? '');
    _weightController = TextEditingController(
      text: widget.initialResult?.weightKg != null ? widget.initialResult!.weightKg.toString() : '',
    );
    _roundsController = TextEditingController(
      text: widget.initialResult?.rounds != null ? widget.initialResult!.rounds.toString() : '',
    );
    _repsController = TextEditingController(
      text: widget.initialResult?.reps != null ? widget.initialResult!.reps.toString() : '',
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _noteController.dispose();
    _weightController.dispose();
    _roundsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    final success = await context.read<CrossfitWorkoutCubit>().submitPartResult(
          workoutId: widget.workoutId,
          partId: widget.part.id,
          status: _status,
          scoreText: _scoreController.text.trim(),
          note: _noteController.text.trim(),
          weightKg: double.tryParse(_weightController.text.trim()),
          rounds: int.tryParse(_roundsController.text.trim()),
          reps: int.tryParse(_repsController.text.trim()),
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Результат сохранен!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ввод результата',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.part.title,
                          style: const TextStyle(color: AppColors.primaryNeon, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<ResultStatus>(
                segments: const [
                  ButtonSegment<ResultStatus>(value: ResultStatus.done, label: Text('Rx (В норме)')),
                  ButtonSegment<ResultStatus>(value: ResultStatus.scaled, label: Text('Scaled')),
                  ButtonSegment<ResultStatus>(value: ResultStatus.notDone, label: Text('Не сделано')),
                ],
                selected: {_status},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _status = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _scoreController,
                decoration: InputDecoration(
                  labelText: 'Результат / Счёт *',
                  hintText: 'например: 12:30 или 140 кг или 5 раундов + 10 бурпи',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите результат' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Вес (кг)',
                        hintText: 'опционально',
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _roundsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Раунды',
                        hintText: 'опционально',
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _repsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Повторы',
                        hintText: 'опционально',
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Заметка к результату (опционально)',
                  hintText: 'например: разбивал подтягивания 15+6',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Сохранить результат'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
