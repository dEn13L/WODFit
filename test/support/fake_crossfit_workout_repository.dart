import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';

class FakeCrossfitWorkoutRepository implements CrossfitWorkoutRepository {
  @override
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<ResultSyncStatus> deletePartResult(String resultId) async => ResultSyncStatus.synced;

  @override
  Future<void> deleteWorkout(String workoutId) async {}

  @override
  Future<CrossfitWorkout> duplicateWorkout(String workoutId) =>
      throw UnimplementedError();

  @override
  Future<List<CrossfitWorkout>> getClientWorkouts() async => [];

  @override
  Future<List<PartResult>> getClientAllResults() async => [];

  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async => [];

  @override
  Future<List<PartResult>> getUserWorkoutResults(String workoutId) async => [];

  @override
  Future<CrossfitWorkout> getWorkoutById(String id) =>
      throw UnimplementedError();

  @override
  Future<List<UserProfile>> getWorkoutParticipants(String workoutId) async => [];

  @override
  Future<List<PartResult>> getWorkoutResults(String workoutId) async => [];

  @override
  Future<void> publishWorkout(String id) async {}

  @override
  Future<void> markWorkoutViewed(String workoutId) async {}

  @override
  Future<PartResult> submitPartResult({
    required String workoutId,
    required String partId,
    required ResultStatus status,
    required String scoreText,
    WorkoutScoreType? scoreType,
    String note = '',
    int? timeMs,
    int? rounds,
    int? reps,
    double? weightKg,
    double? distanceM,
    int? calories,
  }) =>
      throw UnimplementedError();

  @override
  Future<CrossfitWorkout> updateWorkout({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    required WorkoutStatus status,
  }) =>
      throw UnimplementedError();
}
