import '../../domain/entities/workout.dart';

abstract class WorkoutEvent {
  const WorkoutEvent();
}

class LoadWorkoutsEvent extends WorkoutEvent {
  const LoadWorkoutsEvent();
}

class StartWorkoutEvent extends WorkoutEvent {
  final WorkoutType type;
  const StartWorkoutEvent({required this.type});
}

class CompleteWorkoutEvent extends WorkoutEvent {
  final Workout workout;
  const CompleteWorkoutEvent({required this.workout});
}

class StepCountUpdatedEvent extends WorkoutEvent {
  final int steps;
  const StepCountUpdatedEvent({required this.steps});
}
