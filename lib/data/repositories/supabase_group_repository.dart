import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';
import '../models/group_model.dart';

class SupabaseGroupRepository implements GroupRepository {
  static const String _tag = 'SupabaseGroupRepository';
  final SupabaseClient? _client;

  SupabaseGroupRepository({SupabaseClient? client})
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
  Future<List<Group>> getCoachGroups() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('groups')
          .select('*, group_members(user_id)')
          .eq('coach_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => GroupModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении групп тренера', e, st);
      rethrow;
    }
  }

  @override
  Future<List<Group>> getClientGroups() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('group_members')
          .select('group_id, groups(*, group_members(user_id))')
          .eq('user_id', userId);

      final List<Group> list = [];
      for (final row in response as List<dynamic>) {
        if (row['groups'] != null && row['groups'] is Map) {
          final groupJson = Map<String, dynamic>.from(row['groups'] as Map);
          list.add(GroupModel.fromJson(groupJson).toDomain());
        }
      }
      return list;
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении групп клиента', e, st);
      rethrow;
    }
  }

  @override
  Future<Group> createGroup({required String name}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      final inviteCode = _generateInviteCode();

      final response = await client.from('groups').insert({
        'coach_id': userId,
        'name': name.trim(),
        'invite_code': inviteCode,
      }).select().single();

      AppLogger.i(_tag, 'Создана новая группа: ${name.trim()} ($inviteCode)');
      return GroupModel.fromJson(Map<String, dynamic>.from(response)).toDomain();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при создании группы', e, st);
      rethrow;
    }
  }

  @override
  Future<Group> updateGroupName({required String groupId, required String name}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      final response = await client
          .from('groups')
          .update({'name': name.trim()})
          .eq('id', groupId)
          .eq('coach_id', userId)
          .select('*, group_members(user_id)')
          .single();

      AppLogger.i(_tag, 'Обновлено название группы $groupId: ${name.trim()}');
      return GroupModel.fromJson(Map<String, dynamic>.from(response)).toDomain();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при обновлении названия группы $groupId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('groups')
          .delete()
          .eq('id', groupId)
          .eq('coach_id', userId);

      AppLogger.i(_tag, 'Удалена группа $groupId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при удалении группы $groupId', e, st);
      rethrow;
    }
  }

  @override
  Future<Group> joinGroupByCode({required String inviteCode}) async {
    final cleanCode = inviteCode.trim().toUpperCase();

    try {
      // First try via RPC function
      final rpcRes = await client.rpc('join_group_by_code', params: {'code': cleanCode});
      if (rpcRes != null && rpcRes is Map) {
        final groupId = rpcRes['id'] as String;
        final groupRes = await client.from('groups').select('*, group_members(user_id)').eq('id', groupId).single();
        AppLogger.i(_tag, 'Клиент вступил в группу $cleanCode (через RPC)');
        return GroupModel.fromJson(Map<String, dynamic>.from(groupRes)).toDomain();
      }
    } catch (rpcErr) {
      AppLogger.w(_tag, 'join_group_by_code RPC fallback: $rpcErr');
      // Fallback: direct lookup and insert if RPC is not available
      try {
        final groupRes = await client.from('groups').select().eq('invite_code', cleanCode).maybeSingle();
        if (groupRes == null) {
          throw Exception('Группа с кодом $cleanCode не найдена');
        }

        final groupId = groupRes['id'] as String;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          await client.from('group_members').upsert({
            'group_id': groupId,
            'user_id': userId,
          });
        }
        AppLogger.i(_tag, 'Клиент вступил в группу $cleanCode (через fallback)');
        return GroupModel.fromJson(Map<String, dynamic>.from(groupRes)).toDomain();
      } catch (e, st) {
        AppLogger.e(_tag, 'Ошибка при вступлении в группу по коду $cleanCode', e, st);
        rethrow;
      }
    }

    throw Exception('Не удалось присоединиться к группе');
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    try {
      await client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      AppLogger.i(_tag, 'Пользователь $userId вышел из группы $groupId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при выходе из группы $groupId', e, st);
      rethrow;
    }
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      final response = await client
          .from('group_members')
          .select('*, profiles(*)')
          .eq('group_id', groupId)
          .order('joined_at', ascending: true);

      return (response as List<dynamic>)
          .map((item) => GroupMemberModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
          .toList();
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при получении участников группы $groupId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> removeGroupMember({required String groupId, required String userId}) async {
    try {
      await client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      AppLogger.i(_tag, 'Участник $userId удален из группы $groupId');
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при удалении участника $userId из группы $groupId', e, st);
      rethrow;
    }
  }
}
