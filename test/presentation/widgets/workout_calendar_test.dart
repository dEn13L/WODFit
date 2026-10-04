import 'dart:io';

import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/core/utils/workout_date_formatter.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';
import 'package:wod_fit/presentation/bloc/workout_form/workout_form_cubit.dart';
import 'package:wod_fit/presentation/screens/client/client_history_screen.dart';
import 'package:wod_fit/presentation/screens/coach/workouts/coach_all_workouts_screen.dart';
import 'package:wod_fit/presentation/widgets/workout_calendar.dart';

import '../../support/fake_crossfit_workout_repository.dart';

import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';

CrossfitWorkout workout(
  String title,
  DateTime date,
  WorkoutStatus status, {
  String program = 'p',
}) => CrossfitWorkout(
  id: title,
  coachId: 'coach',
  title: title,
  scheduledAt: date,
  status: status,
  createdAt: date,
  updatedAt: date,
  assignments: [
    WorkoutAssignment(
      workoutId: title,
      programId: program,
      programName: program,
      assignedAt: date,
      workoutNumber: {'TODAY': 1, 'TOMORROW': 2, 'DRAFT': 3, 'OTHER': 4}[title],
    ),
  ],
);

class Workouts extends FakeCrossfitWorkoutRepository {
  final List<CrossfitWorkout> workouts;
  int reads = 0;
  Workouts(this.workouts);
  @override
  Future<List<CrossfitWorkout>> getCoachWorkouts() async {
    reads++;
    return workouts;
  }

  @override
  Future<List<CrossfitWorkout>> getClientWorkouts() async {
    reads++;
    return workouts;
  }
}

class Programs implements ProgramRepository {
  @override
  Future<List<TrainingProgram>> getCoachPrograms() async => [
    for (final id in ['p', 'other'])
      TrainingProgram(
        id: id,
        coachId: 'coach',
        name: 'Program $id',
        inviteCode: id,
        createdAt: DateTime(2026),
      ),
  ];
  @override
  Future<List<TrainingProgram>> getClientPrograms() => getCoachPrograms();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory hiveDirectory;
  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('wodfit-calendar-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>('workouts_box');
  });
  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });
  test('calendar compares local days and form preselects date', () async {
    final utc = DateTime.utc(2026, 10, 4, 23, 30);
    final local = utc.toLocal();
    expect(
      WorkoutDateFormatter.sameDay(
        utc,
        DateTime(local.year, local.month, local.day),
      ),
      isTrue,
    );
    final date = DateTime(2026, 12, 31);
    final cubit = WorkoutFormCubit(
      workoutRepository: Workouts([]),
      initialScheduledAt: date,
    );
    expect(cubit.state.scheduledAt, date);
    expect(cubit.state.isEditMode, isFalse);
    await cubit.close();
  });

  test(
    'edit and explicit draft restoration retain their own scheduled date',
    () async {
      final original = workout(
        'original',
        DateTime(2026, 10, 4, 19),
        WorkoutStatus.draft,
      );
      final edit = WorkoutFormCubit(
        workoutRepository: Workouts([]),
        workoutToEdit: original,
        initialScheduledAt: DateTime(2026, 12, 31),
      );
      expect(edit.state.scheduledAt, original.scheduledAt);
      await edit.close();
      final box = Hive.box<dynamic>('workouts_box');
      await box.put('draft_workout_form', {
        'tasks': [
          {'id': 'task', 'title': 'Разминка', 'description': ''},
        ],
        'scheduled_at': original.scheduledAt.toIso8601String(),
      });
      final form = WorkoutFormCubit(
        workoutRepository: Workouts([]),
        initialScheduledAt: DateTime(2026, 12, 31),
      );
      await Future<void>.delayed(Duration.zero);
      expect(form.state.hasCachedDraft, isTrue);
      form.restoreCachedDraft();
      expect(form.state.scheduledAt, original.scheduledAt);
      await form.close();
      await box.clear();
    },
  );

  testWidgets('week navigation crosses year and starts on Monday', (
    tester,
  ) async {
    var selected = DateTime(2026, 12, 31);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => WorkoutCalendar(
              workouts: const [],
              selectedDate: selected,
              onDateSelected: (date) => setState(() => selected = date),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('calendar-day-2026-12-28')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-day-2027-1-3')), findsOneWidget);
    await tester.tap(find.byTooltip('Следующая неделя'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2027, 1, 7));
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('calendar fits 320 px with large text in ${theme.brightness}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = DateTime(2026, 10, 4);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => WorkoutCalendar(
                    workouts: [
                      workout('draft', selected, WorkoutStatus.draft),
                      workout('published', selected, WorkoutStatus.published),
                    ],
                    selectedDate: selected,
                    showDrafts: true,
                    onDateSelected: (date) => setState(() => selected = date),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Показать месяц'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar-day-2026-10-31')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('calendar-day-2026-10-5')));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 10, 5));
      await tester.tap(find.byTooltip('Следующий месяц'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 11, 5));
      await tester.tap(find.text('Сегодня'));
      await tester.pumpAndSettle();
      expect(WorkoutDateFormatter.sameDay(selected, DateTime.now()), isTrue);
    });
  }

  testWidgets('month clamps Jan 31 to leap February; week crosses year', (
    tester,
  ) async {
    var selected = DateTime(2028, 1, 31);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => WorkoutCalendar(
              workouts: const [],
              selectedDate: selected,
              onDateSelected: (date) => setState(() => selected = date),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Показать месяц'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Следующий месяц'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2028, 2, 29));
    await tester.tap(find.byTooltip('Показать неделю'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Следующая неделя'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2028, 3, 7));
  });

  testWidgets('athlete calendar excludes drafts from marks', (tester) async {
    final date = DateTime(2026, 10, 4);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutCalendar(
              workouts: [
                workout('draft', date, WorkoutStatus.draft),
                workout('pub', date, WorkoutStatus.published),
              ],
              selectedDate: date,
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Черновики'), findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp('Воскресенье, 4 октября 2026.*тренировок: 1'),
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final coach in [true, false]) {
    testWidgets(
      '${coach ? 'coach' : 'athlete'} selects day without new requests and filters program',
      (tester) async {
        final today = WorkoutDateFormatter.localDay(DateTime.now());
        final tomorrow = DateTime(today.year, today.month, today.day + 1);
        final repo = Workouts([
          workout('TODAY', today, WorkoutStatus.published),
          workout('TOMORROW', tomorrow, WorkoutStatus.published),
          workout('DRAFT', today, WorkoutStatus.draft),
          workout('OTHER', today, WorkoutStatus.published, program: 'other'),
        ]);
        final cubit = CrossfitWorkoutCubit(workoutRepository: repo);
        final programs = ProgramCubit(programRepository: Programs());
        addTearDown(cubit.close);
        addTearDown(programs.close);
        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cubit),
                BlocProvider.value(value: programs),
              ],
              child: coach
                  ? const CoachAllWorkoutsScreen()
                  : const ClientHistoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byType(ListView).first;
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.textContaining('Тренировка 1\n'), findsOneWidget);
        expect(find.textContaining('Тренировка 2\n'), findsNothing);
        expect(
          find.textContaining('Тренировка 3\n'),
          coach ? findsOneWidget : findsNothing,
        );
        final key = ValueKey(
          'calendar-day-${tomorrow.year}-${tomorrow.month}-${tomorrow.day}',
        );
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.textContaining('Тренировка 2\n'), findsOneWidget);
        expect(find.textContaining('Тренировка 1\n'), findsNothing);
        await tester.drag(list, const Offset(0, 1200));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<String>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Program other').last);
        await tester.pumpAndSettle();
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.textContaining('Тренировка 2\n'), findsNothing);
        expect(repo.reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
