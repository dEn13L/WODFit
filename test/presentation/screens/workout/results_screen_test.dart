import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'package:wod_fit/presentation/screens/workout/results_screen.dart';

import '../../../support/fake_crossfit_workout_repository.dart';

class _ResultsTestCubit extends CrossfitWorkoutCubit {
  final CrossfitWorkoutState nextState;
  int loadCount = 0;

  _ResultsTestCubit(this.nextState)
      : super(workoutRepository: FakeCrossfitWorkoutRepository());

  @override
  Future<void> loadWorkoutDetails(String workoutId) async {
    loadCount++;
    emit(nextState);
  }
}

void main() {
  final now = DateTime(2026, 9, 19, 19);

  CrossfitWorkout workout({List<WorkoutPart> parts = const []}) =>
      CrossfitWorkout(
        id: 'workout',
        coachId: 'coach',
        title: '',
        scheduledAt: now,
        createdAt: now,
        updatedAt: now,
        parts: parts,
      );

  UserProfile participant(String id, String name) => UserProfile(
        id: id,
        email: '$id@example.com',
        fullName: name,
        role: UserRole.client,
        createdAt: now,
      );

  Future<_ResultsTestCubit> pumpScreen(
    WidgetTester tester,
    CrossfitWorkoutState state, {
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    final cubit = _ResultsTestCubit(state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CrossfitWorkoutCubit>.value(
          value: cubit,
          child: const ResultsScreen(workoutId: 'workout'),
        ),
      ),
    );
    await tester.pump();
    return cubit;
  }

  testWidgets('shows empty workout state', (tester) async {
    await pumpScreen(
      tester,
      CrossfitWorkoutDetailLoaded(
        workout: workout(),
        userResults: const [],
        allResults: const [],
        participants: [participant('anna', 'Анна')],
      ),
    );

    expect(find.text('В тренировке нет заданий'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
  });

  testWidgets('filters participants by completion', (tester) async {
    final part = WorkoutPart(
      id: 'part',
      workoutId: 'workout',
      title: 'Бёрпи',
      sortOrder: 0,
    );
    final result = PartResult(
      id: 'result',
      workoutId: 'workout',
      partId: 'part',
      userId: 'anna',
      scoreType: WorkoutScoreType.reps,
      reps: 20,
      createdAt: now,
      updatedAt: now,
    );
    await pumpScreen(
      tester,
      CrossfitWorkoutDetailLoaded(
        workout: workout(parts: [part]),
        userResults: [result],
        allResults: [result],
        participants: [
          participant('anna', 'Анна'),
          participant('boris', 'Борис'),
        ],
      ),
    );

    expect(find.text('Анна'), findsOneWidget);
    expect(find.text('Борис'), findsOneWidget);
    await tester.tap(find.text('Не заполнили').last);
    await tester.pump();

    expect(find.text('Анна'), findsNothing);
    expect(find.text('Борис'), findsOneWidget);
  });

  testWidgets('shows error and retries loading', (tester) async {
    final cubit = await pumpScreen(
      tester,
      const CrossfitWorkoutError('Не удалось загрузить результаты'),
    );

    expect(find.text('Не удалось загрузить результаты'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(cubit.loadCount, 1);

    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(cubit.loadCount, 2);
  });

  for (final width in [320.0, 375.0, 430.0, 1000.0, 1200.0, 1440.0]) {
    testWidgets('handles long content without overflow at ${width.toInt()} px', (tester) async {
      final part = WorkoutPart(
        id: 'part',
        workoutId: 'workout',
        title: 'Очень длинное название задания с дополнительными уточнениями для атлетов',
        sortOrder: 0,
      );
      await pumpScreen(
        tester,
        CrossfitWorkoutDetailLoaded(
          workout: workout(parts: [part]),
          userResults: const [],
          allResults: const [],
          participants: [
            participant('anna', 'Очень длинное имя участника программы без сокращений'),
          ],
        ),
        size: Size(width, 900),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Очень длинное имя'), findsOneWidget);
    });
  }
}
