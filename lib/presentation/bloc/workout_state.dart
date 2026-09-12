import '../../domain/entities/workout.dart';

enum WorkoutStatus { initial, loading, loaded, inProgress, error }

class WorkoutState {
  final WorkoutStatus status;
  final List<Workout> workouts;
  final Workout? activeWorkout;
  final int todaySteps;
  final int todayCalories;
  final int todayDurationMinutes;
  final String? errorMessage;

  const WorkoutState({
    this.status = WorkoutStatus.initial,
    this.workouts = const [],
    this.activeWorkout,
    this.todaySteps = 0,
    this.todayCalories = 0,
    this.todayDurationMinutes = 0,
    this.errorMessage,
  });

  WorkoutState copyWith({
    WorkoutStatus? status,
    List<Workout>? workouts,
    Workout? activeWorkout,
    int? todaySteps,
    int? todayCalories,
    int? todayDurationMinutes,
    String? errorMessage,
  }) {
    return WorkoutState(
      status: status ?? this.status,
      workouts: workouts ?? this.workouts,
      activeWorkout: activeWorkout ?? this.activeWorkout,
      todaySteps: todaySteps ?? this.todaySteps,
      todayCalories: todayCalories ?? this.todayCalories,
      todayDurationMinutes: todayDurationMinutes ?? this.todayDurationMinutes,
      errorMessage: errorMessage,
    );
  }
}
