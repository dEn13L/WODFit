import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../../domain/repositories/crossfit_workout_repository.dart';

abstract class CrossfitWorkoutState extends Equatable {
  const CrossfitWorkoutState();

  @override
  List<Object?> get props => [];
}

class CrossfitWorkoutInitial extends CrossfitWorkoutState {
  const CrossfitWorkoutInitial();
}

class CrossfitWorkoutLoading extends CrossfitWorkoutState {
  const CrossfitWorkoutLoading();
}

class CrossfitWorkoutListLoaded extends CrossfitWorkoutState {
  final List<CrossfitWorkout> workouts;
  final String? message;

  const CrossfitWorkoutListLoaded({
    required this.workouts,
    this.message,
  });

  @override
  List<Object?> get props => [workouts, message];
}

class CrossfitWorkoutDetailLoaded extends CrossfitWorkoutState {
  final CrossfitWorkout workout;
  final List<PartResult> userResults;
  final List<PartResult> allResults;
  final String? message;

  const CrossfitWorkoutDetailLoaded({
    required this.workout,
    required this.userResults,
    required this.allResults,
    this.message,
  });

  @override
  List<Object?> get props => [workout, userResults, allResults, message];
}

class CrossfitWorkoutError extends CrossfitWorkoutState {
  final String message;

  const CrossfitWorkoutError(this.message);

  @override
  List<Object?> get props => [message];
}

class CrossfitWorkoutCubit extends Cubit<CrossfitWorkoutState> {
  final CrossfitWorkoutRepository workoutRepository;

  CrossfitWorkoutCubit({required this.workoutRepository}) : super(const CrossfitWorkoutInitial());

  Future<void> loadCoachWorkouts() async {
    emit(const CrossfitWorkoutLoading());
    try {
      final workouts = await workoutRepository.getCoachWorkouts();
      emit(CrossfitWorkoutListLoaded(workouts: workouts));
    } catch (e) {
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> loadClientWorkouts() async {
    emit(const CrossfitWorkoutLoading());
    try {
      final workouts = await workoutRepository.getClientWorkouts();
      emit(CrossfitWorkoutListLoaded(workouts: workouts));
    } catch (e) {
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> groupIds,
    bool publish = false,
  }) async {
    try {
      final workout = await workoutRepository.createWorkout(
        title: title,
        description: description,
        scheduledAt: scheduledAt,
        parts: parts,
        groupIds: groupIds,
        publish: publish,
      );

      final msg = publish ? 'Тренировка опубликована' : 'Черновик тренировки сохранен';
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(CrossfitWorkoutListLoaded(
          workouts: [workout, ...current],
          message: msg,
        ));
      } else {
        emit(CrossfitWorkoutListLoaded(
          workouts: [workout],
          message: msg,
        ));
      }
      return true;
    } catch (e) {
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<void> publishWorkout(String workoutId) async {
    try {
      await workoutRepository.publishWorkout(workoutId);
      await loadWorkoutDetails(workoutId);
    } catch (e) {
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> loadWorkoutDetails(String workoutId) async {
    emit(const CrossfitWorkoutLoading());
    try {
      final workout = await workoutRepository.getWorkoutById(workoutId);
      final userResults = await workoutRepository.getUserWorkoutResults(workoutId);
      final allResults = await workoutRepository.getWorkoutResults(workoutId);

      emit(CrossfitWorkoutDetailLoaded(
        workout: workout,
        userResults: userResults,
        allResults: allResults,
      ));
    } catch (e) {
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> submitPartResult({
    required String workoutId,
    required String partId,
    required ResultStatus status,
    required String scoreText,
    String note = '',
    int? timeMs,
    int? rounds,
    int? reps,
    double? weightKg,
  }) async {
    try {
      await workoutRepository.submitPartResult(
        workoutId: workoutId,
        partId: partId,
        status: status,
        scoreText: scoreText,
        note: note,
        timeMs: timeMs,
        rounds: rounds,
        reps: reps,
        weightKg: weightKg,
      );

      // Reload details to keep results up to date
      await loadWorkoutDetails(workoutId);
      return true;
    } catch (e) {
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }
}
