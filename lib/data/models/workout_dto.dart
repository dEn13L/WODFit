import '../../domain/entities/workout.dart';

class ExerciseDto {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double? weightKg;

  ExerciseDto({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    this.weightKg,
  });

  factory ExerciseDto.fromDomain(Exercise exercise) {
    return ExerciseDto(
      id: exercise.id,
      name: exercise.name,
      sets: exercise.sets,
      reps: exercise.reps,
      weightKg: exercise.weightKg,
    );
  }

  Exercise toDomain() {
    return Exercise(
      id: id,
      name: name,
      sets: sets,
      reps: reps,
      weightKg: weightKg,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weightKg': weightKg,
    };
  }

  factory ExerciseDto.fromMap(Map<dynamic, dynamic> map) {
    return ExerciseDto(
      id: map['id'] as String,
      name: map['name'] as String,
      sets: (map['sets'] as num).toInt(),
      reps: (map['reps'] as num).toInt(),
      weightKg: map['weightKg'] != null ? (map['weightKg'] as num).toDouble() : null,
    );
  }
}

class WorkoutDto {
  final String id;
  final String title;
  final String description;
  final String type;
  final int durationSeconds;
  final int caloriesBurned;
  final String dateIso;
  final List<ExerciseDto> exercises;

  WorkoutDto({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.dateIso,
    required this.exercises,
  });

  factory WorkoutDto.fromDomain(Workout workout) {
    return WorkoutDto(
      id: workout.id,
      title: workout.title,
      description: workout.description,
      type: workout.type.name,
      durationSeconds: workout.duration.inSeconds,
      caloriesBurned: workout.caloriesBurned,
      dateIso: workout.date.toUtc().toIso8601String(),
      exercises: workout.exercises.map((e) => ExerciseDto.fromDomain(e)).toList(),
    );
  }

  Workout toDomain() {
    return Workout(
      id: id,
      title: title,
      description: description,
      type: WorkoutType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => WorkoutType.crossfit,
      ),
      duration: Duration(seconds: durationSeconds),
      caloriesBurned: caloriesBurned,
      date: (DateTime.tryParse(dateIso) ?? DateTime.now()).toLocal(),
      exercises: exercises.map((e) => e.toDomain()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'durationSeconds': durationSeconds,
      'caloriesBurned': caloriesBurned,
      'dateIso': dateIso,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }

  factory WorkoutDto.fromMap(Map<dynamic, dynamic> map) {
    return WorkoutDto(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
      durationSeconds: (map['durationSeconds'] as num).toInt(),
      caloriesBurned: (map['caloriesBurned'] as num).toInt(),
      dateIso: map['dateIso'] as String,
      exercises: (map['exercises'] as List<dynamic>?)
              ?.map((e) => ExerciseDto.fromMap(e as Map<dynamic, dynamic>))
              .toList() ??
          [],
    );
  }
}
