import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/exceptions/workout_unavailable_exception.dart';
import '../../state/session_data_cache.dart';
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
  final String? refreshError;

  const CrossfitWorkoutListLoaded({
    required this.workouts,
    this.userResults = const [],
    this.message,
    this.refreshError,
  });

  @override
  List<Object?> get props => [workouts, userResults, message, refreshError];
}

class CrossfitWorkoutDetailLoaded extends CrossfitWorkoutState {
  final CrossfitWorkout workout;
  final List<PartResult> userResults;
  final List<PartResult> allResults;
  final List<UserProfile> participants;
  final String? message;
  final String? refreshError;

  const CrossfitWorkoutDetailLoaded({
    required this.workout,
    required this.userResults,
    required this.allResults,
    required this.participants,
    this.message,
    this.refreshError,
  });

  @override
  List<Object?> get props => [
    workout,
    userResults,
    allResults,
    participants,
    message,
    refreshError,
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
  static const coachListKey = 'coach-workouts';
  static const clientListKey = 'client-workouts';
  static String detailKey(String id) => 'workout:$id';
  final SessionDataCache cache;
  final bool _ownsCache;
  late final StreamSubscription<String> _cacheSubscription;
  String? _activeKey;

  ResultSyncStatus lastMutationSyncStatus = ResultSyncStatus.synced;

  CrossfitWorkoutCubit({
    required this.workoutRepository,
    SessionDataCache? cache,
  }) : cache = cache ?? SessionDataCache(),
       _ownsCache = cache == null,
       super(const CrossfitWorkoutInitial()) {
    _cacheSubscription = this.cache.changes.listen((key) {
      if (isClosed) return;
      if (key == '*') {
        _loadRequest++;
        super.emit(const CrossfitWorkoutInitial());
      } else if (key == _activeKey) {
        final value = this.cache.read<CrossfitWorkoutState>(key);
        if (value != null) {
          super.emit(value);
        } else if (key.startsWith('workout:') && state is CrossfitWorkoutDetailLoaded) {
          super.emit(CrossfitWorkoutError(const WorkoutUnavailableException().message));
        }
      }
    });
  }

  @override
  void emit(CrossfitWorkoutState state) {
    if (isClosed) return;
    if (state is CrossfitWorkoutDetailLoaded) {
      cache.put(detailKey(state.workout.id), CrossfitWorkoutDetailLoaded(
        workout: state.workout,
        userResults: state.userResults,
        allResults: state.allResults,
        participants: state.participants,
      ));
    } else if (state is CrossfitWorkoutListLoaded &&
        (_activeKey == coachListKey || _activeKey == clientListKey)) {
      cache.put(_activeKey!, CrossfitWorkoutListLoaded(
        workouts: state.workouts,
        userResults: state.userResults,
      ));
    }
    super.emit(state);
  }

  @override
  Future<void> close() async {
    await _cacheSubscription.cancel();
    if (_ownsCache) await cache.close();
    await super.close();
  }

  void _updateCachedLists(CrossfitWorkout workout) {
    for (final key in [coachListKey, clientListKey]) {
      final list = cache.read<CrossfitWorkoutListLoaded>(key);
      if (list == null) continue;
      // Только список тренера может получать новую тренировку из формы.
      final exists = list.workouts.any((w) => w.id == workout.id);
      if (key == clientListKey && !exists) continue;
      final workouts = list.workouts.where((w) => w.id != workout.id).toList()
        ..add(workout);
      workouts.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      cache.put(key, CrossfitWorkoutListLoaded(
        workouts: workouts,
        userResults: list.userResults,
      ));
    }
  }

  void _removeCachedWorkout(String workoutId) {
    cache.remove(detailKey(workoutId));
    for (final key in [coachListKey, clientListKey]) {
      final list = cache.read<CrossfitWorkoutListLoaded>(key);
      if (list != null) {
        cache.put(key, CrossfitWorkoutListLoaded(
          workouts: list.workouts.where((w) => w.id != workoutId).toList(),
          userResults: list.userResults.where((r) => r.workoutId != workoutId).toList(),
        ));
      }
    }
  }

  void applySavedWorkout(CrossfitWorkout workout) {
    if (isClosed) return;
    _loadRequest++;
    _updateCachedLists(workout);
    final current = cache.read<CrossfitWorkoutDetailLoaded>(detailKey(workout.id));
    if (current != null) {
      final partIds = workout.parts.map((part) => part.id).toSet();
      cache.put(detailKey(workout.id), CrossfitWorkoutDetailLoaded(
        workout: workout,
        userResults: current.userResults.where((r) => partIds.contains(r.partId)).toList(),
        allResults: current.allResults.where((r) => partIds.contains(r.partId)).toList(),
        participants: current.participants,
      ));
    }
  }

  Future<void> _load(String key, Future<CrossfitWorkoutState> Function() fetch) async {
    final request = ++_loadRequest;
    final generation = cache.generation;
    _activeKey = key;
    final cached = cache.read<CrossfitWorkoutState>(key);
    super.emit(cached ?? const CrossfitWorkoutLoading());
    try {
      final value = await cache.refresh(key, fetch);
      if (isClosed || request != _loadRequest || generation != cache.generation) return;
      super.emit(value);
    } catch (e, st) {
      if (e is CacheSessionChanged || isClosed || request != _loadRequest || generation != cache.generation) return;
      AppLogger.e(_tag, 'Refresh failed: $key', e, st);
      if (e is WorkoutUnavailableException) {
        _removeCachedWorkout(key.substring('workout:'.length));
        super.emit(CrossfitWorkoutError(e.message));
        return;
      }
      final previous = cache.read<CrossfitWorkoutState>(key);
      final message = AppLogger.userMessage(e);
      if (previous is CrossfitWorkoutListLoaded) {
        super.emit(CrossfitWorkoutListLoaded(
          workouts: previous.workouts,
          userResults: previous.userResults,
          refreshError: message,
        ));
      } else if (previous is CrossfitWorkoutDetailLoaded) {
        super.emit(CrossfitWorkoutDetailLoaded(
          workout: previous.workout,
          userResults: previous.userResults,
          allResults: previous.allResults,
          participants: previous.participants,
          refreshError: message,
        ));
      } else {
        super.emit(CrossfitWorkoutError(message));
      }
    }
  }

  Future<void> loadCoachWorkouts() => _load(coachListKey, () async =>
    CrossfitWorkoutListLoaded(workouts: await workoutRepository.getCoachWorkouts()));

  Future<void> loadClientWorkouts() => _load(clientListKey, () async {
    final values = await Future.wait<Object>([
      workoutRepository.getClientWorkouts(),
      workoutRepository.getClientAllResults(),
    ]);
    return CrossfitWorkoutListLoaded(
      workouts: values[0] as List<CrossfitWorkout>,
      userResults: values[1] as List<PartResult>,
    );
  });

  Future<bool> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  }) async {
    final generation = cache.generation;
    try {
      final workout = await workoutRepository.createWorkout(
        title: title,
        description: description,
        scheduledAt: scheduledAt,
        parts: parts,
        programIds: programIds,
        publish: publish,
      );

      if (isClosed || generation != cache.generation) return true;
      applySavedWorkout(workout);
      final msg = publish
          ? 'Тренировка опубликована'
          : 'Черновик тренировки сохранен';
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(
          CrossfitWorkoutListLoaded(
            workouts: [workout, ...current.where((w) => w.id != workout.id)],
            message: msg,
          ),
        );
      } else {
        emit(CrossfitWorkoutListLoaded(workouts: [workout], message: msg));
      }
      return true;
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return false;
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
    final generation = cache.generation;
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

      if (isClosed || generation != cache.generation) return true;
      applySavedWorkout(workout);
      final msg = 'Тренировка успешно обновлена';
      if (state is CrossfitWorkoutDetailLoaded && (state as CrossfitWorkoutDetailLoaded).workout.id == id) {
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
      if (isClosed || generation != cache.generation) return false;
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
    final generation = cache.generation;
    try {
      final duplicated = await workoutRepository.duplicateWorkout(workoutId);
      if (isClosed || generation != cache.generation) return true;
      _updateCachedLists(duplicated);
      if (request != _loadRequest) return true;
      if (state is CrossfitWorkoutListLoaded) {
        final current = (state as CrossfitWorkoutListLoaded).workouts;
        emit(
          CrossfitWorkoutListLoaded(
            workouts: [duplicated, ...current.where((w) => w.id != duplicated.id)],
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
      if (isClosed || generation != cache.generation) return false;
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
    final generation = cache.generation;
    try {
      await workoutRepository.deleteWorkout(workoutId);
      if (isClosed || generation != cache.generation) return true;
      _removeCachedWorkout(workoutId);
      if (request != _loadRequest) return true;
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
      if (isClosed || generation != cache.generation) return false;
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
    final generation = cache.generation;
    try {
      await workoutRepository.publishWorkout(workoutId);
      if (isClosed || generation != cache.generation) return;
      await loadWorkoutDetails(workoutId);
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return ;
      AppLogger.e(_tag, 'publishWorkout failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
    }
  }

  Future<void> loadWorkoutDetails(String workoutId) => _load(detailKey(workoutId), () async {
    final values = await Future.wait<Object>([
      workoutRepository.getWorkoutById(workoutId),
      workoutRepository.getUserWorkoutResults(workoutId),
      workoutRepository.getWorkoutResults(workoutId),
      workoutRepository.getWorkoutParticipants(workoutId),
    ]);
    return CrossfitWorkoutDetailLoaded(
      workout: values[0] as CrossfitWorkout,
      userResults: values[1] as List<PartResult>,
      allResults: values[2] as List<PartResult>,
      participants: values[3] as List<UserProfile>,
    );
  });

  Future<void> markWorkoutViewed(String workoutId) async {
    final generation = cache.generation;
    try {
      await workoutRepository.markWorkoutViewed(workoutId);
      if (isClosed || generation != cache.generation) return;
      for (final key in [coachListKey, clientListKey]) {
        final list = cache.read<CrossfitWorkoutListLoaded>(key);
        if (list != null) {
          cache.put(key, CrossfitWorkoutListLoaded(
            workouts: list.workouts.map((w) => w.id == workoutId
                ? w.copyWith(viewedAt: DateTime.now()) : w).toList(),
            userResults: list.userResults,
          ));
        }
      }
    } catch (e, st) {
      AppLogger.e(_tag, 'markWorkoutViewed failed', e, st);
    }
  }

  void _storeResultDetail(CrossfitWorkoutDetailLoaded value) {
    cache.put(detailKey(value.workout.id), value);
    if (_activeKey == detailKey(value.workout.id)) super.emit(value);
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
    final generation = cache.generation;
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

      if (isClosed || generation != cache.generation) return true;
      lastMutationSyncStatus = result.syncStatus;
      final list = cache.read<CrossfitWorkoutListLoaded>(clientListKey);
      if (list != null) {
        cache.put(clientListKey, CrossfitWorkoutListLoaded(
          workouts: list.workouts,
          userResults: [result, ...list.userResults.where((r) => r.partId != result.partId)],
        ));
      }
      final current = cache.read<CrossfitWorkoutDetailLoaded>(detailKey(workoutId));
      if (current != null) {
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
        _storeResultDetail(
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
      if (isClosed || generation != cache.generation) return false;
      AppLogger.e(_tag, 'submitPartResult failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
      return false;
    }
  }

  Future<bool> deletePartResult({
    required String workoutId,
    required String resultId,
  }) async {
    final generation = cache.generation;
    try {
      lastMutationSyncStatus = await workoutRepository.deletePartResult(
        resultId,
      );
      if (isClosed || generation != cache.generation) return true;
      final list = cache.read<CrossfitWorkoutListLoaded>(clientListKey);
      if (list != null) {
        cache.put(clientListKey, CrossfitWorkoutListLoaded(
          workouts: list.workouts,
          userResults: list.userResults.where((r) => r.id != resultId).toList(),
        ));
      }
      final current = cache.read<CrossfitWorkoutDetailLoaded>(detailKey(workoutId));
      if (current != null) {
        _storeResultDetail(
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
      if (isClosed || generation != cache.generation) return false;
      AppLogger.e(_tag, 'deletePartResult failed', e, st);
      emit(CrossfitWorkoutError(AppLogger.userMessage(e)));
      return false;
    }
  }
}
