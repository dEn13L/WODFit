import '../entities/workout.dart';

abstract class WorkoutRepository {
  Future<List<Workout>> getWorkouts();
  Future<void> saveWorkout(Workout workout);
  Future<void> deleteWorkout(String id);
  Stream<int> getStepCountStream();
}
