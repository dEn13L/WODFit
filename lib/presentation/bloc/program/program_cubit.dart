import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_logger.dart';
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

  const ProgramLoaded({
    required this.programs,
    this.successMessage,
  });

  @override
  List<Object?> get props => [programs, successMessage];
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

  ProgramCubit({required this.programRepository}) : super(const ProgramInitial());

  Future<void> loadCoachPrograms() async {
    emit(const ProgramLoading());
    try {
      final programs = await programRepository.getCoachPrograms();
      emit(ProgramLoaded(programs: programs));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadCoachPrograms failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> loadClientPrograms() async {
    emit(const ProgramLoading());
    try {
      final programs = await programRepository.getClientPrograms();
      emit(ProgramLoaded(programs: programs));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadClientPrograms failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<TrainingProgram?> createProgram({
    required String name,
    ProgramKind kind = ProgramKind.group,
    String description = '',
  }) async {
    try {
      final newProgram = await programRepository.createProgram(
        name: name,
        kind: kind,
        description: description,
      );
      final currentPrograms = state is ProgramLoaded ? (state as ProgramLoaded).programs : <TrainingProgram>[];
      emit(ProgramLoaded(
        programs: [newProgram, ...currentPrograms],
        successMessage: 'Программа "${newProgram.name}" создана. Код: ${newProgram.inviteCode}',
      ));
      return newProgram;
    } catch (e, st) {
      AppLogger.e(_tag, 'createProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return null;
    }
  }

  Future<bool> updateProgram({
    required String programId,
    required String name,
    ProgramKind? kind,
    String? description,
  }) async {
    try {
      final updatedProgram = await programRepository.updateProgram(
        programId: programId,
        name: name,
        kind: kind,
        description: description,
      );
      if (state is ProgramLoaded) {
        final currentPrograms = (state as ProgramLoaded).programs;
        final updatedList = currentPrograms.map((p) => p.id == programId ? updatedProgram : p).toList();
        emit(ProgramLoaded(
          programs: updatedList,
          successMessage: 'Программа "${updatedProgram.name}" обновлена',
        ));
      } else {
        await loadCoachPrograms();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'updateProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> deleteProgram(String programId) async {
    try {
      await programRepository.deleteProgram(programId);
      if (state is ProgramLoaded) {
        final currentPrograms = (state as ProgramLoaded).programs;
        emit(ProgramLoaded(
          programs: currentPrograms.where((p) => p.id != programId).toList(),
          successMessage: 'Программа успешно удалена',
        ));
      } else {
        await loadCoachPrograms();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'deleteProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> joinProgram(String inviteCode) async {
    try {
      final program = await programRepository.joinProgramByCode(inviteCode: inviteCode);
      if (state is ProgramLoaded) {
        final currentPrograms = (state as ProgramLoaded).programs;
        final updated = [program, ...currentPrograms.where((p) => p.id != program.id)];
        emit(ProgramLoaded(
          programs: updated,
          successMessage: 'Вы успешно вступили в программу "${program.name}"',
        ));
      } else {
        emit(ProgramLoaded(
          programs: [program],
          successMessage: 'Вы успешно вступили в программу "${program.name}"',
        ));
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'joinProgram failed', e, st);
      emit(ProgramError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> leaveProgram(String programId) async {
    try {
      await programRepository.leaveProgram(programId);
      if (state is ProgramLoaded) {
        final currentPrograms = (state as ProgramLoaded).programs;
        emit(ProgramLoaded(
          programs: currentPrograms.where((p) => p.id != programId).toList(),
          successMessage: 'Вы вышли из программы',
        ));
      } else {
        await loadClientPrograms();
      }
      return true;
    } catch (e, st) {
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
    try {
      await programRepository.removeProgramMember(programId: programId, userId: userId);
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'removeProgramMember failed', e, st);
      rethrow;
    }
  }
}
