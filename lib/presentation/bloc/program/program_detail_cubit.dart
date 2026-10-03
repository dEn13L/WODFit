import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/training_program.dart';
import '../../../domain/repositories/crossfit_workout_repository.dart';
import '../../../domain/repositories/program_repository.dart';
import '../../state/session_data_cache.dart';
import '../workout/crossfit_workout_cubit.dart';
import 'program_cubit.dart';

class ProgramDetailData extends Equatable {
  final TrainingProgram program;
  final List<ProgramMember> members;
  final List<CrossfitWorkout> workouts;
  final Map<String, int> resultCounts;

  const ProgramDetailData({
    required this.program,
    required this.members,
    required this.workouts,
    required this.resultCounts,
  });

  @override
  List<Object?> get props => [program, members, workouts, resultCounts];
}

class ProgramDetailState extends Equatable {
  final ProgramDetailData? data;
  final bool isLoading;
  final String? error;
  final String? refreshError;
  const ProgramDetailState({
    this.data,
    this.isLoading = false,
    this.error,
    this.refreshError,
  });

  @override
  List<Object?> get props => [data, isLoading, error, refreshError];
}

class ProgramDetailCubit extends Cubit<ProgramDetailState> {
  final ProgramRepository programRepository;
  final CrossfitWorkoutRepository workoutRepository;
  final SessionDataCache cache;
  late final StreamSubscription<String> _subscription;
  String? _programId;
  int _request = 0;

  ProgramDetailCubit({
    required this.programRepository,
    required this.workoutRepository,
    required this.cache,
  }) : super(const ProgramDetailState()) {
    _subscription = cache.changes.listen((key) {
      if (isClosed) return;
      if (key == '*') {
        _request++;
        emit(const ProgramDetailState());
        return;
      }
      final id = _programId;
      if (id == null) return;
      if (key == 'program:$id' ||
          key == 'program-members:$id' ||
          key == ProgramCubit.coachListKey ||
          key == CrossfitWorkoutCubit.coachListKey ||
          key.startsWith('workout:')) {
        final saved =
            cache.read<ProgramDetailData>('program:$id') ?? state.data;
        if (saved == null) return;
        try {
          emit(ProgramDetailState(data: _project(saved)));
        } on _ProgramMissing {
          emit(const ProgramDetailState(error: 'Программа не найдена'));
        }
      }
    });
  }

  ProgramDetailData _project(ProgramDetailData saved) {
    final id = saved.program.id;
    final programs = cache.read<ProgramLoaded>(ProgramCubit.coachListKey);
    final matching = programs?.programs.where((p) => p.id == id).toList();
    if (matching != null && matching.isEmpty) throw const _ProgramMissing();
    final list = cache.read<CrossfitWorkoutListLoaded>(
      CrossfitWorkoutCubit.coachListKey,
    );
    final workouts = list == null
        ? saved.workouts
        : list.workouts
              .where((w) => w.assignedProgramIds.contains(id))
              .toList();
    final counts = Map<String, int>.from(saved.resultCounts);
    for (final workout in workouts) {
      final detail = cache.read<CrossfitWorkoutDetailLoaded>(
        CrossfitWorkoutCubit.detailKey(workout.id),
      );
      if (detail != null &&
          cache.revisionOf(CrossfitWorkoutCubit.detailKey(workout.id)) >
              cache.revisionOf('program:$id')) {
        counts[workout.id] = detail.allResults
            .map((r) => r.userId)
            .toSet()
            .length;
      }
    }
    return ProgramDetailData(
      program: matching == null ? saved.program : matching.single,
      members:
          cache.read<List<ProgramMember>>('program-members:$id') ??
          saved.members,
      workouts: workouts,
      resultCounts: counts,
    );
  }

  Future<void> load(String programId) async {
    _programId = programId;
    final request = ++_request;
    final generation = cache.generation;
    final key = 'program:$programId';
    final saved = cache.read<ProgramDetailData>(key);
    try {
      emit(
        ProgramDetailState(
          data: saved == null ? null : _project(saved),
          isLoading: saved == null,
        ),
      );
      final value = await cache.refresh(key, () async {
        final values = await Future.wait<Object>([
          cache.refresh(
            ProgramCubit.coachListKey,
            () async => ProgramLoaded(
              programs: await programRepository.getCoachPrograms(),
            ),
          ),
          cache.refresh(
            CrossfitWorkoutCubit.coachListKey,
            () async => CrossfitWorkoutListLoaded(
              workouts: await workoutRepository.getCoachWorkouts(),
            ),
          ),
          cache.refresh(
            'program-members:$programId',
            () => programRepository.getProgramMembers(programId),
          ),
        ]);
        final programs = (values[0] as ProgramLoaded).programs
            .where((p) => p.id == programId)
            .toList();
        if (programs.isEmpty) throw const _ProgramMissing();
        final workouts = (values[1] as CrossfitWorkoutListLoaded).workouts
            .where((w) => w.assignedProgramIds.contains(programId))
            .toList();
        final counts = await workoutRepository.getWorkoutResultUserCounts(
          workouts.map((w) => w.id).toList(),
        );
        return ProgramDetailData(
          program: programs.single,
          members: values[2] as List<ProgramMember>,
          workouts: workouts,
          resultCounts: counts,
        );
      });
      if (isClosed || request != _request || generation != cache.generation) {
        return;
      }
      emit(ProgramDetailState(data: _project(value)));
    } catch (e, st) {
      if (e is CacheSessionChanged ||
          isClosed ||
          request != _request ||
          generation != cache.generation) {
        return;
      }
      AppLogger.e('ProgramDetailCubit', 'Refresh program=$programId', e, st);
      if (e is _ProgramMissing) {
        cache.remove(key);
        emit(const ProgramDetailState(error: 'Программа не найдена'));
      } else if (state.data != null) {
        emit(
          ProgramDetailState(
            data: state.data,
            refreshError: AppLogger.userMessage(e),
          ),
        );
      } else {
        emit(ProgramDetailState(error: AppLogger.userMessage(e)));
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}

class _ProgramMissing implements Exception {
  const _ProgramMissing();
}
