import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_bloc.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_event.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'package:wod_fit/presentation/screens/workout/results_screen.dart';
import 'package:wod_fit/presentation/screens/workout/workout_detail_screen.dart';

import '../../../support/fake_crossfit_workout_repository.dart';

class _Auth extends Fake implements AuthRepository {
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
}

class _Workouts extends FakeCrossfitWorkoutRepository {
  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async => CrossfitWorkout(
    id: id,
    coachId: 'coach',
    title: '',
    scheduledAt: DateTime(2031, 9, 28, 19, 5),
    status: WorkoutStatus.published,
    createdAt: DateTime(2031),
    updatedAt: DateTime(2031),
    parts: [
      WorkoutPart(id: 'part', workoutId: id, title: 'Бёрпи', sortOrder: 0),
    ],
  );

  @override
  Future<List<UserProfile>> getWorkoutParticipants(String workoutId) async => [
    UserProfile(
      id: 'client',
      email: 'client@example.com',
      fullName: 'Анна',
      role: UserRole.client,
      createdAt: DateTime(2031),
    ),
  ];
}

void main() {
  const date = 'Воскресенье, 28 сентября 2031, 19:05';
  for (final screen in ['coach', 'client', 'results']) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('$screen date header fits $width px at $scale text scale', (
          tester,
        ) async {
          // Client task/action rows have unrelated pre-existing overflows.
          // Load at a safe width, then exercise the real header Card in isolation.
          tester.view.physicalSize = Size(
            screen == 'client' ? 1440 : width,
            1000,
          );
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = AuthBloc(authRepository: _Auth());
          final workouts = CrossfitWorkoutCubit(workoutRepository: _Workouts());
          addTearDown(auth.close);
          addTearDown(workouts.close);
          auth.add(
            AuthUserChanged(
              UserProfile(
                id: screen == 'coach' ? 'coach' : 'client',
                email: 'test@example.com',
                fullName: 'Анна',
                role: screen == 'coach' ? UserRole.coach : UserRole.client,
                createdAt: DateTime(2031),
              ),
            ),
          );
          // Resolve authentication before the screen's initState reads it.
          await tester.pump();
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: auth),
                BlocProvider.value(value: workouts),
              ],
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen == 'results'
                    ? const ResultsScreen(workoutId: 'workout')
                    : const WorkoutDetailScreen(workoutId: 'workout'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (screen == 'client') {
            final card = tester.widget<Card>(
              find
                  .ancestor(
                    of: find.textContaining(date),
                    matching: find.byType(Card),
                  )
                  .first,
            );
            tester.view.physicalSize = Size(width, 1000);
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.darkTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: card,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }
          final header = find.textContaining(date);
          expect(header, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(header);
          expect(paragraph.didExceedMaxLines, isFalse);
          final rect = tester.getRect(header);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
