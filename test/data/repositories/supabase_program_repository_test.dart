import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wod_fit/data/repositories/supabase_program_repository.dart';
import 'package:wod_fit/domain/exceptions/program_join_exception.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';

void main() {
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
