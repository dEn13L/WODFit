import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import 'workout_event.dart';
import 'workout_state.dart';

class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  final WorkoutRepository repository;
  StreamSubscription<int>? _stepSubscription;

  WorkoutBloc({required this.repository}) : super(const WorkoutState()) {
    on<LoadWorkoutsEvent>(_onLoadWorkouts);
    on<StartWorkoutEvent>(_onStartWorkout);
    on<CompleteWorkoutEvent>(_onCompleteWorkout);
    on<StepCountUpdatedEvent>(_onStepCountUpdated);

    _listenToStepSensor();
  }

  void _listenToStepSensor() {
    _stepSubscription = repository.getStepCountStream().listen(
      (steps) {
        add(StepCountUpdatedEvent(steps: steps));
      },
      onError: (_) {},
    );
  }

  Future<void> _onLoadWorkouts(
    LoadWorkoutsEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(state.copyWith(status: WorkoutStatus.loading));
    try {
      final workouts = await repository.getWorkouts();
      int calories = 0;
      int durationSec = 0;
      for (final w in workouts) {
        calories += w.caloriesBurned;
        durationSec += w.duration.inSeconds;
      }

      emit(state.copyWith(
        status: WorkoutStatus.loaded,
        workouts: workouts,
        todayCalories: calories,
        todayDurationMinutes: durationSec ~/ 60,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: WorkoutStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onStartWorkout(
    StartWorkoutEvent event,
    Emitter<WorkoutState> emit,
  ) {
    final workout = Workout(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _getDefaultTitleForType(event.type),
      description: 'Интенсивная тренировка',
      type: event.type,
      duration: Duration.zero,
      caloriesBurned: 0,
      date: DateTime.now(),
    );

    emit(state.copyWith(
      status: WorkoutStatus.inProgress,
      activeWorkout: workout,
    ));
  }

  Future<void> _onCompleteWorkout(
    CompleteWorkoutEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    try {
      await repository.saveWorkout(event.workout);
      final updatedList = [event.workout, ...state.workouts];
      emit(state.copyWith(
        status: WorkoutStatus.loaded,
        workouts: updatedList,
        activeWorkout: null,
        todayCalories: state.todayCalories + event.workout.caloriesBurned,
        todayDurationMinutes:
            state.todayDurationMinutes + (event.workout.duration.inMinutes),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: WorkoutStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onStepCountUpdated(
    StepCountUpdatedEvent event,
    Emitter<WorkoutState> emit,
  ) {
    emit(state.copyWith(todaySteps: event.steps));
  }

  String _getDefaultTitleForType(WorkoutType type) {
    switch (type) {
      case WorkoutType.crossfit:
        return 'CrossFit WOD';
      case WorkoutType.strength:
        return 'Силовая тренировка';
      case WorkoutType.cardio:
        return 'Кардио сессия';
      case WorkoutType.hiit:
        return 'HIIT Интервалы';
      case WorkoutType.mobility:
        return 'Растяжка и мобильность';
    }
  }

  @override
  Future<void> close() {
    _stepSubscription?.cancel();
    return super.close();
  }
}
