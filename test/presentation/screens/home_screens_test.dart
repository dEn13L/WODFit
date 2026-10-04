import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/core/theme/theme_service.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_bloc.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_event.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';
import 'package:wod_fit/presentation/bloc/theme/theme_cubit.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'package:wod_fit/presentation/screens/client/client_home_screen.dart';
import 'package:wod_fit/presentation/screens/coach/coach_home_screen.dart';
import 'package:wod_fit/presentation/widgets/home_welcome_banner.dart';

import '../../support/fake_crossfit_workout_repository.dart';

class _Auth extends Fake implements AuthRepository {
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
}

class _Programs extends Fake implements ProgramRepository {
  @override
  Future<List<TrainingProgram>> getCoachPrograms() async => [
    for (final kind in ProgramKind.values)
      TrainingProgram(
        id: kind.name,
        coachId: 'coach',
        name: 'Программа с длинным названием для проверки переноса текста',
        kind: kind,
        inviteCode: '123456',
        createdAt: DateTime(2026),
      ),
  ];

  @override
  Future<List<TrainingProgram>> getClientPrograms() => getCoachPrograms();
}

class _Workouts extends FakeCrossfitWorkoutRepository {
  final List<CrossfitWorkout> workouts;
  int reads = 0;
  _Workouts(this.workouts);

  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async {
    reads++;
    return workouts;
  }

  @override
  Future<List<CrossfitWorkout>> getClientWorkouts() => getCoachWorkouts();
}

CrossfitWorkout _workout(
  String id,
  DateTime date,
  int number, {
  WorkoutStatus status = WorkoutStatus.published,
}) => CrossfitWorkout(
  id: id,
  coachId: 'coach',
  title: 'Legacy title must not appear',
  scheduledAt: date,
  status: status,
  createdAt: date,
  updatedAt: date,
  assignments: [
    WorkoutAssignment(
      workoutId: id,
      programId: 'personal',
      programName: 'Программа с длинным названием для проверки переноса текста',
      workoutNumber: number,
      assignedAt: date,
    ),
  ],
);

Future<GoRouter> _pumpHome(
  WidgetTester tester, {
  required UserRole role,
  required ThemeData theme,
  required _Workouts repository,
  double scale = 1,
  ValueChanged<Object?>? onCreate,
}) async {
  final auth = AuthBloc(authRepository: _Auth());
  final workouts = CrossfitWorkoutCubit(workoutRepository: repository);
  final programs = ProgramCubit(programRepository: _Programs());
  final themeCubit = ThemeCubit(themeService: ThemeService());
  auth.add(
    AuthUserChanged(
      UserProfile(
        id: 'user',
        email: 'test@example.com',
        fullName: 'Анна Длинная Фамилия',
        role: role,
        createdAt: DateTime(2026),
      ),
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => role == UserRole.coach
            ? const CoachHomeScreen()
            : const ClientHomeScreen(),
      ),
      GoRoute(
        path: '/workout/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/coach/workouts/create',
        builder: (_, state) {
          onCreate?.call(state.extra);
          return const Scaffold(body: Text('Create'));
        },
      ),
    ],
  );
  addTearDown(() async {
    router.dispose();
    await auth.close();
    await workouts.close();
    await programs.close();
    await themeCubit.close();
  });
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: workouts),
        BlocProvider.value(value: programs),
        BlocProvider.value(value: themeCubit),
      ],
      child: MaterialApp.router(
        theme: theme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final role in UserRole.values) {
      for (final width in [320.0, 390.0, 1440.0]) {
        testWidgets('home $role ${theme.brightness} fits $width', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _Workouts([
            _workout(
              'today',
              DateTime.now().add(const Duration(minutes: 10)),
              13,
            ),
          ]);
          await _pumpHome(
            tester,
            role: role,
            theme: theme,
            repository: repository,
            scale: width == 320 ? 1.5 : 1,
          );
          expect(find.text('Привет, Анна'), findsOneWidget);
          expect(find.byType(HomeWelcomeBanner), findsOneWidget);
          expect(find.text('Опубликовано'), findsNothing);
          expect(find.text('Legacy title must not appear'), findsNothing);
          expect(find.byTooltip('Выйти'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'athlete hero opens nearest published workout, excluding drafts and past',
    (tester) async {
      final now = DateTime.now();
      final repository = _Workouts([
        _workout('later', now.add(const Duration(hours: 2)), 15),
        _workout('past', now.subtract(const Duration(hours: 1)), 12),
        _workout(
          'draft',
          now.add(const Duration(minutes: 1)),
          14,
          status: WorkoutStatus.draft,
        ),
        _workout('next', now.add(const Duration(hours: 1)), 13),
      ]);
      await _pumpHome(
        tester,
        role: UserRole.client,
        theme: AppTheme.lightTheme,
        repository: repository,
      );
      final banner = tester.widget<HomeWelcomeBanner>(
        find.byType(HomeWelcomeBanner),
      );
      expect(banner.subtitle, contains('Тренировка 13'));
      await tester.tap(find.text('Открыть тренировку'));
      await tester.pumpAndSettle();
      expect(find.text('Opened next'), findsOneWidget);
    },
  );

  testWidgets('empty athlete schedule has no next workout action', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      role: UserRole.client,
      theme: AppTheme.darkTheme,
      repository: _Workouts([]),
    );
    expect(find.text('Открыть тренировку'), findsNothing);
    expect(find.text('Готовы к следующей тренировке?'), findsOneWidget);
  });

  testWidgets('coach calendar keeps creation date and does not refetch', (
    tester,
  ) async {
    Object? createExtra;
    final repository = _Workouts([]);
    await _pumpHome(
      tester,
      role: UserRole.coach,
      theme: AppTheme.darkTheme,
      repository: repository,
      onCreate: (extra) => createExtra = extra,
    );
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final other = DateTime(
      monday.year,
      monday.month,
      monday.day + (today.weekday == 1 ? 1 : 0),
    );
    final cell = find.byKey(
      ValueKey('calendar-day-${other.year}-${other.month}-${other.day}'),
    );
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(repository.reads, 1);
    final button = find.text('Создать тренировку');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect((createExtra as Map<String, dynamic>)['initialScheduledAt'], other);
  });
}
