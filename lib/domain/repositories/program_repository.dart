import '../entities/training_program.dart';

abstract class ProgramRepository {
  Future<List<TrainingProgram>> getCoachPrograms();
  Future<List<TrainingProgram>> getClientPrograms();
  Future<TrainingProgram> createProgram({
    required String name,
    ProgramKind kind = ProgramKind.group,
    String description = '',
  });
  Future<TrainingProgram> joinProgramByCode({required String inviteCode});
  Future<TrainingProgram> updateProgram({
    required String programId,
    required String name,
    ProgramKind? kind,
    String? description,
  });
  Future<void> deleteProgram(String programId);
  Future<void> leaveProgram(String programId);
  Future<List<ProgramMember>> getProgramMembers(String programId);
  Future<void> removeProgramMember({
    required String programId,
    required String userId,
  });
}
