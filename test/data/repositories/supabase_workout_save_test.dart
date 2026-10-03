import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wod_fit/data/repositories/supabase_crossfit_workout_repository.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/presentation/bloc/workout_form/workout_form_cubit.dart';

const workoutId = '00000000-0000-0000-0000-000000000001';
const partId = '00000000-0000-0000-0000-000000000002';
const programId = '00000000-0000-0000-0000-000000000003';
final scheduledAt = DateTime.utc(2026, 10, 3, 12);
const part = WorkoutPart(
  id: partId,
  workoutId: workoutId,
  title: ' Task ',
  description: ' Details ',
);

Map<String, dynamic> savedWorkout(Map<String, dynamic> payload) => {
  'id': workoutId,
  'coach_id': '00000000-0000-0000-0000-000000000004',
  'title': payload['p_title'],
  'description': payload['p_description'],
  'scheduled_at': payload['p_scheduled_at'],
  'status': payload['p_status'],
  'created_at': scheduledAt.toIso8601String(),
  'updated_at': scheduledAt.toIso8601String(),
  'workout_parts': (payload['p_parts'] as List)
      .asMap()
      .entries
      .map(
        (entry) => {
          ...entry.value as Map<String, dynamic>,
          'workout_id': workoutId,
          'sort_order': entry.key,
        },
      )
      .toList(),
  'workout_assignments': (payload['p_program_ids'] as List)
      .map(
        (id) => {
          'workout_id': workoutId,
          'program_id': id,
          'assigned_at': scheduledAt.toIso8601String(),
          'programs': {'name': 'Программа'},
        },
      )
      .toList(),
};

void main() {
  for (final create in [true, false]) {
    test(
      '${create ? "create" : "update"} saves and reads the entire form in one RPC',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            requests.add(request);
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(savedWorkout(payload)),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseCrossfitWorkoutRepository(client: client);
        final saved = create
            ? await repository.createWorkout(
                title: ' Session ',
                description: '',
                scheduledAt: scheduledAt,
                parts: [part],
                programIds: [programId, programId],
                publish: true,
              )
            : await repository.updateWorkout(
                id: workoutId,
                title: ' Session ',
                description: '',
                scheduledAt: scheduledAt,
                parts: [part],
                programIds: [programId],
                status: WorkoutStatus.published,
              );
        expect(requests, hasLength(1));
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/rest/v1/rpc/save_workout');
        final payload =
            jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(payload['p_workout_id'], create ? null : workoutId);
        expect(payload['p_title'], 'Session');
        expect(payload['p_status'], 'published');
        expect(payload['p_scheduled_at'], scheduledAt.toIso8601String());
        expect(payload['p_program_ids'], [programId]);
        final task = (payload['p_parts'] as List).single as Map;
        expect(task['id'], create ? isNot(partId) : partId);
        expect(task['title'], 'Task');
        expect(task['description'], 'Details');
        expect(task.containsKey('score_type'), isFalse);
        expect(task.containsKey('type'), isFalse);
        expect(saved.parts.single.id, task['id']);
        expect(saved.assignments.single.programName, 'Программа');
      },
    );
  }

  for (final code in ['W0001', '42501', '22023', 'PGRST202', 'XX000']) {
    test(
      'RPC $code returns a safe form error without fallback writes',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'code': code,
                'message': 'internal error',
                'details': 'sensitive detail',
                'hint': 'sensitive hint',
              }),
              400,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final cubit = WorkoutFormCubit(
          workoutRepository: SupabaseCrossfitWorkoutRepository(client: client),
          workoutToEdit: CrossfitWorkout(
            id: workoutId,
            coachId: 'coach',
            title: '',
            scheduledAt: scheduledAt,
            status: WorkoutStatus.draft,
            createdAt: scheduledAt,
            updatedAt: scheduledAt,
            parts: [part],
          ),
        );
        addTearDown(cubit.close);
        cubit.setSessionName('Изменение');
        cubit.setTaskTitle(partId, 'Изменённое задание');
        cubit.removeTask(partId);
        await cubit.saveDraft();
        expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.error);
        expect(cubit.state.errorMessage, isNot(contains('sensitive')));
        expect(cubit.state.errorMessage, isNot(contains('internal')));
        expect(cubit.state.sessionName, 'Изменение');
        if (code == 'W0001') {
          expect(cubit.state.tasks.single.id, partId);
          expect(cubit.state.tasks.single.title, 'Изменённое задание');
          expect(cubit.state.errorMessage, contains('результатами'));
        }
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/rest/v1/rpc/save_workout');
      },
    );
  }

  test('repeated submit while saving sends only one RPC', () async {
    final response = Completer<http.Response>();
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) {
        requests.add(request);
        return response.future;
      }),
    );
    addTearDown(client.dispose);
    final cubit = WorkoutFormCubit(
      workoutRepository: SupabaseCrossfitWorkoutRepository(client: client),
      workoutToEdit: CrossfitWorkout(
        id: workoutId,
        coachId: 'coach',
        title: '',
        scheduledAt: scheduledAt,
        status: WorkoutStatus.draft,
        createdAt: scheduledAt,
        updatedAt: scheduledAt,
        parts: [part],
      ),
    );
    addTearDown(cubit.close);
    final save = cubit.saveDraft();
    await cubit.saveDraft();
    // Доставляем запрос в MockClient, не дожидаясь HTTP-ответа.
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(1));
    final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
    response.complete(
      http.Response(
        jsonEncode(savedWorkout(payload)),
        200,
        headers: {'content-type': 'application/json'},
        request: requests.single,
      ),
    );
    await save;
    expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.success);
  });
}
