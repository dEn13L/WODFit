import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/repositories/crossfit_workout_repository.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';
import 'package:wod_fit/presentation/bloc/workout_form/workout_form_cubit.dart';
import 'package:wod_fit/presentation/screens/coach/workouts/create_workout_screen.dart';

import '../../../support/fake_crossfit_workout_repository.dart';

class _Programs implements ProgramRepository {
  final bool longName;
  _Programs({this.longName = false});
  @override
  Future<List<TrainingProgram>> getCoachPrograms() async => longName
      ? [
          TrainingProgram(
            id: 'program',
            inviteCode: 'CODE',
            coachId: 'coach',
            name: 'Очень длинное название программы ' * 5,
            kind: ProgramKind.group,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ]
      : [];
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
    for (final (width, scale) in [
      (320.0, 1.0),
      (320.0, 1.5),
      (390.0, 1.0),
      (390.0, 1.5),
      (480.0, 1.5),
      (844.0, 1.5),
    ]) {
      testWidgets(
        'form fits $width at scale $scale with keyboard (${theme.brightness})',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          final height = width > 600 ? 390.0 : 700.0;
          tester.view.physicalSize = Size(width, height);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final programs = ProgramCubit(
            programRepository: _Programs(longName: true),
          );
          addTearDown(programs.close);
          await tester.pumpWidget(
            RepositoryProvider<CrossfitWorkoutRepository>.value(
              value: FakeCrossfitWorkoutRepository(),
              child: BlocProvider.value(
                value: programs,
                child: MaterialApp(
                  theme: theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(bottom: 34),
                    ),
                    child: child!,
                  ),
                  home: CreateWorkoutScreen(
                    // Isolate layout from debounced filesystem writes.
                    workoutToCopy: CrossfitWorkout(
                      id: 'source',
                      coachId: 'coach',
                      title: '',
                      scheduledAt: DateTime(2026),
                      createdAt: DateTime(2026),
                      updatedAt: DateTime(2026),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final formContext = tester.element(find.byType(CustomScrollView));
          final cubit = formContext.read<WorkoutFormCubit>();
          await tester.pumpAndSettle();
          final title = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == 'Название задания',
          );
          await tester.scrollUntilVisible(
            title,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(title, 'Очень длинное название задания ' * 4);
          tester.view.viewInsets = FakeViewPadding(
            bottom: width > 600 ? 160 : 300,
          );
          await tester.pumpAndSettle();
          expect(find.text('Опубликовать').hitTestable(), findsOneWidget);
          final description = find.byType(TextField).last;
          await tester.enterText(description, '10 приседаний\n' * 12);
          await tester.pumpAndSettle();
          for (final field in [title, description]) {
            final rect = tester.getRect(field);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
          }
          FocusManager.instance.primaryFocus?.unfocus();
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          final add = find.text('ДОБАВИТЬ ЗАДАНИЕ');
          await tester.scrollUntilVisible(
            add,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(add).bottom, lessThanOrEqualTo(height - 34));
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(cubit.state.tasks.length, 2);
          expect(find.text('Опубликовать').hitTestable(), findsOneWidget);
          expect(
            find.byTooltip('Черновик').hitTestable(),
            width < 400 * scale ? findsOneWidget : findsNothing,
          );
          await tester.runAsync(
            () => Hive.box<dynamic>('workouts_box').flush(),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

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
      await tester.tap(find.text('04.10.2026'));
      await tester.pumpAndSettle();
      final dialog = find.byType(DatePickerDialog);
      final monday = find.descendant(of: dialog, matching: find.text('5'));
      final thursday = find.descendant(of: dialog, matching: find.text('1'));
      final sunday = find.descendant(of: dialog, matching: find.text('4'));
      expect(
        tester.getTopLeft(monday).dx,
        lessThan(tester.getTopLeft(thursday).dx),
      );
      expect(
        tester.getTopLeft(sunday).dx,
        greaterThan(tester.getTopLeft(thursday).dx),
      );
      Navigator.of(tester.element(dialog)).pop();
      await tester.pumpAndSettle();
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
