import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/repositories/program_repository.dart';
import '../models/program_model.dart';

class SupabaseProgramRepository implements ProgramRepository {
  static const String _tag = 'SupabaseProgramRepository';
  final SupabaseClient? _client;

  SupabaseProgramRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client : null);

  SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw Exception('Supabase не инициализирован. Проверьте переменные окружения SUPABASE_URL и SUPABASE_ANON_KEY.');
    }
    return c;
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Future<List<TrainingProgram>> getCoachPrograms() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('programs')
          .select('*, program_members(user_id)')
          .eq('coach_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => TrainingProgramModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении программ тренера', e, st);
      rethrow;
    }
  }

  @override
  Future<List<TrainingProgram>> getClientPrograms() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('program_members')
          .select('program_id, programs(*, program_members(user_id))')
          .eq('user_id', userId);

      final List<TrainingProgram> list = [];
      for (final row in response as List<dynamic>) {
        if (row['programs'] != null && row['programs'] is Map) {
          final programJson = Map<String, dynamic>.from(row['programs'] as Map);
          list.add(TrainingProgramModel.fromJson(programJson).toDomain());
        }
      }
      return list;
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении программ клиента', e, st);
      rethrow;
    }
  }

  @override
  Future<TrainingProgram> createProgram({
    required String name,
    ProgramKind kind = ProgramKind.group,
    String description = '',
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      final inviteCode = _generateInviteCode();

      final response = await client.from('programs').insert({
        'coach_id': userId,
        'name': name.trim(),
        'kind': kind.name,
        'description': description.trim(),
        'invite_code': inviteCode,
      }).select().single();

      AppLogger.i(_tag, 'Создана новая программа: ${name.trim()} ($inviteCode)');
      return TrainingProgramModel.fromJson(Map<String, dynamic>.from(response)).toDomain();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при создании программы', e, st);
      rethrow;
    }
  }

  @override
  Future<TrainingProgram> updateProgram({
    required String programId,
    required String name,
    ProgramKind? kind,
    String? description,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      final updateData = <String, dynamic>{
        'name': name.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (kind != null) {
        updateData['kind'] = kind.name;
      }
      if (description != null) {
        updateData['description'] = description.trim();
      }

      final response = await client
          .from('programs')
          .update(updateData)
          .eq('id', programId)
          .eq('coach_id', userId)
          .select('*, program_members(user_id)')
          .single();

      AppLogger.i(_tag, 'Обновлена программа $programId: ${name.trim()}');
      return TrainingProgramModel.fromJson(Map<String, dynamic>.from(response)).toDomain();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при обновлении программы $programId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> deleteProgram(String programId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('programs')
          .delete()
          .eq('id', programId)
          .eq('coach_id', userId);

      AppLogger.i(_tag, 'Удалена программа $programId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при удалении программы $programId', e, st);
      rethrow;
    }
  }

  @override
  Future<TrainingProgram> joinProgramByCode({required String inviteCode}) async {
    final cleanCode = inviteCode.trim().toUpperCase();

    try {
      // First try via RPC function join_program_by_code
      final rpcRes = await client.rpc('join_program_by_code', params: {'code': cleanCode});
      if (rpcRes != null && rpcRes is Map) {
        final programId = rpcRes['id'] as String;
        final programRes = await client.from('programs').select('*, program_members(user_id)').eq('id', programId).single();
        AppLogger.i(_tag, 'Клиент вступил в программу $cleanCode (через RPC)');
        return TrainingProgramModel.fromJson(Map<String, dynamic>.from(programRes)).toDomain();
      }
    } catch (rpcErr) {
      AppLogger.w(_tag, 'join_program_by_code RPC fallback: $rpcErr');
      // Fallback: direct lookup and insert if RPC is not available
      try {
        final programRes = await client.from('programs').select().eq('invite_code', cleanCode).maybeSingle();
        if (programRes == null) {
          throw Exception('Программа с кодом $cleanCode не найдена');
        }

        final programId = programRes['id'] as String;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          await client.from('program_members').upsert({
            'program_id': programId,
            'user_id': userId,
          });
        }
        AppLogger.i(_tag, 'Клиент вступил в программу $cleanCode (через fallback)');
        return TrainingProgramModel.fromJson(Map<String, dynamic>.from(programRes)).toDomain();
      } catch (e, st) {
        AppLogger.e(_tag, 'Ошибка при вступлении в программу по коду $cleanCode', e, st);
        rethrow;
      }
    }

    throw Exception('Не удалось присоединиться к программе');
  }

  @override
  Future<void> leaveProgram(String programId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('program_members')
          .delete()
          .eq('program_id', programId)
          .eq('user_id', userId);

      AppLogger.i(_tag, 'Пользователь $userId вышел из программы $programId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при выходе из программы $programId', e, st);
      rethrow;
    }
  }

  @override
  Future<List<ProgramMember>> getProgramMembers(String programId) async {
    try {
      final response = await client
          .from('program_members')
          .select('*, profiles(*)')
          .eq('program_id', programId)
          .order('joined_at', ascending: true);

      return (response as List<dynamic>)
          .map((item) => ProgramMemberModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении участников программы $programId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> removeProgramMember({
    required String programId,
    required String userId,
  }) async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('program_members')
          .delete()
          .eq('program_id', programId)
          .eq('user_id', userId);

      AppLogger.i(_tag, 'Участник $userId исключен из программы $programId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при исключении участника из программы', e, st);
      rethrow;
    }
  }
}
