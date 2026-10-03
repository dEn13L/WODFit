import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hive/hive.dart';
import 'package:wod_fit/main.dart';
import 'package:wod_fit/core/theme/theme_service.dart';
import 'package:wod_fit/presentation/screens/coach/coach_home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/data/repositories/supabase_crossfit_workout_repository.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/exceptions/workout_unavailable_exception.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_bloc.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_event.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';
import 'package:wod_fit/presentation/bloc/program/program_detail_cubit.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'package:wod_fit/presentation/screens/coach/programs/program_detail_screen.dart';
import 'package:wod_fit/presentation/screens/workout/workout_detail_screen.dart';
import 'package:wod_fit/presentation/state/session_data_cache.dart';
import 'package:wod_fit/presentation/widgets/app_state_view.dart';
import 'package:wod_fit/presentation/widgets/screen_data_scope.dart';

import '../../support/fake_crossfit_workout_repository.dart';

final now = DateTime(2026, 10, 3, 12);
final program = TrainingProgram(
  id: 'p',
  coachId: 'coach',
  name: 'Program P',
  inviteCode: '123',
  createdAt: now,
);
CrossfitWorkout workout(String id) => CrossfitWorkout(
  id: id,
  coachId: 'coach',
  title: id.toUpperCase(),
  scheduledAt: now,
  createdAt: now,
  updatedAt: now,
  parts: [
    WorkoutPart(
      id: 'part-$id',
      workoutId: id,
      title: 'Task ${id.toUpperCase()}',
    ),
  ],
  assignments: [
    WorkoutAssignment(
      workoutId: id,
      programId: 'p',
      programName: 'Program P',
      assignedAt: now,
    ),
  ],
);

class Workouts extends FakeCrossfitWorkoutRepository {
  Completer<List<CrossfitWorkout>>? delayedList;
  Completer<CrossfitWorkout>? delayedDetail;
  int listReads = 0;
  int detailReads = 0;
  Object? detailError;
  int countReads = 0;
  bool fail = false;
  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async {
    listReads++;
    if (fail) throw Exception('offline');
    return delayedList?.future ?? [workout('a'), workout('b')];
  }

  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async {
    detailReads++;
    if (detailError != null) throw detailError!;
    if (fail) throw Exception('offline');
    return delayedDetail?.future ?? workout(id);
  }

  @override
  Future<Map<String, int>> getWorkoutResultUserCounts(List<String> ids) async {
    countReads++;
    return {for (final id in ids) id: 0};
  }
}

class Programs implements ProgramRepository {
  Completer<List<TrainingProgram>>? delayed;
  bool fail = false;
  @override
  Future<List<TrainingProgram>> getCoachPrograms() async {
    if (fail) throw Exception('offline');
    return delayed?.future ?? [program];
  }

  @override
  Future<List<TrainingProgram>> getClientPrograms() => getCoachPrograms();
  @override
  Future<List<ProgramMember>> getProgramMembers(String id) async => [];
  @override
  Future<TrainingProgram> updateProgram({
    required String programId,
    required String name,
    ProgramKind? kind,
    String? description,
  }) async =>
      program.copyWith(name: name, kind: kind, description: description);
  @override
  Future<void> leaveProgram(String programId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final coach = UserProfile(
  id: 'coach',
  email: 'coach@example.com',
  fullName: 'Coach',
  role: UserRole.coach,
  createdAt: now,
);

class Auth extends AuthRepository {
  @override
  Future<UserProfile?> getCurrentUserProfile() async => coach;
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'cache merges concurrent reads and rejects data from previous session',
    () async {
      final cache = SessionDataCache();
      final pending = Completer<String>();
      var reads = 0;
      Future<String> fetch() {
        reads++;
        return pending.future;
      }

      final first = cache.refresh('key', fetch);
      final second = cache.refresh('key', fetch);
      final firstError = expectLater(
        first,
        throwsA(isA<CacheSessionChanged>()),
      );
      final secondError = expectLater(
        second,
        throwsA(isA<CacheSessionChanged>()),
      );
      expect(reads, 1);
      cache.clear();
      pending.complete('previous user');
      await Future.wait([firstError, secondError]);
      expect(cache.read<String>('key'), isNull);
      await cache.close();
    },
  );

  test(
    'cache never overwrites a saved mutation with an older response',
    () async {
      final cache = SessionDataCache();
      final pending = Completer<String>();
      cache.put('key', 'original');
      final loading = cache.refresh('key', () => pending.future);
      cache.put('key', 'saved');
      pending.complete('old server response');
      expect(await loading, 'saved');
      expect(cache.read<String>('key'), 'saved');
      await cache.close();
    },
  );

  test('session cache evicts least recently read entries', () async {
    final cache = SessionDataCache(maxEntries: 2);
    cache.put('a', 1);
    cache.put('b', 2);
    cache.read<int>('a');
    cache.put('c', 3);
    expect(cache.read<int>('b'), isNull);
    expect(cache.read<int>('a'), 1);
    await cache.close();
  });

  test(
    'separate routes restore a cached list without losing the opened detail',
    () async {
      final cache = SessionDataCache();
      final repository = Workouts();
      final list = CrossfitWorkoutCubit(
        workoutRepository: repository,
        cache: cache,
      );
      final detail = CrossfitWorkoutCubit(
        workoutRepository: repository,
        cache: cache,
      );
      await list.loadCoachWorkouts();
      await detail.loadWorkoutDetails('a');
      repository.delayedList = Completer<List<CrossfitWorkout>>();
      final refreshing = list.loadCoachWorkouts();
      expect(list.state, isA<CrossfitWorkoutListLoaded>());
      expect((detail.state as CrossfitWorkoutDetailLoaded).workout.id, 'a');
      repository.delayedList!.complete([workout('a'), workout('b')]);
      await refreshing;
      await list.close();
      await detail.close();
      await cache.close();
    },
  );

  test('cached detail remains visible when background refresh fails', () async {
    final repository = Workouts();
    final cubit = CrossfitWorkoutCubit(workoutRepository: repository);
    await cubit.loadWorkoutDetails('a');
    repository.fail = true;
    await cubit.loadWorkoutDetails('a');
    expect(cubit.state, isA<CrossfitWorkoutDetailLoaded>());
    expect(
      (cubit.state as CrossfitWorkoutDetailLoaded).refreshError,
      isNotNull,
    );
    await cubit.close();
  });

  test('confirmed missing workout is removed from cache, unlike an offline failure', () async {
    final cache = SessionDataCache();
    final repository = Workouts();
    final cubit = CrossfitWorkoutCubit(
      workoutRepository: repository,
      cache: cache,
    );
    await cubit.loadCoachWorkouts();
    await cubit.loadWorkoutDetails('a');
    repository.detailError = const WorkoutUnavailableException();
    await cubit.loadWorkoutDetails('a');
    expect(cubit.state, isA<CrossfitWorkoutError>());
    expect(
      cache.read<CrossfitWorkoutDetailLoaded>(
        CrossfitWorkoutCubit.detailKey('a'),
      ),
      isNull,
    );
    expect(
      cache
          .read<CrossfitWorkoutListLoaded>(CrossfitWorkoutCubit.coachListKey)!
          .workouts
          .map((w) => w.id),
      ['b'],
    );
    await cubit.close();
    await cache.close();
  });

  test(
    'saved and deleted workouts update other routes and cannot be resurrected',
    () async {
      final cache = SessionDataCache();
      final repository = Workouts();
      final list = CrossfitWorkoutCubit(
        workoutRepository: repository,
        cache: cache,
      );
      final detail = CrossfitWorkoutCubit(
        workoutRepository: repository,
        cache: cache,
      );
      await list.loadCoachWorkouts();
      await detail.loadWorkoutDetails('a');
      detail.applySavedWorkout(workout('a').copyWith(title: 'Saved'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (list.state as CrossfitWorkoutListLoaded).workouts
            .firstWhere((w) => w.id == 'a')
            .title,
        'Saved',
      );
      repository.delayedDetail = Completer<CrossfitWorkout>();
      final refreshing = detail.loadWorkoutDetails('a');
      await detail.deleteWorkout('a');
      repository.delayedDetail!.complete(workout('a'));
      await refreshing;
      await Future<void>.delayed(Duration.zero);
      expect(
        cache.read<CrossfitWorkoutDetailLoaded>(
          CrossfitWorkoutCubit.detailKey('a'),
        ),
        isNull,
      );
      expect(
        (list.state as CrossfitWorkoutListLoaded).workouts.map((w) => w.id),
        ['b'],
      );
      await list.close();
      await detail.close();
      await cache.close();
    },
  );

  test('leaving a program removes inaccessible cached workouts', () async {
    final cache = SessionDataCache();
    final workouts = CrossfitWorkoutCubit(
      workoutRepository: Workouts(),
      cache: cache,
    );
    final programs = ProgramCubit(programRepository: Programs(), cache: cache);
    await programs.loadClientPrograms();
    await workouts.loadWorkoutDetails('a');
    expect(cache.read<Object>('workout:a'), isNotNull);
    expect(await programs.leaveProgram('p'), isTrue);
    expect(cache.read<Object>('workout:a'), isNull);
    await workouts.close();
    await programs.close();
    await cache.close();
  });

  test('new program route restores cached content and sees edits from another route', () async {
    final cache = SessionDataCache();
    final programs = Programs();
    final workouts = Workouts();
    final first = ProgramDetailCubit(
      programRepository: programs,
      workoutRepository: workouts,
      cache: cache,
    );
    await first.load('p');
    final second = ProgramDetailCubit(
      programRepository: programs,
      workoutRepository: workouts,
      cache: cache,
    );
    programs.delayed = Completer<List<TrainingProgram>>();
    final loading = second.load('p');
    expect(second.state.data!.program.id, 'p');
    expect(second.state.isLoading, isFalse);
    final editor = ProgramCubit(programRepository: programs, cache: cache);
    await editor.updateProgram(programId: 'p', name: 'Edited');
    await Future<void>.delayed(Duration.zero);
    expect(first.state.data!.program.name, 'Edited');
    expect(second.state.data!.program.name, 'Edited');
    programs.delayed!.complete([program]);
    await loading;
    expect(second.state.data!.program.name, 'Edited');
    expect(workouts.countReads, 2);
    await editor.close();
    await first.close();
    await second.close();
    await cache.close();
  });

  test(
    'batch counters page results and count each athlete only once',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final offset = request.url.queryParameters['offset'];
          final rows = offset == '0'
              ? List.generate(
                  1000,
                  (i) => {'workout_id': 'a', 'user_id': 'u$i'},
                )
              : [
                  {'workout_id': 'a', 'user_id': 'u0'},
                  {'workout_id': 'b', 'user_id': 'u0'},
                ];
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final repository = SupabaseCrossfitWorkoutRepository(client: client);
      expect(await repository.getWorkoutResultUserCounts(['a', 'b', 'c']), {
        'a': 1000,
        'b': 1,
        'c': 0,
      });
      expect(requests.length, 2);
      expect(
        requests.first.url.queryParameters['select'],
        'workout_id,user_id',
      );
      expect(requests.first.url.queryParameters['deleted_at'], 'is.null');
      expect(
        requests.first.url.queryParameters['workout_id'],
        'in.("a","b","c")',
      );
      await client.dispose();
    },
  );

  testWidgets('account change and logout clear cached data and route state', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('wod-cache-auth-'),
    ))!;
    Hive.init(directory.path);
    final theme = ThemeService();
    await tester.runAsync(theme.init);
    await tester.pumpWidget(
      WodFitApp(
        authRepository: Auth(),
        programRepository: Programs(),
        crossfitWorkoutRepository: Workouts(),
        themeService: theme,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(CoachHomeScreen));
    final cache = context.read<SessionDataCache>();
    final auth = context.read<AuthBloc>();
    final original = context.read<CrossfitWorkoutCubit>();
    cache.put('private', 'first user');
    auth.add(
      AuthUserChanged(
        UserProfile(
          id: 'other',
          email: 'other@example.com',
          fullName: 'Other',
          role: UserRole.coach,
          createdAt: now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(cache.read<String>('private'), isNull);
    final next = tester
        .element(find.byType(CoachHomeScreen))
        .read<CrossfitWorkoutCubit>();
    expect(identical(original, next), isFalse);
    expect(next.state, isA<CrossfitWorkoutListLoaded>());
    cache.put('private', 'second user');
    auth.add(const AuthUserChanged(null));
    await tester.pumpAndSettle();
    expect(cache.read<String>('private'), isNull);
    expect(cache.keys, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
  });

  testWidgets(
    'program → workout A → program → workout B → back preserves workout A',
    (tester) async {
      final cache = SessionDataCache();
      final programs = Programs();
      final workouts = Workouts();
      final auth = AuthBloc(authRepository: Auth());
      auth.add(
        AuthUserChanged(
          UserProfile(
            id: 'coach',
            email: 'coach@example.com',
            fullName: 'Coach',
            role: UserRole.coach,
            createdAt: now,
          ),
        ),
      );
      await tester.pump();
      final router = GoRouter(
        initialLocation: '/coach/programs/p',
        routes: [
          GoRoute(
            path: '/coach/programs/:id',
            builder: (_, state) => ScreenDataScope(
              child: ProgramDetailScreen(
                programId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/workout/:id',
            builder: (_, state) => ScreenDataScope(
              child: WorkoutDetailScreen(
                workoutId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SessionDataCache>.value(value: cache),
            RepositoryProvider<ProgramRepository>.value(value: programs),
            RepositoryProvider<CrossfitWorkoutRepository>.value(
              value: workouts,
            ),
          ],
          child: BlocProvider<AuthBloc>.value(
            value: auth,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('(A)').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkoutDetailScreen>(find.byType(WorkoutDetailScreen))
            .workoutId,
        'a',
      );
      expect(find.text('Task A'), findsOneWidget);
      programs.delayed = Completer<List<TrainingProgram>>();
      await tester.tap(find.text('Program P'));
      await tester.pumpAndSettle();
      expect(find.byType(AppLoadingView), findsNothing);
      expect(find.textContaining('(B)'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('(B)'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('(B)'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkoutDetailScreen>(find.byType(WorkoutDetailScreen))
            .workoutId,
        'b',
      );
      expect(find.text('Task B'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkoutDetailScreen>(find.byType(WorkoutDetailScreen))
            .workoutId,
        'a',
      );
      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsNothing);
      programs.delayed!.complete([program]);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await tester.runAsync(auth.close);
      await cache.close();
    },
  );
}
