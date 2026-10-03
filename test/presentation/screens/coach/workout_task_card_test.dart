import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/presentation/bloc/workout_form/workout_form_cubit.dart';
import 'package:wod_fit/presentation/screens/coach/workouts/widgets/workout_task_card.dart';
import 'package:wod_fit/presentation/widgets/confirm_dialog.dart';

import '../../../support/fake_crossfit_workout_repository.dart';

void main() {
  for (final publish in [false, true]) {
    test(
      'copy only creates a workout on explicit submit (publish=$publish)',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'workout-copy-',
        );
        Hive.init(directory.path);
        final box = await Hive.openBox('workouts_box');
        await box.put('draft_workout_form', {
          'session_name': 'Другой черновик',
        });
        final repository = _CopyRepository();
        final oldDate = DateTime(2024);
        final source = CrossfitWorkout(
          id: 'source',
          coachId: 'coach',
          title: 'Утро',
          scheduledAt: oldDate,
          createdAt: oldDate,
          updatedAt: oldDate,
          status: WorkoutStatus.published,
          parts: const [
            WorkoutPart(
              id: 'second',
              workoutId: 'source',
              title: 'Комплекс',
              description: '5 раундов\n10 приседаний',
              sortOrder: 1,
            ),
            WorkoutPart(
              id: 'first',
              workoutId: 'source',
              title: 'Разминка',
              description: 'Бег',
              sortOrder: 0,
            ),
          ],
          assignments: [
            WorkoutAssignment(
              workoutId: 'source',
              programId: 'program',
              assignedAt: oldDate,
            ),
          ],
        );
        final cubit = WorkoutFormCubit(
          workoutRepository: repository,
          workoutToCopy: source,
        );
        try {
          expect(cubit.state.isEditMode, isFalse);
          expect(cubit.state.workoutId, isNull);
          expect(cubit.state.hasCachedDraft, isFalse);
          expect(cubit.state.sessionName, 'Утро');
          expect(cubit.state.selectedProgramIds, {'program'});
          expect(cubit.state.scheduledAt.year, DateTime.now().year);
          expect(cubit.state.tasks.map((t) => t.title), [
            'Разминка',
            'Комплекс',
          ]);
          expect(
            cubit.state.tasks.last.description,
            '5 раундов\n10 приседаний',
          );
          expect(cubit.state.tasks.map((t) => t.id).toSet().length, 2);
          expect(
            cubit.state.tasks.any((t) => ['first', 'second'].contains(t.id)),
            isFalse,
          );
          cubit.setTaskDescription(
            cubit.state.tasks.first.id,
            'Новая разминка',
          );
          await Future<void>.delayed(const Duration(milliseconds: 600));
          expect(repository.creates, 0);
          expect(
            box.get('draft_workout_form')['session_name'],
            'Другой черновик',
          );
          if (publish) {
            await cubit.publishWorkout();
          } else {
            await cubit.saveDraft();
          }
          expect(repository.creates, 1);
          expect(repository.published, publish);
          expect(repository.parts.first.description, 'Новая разминка');
          expect(repository.parts.map((p) => p.sortOrder), [0, 1]);
          expect(cubit.state.submitStatus, WorkoutFormSubmitStatus.success);
          expect(
            box.get('draft_workout_form')['session_name'],
            'Другой черновик',
          );
          expect(source.parts.last.description, 'Бег');
        } finally {
          await cubit.close();
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  testWidgets(
    'title and multiline description can be edited in the same card',
    (tester) async {
      var title = '';
      var description = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutTaskCard(
              task: const WorkoutFormTask(
                id: 'task',
                title: 'Разминка',
                description: 'Бег',
              ),
              index: 0,
              onDelete: () {},
              onTitleChanged: (value) => title = value,
              onDescriptionChanged: (value) => description = value,
            ),
          ),
        ),
      );
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.first, 'Комплекс');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(tester.widget<TextField>(fields.last).focusNode!.hasFocus, isTrue);
      await tester.enterText(fields.last, '5 раундов\n10 приседаний');
      expect(title, 'Комплекс');
      expect(description, '5 раундов\n10 приседаний');
      expect(tester.widget<TextField>(fields.last).maxLines, isNull);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets('task removal requires confirmation; cancellation retains task', (
    tester,
  ) async {
    var deletions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutTaskCard(
            task: const WorkoutFormTask(id: 'task', title: 'Силовая'),
            index: 0,
            onDelete: () => deletions++,
            onTitleChanged: (_) {},
            onDescriptionChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Удалить задание'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmDialog), findsOneWidget);
    expect(deletions, 0);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(deletions, 0);
    await tester.tap(find.byTooltip('Удалить задание'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(deletions, 1);
  });
}

class _CopyRepository extends FakeCrossfitWorkoutRepository {
  int creates = 0;
  bool published = false;
  List<WorkoutPart> parts = [];

  @override
  Future<CrossfitWorkout> createWorkout({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required List<WorkoutPart> parts,
    required List<String> programIds,
    bool publish = false,
  }) async {
    creates++;
    published = publish;
    this.parts = parts;
    return CrossfitWorkout(
      id: 'copy',
      coachId: 'coach',
      title: title,
      scheduledAt: scheduledAt,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: publish ? WorkoutStatus.published : WorkoutStatus.draft,
      parts: parts,
    );
  }
}
