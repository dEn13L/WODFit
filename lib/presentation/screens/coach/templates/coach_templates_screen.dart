import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/workout_template.dart';
import '../../../bloc/template/workout_template_cubit.dart';
import '../workouts/create_workout_screen.dart';
import 'create_template_screen.dart';

class CoachTemplatesScreen extends StatefulWidget {
  const CoachTemplatesScreen({super.key});

  @override
  State<CoachTemplatesScreen> createState() => _CoachTemplatesScreenState();
}

class _CoachTemplatesScreenState extends State<CoachTemplatesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTemplates() {
    context.read<WorkoutTemplateCubit>().loadTemplates();
  }

  void _confirmDelete(WorkoutTemplate template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить шаблон?'),
        content: Text(
          'Вы уверены, что хотите удалить шаблон "${template.title}"? Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final cubit = context.read<WorkoutTemplateCubit>();
              await cubit.deleteTemplate(template.id);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаблоны тренировок'),
        actions: [
          IconButton(
            tooltip: 'Создать шаблон',
            icon: const Icon(Icons.add, color: AppColors.primaryNeon),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateTemplateScreen()),
              );
              if (mounted) _loadTemplates();
            },
          ),
        ],
      ),
      body: BlocConsumer<WorkoutTemplateCubit, WorkoutTemplateState>(
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
        builder: (context, state) {
          if (state is WorkoutTemplateLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryNeon),
            );
          }

          if (state is WorkoutTemplateError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить шаблоны:\n${state.message}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadTemplates,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final templates = state is WorkoutTemplateLoaded ? state.templates : <WorkoutTemplate>[];
          final filteredTemplates = _searchQuery.trim().isEmpty
              ? templates
              : templates.where((t) {
                  final q = _searchQuery.toLowerCase();
                  return t.title.toLowerCase().contains(q) ||
                      t.description.toLowerCase().contains(q) ||
                      t.parts.any((p) => p.title.toLowerCase().contains(q) || p.description.toLowerCase().contains(q));
                }).toList();

          return RefreshIndicator(
            onRefresh: () async => _loadTemplates(),
            color: AppColors.primaryNeon,
            child: Column(
              children: [
                if (templates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск по шаблонам...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                Expanded(
                  child: filteredTemplates.isEmpty
                      ? _buildEmptyState(templates.isEmpty)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          itemCount: filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = filteredTemplates[index];
                            return _buildTemplateCard(template);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateTemplateScreen()),
          );
          if (mounted) _loadTemplates();
        },
        backgroundColor: AppColors.primaryNeon,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Новый шаблон', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(bool noTemplatesAtAll) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noTemplatesAtAll ? Icons.bookmark_add_outlined : Icons.search_off,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              noTemplatesAtAll ? 'Нет сохраненных шаблонов' : 'Ничего не найдено',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              noTemplatesAtAll
                  ? 'Создавайте шаблоны для часто используемых комплексов (например, WOD "Мёрф", "Синди" или типовых силовых блоков), чтобы назначать их в 1 клик.'
                  : 'По запросу "$_searchQuery" ничего не найдено. Попробуйте изменить формулировку.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (noTemplatesAtAll) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateTemplateScreen()),
                  );
                  if (mounted) _loadTemplates();
                },
                icon: const Icon(Icons.add),
                label: const Text('Создать первый шаблон'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(WorkoutTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (template.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          template.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateTemplateScreen(templateToEdit: template),
                        ),
                      );
                      if (mounted) _loadTemplates();
                    } else if (value == 'duplicate') {
                      await context.read<WorkoutTemplateCubit>().duplicateTemplate(template.id);
                    } else if (value == 'delete') {
                      _confirmDelete(template);
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
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Удалить', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Parts chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: template.parts.map((part) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    part.type.displayName,
                    style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    template.workoutTypesSummary,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateWorkoutScreen(initialTemplate: template),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNeon,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text('Создать тренировку'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
