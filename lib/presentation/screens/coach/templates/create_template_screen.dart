import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../../domain/entities/workout_template.dart';
import '../../../bloc/template/workout_template_cubit.dart';

class _EditableTemplatePart {
  final String id;
  WorkoutPartType type;
  WorkoutScoreType scoreType;
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  _EditableTemplatePart({
    required this.id,
    this.type = WorkoutPartType.crossfitComplex,
    this.scoreType = WorkoutScoreType.text,
    String initialTitle = '',
    String initialDescription = '',
  })  : titleController = TextEditingController(text: initialTitle),
        descriptionController = TextEditingController(text: initialDescription);

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
  }
}

class CreateTemplateScreen extends StatefulWidget {
  final WorkoutTemplate? templateToEdit;

  const CreateTemplateScreen({
    super.key,
    this.templateToEdit,
  });

  @override
  State<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends State<CreateTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final List<_EditableTemplatePart> _parts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.templateToEdit != null) {
      final t = widget.templateToEdit!;
      _titleController = TextEditingController(text: t.title);
      _descriptionController = TextEditingController(text: t.description);
      if (t.parts.isNotEmpty) {
        for (final p in t.parts) {
          _addPart(p.type, p.scoreType, p.title, p.description, p.id);
        }
      } else {
        _addPart(WorkoutPartType.crossfitComplex, WorkoutScoreType.time, 'WOD: Главный комплекс', '');
      }
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _addPart(WorkoutPartType.warmup, WorkoutScoreType.none, 'Разминка', 'Суставная гимнастика, 3 раунда...');
      _addPart(WorkoutPartType.crossfitComplex, WorkoutScoreType.time, 'WOD: Главный комплекс', 'For Time: 21-15-9...');
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
    WorkoutScoreType scoreType = WorkoutScoreType.text,
    String title = '',
    String description = '',
    String? id,
  ]) {
    setState(() {
      _parts.add(_EditableTemplatePart(
        id: id ?? const Uuid().v4(),
        type: type,
        scoreType: scoreType,
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
          content: Text('В шаблоне должна быть хотя бы одна часть'),
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

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одну часть в шаблон'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final parts = _parts.asMap().entries.map((entry) {
      final idx = entry.key;
      final p = entry.value;
      return WorkoutTemplatePart(
        id: p.id,
        templateId: widget.templateToEdit?.id ?? '',
        type: p.type,
        scoreType: p.scoreType,
        title: p.titleController.text.trim().isEmpty ? p.type.displayName : p.titleController.text.trim(),
        description: p.descriptionController.text.trim(),
        sortOrder: idx,
      );
    }).toList();

    final cubit = context.read<WorkoutTemplateCubit>();
    bool success;

    if (widget.templateToEdit != null) {
      success = await cubit.updateTemplate(
        id: widget.templateToEdit!.id,
        title: title,
        description: description,
        parts: parts,
      );
    } else {
      success = await cubit.createTemplate(
        title: title,
        description: description,
        parts: parts,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.templateToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактировать шаблон' : 'Новый шаблон'),
      ),
      body: BlocListener<WorkoutTemplateCubit, WorkoutTemplateState>(
        listener: (context, state) {
          if (state is WorkoutTemplateError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ошибка: ${state.message}'),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is WorkoutTemplateLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Template Title & Description
              Text(
                'Основная информация',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryNeon,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название шаблона *',
                  hintText: 'Например: WOD "Мёрф" или Классическая силовая',
                  prefixIcon: Icon(Icons.bookmark_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название шаблона';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Общее описание (необязательно)',
                  hintText: 'Цели тренировки, масштабирование, рекомендации...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Template Parts Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Части тренировки (${_parts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryNeon,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addPart(),
                    icon: const Icon(Icons.add, color: AppColors.primaryNeon),
                    label: const Text('Добавить часть', style: TextStyle(color: AppColors.primaryNeon)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3. Parts list
              ..._parts.asMap().entries.map((entry) {
                final index = entry.key;
                final part = entry.value;
                return _buildPartCard(part, index);
              }),

              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _addPart(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Добавить еще часть тренировки'),
              ),
              const SizedBox(height: 32),

              // 4. Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTemplate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        isEditing ? 'Сохранить изменения' : 'Создать шаблон',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartCard(_EditableTemplatePart part, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primaryNeon.withValues(alpha: 0.2),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primaryNeon,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<WorkoutPartType>(
                    initialValue: part.type,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: WorkoutPartType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          part.type = val;
                          if (part.titleController.text.isEmpty ||
                              WorkoutPartType.values.any((t) => t.displayName == part.titleController.text)) {
                            part.titleController.text = val.displayName;
                          }
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  tooltip: 'Переместить выше',
                  onPressed: index > 0 ? () => _movePartUp(index) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  tooltip: 'Переместить ниже',
                  onPressed: index < _parts.length - 1 ? () => _movePartDown(index) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  tooltip: 'Удалить часть',
                  onPressed: () => _removePart(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkoutScoreType>(
              initialValue: part.scoreType,
              decoration: const InputDecoration(
                labelText: 'Тип результата (Score Type)',
                isDense: true,
              ),
              items: WorkoutScoreType.values.map((st) {
                return DropdownMenuItem(
                  value: st,
                  child: Text(st.displayName, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    part.scoreType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: part.titleController,
              decoration: const InputDecoration(
                labelText: 'Название части',
                hintText: 'Например: Комплекс 1 / Взятия на грудь',
                isDense: true,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Укажите название части';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: part.descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Описание и задание части',
                hintText: '5 раундов на время:\n- 10 бурпи\n- 15 махов гирей 24 кг\n- 20 приседаний',
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
