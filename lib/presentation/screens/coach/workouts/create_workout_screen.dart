import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../bloc/group/group_cubit.dart';
import '../../../bloc/workout/crossfit_workout_cubit.dart';

class _EditablePart {
  final String id;
  WorkoutPartType type;
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  _EditablePart({
    required this.id,
    this.type = WorkoutPartType.crossfitComplex,
    String initialTitle = '',
    String initialDescription = '',
  })  : titleController = TextEditingController(text: initialTitle),
        descriptionController = TextEditingController(text: initialDescription);

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
  }
}

class CreateWorkoutScreen extends StatefulWidget {
  final CrossfitWorkout? workoutToEdit;

  const CreateWorkoutScreen({
    super.key,
    this.workoutToEdit,
  });

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _scheduledAt;
  final Set<String> _selectedGroupIds = {};
  final List<_EditablePart> _parts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    context.read<GroupCubit>().loadCoachGroups();

    if (widget.workoutToEdit != null) {
      final w = widget.workoutToEdit!;
      _titleController = TextEditingController(text: w.title);
      _descriptionController = TextEditingController(text: w.description);
      _scheduledAt = w.scheduledAt;
      _selectedGroupIds.addAll(w.assignedGroupIds);

      if (w.parts.isNotEmpty) {
        for (final p in w.parts) {
          _addPart(p.type, p.title, p.description, p.id);
        }
      } else {
        _addPart(WorkoutPartType.crossfitComplex, 'WOD: Главный комплекс', '');
      }
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _scheduledAt = DateTime.now();
      // Pre-populate with one default part
      _addPart(WorkoutPartType.warmup, 'Разминка', 'Суставная гимнастика, 3 раунда...');
      _addPart(WorkoutPartType.crossfitComplex, 'WOD: Главный комплекс', 'For Time: 21-15-9...');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final part in _parts) {
      part.dispose();
    }
    super.dispose();
  }

  void _addPart([
    WorkoutPartType type = WorkoutPartType.crossfitComplex,
    String title = '',
    String description = '',
    String? id,
  ]) {
    setState(() {
      _parts.add(_EditablePart(
        id: id ?? const Uuid().v4(),
        type: type,
        initialTitle: title,
        initialDescription: description,
      ));
    });
  }

  void _movePartUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _parts.removeAt(index);
        _parts.insert(index - 1, item);
      });
    }
  }

  void _movePartDown(int index) {
    if (index < _parts.length - 1) {
      setState(() {
        final item = _parts.removeAt(index);
        _parts.insert(index + 1, item);
      });
    }
  }

  void _removePart(int index) {
    if (_parts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тренировка должна содержать хотя бы одну часть'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      final removed = _parts.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit({required bool publish}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одну часть тренировки'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите хотя бы одну группу для тренировки'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final workoutParts = _parts.asMap().entries.map((entry) {
      final idx = entry.key;
      final part = entry.value;
      return WorkoutPart(
        id: part.id,
        workoutId: widget.workoutToEdit?.id ?? '',
        type: part.type,
        title: part.titleController.text.trim().isEmpty ? part.type.displayName : part.titleController.text.trim(),
        description: part.descriptionController.text.trim(),
        sortOrder: idx,
      );
    }).toList();

    bool success;
    if (widget.workoutToEdit != null) {
      final status = publish ? WorkoutStatus.published : widget.workoutToEdit!.status;
      success = await context.read<CrossfitWorkoutCubit>().updateWorkout(
            id: widget.workoutToEdit!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            scheduledAt: _scheduledAt,
            parts: workoutParts,
            groupIds: _selectedGroupIds.toList(),
            status: status,
          );
    } else {
      success = await context.read<CrossfitWorkoutCubit>().createWorkout(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            scheduledAt: _scheduledAt,
            parts: workoutParts,
            groupIds: _selectedGroupIds.toList(),
            publish: publish,
          );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutToEdit != null ? 'Редактирование тренировки' : 'Создание тренировки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Основная информация',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Название тренировки / WOD *',
                    hintText: 'например: WOD "FRAN" & Силовой блок',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Общее описание / задачи (опционально)',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.primaryNeon),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Дата и время проведения', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(dateFormat.format(_scheduledAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Назначить группам',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                BlocBuilder<GroupCubit, GroupState>(
                  builder: (context, state) {
                    if (state is GroupLoaded) {
                      if (state.groups.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'У вас пока нет групп. Вы сможете назначить тренировку позже или создать группу в разделе "Мои группы".',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: state.groups.map((group) {
                          final isSelected = _selectedGroupIds.contains(group.id);
                          return FilterChip(
                            label: Text(group.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedGroupIds.add(group.id);
                                } else {
                                  _selectedGroupIds.remove(group.id);
                                }
                              });
                            },
                            selectedColor: AppColors.primaryNeon,
                            checkmarkColor: Colors.black,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: AppColors.surface,
                          );
                        }).toList(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Части тренировки (${_parts.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () => _addPart(),
                      icon: const Icon(Icons.add, color: AppColors.primaryNeon),
                      label: const Text('Добавить часть', style: TextStyle(color: AppColors.primaryNeon, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _parts.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _parts.removeAt(oldIndex);
                      _parts.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final part = _parts[index];
                    return Card(
                      key: ValueKey(part.id),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.drag_handle, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Часть ${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward, size: 20),
                                  tooltip: 'Переместить выше',
                                  onPressed: index > 0 ? () => _movePartUp(index) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward, size: 20),
                                  tooltip: 'Переместить ниже',
                                  onPressed: index < _parts.length - 1 ? () => _movePartDown(index) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                  tooltip: 'Удалить часть',
                                  onPressed: () => _removePart(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<WorkoutPartType>(
                              initialValue: part.type,
                              decoration: InputDecoration(
                                labelText: 'Тип части',
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              items: WorkoutPartType.values.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type.displayName),
                                );
                              }).toList(),
                              onChanged: (newType) {
                                if (newType != null) {
                                  setState(() {
                                    part.type = newType;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: part.titleController,
                              decoration: InputDecoration(
                                labelText: 'Название блока / упражнения',
                                hintText: 'например: Snatch Complex 5x2',
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: part.descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Задание / Описание / Схема',
                                hintText: 'например: EMOM 10 min:\n- 3 Power Snatch\n- 5 Overhead Squat',
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _submit(publish: true),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Опубликовать тренировку'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isLoading ? null : () => _submit(publish: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.surfaceLight),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Сохранить как черновик'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
