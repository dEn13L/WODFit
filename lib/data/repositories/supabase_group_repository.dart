import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';
import '../models/group_model.dart';

class SupabaseGroupRepository implements GroupRepository {
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

    final response = await client
        .from('groups')
        .select('*, group_members(user_id)')
        .eq('coach_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => GroupModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
        .toList();
  }

  @override
  Future<List<Group>> getClientGroups() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

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
  }

  @override
  Future<Group> createGroup({required String name}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Необходима авторизация');
    }

    final inviteCode = _generateInviteCode();

    final response = await client.from('groups').insert({
      'coach_id': userId,
      'name': name.trim(),
      'invite_code': inviteCode,
    }).select().single();

    return GroupModel.fromJson(Map<String, dynamic>.from(response)).toDomain();
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
        return GroupModel.fromJson(Map<String, dynamic>.from(groupRes)).toDomain();
      }
    } catch (_) {
      // Fallback: direct lookup and insert if RPC is not available
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
      return GroupModel.fromJson(Map<String, dynamic>.from(groupRes)).toDomain();
    }

    throw Exception('Не удалось присоединиться к группе');
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final response = await client
        .from('group_members')
        .select('*, profiles(*)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    return (response as List<dynamic>)
        .map((item) => GroupMemberModel.fromJson(Map<String, dynamic>.from(item as Map)).toDomain())
        .toList();
  }
}
