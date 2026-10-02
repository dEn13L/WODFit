import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/data/models/part_result_model.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/part_result.dart';

void main() {
  test('part result survives domain and JSON serialization', () {
    final source = PartResult(
      id: 'result',
      workoutId: 'workout',
      partId: 'part',
      userId: 'user',
      scoreType: WorkoutScoreType.weight,
      status: ResultStatus.scaled,
      scoreText: '82.5 кг (3 повт)',
      note: 'Техника',
      reps: 3,
      weightKg: 82.5,
      createdAt: DateTime.utc(2026, 9, 19, 18),
      updatedAt: DateTime.utc(2026, 9, 19, 19),
      syncStatus: ResultSyncStatus.pending,
    );

    final json = PartResultModel.fromDomain(source).toJson();
    final restored = PartResultModel.fromJson(json).toDomain();

    expect(restored.id, source.id);
    expect(restored.scoreType, WorkoutScoreType.weight);
    expect(restored.status, ResultStatus.scaled);
    expect(restored.scoreText, source.scoreText);
    expect(restored.note, source.note);
    expect(restored.reps, 3);
    expect(restored.weightKg, 82.5);
    expect(restored.createdAt.toUtc(), source.createdAt);
    expect(restored.updatedAt.toUtc(), source.updatedAt);
    expect(restored.syncStatus, ResultSyncStatus.pending);
  });
}
