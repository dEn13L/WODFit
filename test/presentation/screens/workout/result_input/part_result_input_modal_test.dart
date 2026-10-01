import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'package:wod_fit/presentation/screens/workout/result_input/part_result_input_modal.dart';
import 'package:wod_fit/presentation/screens/workout/result_input/score_input_fields.dart';

import '../../../../support/fake_crossfit_workout_repository.dart';

void main() {
  final now = DateTime(2026);
  const part = WorkoutPart(
    id: 'part',
    workoutId: 'workout',
    title: 'Бег',
  );

  Future<void> pumpModal(
    WidgetTester tester, {
    required PartResult result,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (_) => CrossfitWorkoutCubit(
              workoutRepository: FakeCrossfitWorkoutRepository(),
            ),
            child: PartResultInputModal(
              workoutId: 'workout',
              part: part,
              initialResult: result,
            ),
          ),
        ),
      ),
    );
  }

  PartResult timeResult({ResultStatus status = ResultStatus.done}) =>
      PartResult(
        id: 'result',
        workoutId: 'workout',
        partId: 'part',
        userId: 'user',
        scoreType: WorkoutScoreType.time,
        status: status,
        scoreText: '01:05',
        timeMs: 65000,
        note: 'Ровный темп',
        createdAt: now,
        updatedAt: now,
      );

  testWidgets('prefills MM:SS time form', (tester) async {
    await pumpModal(tester, result: timeResult());

    expect(find.byType(TimeScoreField), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.text('Ровный темп'), findsOneWidget);
  });

  testWidgets('notDone status hides score fields and keeps note', (tester) async {
    await pumpModal(
      tester,
      result: timeResult(status: ResultStatus.notDone),
    );

    expect(find.byType(TimeScoreField), findsNothing);
    expect(
      find.text('Для статуса «Не выполнено» результат не требуется.'),
      findsOneWidget,
    );
    expect(find.text('Ровный темп'), findsOneWidget);
  });
}
