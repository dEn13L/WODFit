import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../../domain/entities/part_result.dart';
import '../../../bloc/workout/crossfit_workout_cubit.dart';
import 'result_input_parsers.dart';
import 'score_input_fields.dart';

class PartResultInputModal extends StatefulWidget {
  final String workoutId;
  final WorkoutPart part;
  final PartResult? initialResult;

  const PartResultInputModal({
    super.key,
    required this.workoutId,
    required this.part,
    this.initialResult,
  });

  @override
  State<PartResultInputModal> createState() => _PartResultInputModalState();
}

class _PartResultInputModalState extends State<PartResultInputModal> {
  final _formKey = GlobalKey<FormState>();
  late ResultStatus _status;
  late WorkoutScoreType _selectedScoreType;
  late final TextEditingController _scoreController;
  late final TextEditingController _noteController;
  late final TextEditingController _weightController;
  late final TextEditingController _roundsController;
  late final TextEditingController _repsController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;
  late final TextEditingController _distanceController;
  late final TextEditingController _caloriesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final result = widget.initialResult;
    _status = result?.status ?? ResultStatus.done;
    _selectedScoreType = result?.scoreType ?? WorkoutScoreType.text;
    _scoreController = TextEditingController(text: result?.scoreText ?? '');
    _noteController = TextEditingController(text: result?.note ?? '');
    _weightController = TextEditingController(
      text: result?.weightKg == null ? '' : formatDecimal(result!.weightKg!),
    );
    _roundsController = TextEditingController(
      text: result?.rounds?.toString() ?? '',
    );
    _repsController = TextEditingController(
      text: result?.reps?.toString() ?? '',
    );
    _distanceController = TextEditingController(
      text: result?.distanceM == null ? '' : formatDecimal(result!.distanceM!),
    );
    _caloriesController = TextEditingController(
      text: result?.calories?.toString() ?? '',
    );

    final initialTime = _initialTime(result);
    _minutesController = TextEditingController(
      text: initialTime?.minutes.toString().padLeft(2, '0') ?? '',
    );
    _secondsController = TextEditingController(
      text: initialTime?.seconds.toString().padLeft(2, '0') ?? '',
    );
  }

  ParsedWorkoutTime? _initialTime(PartResult? result) {
    if (result?.timeMs != null) {
      final totalSeconds = result!.timeMs! ~/ 1000;
      return ParsedWorkoutTime(
        minutes: totalSeconds ~/ 60,
        seconds: totalSeconds % 60,
      );
    }
    if (result == null || !result.scoreText.contains(':')) return null;
    final parts = result.scoreText.split(':');
    if (parts.length != 2) return null;
    return parseWorkoutTime(parts[0], parts[1]);
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
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    int? timeMs;
    int? rounds;
    int? reps;
    double? weightKg;
    double? distanceM;
    int? calories;
    var scoreText = '';

    if (_status == ResultStatus.notDone) {
      scoreText = 'Не выполнено';
    } else {
      switch (_selectedScoreType) {
        case WorkoutScoreType.time:
          final time = parseWorkoutTime(
            _minutesController.text,
            _secondsController.text,
          )!;
          timeMs = time.milliseconds;
          scoreText = time.formatted;
          break;
        case WorkoutScoreType.roundsReps:
          rounds = parseNonNegativeInt(_roundsController.text)!;
          reps = _optionalInt(_repsController.text);
          scoreText = reps != null && reps > 0
              ? '$rounds рд + $reps повт'
              : '$rounds рд';
          break;
        case WorkoutScoreType.weight:
          weightKg = parseNonNegativeDecimal(_weightController.text)!;
          reps = _optionalInt(_repsController.text);
          final weight = formatDecimal(weightKg);
          scoreText = reps != null && reps > 0
              ? '$weight кг ($reps повт)'
              : '$weight кг';
          break;
        case WorkoutScoreType.reps:
          reps = parseNonNegativeInt(_repsController.text)!;
          scoreText = '$reps повт';
          break;
        case WorkoutScoreType.distance:
          distanceM = parseNonNegativeDecimal(_distanceController.text)!;
          scoreText = '${formatDecimal(distanceM)} м';
          break;
        case WorkoutScoreType.calories:
          calories = parseNonNegativeInt(_caloriesController.text)!;
          scoreText = '$calories кал';
          break;
        case WorkoutScoreType.text:
          scoreText = _scoreController.text.trim();
          break;
        case WorkoutScoreType.none:
          break;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    final successColor = context.appTheme.success;
    final pendingColor = context.appTheme.warning;
    final cubit = context.read<CrossfitWorkoutCubit>();
    final success = await cubit.submitPartResult(
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

    if (!mounted) return;
    if (!success) {
      setState(() => _isLoading = false);
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cubit.lastMutationSyncStatus == ResultSyncStatus.synced
              ? 'Результат сохранён'
              : 'Результат сохранён локально и ожидает синхронизации',
        ),
        backgroundColor: cubit.lastMutationSyncStatus == ResultSyncStatus.synced
            ? successColor
            : pendingColor,
      ),
    );
  }

  int? _optionalInt(String value) =>
      value.trim().isEmpty ? null : parseNonNegativeInt(value);

  Future<void> _deleteResult() async {
    if (_isLoading || widget.initialResult == null) return;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить результат?'),
        content: const Text(
          'Вы действительно хотите удалить результат по этому заданию?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.destructive,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final successColor = context.appTheme.success;
    final pendingColor = context.appTheme.warning;
    final cubit = context.read<CrossfitWorkoutCubit>();
    final success = await cubit.deletePartResult(
          workoutId: widget.workoutId,
          resultId: widget.initialResult!.id,
        );
    if (!mounted) return;
    if (!success) {
      setState(() => _isLoading = false);
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cubit.lastMutationSyncStatus == ResultSyncStatus.synced
              ? 'Результат удалён'
              : 'Удаление сохранено локально и ожидает синхронизации',
        ),
        backgroundColor: cubit.lastMutationSyncStatus == ResultSyncStatus.synced
            ? successColor
            : pendingColor,
      ),
    );
  }

  Widget _scoreInput() {
    if (_status == ResultStatus.notDone) {
      return NoScoreRequired(
        text: 'Для статуса «Не выполнено» результат не требуется.',
        accentColor: context.appTheme.destructive,
      );
    }
    return switch (_selectedScoreType) {
      WorkoutScoreType.time => TimeScoreField(
          minutesController: _minutesController,
          secondsController: _secondsController,
        ),
      WorkoutScoreType.roundsReps => RoundsRepsScoreFields(
          roundsController: _roundsController,
          repsController: _repsController,
        ),
      WorkoutScoreType.weight => WeightScoreFields(
          weightController: _weightController,
          repsController: _repsController,
        ),
      WorkoutScoreType.reps => RepsScoreField(controller: _repsController),
      WorkoutScoreType.distance =>
        DistanceScoreField(controller: _distanceController),
      WorkoutScoreType.calories =>
        CaloriesScoreField(controller: _caloriesController),
      WorkoutScoreType.text => TextScoreField(controller: _scoreController),
      WorkoutScoreType.none => const NoScoreRequired(
          text: 'Выберите статус и при желании добавьте заметку.',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.initialResult != null;
    final taskTitle = widget.part.title.trim().isEmpty
        ? 'Задание'
        : widget.part.title.trim();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'Редактирование результата'
                                  : 'Ввод результата',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              taskTitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<ResultStatus>(
                              segments: const [
                                ButtonSegment(
                                  value: ResultStatus.done,
                                  label: Text('Выполнено'),
                                ),
                                ButtonSegment(
                                  value: ResultStatus.scaled,
                                  label: Text('Масштабировано'),
                                ),
                                ButtonSegment(
                                  value: ResultStatus.notDone,
                                  label: Text('Не выполнено'),
                                ),
                              ],
                              selected: {_status},
                              showSelectedIcon: false,
                              onSelectionChanged: _isLoading
                                  ? null
                                  : (selection) => setState(
                                        () => _status = selection.first,
                                      ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<WorkoutScoreType>(
                            initialValue: _selectedScoreType,
                            decoration: InputDecoration(
                              labelText: 'Формат записи',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: colorScheme.surface,
                            items: const [
                              DropdownMenuItem(
                                value: WorkoutScoreType.none,
                                child: Text('Без фиксации (статус)'),
                              ),
                              DropdownMenuItem(
                                value: WorkoutScoreType.text,
                                child: Text('Текст (произвольно)'),
                              ),
                              DropdownMenuItem(
                                value: WorkoutScoreType.time,
                                child: Text('Время'),
                              ),
                              DropdownMenuItem(
                                value: WorkoutScoreType.roundsReps,
                                child: Text('Раунды + повторы'),
                              ),
                              DropdownMenuItem(
                                value: WorkoutScoreType.weight,
                                child: Text('Вес'),
                              ),
                              DropdownMenuItem(
                                value: WorkoutScoreType.reps,
                                child: Text('Повторы'),
                              ),
                              DropdownMenuItem(
                                value: WorkoutScoreType.distance,
                                child: Text('Дистанция'),
                              ),
                              DropdownMenuItem(
                                value: WorkoutScoreType.calories,
                                child: Text('Калории'),
                              ),
                            ],
                            onChanged: _isLoading
                                ? null
                                : (type) {
                                    if (type != null) {
                                      setState(() => _selectedScoreType = type);
                                    }
                                  },
                          ),
                          const SizedBox(height: 16),
                          _scoreInput(),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _noteController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Заметка к результату',
                              hintText: 'например: разбивал подтягивания 15+6',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              isEditing
                                  ? 'Сохранить изменения'
                                  : 'Сохранить результат',
                            ),
                    ),
                  ),
                  if (isEditing)
                    TextButton.icon(
                      onPressed: _isLoading ? null : _deleteResult,
                      icon: Icon(
                        Icons.delete_outline,
                        color: context.appTheme.destructive,
                      ),
                      label: Text(
                        'Удалить результат',
                        style: TextStyle(color: context.appTheme.destructive),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
