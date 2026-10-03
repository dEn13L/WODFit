import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../../domain/entities/user_profile.dart';
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
  final List<UserProfile> participants;
  final String? message;

  const CrossfitWorkoutDetailLoaded({
    required this.workout,
    required this.userResults,
    required this.allResults,
    required this.participants,
    this.message,
  });

  @override
  List<Object?> get props => [
    workout,
    userResults,
    allResults,
    participants,
    message,
  ];
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
  int _loadRequest = 0;
  bool _mutating = false;
  ResultSyncStatus lastMutationSyncStatus = ResultSyncStatus.synced;

  CrossfitWorkoutCubit({required this.workoutRepository})
    : super(const CrossfitWorkoutInitial());

  void applySavedWorkout(CrossfitWorkout workout) {
    if (isClosed) return;
    _loadRequest++;
    final current = state;
    if (current is CrossfitWorkoutDetailLoaded &&
        current.workout.id == workout.id) {
      final partIds = workout.parts.map((part) => part.id).toSet();
      emit(
        CrossfitWorkoutDetailLoaded(
          workout: workout,
          userResults: current.userResults
              .where((r) => partIds.contains(r.partId))
              .toList(),
          allResults: current.allResults
              .where((r) => partIds.contains(r.partId))
              .toList(),
          participants: current.participants,
        ),
      );
    } else if (current is CrossfitWorkoutListLoaded) {
      final workouts =
          current.workouts.where((w) => w.id != workout.id).toList()
            ..add(workout);
      workouts.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      emit(
        CrossfitWorkoutListLoaded(
          workouts: workouts,
          userResults: current.userResults,
        ),
      );
    }
  }

  Future<void> loadCoachWorkouts() async {
    final request = ++_loadRequest;
    emit(const CrossfitWorkoutLoading());
    try {
      final workouts = await workoutRepository.getCoachWorkouts();
      if (isClosed || request != _loadRequest) return;
      emit(CrossfitWorkoutListLoaded(workouts: workouts));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadCoachWorkouts failed', e, st);
      if (isClosed || request != _loadRequest) return;
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
    }
  }

  Future<void> loadClientWorkouts() async {
    final request = ++_loadRequest;
    emit(const CrossfitWorkoutLoading());
    try {
      final workoutsFuture = workoutRepository.getClientWorkouts();
      final resultsFuture = workoutRepository.getClientAllResults();
      final results = await Future.wait([workoutsFuture, resultsFuture]);
      final workouts = results[0] as List<CrossfitWorkout>;
      final userResults = results[1] as List<PartResult>;
      if (isClosed || request != _loadRequest) return;
      emit(
        CrossfitWorkoutListLoaded(workouts: workouts, userResults: userResults),
      );
    } catch (e, st) {
      AppLogger.e(_tag, 'loadClientWorkouts failed', e, st);
      if (isClosed || request != _loadRequest) return;
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
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

      final msg = publish
          ? 'Тренировка опубликована'
          : 'Черновик тренировки сохранен';
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(
          CrossfitWorkoutListLoaded(
            workouts: [workout, ...current],
            message: msg,
          ),
        );
      } else {
        emit(CrossfitWorkoutListLoaded(workouts: [workout], message: msg));
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'createWorkout failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
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
        emit(
          CrossfitWorkoutDetailLoaded(
            workout: workout,
            userResults: current.userResults,
            allResults: current.allResults,
            participants: current.participants,
            message: msg,
          ),
        );
      } else if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(
          CrossfitWorkoutListLoaded(
            workouts: current.map((w) => w.id == id ? workout : w).toList(),
            message: msg,
          ),
        );
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'updateWorkout failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
      return false;
    }
  }

  Future<bool> duplicateWorkout(String workoutId) async {
    if (_mutating) return false;
    _mutating = true;
    if (state is CrossfitWorkoutDetailLoaded) {
      _detailMessage(state as CrossfitWorkoutDetailLoaded, null);
    }
    final previous = state;
    final request = _loadRequest;
    try {
      final duplicated = await workoutRepository.duplicateWorkout(workoutId);
      if (isClosed || request != _loadRequest) return true;
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(
          CrossfitWorkoutListLoaded(
            workouts: [duplicated, ...current],
            message: 'Копия тренировки успешно создана',
          ),
        );
      } else if (state is CrossfitWorkoutDetailLoaded) {
        _detailMessage(
          state as CrossfitWorkoutDetailLoaded,
          'Копия тренировки успешно создана',
        );
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'duplicateWorkout failed: workoutId=$workoutId', e, st);
      if (isClosed || request != _loadRequest) return false;
      if (previous is CrossfitWorkoutDetailLoaded && state == previous) {
        _detailMessage(previous, AppLogger.userMessage(e));
      } else {
        emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
      }
      return false;
    } finally {
      _mutating = false;
    }
  }

  void _detailMessage(CrossfitWorkoutDetailLoaded current, String? message) {
    emit(
      CrossfitWorkoutDetailLoaded(
        workout: current.workout,
        userResults: current.userResults,
        allResults: current.allResults,
        participants: current.participants,
        message: message,
      ),
    );
  }

  Future<bool> deleteWorkout(String workoutId) async {
    if (_mutating) return false;
    _mutating = true;
    if (state is CrossfitWorkoutDetailLoaded) {
      _detailMessage(state as CrossfitWorkoutDetailLoaded, null);
    }
    final previous = state;
    final request = _loadRequest;
    try {
      await workoutRepository.deleteWorkout(workoutId);
      if (isClosed || request != _loadRequest) return true;
      _loadRequest++;
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(
          CrossfitWorkoutListLoaded(
            workouts: current.where((w) => w.id != workoutId).toList(),
            message: 'Тренировка удалена',
          ),
        );
      } else {
        emit(
          const CrossfitWorkoutListLoaded(
            workouts: [],
            message: 'Тренировка удалена',
          ),
        );
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'deleteWorkout failed: workoutId=$workoutId', e, st);
      if (isClosed || request != _loadRequest) return false;
      if (previous is CrossfitWorkoutDetailLoaded && state == previous) {
        _detailMessage(previous, AppLogger.userMessage(e));
      } else {
        emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
      }
      return false;
    } finally {
      _mutating = false;
    }
  }

  Future<void> publishWorkout(String workoutId) async {
    try {
      await workoutRepository.publishWorkout(workoutId);
      await loadWorkoutDetails(workoutId);
    } catch (e, st) {
      AppLogger.e(_tag, 'publishWorkout failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
    }
  }

  Future<void> loadWorkoutDetails(String workoutId) async {
    final request = ++_loadRequest;
    emit(const CrossfitWorkoutLoading());
    try {
      final workout = await workoutRepository.getWorkoutById(workoutId);
      final userResults = await workoutRepository.getUserWorkoutResults(
        workoutId,
      );
      final allResults = await workoutRepository.getWorkoutResults(workoutId);
      final participants = await workoutRepository.getWorkoutParticipants(
        workoutId,
      );

      if (isClosed || request != _loadRequest) return;
      emit(
        CrossfitWorkoutDetailLoaded(
          workout: workout,
          userResults: userResults,
          allResults: allResults,
          participants: participants,
        ),
      );
    } catch (e, st) {
      AppLogger.e(
        _tag,
        'loadWorkoutDetails failed: workoutId=$workoutId',
        e,
        st,
      );
      if (isClosed || request != _loadRequest) return;
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
    }
  }

  Future<void> markWorkoutViewed(String workoutId) async {
    try {
      await workoutRepository.markWorkoutViewed(workoutId);
    } catch (e, st) {
      AppLogger.e(_tag, 'markWorkoutViewed failed', e, st);
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
      final result = await workoutRepository.submitPartResult(
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

      lastMutationSyncStatus = result.syncStatus;
      final current = state;
      if (current is CrossfitWorkoutDetailLoaded) {
        final userResults =
            current.userResults
                .where((item) => item.partId != result.partId)
                .toList()
              ..add(result);
        final allResults =
            current.allResults
                .where(
                  (item) =>
                      !(item.partId == result.partId &&
                          item.userId == result.userId),
                )
                .toList()
              ..add(result);
        emit(
          CrossfitWorkoutDetailLoaded(
            workout: current.workout,
            userResults: userResults,
            allResults: allResults,
            participants: current.participants,
          ),
        );
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'submitPartResult failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
      return false;
    }
  }

  Future<bool> deletePartResult({
    required String workoutId,
    required String resultId,
  }) async {
    try {
      lastMutationSyncStatus = await workoutRepository.deletePartResult(
        resultId,
      );
      final current = state;
      if (current is CrossfitWorkoutDetailLoaded) {
        emit(
          CrossfitWorkoutDetailLoaded(
            workout: current.workout,
            userResults: current.userResults
                .where((item) => item.id != resultId)
                .toList(),
            allResults: current.allResults
                .where((item) => item.id != resultId)
                .toList(),
            participants: current.participants,
          ),
        );
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'deletePartResult failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
      return false;
    }
  }
}
