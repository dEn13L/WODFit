import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/local/workout_local_datasource.dart';
import '../datasources/sensors/sensor_datasource.dart';
import '../models/workout_dto.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutLocalDataSource localDataSource;
  final SensorDataSource sensorDataSource;

  WorkoutRepositoryImpl({
    required this.localDataSource,
    required this.sensorDataSource,
  });

  @override
  Future<List<Workout>> getWorkouts() async {
    final dtos = await localDataSource.getAllWorkouts();
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<void> saveWorkout(Workout workout) async {
    final dto = WorkoutDto.fromDomain(workout);
    await localDataSource.saveWorkout(dto);
  }

  @override
  Future<void> deleteWorkout(String id) async {
    await localDataSource.deleteWorkout(id);
  }

  @override
  Stream<int> getStepCountStream() {
    return sensorDataSource.stepCountStream;
  }
}
