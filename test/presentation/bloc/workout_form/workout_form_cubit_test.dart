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
