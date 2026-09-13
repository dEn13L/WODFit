import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/crossfit_workout.dart';
import '../../domain/entities/part_result.dart';
import '../../domain/repositories/crossfit_workout_repository.dart';
import '../models/crossfit_workout_model.dart';
import '../models/part_result_model.dart';

class SupabaseCrossfitWorkoutRepository implements CrossfitWorkoutRepository {
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

    final response = await client
        .from('workouts')
        .select('*, workout_parts(*), workout_assignments(*, groups(name))')
        .eq('coach_id', userId)
        .order('scheduled_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => CrossfitWorkoutModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
        .toList();
  }

  @override
  Future<List<CrossfitWorkout>> getClientWorkouts() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    // 1. Get all group IDs for current user
    final memberRes = await client.from('group_members').select('group_id').eq('user_id', userId);
    final groupIds = (memberRes as List<dynamic>).map((e) => e['group_id'] as String).toList();

    if (groupIds.isEmpty) return [];

    // 2. Get assignments for these groups
    final assignRes = await client
        .from('workout_assignments')
        .select('workout_id')
        .filter('group_id', 'in', groupIds);

    final workoutIds = (assignRes as List<dynamic>).map((e) => e['workout_id'] as String).toSet().toList();

    if (workoutIds.isEmpty) return [];

    // 3. Get published workouts
    final response = await client
        .from('workouts')
        .select('*, workout_parts(*), workout_assignments(*, groups(name))')
        .filter('id', 'in', workoutIds)
        .eq('status', 'published')
        .order('scheduled_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => CrossfitWorkoutModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
        .toList();
  }

  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async {
    final response = await client
        .from('workouts')
        .select('*, workout_parts(*), workout_assignments(*, groups(name))')
        .eq('id', id)
        .single();

    final model = CrossfitWorkoutModel.fromJson(Map<String, dynamic>.from(response));
    final sortedParts = List<WorkoutPart>.from(model.parts.map((p) => p.toDomain()))
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return model.toDomain().copyWith(parts: sortedParts);
  }

  @override
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> groupIds,
    bool publish = false,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    // 1. Insert workout
    final workoutRes = await client.from('workouts').insert({
      'coach_id': userId,
      'title': title.trim(),
      'description': description.trim(),
      'scheduled_at': scheduledAt.toIso8601String(),
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
          'title': part.title.trim(),
          'description': part.description.trim(),
          'sort_order': index,
        };
      }).toList();

      await client.from('workout_parts').insert(partsData);
    }

    // 3. Insert assignments
    if (groupIds.isNotEmpty) {
      final assignmentsData = groupIds.map((groupId) => {
        'workout_id': workoutId,
        'group_id': groupId,
      }).toList();

      await client.from('workout_assignments').insert(assignmentsData);
    }

    return getWorkoutById(workoutId);
  }

  @override
  Future<void> publishWorkout(String id) async {
    await client.from('workouts').update({
      'status': 'published',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<List<PartResult>> getWorkoutResults(String workoutId) async {
    final response = await client
        .from('part_results')
        .select('*, profiles(*)')
        .eq('workout_id', workoutId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => PartResultModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
        .toList();
  }

  @override
  Future<List<PartResult>> getUserWorkoutResults(String workoutId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await client
        .from('part_results')
        .select('*, profiles(*)')
        .eq('workout_id', workoutId)
        .eq('user_id', userId);

    return (response as List<dynamic>)
        .map((item) => PartResultModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
        .toList();
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
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

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
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await client
        .from('part_results')
        .upsert(data, onConflict: 'part_id, user_id')
        .select('*, profiles(*)')
        .single();

    return PartResultModel.fromJson(Map<String, dynamic>.from(response)).toDomain();
  }
}
