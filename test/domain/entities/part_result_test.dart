import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/part_result.dart';

void main() {
  final now = DateTime(2026);

  PartResult result({
    WorkoutScoreType? type,
    ResultStatus status = ResultStatus.done,
    String text = '',
    int? timeMs,
    int? rounds,
    int? reps,
    double? weight,
    double? distance,
    int? calories,
  }) =>
      PartResult(
        id: 'result',
        workoutId: 'workout',
        partId: 'part',
        userId: 'user',
        scoreType: type,
        status: status,
        scoreText: text,
        timeMs: timeMs,
        rounds: rounds,
        reps: reps,
        weightKg: weight,
        distanceM: distance,
        calories: calories,
        createdAt: now,
        updatedAt: now,
      );

  test('formattedScore formats every score type', () {
    expect(result(type: WorkoutScoreType.none).formattedScore, 'Выполнено');
    expect(result(type: WorkoutScoreType.text, text: 'AMRAP 7').formattedScore, 'AMRAP 7');
    expect(result(type: WorkoutScoreType.time, timeMs: 65000).formattedScore, '01:05');
    expect(result(type: WorkoutScoreType.roundsReps, rounds: 5, reps: 12).formattedScore, '5 рд + 12 повт');
    expect(result(type: WorkoutScoreType.weight, weight: 82.5, reps: 3).formattedScore, '82.5 кг (3 повт)');
    expect(result(type: WorkoutScoreType.reps, reps: 150).formattedScore, '150 повт');
    expect(result(type: WorkoutScoreType.distance, distance: 2000).formattedScore, '2000 м');
    expect(result(type: WorkoutScoreType.calories, calories: 35).formattedScore, '35 кал');
  });

  test('formattedScore uses status for an uncompleted status-only result', () {
    expect(
      result(type: WorkoutScoreType.none, status: ResultStatus.notDone).formattedScore,
      'Не выполнено',
    );
  });
}
