import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/entities/workout.dart';
import 'package:wod_fit/domain/entities/workout_template.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';
import 'package:wod_fit/domain/repositories/workout_repository.dart';
import 'package:wod_fit/domain/repositories/workout_template_repository.dart';
import 'package:wod_fit/main.dart';

class FakeAuthRepository implements AuthRepository {
  UserProfile? _currentUser;
  final _controller = StreamController<UserProfile?>.broadcast();

  @override
  Future<UserProfile?> getCurrentUserProfile() async => _currentUser;

  @override
  Stream<UserProfile?> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _currentUser = UserProfile(
      id: 'test-user',
      email: email,
      fullName: 'Тестовый Пользователь',
      role: UserRole.coach,
      createdAt: DateTime.now(),
    );
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    _currentUser = UserProfile(
      id: 'test-user',
      email: email,
      fullName: fullName,
      role: role,
      createdAt: DateTime.now(),
    );
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}

class FakeProgramRepository implements ProgramRepository {
  @override
  Future<List<TrainingProgram>> getCoachPrograms() async => [];

  @override
  Future<List<TrainingProgram>> getClientPrograms() async => [];

  @override
  Future<TrainingProgram> createProgram({
    required String name,
    ProgramKind kind = ProgramKind.group,
    String description = '',
  }) async {
    return TrainingProgram(
      id: 'program-1',
      coachId: 'coach-1',
      name: name,
      kind: kind,
      description: description,
      inviteCode: 'TEST01',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<TrainingProgram> joinProgramByCode({required String inviteCode}) async {
    return TrainingProgram(
      id: 'program-1',
      coachId: 'coach-1',
      name: 'Test Program',
      kind: ProgramKind.group,
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<TrainingProgram> updateProgram({
    required String programId,
    required String name,
    ProgramKind? kind,
    String? description,
  }) async {
    return TrainingProgram(
      id: programId,
      coachId: 'coach-1',
      name: name,
      kind: kind ?? ProgramKind.group,
      description: description ?? '',
      inviteCode: 'TEST01',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteProgram(String programId) async {}

  @override
  Future<void> leaveProgram(String programId) async {}

  @override
  Future<List<ProgramMember>> getProgramMembers(String programId) async => [];

  @override
  Future<void> removeProgramMember({required String programId, required String userId}) async {}
}

class FakeCrossfitWorkoutRepository implements CrossfitWorkoutRepository {
  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async => [];

  @override
  Future<List<CrossfitWorkout>> getClientWorkouts() async => [];

  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async {
    return CrossfitWorkout(
      id: id,
      coachId: 'coach-1',
      title: 'Test Workout',
      scheduledAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  }) async {
    return CrossfitWorkout(
      id: 'w-1',
      coachId: 'coach-1',
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      status: publish ? WorkoutStatus.published : WorkoutStatus.draft,
      parts: parts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<CrossfitWorkout> updateWorkout({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    required WorkoutStatus status,
  }) async {
    return CrossfitWorkout(
      id: id,
      coachId: 'coach-1',
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      status: status,
      parts: parts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<CrossfitWorkout> duplicateWorkout(String workoutId) async {
    return CrossfitWorkout(
      id: 'w-copy-1',
      coachId: 'coach-1',
      title: 'Test Workout (Копия)',
      scheduledAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteWorkout(String workoutId) async {}

  @override
  Future<void> publishWorkout(String id) async {}

  @override
  Future<List<PartResult>> getWorkoutResults(String workoutId) async => [];

  @override
  Future<List<PartResult>> getUserWorkoutResults(String workoutId) async => [];

  @override
  Future<List<PartResult>> getClientAllResults() async => [];

  @override
  Future<PartResult> submitPartResult({
    required String workoutId,
    required String partId,
    required ResultStatus status,
    required String scoreText,
    String note = '',
    int? timeMs,
    int? rounds,
    int? reps,
    double? weightKg,
    double? distanceM,
    int? calories,
  }) async {
    return PartResult(
      id: 'res-1',
      workoutId: workoutId,
      partId: partId,
      userId: 'user-1',
      status: status,
      scoreText: scoreText,
      note: note,
      timeMs: timeMs,
      rounds: rounds,
      reps: reps,
      weightKg: weightKg,
      distanceM: distanceM,
      calories: calories,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deletePartResult(String resultId) async {}
}

class FakeWorkoutTemplateRepository implements WorkoutTemplateRepository {
  @override
  Future<List<WorkoutTemplate>> getCoachTemplates() async => [];

  @override
  Future<WorkoutTemplate> getTemplateById(String templateId) async {
    return WorkoutTemplate(
      id: templateId,
      coachId: 'coach-1',
      title: 'Шаблон',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<WorkoutTemplate> createTemplate({
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    return WorkoutTemplate(
      id: 'template-1',
      coachId: 'coach-1',
      title: title,
      description: description,
      parts: parts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<WorkoutTemplate> updateTemplate({
    required String id,
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    return WorkoutTemplate(
      id: id,
      coachId: 'coach-1',
      title: title,
      description: description,
      parts: parts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) async {}

  @override
  Future<WorkoutTemplate> duplicateTemplate(String templateId) async {
    return WorkoutTemplate(
      id: 'template-copy-1',
      coachId: 'coach-1',
      title: 'Шаблон (Копия)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class FakeLegacyWorkoutRepository implements WorkoutRepository {
  @override
  Future<List<Workout>> getWorkouts() async => [];

  @override
  Future<void> saveWorkout(Workout workout) async {}

  @override
  Future<void> deleteWorkout(String id) async {}

  @override
  Stream<int> getStepCountStream() => Stream.value(0);
}

void main() {
  testWidgets('App launches with LoginScreen for unauthenticated users', (WidgetTester tester) async {
    final authRepo = FakeAuthRepository();
    final programRepo = FakeProgramRepository();
    final workoutRepo = FakeCrossfitWorkoutRepository();
    final templateRepo = FakeWorkoutTemplateRepository();
    final legacyRepo = FakeLegacyWorkoutRepository();

    await tester.pumpWidget(
      WodFitApp(
        authRepository: authRepo,
        programRepository: programRepo,
        crossfitWorkoutRepository: workoutRepo,
        workoutTemplateRepository: templateRepo,
        legacyWorkoutRepository: legacyRepo,
      ),
    );
    await tester.pumpAndSettle();

    // Verify LoginScreen is shown
    expect(find.text('WOD FIT'), findsOneWidget);
    expect(find.text('Вход в систему тренировок'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
