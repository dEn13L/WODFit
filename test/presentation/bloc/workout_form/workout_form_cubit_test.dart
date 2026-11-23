import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/presentation/bloc/workout_form/workout_form_cubit.dart';

import '../../../support/fake_crossfit_workout_repository.dart';

void main() {
  late Directory directory;
  late FakeCrossfitWorkoutRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('workout-cubit-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>('workouts_box');
    repository = FakeCrossfitWorkoutRepository();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('WorkoutFormCubit - saveDraft', () {
    late _SavingWorkoutRepository savingRepository;

    setUp(() {
      savingRepository = _SavingWorkoutRepository();
    });

    WorkoutFormCubit createCubit({bool edit = false}) {
      final cubit = WorkoutFormCubit(
        workoutRepository: savingRepository,
        workoutToEdit: edit
            ? CrossfitWorkout(
                id: 'w-1',
                coachId: 'coach-1',
                title: '',
                scheduledAt: DateTime(2026),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                parts: const [
                  WorkoutPart(id: 'task-1', workoutId: 'w-1', title: ''),
                ],
              )
            : null,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('emits error when all tasks are removed in edit mode', () async {
      final cubit = createCubit(edit: true);
      cubit.removeTask(cubit.state.tasks.single.id);
      expect(cubit.state.tasks, isEmpty);
      final emitted = <WorkoutFormState>[];
      final subscription = cubit.stream.listen(emitted.add);

      await cubit.saveDraft();
      await subscription.cancel();

      expect(emitted.map((state) => state.submitStatus), [
        WorkoutFormSubmitStatus.error,
      ]);
      expect(
        cubit.state.errorMessage,
        'Добавьте хотя бы одно задание для сохранения черновика',
      );
      expect(savingRepository.createCalls, 0);
      expect(savingRepository.updateCalls, 0);
    });

    test('succeeds with a task with empty title and description', () async {
      final cubit = createCubit();
      expect(cubit.state.tasks.single.title, isEmpty);
      expect(cubit.state.tasks.single.description, isEmpty);

      await cubit.saveDraft();

      expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.success);
      expect(savingRepository.createCalls, 1);
      expect(cubit.state.savedWorkout!.status, WorkoutStatus.draft);
      expect(cubit.state.savedWorkout!.parts.single.title, isEmpty);
      expect(cubit.state.savedWorkout!.parts.single.description, isEmpty);
    });

    test('publish requires a task title but saveDraft permits it empty', () async {
      final cubit = createCubit();
      cubit.setPrograms({'prog-1'});

      await cubit.publishWorkout();

      expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.error);
      expect(cubit.state.errorMessage, 'Заполните название для всех заданий');
      expect(savingRepository.createCalls, 0);

      await cubit.saveDraft();

      expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.success);
      expect(cubit.state.errorMessage, isNull);
      expect(savingRepository.createCalls, 1);
      expect(cubit.state.savedWorkout!.status, WorkoutStatus.draft);
      expect(cubit.state.savedWorkout!.parts.single.title, isEmpty);
    });

    test('succeeds after adding a task following an empty tasks error', () async {
      final cubit = createCubit(edit: true);
      cubit.removeTask(cubit.state.tasks.single.id);
      await cubit.saveDraft();
      expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.error);
      expect(savingRepository.updateCalls, 0);

      cubit.addTask();
      await cubit.saveDraft();

      expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.success);
      expect(cubit.state.errorMessage, isNull);
      expect(savingRepository.createCalls, 0);
      expect(savingRepository.updateCalls, 1);
      expect(cubit.state.savedWorkout!.parts.single.title, isEmpty);
      expect(cubit.state.savedWorkout!.status, WorkoutStatus.draft);
    });
  });

  group('WorkoutFormCubit - autoSelectIfSingleProgram', () {
    test(
      'auto-selects program when single program is provided on creation',
      () {
        final cubit = WorkoutFormCubit(workoutRepository: repository);
        addTearDown(cubit.close);

        expect(cubit.state.selectedProgramIds, isEmpty);

        cubit.autoSelectIfSingleProgram(['prog-1']);

        expect(cubit.state.selectedProgramIds, {'prog-1'});
      },
    );

    test('does not auto-select when multiple programs are provided', () {
      final cubit = WorkoutFormCubit(workoutRepository: repository);
      addTearDown(cubit.close);

      cubit.autoSelectIfSingleProgram(['prog-1', 'prog-2']);

      expect(cubit.state.selectedProgramIds, isEmpty);
    });

    test('does not auto-select when empty program list is provided', () {
      final cubit = WorkoutFormCubit(workoutRepository: repository);
      addTearDown(cubit.close);

      cubit.autoSelectIfSingleProgram([]);

      expect(cubit.state.selectedProgramIds, isEmpty);

      // When program finishes loading later with single program, it should select
      cubit.autoSelectIfSingleProgram(['prog-1']);
      expect(cubit.state.selectedProgramIds, {'prog-1'});
    });

    test('does not auto-select in edit mode', () {
      final workout = CrossfitWorkout(
        id: 'w-1',
        coachId: 'coach-1',
        title: '',
        scheduledAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final cubit = WorkoutFormCubit(
        workoutRepository: repository,
        workoutToEdit: workout,
      );
      addTearDown(cubit.close);

      expect(cubit.state.isEditMode, isTrue);
      expect(cubit.state.selectedProgramIds, isEmpty);

      cubit.autoSelectIfSingleProgram(['prog-1']);

      expect(cubit.state.selectedProgramIds, isEmpty);
    });

    test('does not auto-select in copy mode', () {
      final workout = CrossfitWorkout(
        id: 'w-source',
        coachId: 'coach-1',
        title: 'Original',
        scheduledAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final cubit = WorkoutFormCubit(
        workoutRepository: repository,
        workoutToCopy: workout,
      );
      addTearDown(cubit.close);

      expect(cubit.state.selectedProgramIds, isEmpty);

      cubit.autoSelectIfSingleProgram(['prog-1']);

      expect(cubit.state.selectedProgramIds, isEmpty);
    });

    test('does not override initialProgramId', () {
      final cubit = WorkoutFormCubit(
        workoutRepository: repository,
        initialProgramId: 'prog-custom',
      );
      addTearDown(cubit.close);

      expect(cubit.state.selectedProgramIds, {'prog-custom'});

      cubit.autoSelectIfSingleProgram(['prog-other']);

      expect(cubit.state.selectedProgramIds, {'prog-custom'});
    });

    test('does not re-select when user manually unchecks the program', () {
      final cubit = WorkoutFormCubit(workoutRepository: repository);
      addTearDown(cubit.close);

      cubit.autoSelectIfSingleProgram(['prog-1']);
      expect(cubit.state.selectedProgramIds, {'prog-1'});

      // User deselects the program
      cubit.toggleProgram('prog-1');
      expect(cubit.state.selectedProgramIds, isEmpty);

      // Re-triggering auto-select (e.g. on cubit emission or refresh) should not re-select
      cubit.autoSelectIfSingleProgram(['prog-1']);
      expect(cubit.state.selectedProgramIds, isEmpty);
    });
  });
}

class _SavingWorkoutRepository extends FakeCrossfitWorkoutRepository {
  int createCalls = 0;
  int updateCalls = 0;

  @override
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  }) async {
    createCalls++;
    return CrossfitWorkout(
      id: 'w-created',
      coachId: 'coach-1',
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      parts: parts,
      status: publish ? WorkoutStatus.published : WorkoutStatus.draft,
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
    updateCalls++;
    return CrossfitWorkout(
      id: id,
      coachId: 'coach-1',
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      parts: parts,
      status: status,
    );
  }
}
