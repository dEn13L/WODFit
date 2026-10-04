import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';
import 'package:wod_fit/presentation/screens/client/join_program_screen.dart';
import 'package:wod_fit/presentation/screens/coach/programs/coach_programs_screen.dart';
import 'package:wod_fit/presentation/screens/coach/programs/program_detail_screen.dart';
import 'package:wod_fit/presentation/state/session_data_cache.dart';
import 'package:wod_fit/presentation/widgets/program_visual_banner.dart';

import '../../support/fake_crossfit_workout_repository.dart';

TrainingProgram _program(ProgramKind kind) => TrainingProgram(
  id: kind.name,
  coachId: 'coach',
  name: kind == ProgramKind.group
      ? 'Сила и выносливость с длинным названием'
      : 'Персональная · Анна',
  kind: kind,
  description: 'Полное описание программы с целями и расписанием тренировок',
  inviteCode: 'WOD247',
  memberCount: 1,
  createdAt: DateTime(2026),
);

class _Programs extends Fake implements ProgramRepository {
  List<TrainingProgram> programs = ProgramKind.values.map(_program).toList();
  final joinResponse = Completer<TrainingProgram>();
  String? joinedCode;
  int joinRequests = 0;
  int memberReads = 0;

  @override
  Future<List<TrainingProgram>> getCoachPrograms() async => programs;
  @override
  Future<List<ProgramMember>> getProgramMembers(String programId) async {
    memberReads++;
    return [
      ProgramMember(
        programId: programId,
        userId: 'athlete',
        joinedAt: DateTime(2026),
        userProfile: UserProfile(
          id: 'athlete',
          email: 'athlete@example.com',
          fullName: 'Анна Атлет',
          role: UserRole.client,
          createdAt: DateTime(2026),
        ),
      ),
    ];
  }

  @override
  Future<TrainingProgram> joinProgramByCode({required String inviteCode}) {
    joinedCode = inviteCode;
    joinRequests++;
    return joinResponse.future;
  }
}

class _Workouts extends FakeCrossfitWorkoutRepository {
  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async => [
    for (final draft in [false, true])
      CrossfitWorkout(
        id: draft ? 'draft' : 'published',
        coachId: 'coach',
        title: 'Legacy hidden title',
        scheduledAt: DateTime.now().add(Duration(days: draft ? 2 : 1)),
        status: draft ? WorkoutStatus.draft : WorkoutStatus.published,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        assignments: [
          WorkoutAssignment(
            workoutId: draft ? 'draft' : 'published',
            programId: 'group',
            programName: 'Сила',
            workoutNumber: draft ? 14 : 13,
            assignedAt: DateTime(2026),
          ),
        ],
      ),
  ];
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String screen,
  ThemeData? theme,
  double scale = 1,
  _Programs? repository,
  ValueChanged<Object?>? onCreate,
}) async {
  final programs = repository ?? _Programs();
  final cache = SessionDataCache();
  final cubit = ProgramCubit(programRepository: programs, cache: cache);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/programs',
        builder: (_, _) => const CoachProgramsScreen(),
      ),
      GoRoute(
        path: '/coach/programs/group',
        builder: (_, _) => const ProgramDetailScreen(programId: 'group'),
      ),
      GoRoute(
        path: '/coach/programs/create',
        builder: (_, _) => const Scaffold(body: Text('Create program')),
      ),
      GoRoute(
        path: '/coach/workouts/create',
        builder: (_, state) {
          onCreate?.call(state.extra);
          return const Scaffold(body: Text('Create workout'));
        },
      ),
      GoRoute(
        path: '/workout/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
      ),
      GoRoute(path: '/join', builder: (_, _) => const JoinProgramScreen()),
    ],
  );
  addTearDown(() async {
    router.dispose();
    await cubit.close();
    await cache.close();
  });
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProgramRepository>.value(value: programs),
        RepositoryProvider<CrossfitWorkoutRepository>.value(value: _Workouts()),
        RepositoryProvider<SessionDataCache>.value(value: cache),
      ],
      child: BlocProvider.value(
        value: cubit,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.darkTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push(screen);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final width in [320.0, 390.0, 1440.0]) {
      for (final screen in ['/programs', '/coach/programs/group', '/join']) {
        testWidgets('$screen ${theme.brightness} fits $width', (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _pump(
            tester,
            screen: screen,
            theme: theme,
            scale: width == 320 ? 1.5 : 1,
          );
          expect(find.byType(ProgramVisualBanner), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (screen == '/programs') {
            expect(find.text('Создать программу'), findsOneWidget);
            expect(find.byType(FloatingActionButton), findsNothing);
            expect(
              tester.getTopLeft(find.text('Создать программу')).dy,
              greaterThan(
                tester.getBottomLeft(find.byType(ProgramVisualBanner)).dy,
              ),
            );
            expect(find.text('WOD247'), findsNothing);
          } else if (screen == '/coach/programs/group') {
            final members = find.text('Участники · 1');
            await tester.ensureVisible(members);
            await tester.tap(members);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Анна Атлет'));
            expect(find.text('Анна Атлет'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('list card opens details; create workout retains program', (
    tester,
  ) async {
    Object? extra;
    await _pump(
      tester,
      screen: '/programs',
      onCreate: (value) => extra = value,
    );
    await tester.tap(find.text('Сила и выносливость с длинным названием'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Скопировать код приглашения'), findsOneWidget);
    expect(find.text('Legacy hidden title'), findsNothing);
    final button = find.text('Новая тренировка');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Create workout'), findsOneWidget);
    expect((extra as Map<String, dynamic>)['initialProgramId'], 'group');
  });

  testWidgets('empty list has one create action below banner', (tester) async {
    await _pump(
      tester,
      screen: '/programs',
      repository: _Programs()..programs = [],
    );
    expect(find.text('У вас пока нет программ'), findsOneWidget);
    expect(find.text('Создать программу'), findsOneWidget);
    await tester.tap(find.text('Создать программу'));
    await tester.pumpAndSettle();
    expect(find.text('Create program'), findsOneWidget);
  });

  testWidgets(
    'join hides banner with keyboard and reports error without losing code',
    (tester) async {
      final programs = _Programs();
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await _pump(tester, screen: '/join', repository: programs);
      await tester.enterText(find.byType(TextFormField), ' WOD247 ');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byType(ProgramVisualBanner), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(programs.joinedCode, 'WOD247');
      expect(programs.joinRequests, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      programs.joinResponse.completeError(Exception('Программа не найдена'));
      await tester.pumpAndSettle();
      expect(find.text('Программа не найдена'), findsOneWidget);
      expect(find.text(' WOD247 '), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('join validates code and returns after successful membership', (
    tester,
  ) async {
    final programs = _Programs();
    await _pump(tester, screen: '/join', repository: programs);
    final button = find.text('Присоединиться к программе');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Введите код приглашения'), findsOneWidget);
    expect(programs.joinRequests, 0);
    await tester.enterText(find.byType(TextFormField), 'WOD247');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    programs.joinResponse.complete(_program(ProgramKind.group));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
