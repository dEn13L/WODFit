import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_logger.dart';
import '../../state/session_data_cache.dart';
import '../workout/crossfit_workout_cubit.dart';
import '../../../domain/entities/training_program.dart';
import '../../../domain/repositories/program_repository.dart';

abstract class ProgramState extends Equatable {
  const ProgramState();

  @override
  List<Object?> get props => [];
}

class ProgramInitial extends ProgramState {
  const ProgramInitial();
}

class ProgramLoading extends ProgramState {
  const ProgramLoading();
}

class ProgramLoaded extends ProgramState {
  final List<TrainingProgram> programs;
  final String? successMessage;
  final String? refreshError;

  const ProgramLoaded({
    required this.programs,
    this.successMessage,
    this.refreshError,
  });

  @override
  List<Object?> get props => [programs, successMessage, refreshError];
}

class ProgramError extends ProgramState {
  final String message;

  const ProgramError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProgramCubit extends Cubit<ProgramState> {
  static const String _tag = 'ProgramCubit';
  final ProgramRepository programRepository;

  static const coachListKey = 'coach-programs';
  static const clientListKey = 'client-programs';
  final SessionDataCache cache;
  final bool _ownsCache;
  late final StreamSubscription<String> _cacheSubscription;
  String? _activeKey;
  int _loadRequest = 0;

  ProgramCubit({required this.programRepository, SessionDataCache? cache})
      : cache = cache ?? SessionDataCache(),
        _ownsCache = cache == null,
        super(const ProgramInitial()) {
    _cacheSubscription = this.cache.changes.listen((key) {
      if (isClosed) return;
      if (key == '*') {
        _loadRequest++;
        super.emit(const ProgramInitial());
      } else if (key == _activeKey) {
        final value = this.cache.read<ProgramLoaded>(key);
        if (value != null) super.emit(value);
      }
    });
  }

  @override
  void emit(ProgramState state) {
    if (isClosed) return;
    if (state is ProgramLoaded && _activeKey != null) {
      cache.put(_activeKey!, ProgramLoaded(programs: state.programs));
    }
    super.emit(state);
  }

  @override
  Future<void> close() async {
    await _cacheSubscription.cancel();
    if (_ownsCache) await cache.close();
    await super.close();
  }

  Future<void> _load(String key, Future<List<TrainingProgram>> Function() fetch) async {
    final request = ++_loadRequest;
    final generation = cache.generation;
    _activeKey = key;
    super.emit(cache.read<ProgramLoaded>(key) ?? const ProgramLoading());
    try {
      final value = await cache.refresh(key, () async => ProgramLoaded(programs: await fetch()));
      if (isClosed || request != _loadRequest || generation != cache.generation) return;
      if (key == clientListKey) _retainClientAccess(value.programs);
      super.emit(value);
    } catch (e, st) {
      if (e is CacheSessionChanged || isClosed || request != _loadRequest || generation != cache.generation) return;
      AppLogger.e(_tag, 'Refresh failed: $key', e, st);
      final previous = cache.read<ProgramLoaded>(key);
      if (previous != null) {
        super.emit(ProgramLoaded(programs: previous.programs, refreshError: AppLogger.userMessage(e)));
      } else {
        super.emit(ProgramError(AppLogger.userMessage(e)));
      }
    }
  }

  Future<void> loadCoachPrograms() => _load(coachListKey, programRepository.getCoachPrograms);
  Future<void> loadClientPrograms() => _load(clientListKey, programRepository.getClientPrograms);

  List<TrainingProgram> _mutationPrograms(String key) {
    _activeKey = key;
    return cache.read<ProgramLoaded>(key)?.programs ?? const [];
  }

  void _retainClientAccess(List<TrainingProgram> programs) {
    final ids = programs.map((p) => p.id).toSet();
    final list = cache.read<CrossfitWorkoutListLoaded>(CrossfitWorkoutCubit.clientListKey);
    if (list != null) {
      cache.put(CrossfitWorkoutCubit.clientListKey, CrossfitWorkoutListLoaded(
        workouts: list.workouts.where((w) => w.assignedProgramIds.any(ids.contains)).toList(),
        userResults: list.userResults,
      ));
    }
    for (final key in cache.keys) {
      final detail = key.startsWith('workout:') ? cache.read<CrossfitWorkoutDetailLoaded>(key) : null;
      if (detail != null && !detail.workout.assignedProgramIds.any(ids.contains)) {
        cache.remove(key);
      }
    }
  }

  void _removeProgramAssignments(String programId) {
    for (final key in cache.keys) {
      final value = cache.read<Object>(key);
      if (value is CrossfitWorkoutListLoaded) {
        cache.put(key, CrossfitWorkoutListLoaded(
          workouts: value.workouts.map((w) => w.copyWith(
            assignments: w.assignments.where((a) => a.programId != programId).toList())).toList(),
          userResults: value.userResults,
        ));
      } else if (value is CrossfitWorkoutDetailLoaded) {
        cache.put(key, CrossfitWorkoutDetailLoaded(
          workout: value.workout.copyWith(assignments: value.workout.assignments.where((a) => a.programId != programId).toList()),
          userResults: value.userResults,
          allResults: value.allResults,
          participants: value.participants,
        ));
      }
    }
  }

  Future<TrainingProgram?> createProgram({
    required String name,
    ProgramKind kind = ProgramKind.group,
    String description = '',
  }) async {
    final generation = cache.generation;
    try {
      final newProgram = await programRepository.createProgram(
        name: name,
        kind: kind,
        description: description,
      );
      if (isClosed || generation != cache.generation) return null;
      final currentPrograms = _mutationPrograms(coachListKey);
      emit(ProgramLoaded(
        programs: [newProgram, ...currentPrograms],
        successMessage: 'Программа "${newProgram.name}" создана. Код: ${newProgram.inviteCode}',
      ));
      return newProgram;
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return null;
      AppLogger.e(_tag, 'createProgram failed', e, st);
      emit(const ProgramError('Не удалось создать программу. Проверьте подключение и попробуйте снова.'));
      return null;
    }
  }

  Future<bool> updateProgram({
    required String programId,
    required String name,
    ProgramKind? kind,
    String? description,
  }) async {
    final generation = cache.generation;
    try {
      final updatedProgram = await programRepository.updateProgram(
        programId: programId,
        name: name,
        kind: kind,
        description: description,
      );
      if (isClosed || generation != cache.generation) return false;
      final currentPrograms = _mutationPrograms(coachListKey);
      emit(ProgramLoaded(
        programs: currentPrograms.any((p) => p.id == programId)
            ? currentPrograms.map((p) => p.id == programId ? updatedProgram : p).toList()
            : [updatedProgram, ...currentPrograms],
        successMessage: 'Программа "${updatedProgram.name}" обновлена',
      ));
      return true;
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return false;
      AppLogger.e(_tag, 'updateProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> deleteProgram(String programId) async {
    final generation = cache.generation;
    try {
      await programRepository.deleteProgram(programId);
      if (isClosed || generation != cache.generation) return false;
      cache.remove('program:$programId');
      cache.remove('program-members:$programId');
      if (isClosed || generation != cache.generation) return false;
      final currentPrograms = _mutationPrograms(coachListKey);
      emit(ProgramLoaded(
        programs: currentPrograms.where((p) => p.id != programId).toList(),
        successMessage: 'Программа успешно удалена',
      ));
      _removeProgramAssignments(programId);
      return true;
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return false;
      AppLogger.e(_tag, 'deleteProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> joinProgram(String inviteCode) async {
    final generation = cache.generation;
    try {
      final program = await programRepository.joinProgramByCode(inviteCode: inviteCode);
      if (isClosed || generation != cache.generation) return false;
      final currentPrograms = _mutationPrograms(clientListKey);
      emit(ProgramLoaded(
        programs: [program, ...currentPrograms.where((p) => p.id != program.id)],
        successMessage: 'Вы успешно вступили в программу "${program.name}"',
      ));
      return true;
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return false;
      AppLogger.e(_tag, 'joinProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> leaveProgram(String programId) async {
    final generation = cache.generation;
    try {
      await programRepository.leaveProgram(programId);
      if (isClosed || generation != cache.generation) return false;
      cache.remove('program:$programId');
      cache.remove('program-members:$programId');
      if (isClosed || generation != cache.generation) return false;
      final currentPrograms = _mutationPrograms(clientListKey);
      emit(ProgramLoaded(
        programs: currentPrograms.where((p) => p.id != programId).toList(),
        successMessage: 'Вы вышли из программы',
      ));
      _retainClientAccess(currentPrograms.where((p) => p.id != programId).toList());
      return true;
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return false;
      AppLogger.e(_tag, 'leaveProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<List<ProgramMember>> getProgramMembers(String programId) async {
    try {
      return await programRepository.getProgramMembers(programId);
    } catch (e, st) {
      AppLogger.e(_tag, 'getProgramMembers failed', e, st);
      rethrow;
    }
  }

  Future<bool> removeProgramMember(String programId, String userId) async {
    final generation = cache.generation;
    try {
      await programRepository.removeProgramMember(programId: programId, userId: userId);
      if (isClosed || generation != cache.generation) return false;
      final members = cache.read<List<ProgramMember>>('program-members:$programId');
      if (members != null) {
        cache.put('program-members:$programId', members.where((m) => m.userId != userId).toList());
      }
      return true;
    } catch (e, st) {
      if (isClosed || generation != cache.generation) return false;
      AppLogger.e(_tag, 'removeProgramMember failed', e, st);
      rethrow;
    }
  }
}
