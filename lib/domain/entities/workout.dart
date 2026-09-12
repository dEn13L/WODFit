enum WorkoutType {
  crossfit,
  strength,
  cardio,
  hiit,
  mobility,
}

class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double? weightKg;

  const Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    this.weightKg,
  });
}

class Workout {
  final String id;
  final String title;
  final String description;
  final WorkoutType type;
  final Duration duration;
  final int caloriesBurned;
  final DateTime date;
  final List<Exercise> exercises;

  const Workout({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.duration,
    required this.caloriesBurned,
    required this.date,
    this.exercises = const [],
  });
}
