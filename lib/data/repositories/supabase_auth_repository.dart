import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_profile_model.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? _client;

  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client : null);

  SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw Exception('Supabase не инициализирован. Проверьте переменные окружения SUPABASE_URL и SUPABASE_ANON_KEY.');
    }
    return c;
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    if (_client == null) return null;
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return UserProfileModel.fromJson(response).toDomain();
      }

      // Fallback: create from auth metadata if profile row isn't populated yet
      final roleStr = (user.userMetadata?['role'] as String?) ?? 'client';
      final nameStr = (user.userMetadata?['full_name'] as String?) ?? user.email?.split('@').first ?? 'Атлет';
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: nameStr,
        role: UserRole.fromString(roleStr),
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting current user profile: $e');
      return null;
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges {
    if (_client == null) {
      return Stream.value(null);
    }

    return client.auth.onAuthStateChange.asyncMap((data) async {
      final session = data.session;
      if (session == null) return null;
      return await getCurrentUserProfile();
    });
  }

  @override
  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final authResponse = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = authResponse.user;
    if (user == null) {
      throw Exception('Не удалось выполнить вход: пользователь не найден');
    }

    final profile = await getCurrentUserProfile();
    if (profile != null) return profile;

    final roleStr = (user.userMetadata?['role'] as String?) ?? 'client';
    final nameStr = (user.userMetadata?['full_name'] as String?) ?? user.email?.split('@').first ?? 'Атлет';
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      fullName: nameStr,
      role: UserRole.fromString(roleStr),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  @override
  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final authResponse = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role.name,
      },
    );

    final user = authResponse.user;
    if (user == null) {
      throw Exception('Не удалось зарегистрировать пользователя');
    }

    // Give database trigger a small moment or return populated profile
    await Future.delayed(const Duration(milliseconds: 300));
    final profile = await getCurrentUserProfile();
    if (profile != null) return profile;

    return UserProfile(
      id: user.id,
      email: user.email ?? email,
      fullName: fullName,
      role: role,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> signOut() async {
    if (_client != null) {
      await client.auth.signOut();
    }
  }
}
