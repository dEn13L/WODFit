import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/workout_date_formatter.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../../domain/entities/training_program.dart';
import '../../../../domain/entities/workout_template.dart';
import '../../../bloc/program/program_cubit.dart';
import '../../../bloc/template/workout_template_cubit.dart';
import '../../../bloc/workout/crossfit_workout_cubit.dart';

class _EditablePart {
  final String id;
  WorkoutPartType type;
  WorkoutScoreType scoreType;
  final TextEditingController descriptionController;

  _EditablePart({
    required this.id,
    this.type = WorkoutPartType.crossfitComplex,
    this.scoreType = WorkoutScoreType.text,
    String initialDescription = '',
  }) : descriptionController = TextEditingController(text: initialDescription);

  void dispose() {
    descriptionController.dispose();
  }
}

class CreateWorkoutScreen extends StatefulWidget {
  final CrossfitWorkout? workoutToEdit;
  final WorkoutTemplate? initialTemplate;
  final String? initialProgramId;
  final List<String>? initialProgramIds;

  const CreateWorkoutScreen({
    super.key,
    this.workoutToEdit,
    this.initialTemplate,
    this.initialProgramId,
    this.initialProgramIds,
  });

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _scheduledAt;
  final Set<String> _selectedProgramIds = {};
  final List<_EditablePart> _parts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    context.read<ProgramCubit>().loadCoachPrograms();

    if (widget.initialProgramId != null) {
      _selectedProgramIds.add(widget.initialProgramId!);
    }
    if (widget.initialProgramIds != null) {
      _selectedProgramIds.addAll(widget.initialProgramIds!);
    }

    if (widget.workoutToEdit != null) {
      final w = widget.workoutToEdit!;
      _titleController = TextEditingController(text: w.title);
      _descriptionController = TextEditingController(text: w.description);
      _scheduledAt = w.scheduledAt.toLocal();
      _selectedProgramIds.addAll(w.assignedProgramIds);

      if (w.parts.isNotEmpty) {
        for (final p in w.parts) {
          _addPart(p.type, p.scoreType, p.description, p.id);
        }
      } else {
        _addPart(WorkoutPartType.crossfitComplex, WorkoutScoreType.time, '', null);
      }
    } else if (widget.initialTemplate != null) {
      final t = widget.initialTemplate!;
      // Deployment from template creates workout with empty label
      _titleController = TextEditingController(text: '');
      _descriptionController = TextEditingController(text: t.description);
      _scheduledAt = DateTime.now();

      if (t.parts.isNotEmpty) {
        for (final p in t.parts) {
          _addPart(p.type, p.scoreType, p.description);
        }
      } else {
        _addPart(WorkoutPartType.crossfitComplex, WorkoutScoreType.time, t.description);
      }
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _scheduledAt = DateTime.now();
      // Pre-populate with default parts
      _addPart(WorkoutPartType.warmup, WorkoutScoreType.none, 'Суставная гимнастика, 3 раунда...');
      _addPart(WorkoutPartType.crossfitComplex, WorkoutScoreType.time, 'For Time: 21-15-9...');
    }
  }

  void _applyTemplate(WorkoutTemplate template) {
    setState(() {
      // Deployment from template creates workout with empty label
      _titleController.text = '';
      _descriptionController.text = template.description;
      for (final p in _parts) {
        p.dispose();
      }
      _parts.clear();

      if (template.parts.isNotEmpty) {
        for (final p in template.parts) {
          _parts.add(_EditablePart(
            id: const Uuid().v4(),
            type: p.type,
            scoreType: p.scoreType,
            initialDescription: p.description,
          ));
        }
      } else {
        _addPart(WorkoutPartType.crossfitComplex, WorkoutScoreType.time, template.description);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Данные заполнены из шаблона "${template.title}"'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showTemplatePicker() {
    context.read<WorkoutTemplateCubit>().loadTemplates();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Выберите шаблон тренировки',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: BlocBuilder<WorkoutTemplateCubit, WorkoutTemplateState>(
                    builder: (context, state) {
                      if (state is WorkoutTemplateLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(color: AppColors.primaryNeon),
                          ),
                        );
                      }
                      final templates = state is WorkoutTemplateLoaded ? state.templates : <WorkoutTemplate>[];
                      if (templates.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'У вас пока нет сохраненных шаблонов.\nСоздайте их в разделе «Шаблоны».',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: templates.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = templates[index];
                          return ListTile(
                            leading: const Icon(Icons.bookmark_outline, color: AppColors.primaryNeon),
                            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${t.workoutTypesSummary} • ${t.description.isNotEmpty ? t.description : "Без описания"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _applyTemplate(t);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    WorkoutScoreType scoreType = WorkoutScoreType.text,
    String description = '',
    String? id,
  ]) {
    setState(() {
      _parts.add(_EditablePart(
        id: id ?? const Uuid().v4(),
        type: type,
        scoreType: scoreType,
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
          content: Text('Тренировка должна содержать хотя бы один блок'),
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
          content: Text('Добавьте хотя бы одно задание или блок тренировки'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (publish && _selectedProgramIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите хотя бы одну программу для публикации тренировки'),
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
        scoreType: part.scoreType,
        title: part.type.displayName,
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
            programIds: _selectedProgramIds.toList(),
            status: status,
          );
    } else {
      success = await context.read<CrossfitWorkoutCubit>().createWorkout(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            scheduledAt: _scheduledAt,
            parts: workoutParts,
            programIds: _selectedProgramIds.toList(),
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
                // 1. Секция — "Назначить программам"
                Text(
                  'Назначить программам',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                BlocBuilder<ProgramCubit, ProgramState>(
                  builder: (context, state) {
                    if (state is ProgramLoaded) {
                      if (state.programs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'У вас пока нет программ. Вы сможете назначить тренировку позже или создать программу в разделе "Программы".',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: state.programs.map((program) {
                          final isSelected = _selectedProgramIds.contains(program.id);
                          return FilterChip(
                            avatar: Icon(
                              program.kind == ProgramKind.personal ? Icons.person : Icons.groups,
                              size: 16,
                              color: isSelected ? Colors.black : AppColors.primaryNeon,
                            ),
                            label: Text('${program.name} (${program.kind.displayName})'),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedProgramIds.add(program.id);
                                } else {
                                  _selectedProgramIds.remove(program.id);
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
                const SizedBox(height: 24),

                // 2. Секци�� — "Основная информация"
                Text(
                  'Основная информация',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                // а) Плитка "Дата и время проведения"
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
                                Text(
                                  WorkoutDateFormatter.formatDetail(_scheduledAt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // б) Поле "Уточнение (опционально)"
                TextFormField(
                  controller: _titleController,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: 'Уточнение (опционально)',
                    hintText: 'Утро, Вечер, Сессия 1…',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                // в) Поле "Описание / задачи (опционально)"
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Описание / задачи (опционально)',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 28),

                // 3. Секция — "Блоки тренировки"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Блоки тренировки',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () => _addPart(),
                      icon: const Icon(Icons.add, color: AppColors.primaryNeon),
                      label: const Text('＋ Добавить блок', style: TextStyle(color: AppColors.primaryNeon, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showTemplatePicker,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryNeon),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bookmark_border, color: AppColors.primaryNeon),
                  label: const Text(
                    'Заполнить из шаблона',
                    style: TextStyle(color: AppColors.primaryNeon, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 16),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNeon.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    part.type.displayName,
                                    style: const TextStyle(
                                      color: AppColors.primaryNeon,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
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
                                  tooltip: 'Удалить блок',
                                  onPressed: () => _removePart(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<WorkoutPartType>(
                              initialValue: part.type,
                              decoration: InputDecoration(
                                labelText: 'Тип тренировки',
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
                            DropdownButtonFormField<WorkoutScoreType>(
                              initialValue: part.scoreType,
                              decoration: InputDecoration(
                                labelText: 'Тип результата (Score Type)',
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              items: WorkoutScoreType.values.map((st) {
                                return DropdownMenuItem(
                                  value: st,
                                  child: Text(st.displayName),
                                );
                              }).toList(),
                              onChanged: (newScoreType) {
                                if (newScoreType != null) {
                                  setState(() {
                                    part.scoreType = newScoreType;
                                  });
                                }
                              },
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

                // 4. Sticky-низ с действиями
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
