import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/group.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/entities/workout.dart';
import 'package:wod_fit/domain/entities/workout_template.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';
import 'package:wod_fit/domain/repositories/group_repository.dart';
import 'package:wod_fit/domain/repositories/workout_repository.dart';
import 'package:wod_fit/domain/repositories/workout_template_repository.dart';
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

class MockWorkoutTemplateRepository implements WorkoutTemplateRepository {
  final List<WorkoutTemplate> _templates = [
    WorkoutTemplate(
      id: 't-1',
      coachId: 'coach-123',
      title: 'WOD: Мёрф (Классика)',
      description: 'Знаменитый комплекс в бронежилете',
      parts: const [
        WorkoutTemplatePart(
          id: 'tp-1',
          templateId: 't-1',
          type: WorkoutPartType.warmup,
          title: 'Разминка суставов',
          description: '10 мин кардио и стретчинг',
          sortOrder: 0,
        ),
        WorkoutTemplatePart(
          id: 'tp-2',
          templateId: 't-1',
          type: WorkoutPartType.crossfitComplex,
          title: 'Мёрф',
          description: '1 миля бег, 100 подтягиваний, 200 отжиманий, 300 приседаний, 1 миля бег',
          sortOrder: 1,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<WorkoutTemplate>> getCoachTemplates() async => _templates;

  @override
  Future<WorkoutTemplate> getTemplateById(String templateId) async {
    return _templates.firstWhere((t) => t.id == templateId);
  }

  @override
  Future<WorkoutTemplate> createTemplate({
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    final t = WorkoutTemplate(
      id: 't-${DateTime.now().millisecondsSinceEpoch}',
      coachId: 'coach-123',
      title: title,
      description: description,
      parts: parts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _templates.add(t);
    return t;
  }

  @override
  Future<WorkoutTemplate> updateTemplate({
    required String id,
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    final idx = _templates.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = _templates[idx].copyWith(
        title: title,
        description: description,
        parts: parts,
        updatedAt: DateTime.now(),
      );
      _templates[idx] = updated;
      return updated;
    }
    throw Exception('Template not found');
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    _templates.removeWhere((t) => t.id == templateId);
  }

  @override
  Future<WorkoutTemplate> duplicateTemplate(String templateId) async {
    final original = await getTemplateById(templateId);
    final copy = original.copyWith(
      id: 't-copy-${DateTime.now().millisecondsSinceEpoch}',
      title: '${original.title} (Копия)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _templates.add(copy);
    return copy;
  }
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
    final templateRepo = MockWorkoutTemplateRepository();
    final legacyRepo = MockLegacyWorkoutRepository();

    await tester.pumpWidget(
      WodFitApp(
        authRepository: authRepo,
        groupRepository: groupRepo,
        crossfitWorkoutRepository: workoutRepo,
        workoutTemplateRepository: templateRepo,
        legacyWorkoutRepository: legacyRepo,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Coach Home Screen
    expect(find.text('Главный Тренер'), findsOneWidget);
    expect(find.text('Панель тренера'), findsOneWidget);
    expect(find.text('Новая тренировка'), findsOneWidget);
    expect(find.text('Шаблоны'), findsWidgets);
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

  test('Workout Template CRUD and creating workout from template logic', () async {
    final templateRepo = MockWorkoutTemplateRepository();
    final workoutRepo = MockWorkoutRepository();

    // 1. Get templates
    final initialTemplates = await templateRepo.getCoachTemplates();
    expect(initialTemplates.length, 1);
    expect(initialTemplates.first.title, 'WOD: Мёрф (Классика)');
    expect(initialTemplates.first.parts.length, 2);

    // 2. Create template
    final newTemplate = await templateRepo.createTemplate(
      title: 'Синди (Cindy)',
      description: 'AMRAP 20 минут',
      parts: const [
        WorkoutTemplatePart(
          id: 'p-1',
          templateId: '',
          type: WorkoutPartType.crossfitComplex,
          title: 'Cindy',
          description: '5 подтягиваний, 10 отжиманий, 15 приседаний',
          sortOrder: 0,
        ),
      ],
    );
    expect(newTemplate.title, 'Синди (Cindy)');
    expect(newTemplate.parts.length, 1);

    // 3. Update template
    final updatedTemplate = await templateRepo.updateTemplate(
      id: newTemplate.id,
      title: 'Синди Hardcore',
      description: 'AMRAP 30 минут',
      parts: newTemplate.parts,
    );
    expect(updatedTemplate.title, 'Синди Hardcore');
    expect(updatedTemplate.description, 'AMRAP 30 минут');

    // 4. Duplicate template
    final duplicated = await templateRepo.duplicateTemplate(updatedTemplate.id);
    expect(duplicated.title, 'Синди Hardcore (Копия)');
    expect(duplicated.parts.length, 1);

    // 5. Create Workout from Template (copying parts without mutating template)
    final templateToUse = await templateRepo.getTemplateById('t-1');
    final copiedParts = templateToUse.parts.map((tp) {
      return WorkoutPart(
        id: 'wp-${tp.id}',
        workoutId: '',
        type: tp.type,
        title: tp.title,
        description: tp.description,
        sortOrder: tp.sortOrder,
      );
    }).toList();

    final createdWorkout = await workoutRepo.createWorkout(
      title: templateToUse.title,
      description: templateToUse.description,
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
      parts: copiedParts,
      groupIds: ['g-1'],
      publish: true,
    );

    expect(createdWorkout.title, templateToUse.title);
    expect(createdWorkout.parts.length, 2);
    expect(createdWorkout.status, WorkoutStatus.published);

    // Verify original template is untouched
    final templateAfter = await templateRepo.getTemplateById('t-1');
    expect(templateAfter.title, 'WOD: Мёрф (Классика)');
    expect(templateAfter.parts.length, 2);

    // 6. Delete template
    await templateRepo.deleteTemplate(duplicated.id);
    final allTemplates = await templateRepo.getCoachTemplates();
    expect(allTemplates.any((t) => t.id == duplicated.id), isFalse);
  });

  test('WorkoutScoreType mapping and PartResult formattedScore with backward compatibility', () {
    // 1. ScoreType fromString & dbValue
    expect(WorkoutScoreType.fromString('time'), WorkoutScoreType.time);
    expect(WorkoutScoreType.fromString('rounds_reps'), WorkoutScoreType.roundsReps);
    expect(WorkoutScoreType.fromString('weight'), WorkoutScoreType.weight);
    expect(WorkoutScoreType.fromString('reps'), WorkoutScoreType.reps);
    expect(WorkoutScoreType.fromString('distance'), WorkoutScoreType.distance);
    expect(WorkoutScoreType.fromString('calories'), WorkoutScoreType.calories);
    expect(WorkoutScoreType.fromString('none'), WorkoutScoreType.none);
    expect(WorkoutScoreType.fromString('text'), WorkoutScoreType.text);
    expect(WorkoutScoreType.fromString(null), WorkoutScoreType.text);

    expect(WorkoutScoreType.roundsReps.dbValue, 'rounds_reps');
    expect(WorkoutScoreType.time.dbValue, 'time');

    // 2. PartResult formattedScore backward compatibility with legacy scoreText
    final legacyResult = PartResult(
      id: 'r-legacy',
      workoutId: 'w-1',
      partId: 'p-1',
      userId: 'u-1',
      scoreText: '12:45 (Rx)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(legacyResult.formattedScore, '12:45 (Rx)');

    // 3. Formatted scores derived from structured metrics
    final timeResult = PartResult(
      id: 'r-time',
      workoutId: 'w-1',
      partId: 'p-1',
      userId: 'u-1',
      timeMs: 765000, // 12 min 45 sec
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(timeResult.formattedScore, '12:45');

    final roundsRepsResult = PartResult(
      id: 'r-rr',
      workoutId: 'w-1',
      partId: 'p-1',
      userId: 'u-1',
      rounds: 5,
      reps: 12,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(roundsRepsResult.formattedScore, '5 рд • 12 повт');

    final weightResult = PartResult(
      id: 'r-w',
      workoutId: 'w-1',
      partId: 'p-1',
      userId: 'u-1',
      weightKg: 105.5,
      reps: 3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(weightResult.formattedScore, '3 повт • 105.5 кг');

    final distanceResult = PartResult(
      id: 'r-dist',
      workoutId: 'w-1',
      partId: 'p-1',
      userId: 'u-1',
      distanceM: 2000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(distanceResult.formattedScore, '2000 м');

    final caloriesResult = PartResult(
      id: 'r-cal',
      workoutId: 'w-1',
      partId: 'p-1',
      userId: 'u-1',
      calories: 350,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(caloriesResult.formattedScore, '350 кал');

    final noneResult = PartResult(
      id: 'r-none',
      workoutId: 'w-1',
      partId: 'p-1',
      userId: 'u-1',
      status: ResultStatus.done,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(noneResult.formattedScore, 'Выполнено');
  });
}
