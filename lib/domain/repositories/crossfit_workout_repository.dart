import '../entities/crossfit_workout.dart';
import '../entities/part_result.dart';

abstract class CrossfitWorkoutRepository {
  Future<List<CrossfitWorkout>> getCoachWorkouts();
  Future<List<CrossfitWorkout>> getClientWorkouts();
  Future<CrossfitWorkout> getWorkoutById(String id);
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  });
  Future<CrossfitWorkout> updateWorkout({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    required WorkoutStatus status,
  });
  Future<CrossfitWorkout> duplicateWorkout(String workoutId);
  Future<void> deleteWorkout(String workoutId);
  Future<void> publishWorkout(String id);
  Future<List<PartResult>> getWorkoutResults(String workoutId);
  Future<List<PartResult>> getUserWorkoutResults(String workoutId);
  Future<List<PartResult>> getClientAllResults();
  Future<PartResult> submitPartResult({
    required String workoutId,
    required String partId,
    required ResultStatus status,
    required String scoreText,
    String note = '',
    int? timeMs,
    int? rounds,
    int? reps,
    double? weightKg,
    double? distanceM,
    int? calories,
  });
  Future<void> deletePartResult(String resultId);
}
