import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';
import 'package:wod_fit/presentation/screens/coach/workouts/create_workout_screen.dart';

import '../../../support/fake_crossfit_workout_repository.dart';

class _Programs implements ProgramRepository {
  @override
  Future<List<TrainingProgram>> getCoachPrograms() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('workout-form-');
    Hive.init(directory.path);
    await Hive.openBox<dynamic>('workouts_box');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('no session field, matched action heights and 24h picker', (
      tester,
    ) async {
      final programs = ProgramCubit(programRepository: _Programs());
      addTearDown(programs.close);
      await tester.pumpWidget(
        RepositoryProvider<CrossfitWorkoutRepository>.value(
          value: FakeCrossfitWorkoutRepository(),
          child: BlocProvider.value(
            value: programs,
            child: MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(alwaysUse24HourFormat: false),
                child: child!,
              ),
              home: CreateWorkoutScreen(
                initialScheduledAt: DateTime(2026, 10, 4, 13, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Уточнение'), findsNothing);
      expect(find.text('Добавить уточнение'), findsNothing);
      final publish = find.widgetWithText(ElevatedButton, 'Опубликовать');
      final draft = find.widgetWithText(TextButton, 'Черновик');
      expect(tester.getSize(publish).height, tester.getSize(draft).height);
      final button = tester.widget<ElevatedButton>(publish);
      expect(
        button.style!.backgroundColor!.resolve({}),
        theme.colorScheme.primary,
      );
      await tester.tap(find.text('13:15'));
      await tester.pumpAndSettle();
      final pickerContext = tester.element(find.byType(TimePickerDialog));
      expect(MediaQuery.of(pickerContext).alwaysUse24HourFormat, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
