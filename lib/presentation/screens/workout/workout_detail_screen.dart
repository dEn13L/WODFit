import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/workout_date_formatter.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/workout/crossfit_workout_cubit.dart';
import '../coach/workouts/create_workout_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Результаты атлетов',
            icon: const Icon(Icons.leaderboard_outlined, color: AppColors.primaryNeon),
            onPressed: () => context.push('/workout/${widget.workoutId}/results'),
          ),
          if (isCoach)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                final cubit = context.read<CrossfitWorkoutCubit>();
                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                final state = cubit.state;
                if (state is! CrossfitWorkoutDetailLoaded) return;
                final workout = state.workout;

                if (value == 'edit') {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => CreateWorkoutScreen(workoutToEdit: workout),
                    ),
                  );
                  if (mounted) {
                    cubit.loadWorkoutDetails(widget.workoutId);
                  }
                } else if (value == 'duplicate') {
                  final ok = await cubit.duplicateWorkout(workout.id);
                  if (ok) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Копия тренировки успешно создана в черновиках'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Удалить тренировку?'),
                      content: Text(
                        'Вы действительно хотите удалить тренировку "${WorkoutDateFormatter.formatList(workout.scheduledAt, workout.title)}"?\n\n'
                        'Все данные тренировки, назначения и внесенные результаты участников будут безвозвратно удалены.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(false),
                          child: const Text('Отмена'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          onPressed: () => Navigator.of(dCtx).pop(true),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final ok = await cubit.deleteWorkout(workout.id);
                    if (ok) {
                      router.pop();
                    }
                  }
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
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Дублировать'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Удалить тренировку', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
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
                                  WorkoutDateFormatter.formatDetail(workout.scheduledAt, workout.title),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: AppColors.primaryNeon,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              if (workout.status == WorkoutStatus.draft) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.accentOrange),
                                  ),
                                  child: const Text(
                                    'Черновик',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (workout.assignments.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Назначено программам:',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: workout.assignments.map((a) {
                                return Chip(
                                  label: Text(a.programName ?? 'Программа', style: const TextStyle(fontSize: 11)),
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
                        'Задания тренировки (${workout.parts.length})',
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
                        child: Center(child: Text('В этой тренировке пока нет заданий')),
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
                        final taskTitle = part.title.trim().isNotEmpty
                            ? part.title.trim()
                            : (part.type?.displayName ?? 'Задание');

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  taskTitle,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (part.description.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    part.description.trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Ваш результат: ${userResult.formattedScore}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
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

          if (state is CrossfitWorkoutError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить попытку'),
                      onPressed: () => context.read<CrossfitWorkoutCubit>().loadWorkoutDetails(widget.workoutId),
                    ),
                  ],
                ),
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
  late WorkoutScoreType _selectedScoreType;
  late TextEditingController _scoreController;
  late TextEditingController _noteController;
  late TextEditingController _weightController;
  late TextEditingController _roundsController;
  late TextEditingController _repsController;
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;
  late TextEditingController _distanceController;
  late TextEditingController _caloriesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final res = widget.initialResult;
    _status = res?.status ?? ResultStatus.done;
    _selectedScoreType = res?.scoreType ?? WorkoutScoreType.text;
    _scoreController = TextEditingController(text: res?.scoreText ?? '');
    _noteController = TextEditingController(text: res?.note ?? '');
    _weightController = TextEditingController(
      text: res?.weightKg != null
          ? (res!.weightKg!.truncateToDouble() == res.weightKg
              ? res.weightKg!.toInt().toString()
              : res.weightKg.toString())
          : '',
    );
    _roundsController = TextEditingController(
      text: res?.rounds != null ? res!.rounds.toString() : '',
    );
    _repsController = TextEditingController(
      text: res?.reps != null ? res!.reps.toString() : '',
    );
    _distanceController = TextEditingController(
      text: res?.distanceM != null
          ? (res!.distanceM!.truncateToDouble() == res.distanceM
              ? res.distanceM!.toInt().toString()
              : res.distanceM.toString())
          : '',
    );
    _caloriesController = TextEditingController(
      text: res?.calories != null ? res!.calories.toString() : '',
    );

    // Parse time
    int? initialMinutes;
    int? initialSeconds;
    if (res?.timeMs != null) {
      final totalSec = res!.timeMs! ~/ 1000;
      initialMinutes = totalSec ~/ 60;
      initialSeconds = totalSec % 60;
    } else if (res != null && res.scoreText.isNotEmpty && res.scoreText.contains(':')) {
      final parts = res.scoreText.split(':');
      if (parts.length >= 2) {
        initialMinutes = int.tryParse(parts[0].trim());
        initialSeconds = int.tryParse(parts[1].trim());
      }
    }
    _minutesController = TextEditingController(
      text: initialMinutes != null ? initialMinutes.toString() : '',
    );
    _secondsController = TextEditingController(
      text: initialSeconds != null ? initialSeconds.toString() : '',
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _noteController.dispose();
    _weightController.dispose();
    _roundsController.dispose();
    _repsController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _distanceController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    int? timeMs;
    int? rounds;
    int? reps;
    double? weightKg;
    double? distanceM;
    int? calories;
    String scoreText = '';

    if (_status == ResultStatus.notDone) {
      scoreText = 'Не выполнено';
    } else {
      switch (_selectedScoreType) {
        case WorkoutScoreType.time:
          final min = int.tryParse(_minutesController.text.trim()) ?? 0;
          final sec = int.tryParse(_secondsController.text.trim()) ?? 0;
          timeMs = (min * 60 + sec) * 1000;
          scoreText = '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
          break;
        case WorkoutScoreType.roundsReps:
          rounds = int.tryParse(_roundsController.text.trim()) ?? 0;
          reps = int.tryParse(_repsController.text.trim());
          if (reps != null && reps > 0) {
            scoreText = '$rounds рд + $reps повт';
          } else {
            scoreText = '$rounds рд';
          }
          break;
        case WorkoutScoreType.weight:
          weightKg = double.tryParse(_weightController.text.trim()) ?? 0;
          reps = int.tryParse(_repsController.text.trim());
          final wStr = weightKg.truncateToDouble() == weightKg ? weightKg.toInt().toString() : weightKg.toString();
          if (reps != null && reps > 0) {
            scoreText = '$wStr кг ($reps повт)';
          } else {
            scoreText = '$wStr кг';
          }
          break;
        case WorkoutScoreType.reps:
          reps = int.tryParse(_repsController.text.trim()) ?? 0;
          scoreText = '$reps повт';
          break;
        case WorkoutScoreType.distance:
          distanceM = double.tryParse(_distanceController.text.trim()) ?? 0;
          final dStr = distanceM.truncateToDouble() == distanceM ? distanceM.toInt().toString() : distanceM.toString();
          scoreText = '$dStr м';
          break;
        case WorkoutScoreType.calories:
          calories = int.tryParse(_caloriesController.text.trim()) ?? 0;
          scoreText = '$calories кал';
          break;
        case WorkoutScoreType.text:
          scoreText = _scoreController.text.trim();
          break;
        case WorkoutScoreType.none:
          scoreText = '';
          break;
      }
    }

    final success = await context.read<CrossfitWorkoutCubit>().submitPartResult(
          workoutId: widget.workoutId,
          partId: widget.part.id,
          status: _status,
          scoreText: scoreText,
          scoreType: _selectedScoreType,
          note: _noteController.text.trim(),
          timeMs: timeMs,
          rounds: rounds,
          reps: reps,
          weightKg: weightKg,
          distanceM: distanceM,
          calories: calories,
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

  Future<void> _deleteResult() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить результат?'),
        content: const Text('Вы действительно хотите удалить ваш результат по этому заданию?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted && widget.initialResult != null) {
      setState(() {
        _isLoading = true;
      });

      final success = await context.read<CrossfitWorkoutCubit>().deletePartResult(
            workoutId: widget.workoutId,
            resultId: widget.initialResult!.id,
          );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Результат удален'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  Widget _buildScoreInputs() {
    if (_status == ResultStatus.notDone) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Статус «Не выполнено». Ввод очков не требуется.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    switch (_selectedScoreType) {
      case WorkoutScoreType.time:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Минуты *',
                  hintText: 'например: 12',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixText: 'мин',
                ),
                validator: (v) {
                  if (_status == ResultStatus.notDone) return null;
                  if ((v == null || v.trim().isEmpty) && _secondsController.text.trim().isEmpty) {
                    return 'Укажите время';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _secondsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Секунды *',
                  hintText: 'например: 45',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixText: 'сек',
                ),
                validator: (v) {
                  if (_status == ResultStatus.notDone) return null;
                  final sec = int.tryParse(v ?? '');
                  if (sec != null && (sec < 0 || sec >= 60)) {
                    return '0 - 59 сек';
                  }
                  return null;
                },
              ),
            ),
          ],
        );

      case WorkoutScoreType.roundsReps:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _roundsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Раунды *',
                  hintText: 'например: 5',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixText: 'рд',
                ),
                validator: (v) => (_status != ResultStatus.notDone && (v == null || v.trim().isEmpty))
                    ? 'Введите раунды'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Доп. повторы',
                  hintText: 'например: 12',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixText: 'повт',
                ),
              ),
            ),
          ],
        );

      case WorkoutScoreType.weight:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Вес (кг) *',
                  hintText: 'например: 100',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixText: 'кг',
                ),
                validator: (v) => (_status != ResultStatus.notDone && (v == null || v.trim().isEmpty))
                    ? 'Введите вес'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Повторы',
                  hintText: 'например: 3',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixText: 'повт',
                ),
              ),
            ),
          ],
        );

      case WorkoutScoreType.reps:
        return TextFormField(
          controller: _repsController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Количество повторов *',
            hintText: 'например: 150',
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixText: 'повт',
          ),
          validator: (v) => (_status != ResultStatus.notDone && (v == null || v.trim().isEmpty))
              ? 'Введите повторы'
              : null,
        );

      case WorkoutScoreType.distance:
        return TextFormField(
          controller: _distanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Диста��ция (метры) *',
            hintText: 'например: 2000 или 5000',
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixText: 'м',
          ),
          validator: (v) => (_status != ResultStatus.notDone && (v == null || v.trim().isEmpty))
              ? 'Введите дистанцию'
              : null,
        );

      case WorkoutScoreType.calories:
        return TextFormField(
          controller: _caloriesController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Калории *',
            hintText: 'например: 350',
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixText: 'ккал',
          ),
          validator: (v) => (_status != ResultStatus.notDone && (v == null || v.trim().isEmpty))
              ? 'Введите калории'
              : null,
        );

      case WorkoutScoreType.text:
        return TextFormField(
          controller: _scoreController,
          decoration: InputDecoration(
            labelText: 'Результат *',
            hintText: 'например: 5 раундов + 12 берпи или 80 кг',
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => (_status != ResultStatus.notDone && (v == null || v.trim().isEmpty))
              ? 'Введите результат'
              : null,
        );

      case WorkoutScoreType.none:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.primaryNeon, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'В этом задании не требуется ввод очков. Выберите статус и при желании добавьте заметку.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialResult != null;
    final taskTitle = widget.part.title.trim().isNotEmpty ? widget.part.title.trim() : 'Задание';

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
                        Text(
                          isEditing ? 'Редактирование результата' : 'Ввод результата',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          taskTitle,
                          style: const TextStyle(color: AppColors.primaryNeon, fontSize: 13, fontWeight: FontWeight.w600),
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
              DropdownButtonFormField<WorkoutScoreType>(
                initialValue: _selectedScoreType,
                decoration: InputDecoration(
                  labelText: 'Формат записи',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                dropdownColor: AppColors.surface,
                items: const [
                  DropdownMenuItem(value: WorkoutScoreType.none, child: Text('Только статус')),
                  DropdownMenuItem(value: WorkoutScoreType.text, child: Text('Текст')),
                  DropdownMenuItem(value: WorkoutScoreType.time, child: Text('Время')),
                  DropdownMenuItem(value: WorkoutScoreType.roundsReps, child: Text('Раунды + повторы')),
                  DropdownMenuItem(value: WorkoutScoreType.weight, child: Text('Вес')),
                  DropdownMenuItem(value: WorkoutScoreType.reps, child: Text('Повторы')),
                  DropdownMenuItem(value: WorkoutScoreType.distance, child: Text('Дистанция')),
                  DropdownMenuItem(value: WorkoutScoreType.calories, child: Text('Калории')),
                ],
                onChanged: (newType) {
                  if (newType != null) {
                    setState(() {
                      _selectedScoreType = newType;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildScoreInputs(),
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
                    : Text(isEditing ? 'Сохранить изменения' : 'Сохранить результат'),
              ),
              if (isEditing) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text('Удалить результат', style: TextStyle(color: AppColors.error)),
                  onPressed: _isLoading ? null : _deleteResult,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
