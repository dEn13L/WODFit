import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/presentation/bloc/workout_form/workout_form_cubit.dart';
import 'package:wod_fit/presentation/screens/coach/workouts/widgets/workout_task_card.dart';
import 'package:wod_fit/presentation/widgets/confirm_dialog.dart';

void main() {
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
