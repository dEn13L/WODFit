import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/crossfit_workout.dart';
import '../../domain/entities/part_result.dart';
import '../../domain/repositories/crossfit_workout_repository.dart';
import '../models/crossfit_workout_model.dart';
import '../models/part_result_model.dart';

class SupabaseCrossfitWorkoutRepository implements CrossfitWorkoutRepository {
  static const String _tag = 'SupabaseCrossfitWorkoutRepository';
  final SupabaseClient? _client;

  SupabaseCrossfitWorkoutRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client : null);

  SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw Exception('Supabase не инициализирован. Проверьте переменные окружения SUPABASE_URL и SUPABASE_ANON_KEY.');
    }
    return c;
  }

  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('workouts')
          .select('*, workout_parts(*), workout_assignments(*, programs(name))')
          .eq('coach_id', userId)
          .order('scheduled_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => CrossfitWorkoutModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении тренировок тренера', e, st);
      rethrow;
    }
  }

  @override
  Future<List<CrossfitWorkout>> getClientWorkouts() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // 1. Get all program IDs for current user
      final memberRes = await client.from('program_members').select('program_id').eq('user_id', userId);
      final programIds = (memberRes as List<dynamic>).map((e) => (e['program_id'] ?? e['group_id']) as String).toList();

      if (programIds.isEmpty) return [];

      // 2. Get assignments for these programs
      final assignRes = await client
          .from('workout_assignments')
          .select('workout_id')
          .filter('program_id', 'in', programIds);

      final workoutIds = (assignRes as List<dynamic>).map((e) => e['workout_id'] as String).toSet().toList();

      if (workoutIds.isEmpty) return [];

      // 3. Get published workouts
      final response = await client
          .from('workouts')
          .select('*, workout_parts(*), workout_assignments(*, programs(name))')
          .filter('id', 'in', workoutIds)
          .eq('status', 'published')
          .order('scheduled_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => CrossfitWorkoutModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении тренировок клиента', e, st);
      rethrow;
    }
  }

  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async {
    try {
      final response = await client
          .from('workouts')
          .select('*, workout_parts(*), workout_assignments(*, programs(name))')
          .eq('id', id)
          .single();

      final model = CrossfitWorkoutModel.fromJson(Map<String, dynamic>.from(response));
      final sortedParts = List<WorkoutPart>.from(model.parts.map((p) => p.toDomain()))
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return model.toDomain().copyWith(parts: sortedParts);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении тренировки $id', e, st);
      rethrow;
    }
  }

  @override
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      // 1. Insert workout
      final workoutRes = await client.from('workouts').insert({
        'coach_id': userId,
        'title': title.trim(),
        'description': description.trim(),
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': publish ? 'published' : 'draft',
      }).select().single();

      final workoutId = workoutRes['id'] as String;

      // 2. Insert workout parts
      if (parts.isNotEmpty) {
        final partsData = parts.asMap().entries.map((entry) {
          final index = entry.key;
          final part = entry.value;
          return {
            'workout_id': workoutId,
            'type': part.type.name,
            'score_type': part.scoreType.dbValue,
            'description': part.description.trim(),
            'sort_order': index,
          };
        }).toList();

        await client.from('workout_parts').insert(partsData);
      }

      // 3. Insert assignments
      if (programIds.isNotEmpty) {
        final assignmentsData = programIds.map((programId) => {
          'workout_id': workoutId,
          'program_id': programId,
        }).toList();

        await client.from('workout_assignments').insert(assignmentsData);
      }

      AppLogger.i(_tag, 'Создана тренировка $workoutId: $title (publish=$publish)');
      return await getWorkoutById(workoutId);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при создании тренировки', e, st);
      rethrow;
    }
  }

  @override
  Future<CrossfitWorkout> updateWorkout({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    required WorkoutStatus status,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      // 1. Update workout header
      await client.from('workouts').update({
        'title': title.trim(),
        'description': description.trim(),
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': status.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id).eq('coach_id', userId);

      // 2. Get existing parts from DB
      final existingPartsRes = await client
          .from('workout_parts')
          .select('id')
          .eq('workout_id', id);

      final existingPartIds = (existingPartsRes as List<dynamic>)
          .map((e) => e['id'] as String)
          .toSet();

      final currentPartIds = parts.map((p) => p.id).toSet();

      // Delete parts that no longer exist
      final toDeleteIds = existingPartIds.difference(currentPartIds);
      if (toDeleteIds.isNotEmpty) {
        await client
            .from('workout_parts')
            .delete()
            .filter('id', 'in', toDeleteIds.toList());
      }

      // Upsert / insert parts
      if (parts.isNotEmpty) {
        final partsData = parts.asMap().entries.map((entry) {
          final index = entry.key;
          final part = entry.value;
          final data = <String, dynamic>{
            'workout_id': id,
            'type': part.type.name,
            'score_type': part.scoreType.dbValue,
            'description': part.description.trim(),
            'sort_order': index,
          };
          if (existingPartIds.contains(part.id)) {
            data['id'] = part.id;
          }
          return data;
        }).toList();

        await client.from('workout_parts').upsert(partsData);
      }

      // 3. Update assignments
      await client.from('workout_assignments').delete().eq('workout_id', id);

      if (programIds.isNotEmpty) {
        final assignmentsData = programIds.map((programId) => {
          'workout_id': id,
          'program_id': programId,
        }).toList();

        await client.from('workout_assignments').insert(assignmentsData);
      }

      AppLogger.i(_tag, 'Обновлена тренировка $id: $title');
      return await getWorkoutById(id);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при обновлении тренировки $id', e, st);
      rethrow;
    }
  }

  @override
  Future<CrossfitWorkout> duplicateWorkout(String workoutId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      final original = await getWorkoutById(workoutId);

      final duplicated = await createWorkout(
        title: original.title,
        description: original.description,
        scheduledAt: DateTime.now(),
        parts: original.parts,
        programIds: original.assignedProgramIds,
        publish: false,
      );

      AppLogger.i(_tag, 'Дублирована тренировка $workoutId -> ${duplicated.id}');
      return duplicated;
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при дублировании тренировки $workoutId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> deleteWorkout(String workoutId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('workouts')
          .delete()
          .eq('id', workoutId)
          .eq('coach_id', userId);

      AppLogger.i(_tag, 'Удалена тренировка $workoutId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при удалении тренировки $workoutId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> publishWorkout(String id) async {
    try {
      await client.from('workouts').update({
        'status': 'published',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

      AppLogger.i(_tag, 'Тренировка $id опубликована');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при публикации тренировки $id', e, st);
      rethrow;
    }
  }

  @override
  Future<List<PartResult>> getWorkoutResults(String workoutId) async {
    try {
      final response = await client
          .from('part_results')
          .select('*, profiles(*)')
          .eq('workout_id', workoutId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => PartResultModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении результатов тренировки $workoutId', e, st);
      rethrow;
    }
  }

  @override
  Future<List<PartResult>> getUserWorkoutResults(String workoutId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('part_results')
          .select('*, profiles(*)')
          .eq('workout_id', workoutId)
          .eq('user_id', userId);

      return (response as List<dynamic>)
          .map((item) => PartResultModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении результатов пользователя для $workoutId', e, st);
      rethrow;
    }
  }

  @override
  Future<List<PartResult>> getClientAllResults() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('part_results')
          .select('*, profiles(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => PartResultModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении всех результатов клиента', e, st);
      rethrow;
    }
  }

  @override
  Future<PartResult> submitPartResult({
    required String workoutId,
    required String partId,
    required ResultStatus status,
    required String scoreText,
    String note = '',
    int? timeMs,
    int? rounds,
    int? reps,
    double? weightKg,
    double? distanceM,
    int? calories,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      final data = {
        'workout_id': workoutId,
        'part_id': partId,
        'user_id': userId,
        'status': status.name,
        'score_text': scoreText.trim(),
        'note': note.trim(),
        'time_ms': timeMs,
        'rounds': rounds,
        'reps': reps,
        'weight_kg': weightKg,
        'distance_m': distanceM,
        'calories': calories,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await client
          .from('part_results')
          .upsert(data, onConflict: 'part_id, user_id')
          .select('*, profiles(*)')
          .single();

      AppLogger.i(_tag, 'Сохранен результат пользователя $userId для части $partId тренировки $workoutId');
      return PartResultModel.fromJson(Map<String, dynamic>.from(response)).toDomain();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при сохранении результата для части $partId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> deletePartResult(String resultId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('part_results')
          .delete()
          .eq('id', resultId)
          .eq('user_id', userId);

      AppLogger.i(_tag, 'Удален результат $resultId пользователя $userId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при удалении результата $resultId', e, st);
      rethrow;
    }
  }
}
