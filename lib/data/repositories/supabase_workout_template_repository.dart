import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/repositories/workout_template_repository.dart';
import '../models/workout_template_model.dart';

class SupabaseWorkoutTemplateRepository implements WorkoutTemplateRepository {
  static const String _tag = 'SupabaseWorkoutTemplateRepository';
  final SupabaseClient? _client;

  SupabaseWorkoutTemplateRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client : null);

  SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw Exception('Supabase не инициализирован. Проверьте переменные окружения SUPABASE_URL и SUPABASE_ANON_KEY.');
    }
    return c;
  }

  @override
  Future<List<WorkoutTemplate>> getCoachTemplates() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('workout_templates')
          .select('*, workout_template_parts(*)')
          .eq('coach_id', userId)
          .order('created_at', ascending: false);

      final templates = (response as List<dynamic>)
          .map((item) => WorkoutTemplateModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .map((t) {
            final sortedParts = List<WorkoutTemplatePart>.from(t.parts)
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return t.copyWith(parts: sortedParts);
          })
          .toList();

      return templates;
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении шаблонов тренера', e, st);
      rethrow;
    }
  }

  @override
  Future<WorkoutTemplate> getTemplateById(String templateId) async {
    try {
      final response = await client
          .from('workout_templates')
          .select('*, workout_template_parts(*)')
          .eq('id', templateId)
          .single();

      final model = WorkoutTemplateModel.fromJson(Map<String, dynamic>.from(response));
      final sortedParts = List<WorkoutTemplatePart>.from(model.parts.map((p) => p.toDomain()))
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return model.toDomain().copyWith(parts: sortedParts);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении шаблона $templateId', e, st);
      rethrow;
    }
  }

  @override
  Future<WorkoutTemplate> createTemplate({
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      // 1. Insert template
      final templateRes = await client.from('workout_templates').insert({
        'coach_id': userId,
        'title': title.trim(),
        'description': description.trim(),
      }).select().single();

      final templateId = templateRes['id'] as String;

      // 2. Insert template parts
      if (parts.isNotEmpty) {
        final partsData = parts.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          return {
            'template_id': templateId,
            'type': p.type.name,
            'score_type': p.scoreType.dbValue,
            'title': p.title.trim(),
            'description': p.description.trim(),
            'sort_order': idx,
          };
        }).toList();

        await client.from('workout_template_parts').insert(partsData);
      }

      AppLogger.i(_tag, 'Создан шаблон тренировки: $templateId ("$title")');
      return await getTemplateById(templateId);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при создании шаблона', e, st);
      rethrow;
    }
  }

  @override
  Future<WorkoutTemplate> updateTemplate({
    required String id,
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      // 1. Update template
      await client
          .from('workout_templates')
          .update({
            'title': title.trim(),
            'description': description.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('coach_id', userId);

      // 2. Re-create parts
      await client.from('workout_template_parts').delete().eq('template_id', id);

      if (parts.isNotEmpty) {
        final partsData = parts.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          return {
            'template_id': id,
            'type': p.type.name,
            'score_type': p.scoreType.dbValue,
            'title': p.title.trim(),
            'description': p.description.trim(),
            'sort_order': idx,
          };
        }).toList();

        await client.from('workout_template_parts').insert(partsData);
      }

      AppLogger.i(_tag, 'Обновлен шаблон тренировки: $id ("$title")');
      return await getTemplateById(id);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при обновлении шаблона $id', e, st);
      rethrow;
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('workout_templates')
          .delete()
          .eq('id', templateId)
          .eq('coach_id', userId);

      AppLogger.i(_tag, 'Удален шаблон тренировки: $templateId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при удалении шаблона $templateId', e, st);
      rethrow;
    }
  }

  @override
  Future<WorkoutTemplate> duplicateTemplate(String templateId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      final original = await getTemplateById(templateId);
      final newTitle = '${original.title} (Копия)';

      final created = await createTemplate(
        title: newTitle,
        description: original.description,
        parts: original.parts,
      );

      AppLogger.i(_tag, 'Шаблон $templateId продублирован как ${created.id}');
      return created;
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при дублировании шаблона $templateId', e, st);
      rethrow;
    }
  }
}
