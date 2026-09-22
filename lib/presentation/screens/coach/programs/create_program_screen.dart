import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../domain/entities/training_program.dart';
import '../../../bloc/program/program_cubit.dart';

class CreateProgramScreen extends StatefulWidget {
  const CreateProgramScreen({super.key});

  @override
  State<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

class _CreateProgramScreenState extends State<CreateProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ProgramKind _selectedKind = ProgramKind.group;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Код $text скопирован в буфер обмена'),
        backgroundColor: context.appTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSuccessDialog(TrainingProgram program) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = context.appTheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: appTheme.success),
            const SizedBox(width: 8),
            Text('Программа создана', style: TextStyle(color: colorScheme.onSurface)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Программа "${program.name}" (${program.kind.displayName}) успешно создана.',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Код для приглашения атлетов:',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    program.inviteCode,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 20, color: colorScheme.primary),
                    onPressed: () => _copyToClipboard(program.inviteCode),
                    tooltip: 'Скопировать код',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Передайте этот код атлету, чтобы он мог подключиться к программе.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (mounted) {
                context.pop();
              }
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    final program = await context.read<ProgramCubit>().createProgram(
          name: _nameController.text,
          kind: _selectedKind,
          description: _descriptionController.text,
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (program != null) {
        await _showSuccessDialog(program);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание программы'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Новая программа',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Выберите тип программы и задайте параметры. Инвайт-код для атлетов сгенерируется автоматически.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                // Тип программы
                Text(
                  'Тип программы',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ProgramKind>(
                  segments: const [
                    ButtonSegment(
                      value: ProgramKind.group,
                      label: Text('Группа'),
                      icon: Icon(Icons.groups),
                    ),
                    ButtonSegment(
                      value: ProgramKind.personal,
                      label: Text('Персональная'),
                      icon: Icon(Icons.person),
                    ),
                  ],
                  selected: {_selectedKind},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedKind = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Название программы
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название программы *',
                    hintText: _selectedKind == ProgramKind.group
                        ? 'например: Утренняя группа 08:00'
                        : 'например: Персональная (Иван)',
                    prefixIcon: Icon(
                      _selectedKind == ProgramKind.group ? Icons.groups_outlined : Icons.person_outline,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название программы';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Описание программы
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Описание (опционально)',
                    hintText: 'Цели, график занятий, уровень подготовки...',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _onSubmit,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                        )
                      : const Text('Создать программу'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
