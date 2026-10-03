import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wod_fit/data/repositories/supabase_program_repository.dart';
import 'package:wod_fit/domain/exceptions/program_join_exception.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';

void main() {
  test('program creation inserts without RETURNING before reading by UUID', () async {
    const userId = '00000000-0000-0000-0000-000000000004';
    final requests = <http.Request>[];
    Map<String, dynamic>? inserted;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(jsonEncode({
            'access_token': 'test-access-token',
            'refresh_token': 'test-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': userId,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'coach@example.com',
              'created_at': '2026-10-03T12:00:00Z',
            },
          }), 200, headers: {'content-type': 'application/json'});
        }
        requests.add(request);
        if (request.method == 'POST') {
          expect(request.headers['prefer'], isNot(contains('return=representation')));
          expect(request.url.queryParameters, isNot(contains('select')));
          inserted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 201, request: request);
        }
        expect(request.method, 'GET');
        expect(request.url.queryParameters['id'], 'eq.${inserted!['id']}');
        expect(request.url.queryParameters['coach_id'], 'eq.$userId');
        return http.Response(jsonEncode({
          ...inserted!,
          'created_at': '2026-10-03T12:00:00Z',
        }), 200, headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(email: 'coach@example.com', password: 'test-password');
    final program = await SupabaseProgramRepository(client: client).createProgram(
      name: ' Новая программа ',
      description: ' Описание ',
    );
    expect(requests, hasLength(2));
    expect(requests.every((request) => request.url.path == '/rest/v1/programs'), isTrue);
    expect(program.id, inserted!['id']);
    expect(program.name, 'Новая программа');
    expect(program.description, 'Описание');
  });

  for (final scenario in [
    (
      code: 'P0001',
      message: 'Программа с кодом BAD не найдена',
      expected: 'Программа с таким кодом не найдена. Проверьте код приглашения.',
    ),
    (
      code: '42501',
      message: 'Only clients can join programs',
      expected: 'Вступать в программу могут только авторизованные атлеты.',
    ),
    (
      code: 'XX000',
      message: 'internal database error',
      expected: 'Не удалось вступить в программу. Попробуйте ещё раз.',
    ),
  ]) {
    test('RPC ${scenario.code} reaches ProgramError without SDK details or fallback', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'code': scenario.code,
              'message': scenario.message,
              'details': 'sensitive-detail',
              'hint': 'sensitive-hint',
            }),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final repository = SupabaseProgramRepository(client: client);
      final cubit = ProgramCubit(programRepository: repository);
      addTearDown(cubit.close);
      addTearDown(client.dispose);

      expect(await cubit.joinProgram(' bad '), isFalse);
      expect((cubit.state as ProgramError).message, scenario.expected);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/rpc/join_program_by_code');
      expect(jsonDecode(requests.single.body), {'code': 'BAD'});
      expect((cubit.state as ProgramError).message, isNot(contains('sensitive')));
    });
  }

  test('domain exception string is safe for presentation', () {
    expect(const ProgramJoinException('Понятная ошибка').toString(), 'Понятная ошибка');
  });
}
