import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wod_fit/core/utils/app_logger.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';

import '../support/fake_crossfit_workout_repository.dart';

final workout = CrossfitWorkout(
  id: 'original',
  coachId: 'coach',
  title: '',
  scheduledAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class Repository extends FakeCrossfitWorkoutRepository {
  Object? mutationError;
  Completer<CrossfitWorkout>? delayed;
  Completer<List<CrossfitWorkout>>? delayedList;
  int listReads = 0;
  int copies = 0;

  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async =>
      delayed == null ? workout.copyWith(id: id) : delayed!.future;

  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async {
    listReads++;
    return delayedList == null ? [workout] : delayedList!.future;
  }

  @override
  Future<CrossfitWorkout> duplicateWorkout(String workoutId) async {
    copies++;
    if (mutationError != null) throw mutationError!;
    return workout.copyWith(id: 'copy');
  }

  @override
  Future<void> deleteWorkout(String workoutId) async {
    if (mutationError != null) throw mutationError!;
  }
}

void main() {
  test('duplicate from detail keeps the original detail and results', () async {
    final repository = Repository();
    final cubit = CrossfitWorkoutCubit(workoutRepository: repository);
    await cubit.loadWorkoutDetails('original');
    expect(await cubit.duplicateWorkout('original'), isTrue);
    expect((cubit.state as CrossfitWorkoutDetailLoaded).workout.id, 'original');
    expect(repository.listReads, 0);
    await cubit.close();
  });

  test('duplicate from list inserts the copy', () async {
    final cubit = CrossfitWorkoutCubit(workoutRepository: Repository());
    await cubit.loadCoachWorkouts();
    await cubit.duplicateWorkout('original');
    expect(
      (cubit.state as CrossfitWorkoutListLoaded).workouts.map((w) => w.id),
      ['copy', 'original'],
    );
    await cubit.close();
  });

  test(
    'failed mutations preserve detail and hide PostgREST internals',
    () async {
      final repository = Repository()
        ..mutationError = const PostgrestException(
          message: 'Cannot coerce',
          code: 'PGRST116',
        );
      final cubit = CrossfitWorkoutCubit(workoutRepository: repository);
      await cubit.loadWorkoutDetails('original');
      expect(await cubit.duplicateWorkout('original'), isFalse);
      expect(cubit.state, isA<CrossfitWorkoutDetailLoaded>());
      expect(
        (cubit.state as CrossfitWorkoutDetailLoaded).message,
        isNot(contains('Postgrest')),
      );
      expect(await cubit.deleteWorkout('original'), isFalse);
      expect(cubit.state, isA<CrossfitWorkoutDetailLoaded>());
      await cubit.close();
    },
  );

  test(
    'late missing-row error after deletion cannot replace success',
    () async {
      final repository = Repository()..delayed = Completer<CrossfitWorkout>();
      final cubit = CrossfitWorkoutCubit(workoutRepository: repository);
      final loading = cubit.loadWorkoutDetails('original');
      expect(await cubit.deleteWorkout('original'), isTrue);
      repository.delayed!.completeError(
        const PostgrestException(message: '0 rows', code: 'PGRST116'),
      );
      await loading;
      expect(cubit.state, isA<CrossfitWorkoutListLoaded>());
      expect(repository.listReads, 0);
      await cubit.close();
    },
  );

  test('late list load does not replace opened detail', () async {
    final repository = Repository()
      ..delayedList = Completer<List<CrossfitWorkout>>();
    final cubit = CrossfitWorkoutCubit(workoutRepository: repository);
    final loading = cubit.loadCoachWorkouts();
    await cubit.loadWorkoutDetails('original');
    repository.delayedList!.complete([workout]);
    await loading;
    expect(cubit.state, isA<CrossfitWorkoutDetailLoaded>());
    await cubit.close();
  });

  test(
    'errors survive reopening storage, are bounded and redact credentials',
    () async {
      final directory = await Directory.systemTemp.createTemp('wod-error-log-');
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('diagnostics');
      await AppLogger.initialize(box);
      for (var i = 0; i < 60; i++) {
        AppLogger.e(
          'Test',
          'operation=$i',
          const PostgrestException(
            message: 'Bearer secret test@example.com eyJhbGciOiJIUzI1NiJ9.payload.signature',
            code: 'PGRST116',
            details: '0 rows',
            hint: 'retry',
          ),
          StackTrace.current,
        );
      }
      await AppLogger.flush();
      await box.close();
      final reopened = await Hive.openBox<dynamic>('diagnostics');
      final records = (reopened.get('error_log') as List).cast<String>();
      expect(records.length, AppLogger.maxEntries);
      expect(records.first, contains('operation=10'));
      expect(records.last, contains('PGRST116'));
      expect(records.last, contains('0 rows'));
      expect(records.last, contains('retry'));
      expect(records.last, contains('stack'));
      expect(records.last, isNot(contains('secret')));
      expect(records.last, isNot(contains('test@example.com')));
      expect(records.last, isNot(contains('eyJhbG')));
      await AppLogger.initialize(reopened);
      expect(AppLogger.exportErrors(), contains('operation=59'));
      await reopened.close();
      await directory.delete(recursive: true);
    },
  );
}
