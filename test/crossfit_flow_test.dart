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

class MockCoachAuthRepository implements AuthRepository {
  final _controller = StreamController<UserProfile?>.broadcast();
  final UserProfile _coach = UserProfile(
    id: 'coach-123',
    email: 'coach@wodfit.com',
    fullName: 'Главный Тренер',
    role: UserRole.coach,
    createdAt: DateTime.now(),
  );

  @override
  Future<UserProfile?> getCurrentUserProfile() async => _coach;

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(_coach);

  @override
  Future<UserProfile> signInWithEmailPassword({required String email, required String password}) async => _coach;

  @override
  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async => _coach;

  @override
  Future<void> signOut() async => _controller.add(null);
}

class MockGroupRepository implements GroupRepository {
  final List<Group> _groups = [
    Group(
      id: 'g-1',
      coachId: 'coach-123',
      name: 'Утренняя группа 07:00',
      inviteCode: 'CF0700',
      createdAt: DateTime.now(),
      memberCount: 5,
    ),
  ];

  @override
  Future<List<Group>> getCoachGroups() async => _groups;

  @override
  Future<List<Group>> getClientGroups() async => _groups;

  @override
  Future<Group> createGroup({required String name}) async {
    final g = Group(
      id: 'g-2',
      coachId: 'coach-123',
      name: name,
      inviteCode: 'NEW123',
      createdAt: DateTime.now(),
    );
    _groups.add(g);
    return g;
  }

  @override
  Future<Group> joinGroupByCode({required String inviteCode}) async => _groups.first;

  @override
  Future<Group> updateGroupName({required String groupId, required String name}) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final updated = _groups[idx].copyWith(name: name);
      _groups[idx] = updated;
      return updated;
    }
    throw Exception('Group not found');
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    _groups.removeWhere((g) => g.id == groupId);
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    _groups.removeWhere((g) => g.id == groupId);
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async => [];

  @override
  Future<void> removeGroupMember({required String groupId, required String userId}) async {}
}

class MockWorkoutRepository implements CrossfitWorkoutRepository {
  final List<CrossfitWorkout> _workouts = [
    CrossfitWorkout(
      id: 'w-1',
      coachId: 'coach-123',
      title: 'WOD: Fran & Heavy Snatch',
      description: 'Интенсивный комплекс',
      scheduledAt: DateTime.now(),
      status: WorkoutStatus.published,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      parts: const [
        WorkoutPart(
          id: 'p-1',
          workoutId: 'w-1',
          type: WorkoutPartType.weightlifting,
          title: 'Snatch 5x2',
        ),
        WorkoutPart(
          id: 'p-2',
          workoutId: 'w-1',
          type: WorkoutPartType.crossfitComplex,
          title: 'Fran (21-15-9 Thrusters & Pull-ups)',
        ),
      ],
      assignments: [
        WorkoutAssignment(
          workoutId: 'w-1',
          groupId: 'g-1',
          assignedAt: DateTime(2026, 1, 1),
          groupName: 'Утренняя группа 07:00',
        ),
      ],
    ),
  ];

  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async => _workouts;

  @override
  Future<List<CrossfitWorkout>> getClientWorkouts() async => _workouts;

  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async => _workouts.first;

  @override
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> groupIds,
    bool publish = false,
  }) async {
    final w = CrossfitWorkout(
      id: 'w-new',
      coachId: 'coach-123',
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      status: publish ? WorkoutStatus.published : WorkoutStatus.draft,
      parts: parts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _workouts.add(w);
    return w;
  }

  @override
  Future<CrossfitWorkout> updateWorkout({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> groupIds,
    required WorkoutStatus status,
  }) async {
    final idx = _workouts.indexWhere((w) => w.id == id);
    if (idx != -1) {
      final updated = _workouts[idx].copyWith(
        title: title,
        description: description,
        scheduledAt: scheduledAt,
        parts: parts,
        status: status,
      );
      _workouts[idx] = updated;
      return updated;
    }
    throw Exception('Workout not found');
  }

  @override
  Future<CrossfitWorkout> duplicateWorkout(String workoutId) async {
    final original = _workouts.firstWhere((w) => w.id == workoutId);
    final copy = original.copyWith(
      id: 'w-copy-${DateTime.now().millisecondsSinceEpoch}',
      title: '${original.title} (Копия)',
      status: WorkoutStatus.draft,
    );
    _workouts.add(copy);
    return copy;
  }

  @override
  Future<void> deleteWorkout(String workoutId) async {
    _workouts.removeWhere((w) => w.id == workoutId);
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

  @override
  Future<void> deletePartResult(String resultId) async {}
}

class MockLegacyWorkoutRepository implements WorkoutRepository {
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
  testWidgets('Coach Home Screen displays coach profile, workouts and navigation', (WidgetTester tester) async {
    final authRepo = MockCoachAuthRepository();
    final groupRepo = MockGroupRepository();
    final workoutRepo = MockWorkoutRepository();
    final legacyRepo = MockLegacyWorkoutRepository();

    await tester.pumpWidget(
      WodFitApp(
        authRepository: authRepo,
        groupRepository: groupRepo,
        crossfitWorkoutRepository: workoutRepo,
        legacyWorkoutRepository: legacyRepo,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Coach Home Screen
    expect(find.text('Главный Тренер'), findsOneWidget);
    expect(find.text('Панель тренера'), findsOneWidget);
    expect(find.text('Новая тренировка'), findsOneWidget);
    expect(find.text('Мои группы'), findsWidgets);
    expect(find.text('WOD: Fran & Heavy Snatch'), findsOneWidget);
  });

  test('Group and Workout operations logic in repositories and cubits', () async {
    final groupRepo = MockGroupRepository();
    final workoutRepo = MockWorkoutRepository();

    // 1. Group operations
    final createdGroup = await groupRepo.createGroup(name: 'Вечерняя 19:00');
    expect(createdGroup.name, 'Вечерняя 19:00');

    final updatedGroup = await groupRepo.updateGroupName(groupId: createdGroup.id, name: 'Вечерняя 19:30');
    expect(updatedGroup.name, 'Вечерняя 19:30');

    await groupRepo.deleteGroup(createdGroup.id);
    final coachGroups = await groupRepo.getCoachGroups();
    expect(coachGroups.any((g) => g.id == createdGroup.id), isFalse);

    // 2. Workout duplication
    final duplicate = await workoutRepo.duplicateWorkout('w-1');
    expect(duplicate.title, contains('(Копия)'));
    expect(duplicate.status, WorkoutStatus.draft);

    // 3. Workout update
    final updatedWorkout = await workoutRepo.updateWorkout(
      id: 'w-1',
      title: 'WOD: Fran Updated',
      description: 'Обновленное описание',
      scheduledAt: DateTime.now(),
      parts: const [],
      groupIds: ['g-1'],
      status: WorkoutStatus.published,
    );
    expect(updatedWorkout.title, 'WOD: Fran Updated');
  });
}
