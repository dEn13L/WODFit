import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_logger.dart';
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
  final List<PartResult> userResults;
  final String? message;

  const CrossfitWorkoutListLoaded({
    required this.workouts,
    this.userResults = const [],
    this.message,
  });

  @override
  List<Object?> get props => [workouts, userResults, message];
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
  static const String _tag = 'CrossfitWorkoutCubit';
  final CrossfitWorkoutRepository workoutRepository;

  CrossfitWorkoutCubit({required this.workoutRepository}) : super(const CrossfitWorkoutInitial());

  Future<void> loadCoachWorkouts() async {
    emit(const CrossfitWorkoutLoading());
    try {
      final workouts = await workoutRepository.getCoachWorkouts();
      emit(CrossfitWorkoutListLoaded(workouts: workouts));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadCoachWorkouts failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> loadClientWorkouts() async {
    emit(const CrossfitWorkoutLoading());
    try {
      final workoutsFuture = workoutRepository.getClientWorkouts();
      final resultsFuture = workoutRepository.getClientAllResults();
      final results = await Future.wait([workoutsFuture, resultsFuture]);
      final workouts = results[0] as List<CrossfitWorkout>;
      final userResults = results[1] as List<PartResult>;
      emit(CrossfitWorkoutListLoaded(workouts: workouts, userResults: userResults));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadClientWorkouts failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  }) async {
    try {
      final workout = await workoutRepository.createWorkout(
        title: title,
        description: description,
        scheduledAt: scheduledAt,
        parts: parts,
        programIds: programIds,
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
    } catch (e, st) {
      AppLogger.e(_tag, 'createWorkout failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> updateWorkout({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    required WorkoutStatus status,
  }) async {
    try {
      final workout = await workoutRepository.updateWorkout(
        id: id,
        title: title,
        description: description,
        scheduledAt: scheduledAt,
        parts: parts,
        programIds: programIds,
        status: status,
      );

      final msg = 'Тренировка успешно обновлена';
      if (state is CrossfitWorkoutDetailLoaded) {
        final current = state as CrossfitWorkoutDetailLoaded;
        emit(CrossfitWorkoutDetailLoaded(
          workout: workout,
          userResults: current.userResults,
          allResults: current.allResults,
          message: msg,
        ));
      } else if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(CrossfitWorkoutListLoaded(
          workouts: current.map((w) => w.id == id ? workout : w).toList(),
          message: msg,
        ));
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'updateWorkout failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> duplicateWorkout(String workoutId) async {
    try {
      final duplicated = await workoutRepository.duplicateWorkout(workoutId);
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(CrossfitWorkoutListLoaded(
          workouts: [duplicated, ...current],
          message: 'Копия тренировки успешно создана',
        ));
      } else {
        await loadCoachWorkouts();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'duplicateWorkout failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> deleteWorkout(String workoutId) async {
    try {
      await workoutRepository.deleteWorkout(workoutId);
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(CrossfitWorkoutListLoaded(
          workouts: current.where((w) => w.id != workoutId).toList(),
          message: 'Тренировка удалена',
        ));
      } else {
        await loadCoachWorkouts();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'deleteWorkout failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<void> publishWorkout(String workoutId) async {
    try {
      await workoutRepository.publishWorkout(workoutId);
      await loadWorkoutDetails(workoutId);
    } catch (e, st) {
      AppLogger.e(_tag, 'publishWorkout failed', e, st);
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
    } catch (e, st) {
      AppLogger.e(_tag, 'loadWorkoutDetails failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> submitPartResult({
    required String workoutId,
    required String partId,
    required ResultStatus status,
    required String scoreText,
    WorkoutScoreType? scoreType,
    String note = '',
    int? timeMs,
    int? rounds,
    int? reps,
    double? weightKg,
    double? distanceM,
    int? calories,
  }) async {
    try {
      await workoutRepository.submitPartResult(
        workoutId: workoutId,
        partId: partId,
        status: status,
        scoreText: scoreText,
        scoreType: scoreType,
        note: note,
        timeMs: timeMs,
        rounds: rounds,
        reps: reps,
        weightKg: weightKg,
        distanceM: distanceM,
        calories: calories,
      );

      // Reload details to keep results up to date
      await loadWorkoutDetails(workoutId);
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'submitPartResult failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> deletePartResult({
    required String workoutId,
    required String resultId,
  }) async {
    try {
      await workoutRepository.deletePartResult(resultId);
      await loadWorkoutDetails(workoutId);
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'deletePartResult failed', e, st);
      emit(CrossfitWorkoutError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }
}
