import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/group.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/entities/workout.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';
import 'package:wod_fit/domain/repositories/group_repository.dart';
import 'package:wod_fit/domain/repositories/workout_repository.dart';
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

class FakeGroupRepository implements GroupRepository {
  @override
  Future<List<Group>> getCoachGroups() async => [];

  @override
  Future<List<Group>> getClientGroups() async => [];

  @override
  Future<Group> createGroup({required String name}) async {
    return Group(
      id: 'group-1',
      coachId: 'coach-1',
      name: name,
      inviteCode: 'TEST01',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Group> joinGroupByCode({required String inviteCode}) async {
    return Group(
      id: 'group-1',
      coachId: 'coach-1',
      name: 'Test Group',
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async => [];
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
    required List<String> groupIds,
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
  Future<void> publishWorkout(String id) async {}

  @override
  Future<List<PartResult>> getWorkoutResults(String workoutId) async => [];

  @override
  Future<List<PartResult>> getUserWorkoutResults(String workoutId) async => [];

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
  }) async {
    return PartResult(
      id: 'res-1',
      workoutId: workoutId,
      partId: partId,
      userId: 'user-1',
      status: status,
      scoreText: scoreText,
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
    final groupRepo = FakeGroupRepository();
    final workoutRepo = FakeCrossfitWorkoutRepository();
    final legacyRepo = FakeLegacyWorkoutRepository();

    await tester.pumpWidget(
      WodFitApp(
        authRepository: authRepo,
        groupRepository: groupRepo,
        crossfitWorkoutRepository: workoutRepo,
        legacyWorkoutRepository: legacyRepo,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Login Screen elements
    expect(find.text('WOD FIT'), findsOneWidget);
    expect(find.text('Вход в систему тренировок'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.textContaining('Зарегистрироваться'), findsOneWidget);

    // Tap register button
    await tester.tap(find.textContaining('Зарегистрироваться'));
    await tester.pumpAndSettle();

    // Verify Register Screen elements
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Атлет (Клиент)'), findsOneWidget);
    expect(find.text('Тренер'), findsOneWidget);
    expect(find.text('Имя и фамилия'), findsOneWidget);
  });
}
