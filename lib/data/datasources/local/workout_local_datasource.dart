import 'package:hive_flutter/hive_flutter.dart';
import '../../models/workout_dto.dart';

abstract class WorkoutLocalDataSource {
  Future<void> init();
  Future<List<WorkoutDto>> getAllWorkouts();
  Future<void> saveWorkout(WorkoutDto workout);
  Future<void> deleteWorkout(String id);
}

class WorkoutLocalDataSourceImpl implements WorkoutLocalDataSource {
  static const String boxName = 'workouts_box';
  Box? _box;

  @override
  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      _box = await Hive.openBox(boxName);
    } else {
      _box = Hive.box(boxName);
    }
  }

  Box get box {
    return _box ?? Hive.box(boxName);
  }

  @override
  Future<List<WorkoutDto>> getAllWorkouts() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    final rawList = box.values;
    return rawList
        .map((item) => WorkoutDto.fromMap(Map<dynamic, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<void> saveWorkout(WorkoutDto workout) async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    await box.put(workout.id, workout.toMap());
  }

  @override
  Future<void> deleteWorkout(String id) async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    await box.delete(id);
  }
}
