import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/presentation/screens/workout/results_filter_panel.dart';
import 'package:wod_fit/presentation/screens/workout/results_matrix.dart';

void main() {
  final now = DateTime(2026);
  final parts = [
    WorkoutPart(
      id: 'first',
      workoutId: 'workout',
      title: 'Бёрпи',
      sortOrder: 0,
    ),
    WorkoutPart(id: 'second', workoutId: 'workout', title: 'Бег', sortOrder: 1),
  ];
  final participants = [
    for (final id in ['complete', 'partial', 'not-done', 'empty'])
      UserProfile(
        id: id,
        email: '',
        fullName: id,
        role: UserRole.client,
        createdAt: now,
      ),
  ];
  PartResult result(
    String userId,
    String partId, {
    ResultStatus status = ResultStatus.done,
  }) => PartResult(
    id: '$userId-$partId',
    workoutId: 'workout',
    userId: userId,
    partId: partId,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
  final matrix = buildResultsMatrix(
    parts: parts,
    participants: participants,
    results: [
      result('complete', 'first'),
      result('complete', 'second', status: ResultStatus.scaled),
      result('partial', 'first'),
      result('not-done', 'first'),
      result('not-done', 'second', status: ResultStatus.notDone),
    ],
  );

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'counted tabs scroll and select at 320 px, ${theme.brightness}, scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = ResultsFilter.all;
          final changes = <ResultsFilter>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: StatefulBuilder(
                    builder: (context, setState) => ResultsFilterPanel(
                      matrix: matrix,
                      selected: selected,
                      onChanged: (value) => setState(() {
                        changes.add(value);
                        selected = value;
                      }),
                    ),
                  ),
                ),
              ),
            ),
          );

          final tabs = find.byType(SegmentedButton<ResultsFilter>);
          final labels = [
            'Все 4',
            'Выполнили 1',
            'Частично 2',
            'Не заполнили 1',
          ];
          void expectCounts() {
            for (final label in labels) {
              expect(
                find.descendant(of: tabs, matching: find.text(label)),
                findsOneWidget,
              );
            }
            expect(find.byType(Chip), findsNothing);
            expect(tester.takeException(), isNull);
          }

          expectCounts();
          final scrollable = tester.state<ScrollableState>(
            find.byType(Scrollable),
          );
          expect(scrollable.position.maxScrollExtent, greaterThan(0));
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(-240, 0),
          );
          await tester.pumpAndSettle();
          expect(scrollable.position.pixels, greaterThan(0));

          for (final filter in [
            ResultsFilter.empty,
            ResultsFilter.partial,
            ResultsFilter.completed,
            ResultsFilter.all,
          ]) {
            final label = find.text(labels[filter.index]);
            await tester.ensureVisible(label);
            await tester.tap(label);
            await tester.pumpAndSettle();
            expect(
              tester.widget<SegmentedButton<ResultsFilter>>(tabs).selected,
              {filter},
            );
            expectCounts();
          }
          expect(changes, [
            ResultsFilter.empty,
            ResultsFilter.partial,
            ResultsFilter.completed,
            ResultsFilter.all,
          ]);
        },
      );
    }
  }

  testWidgets('all tabs include zero counts for an empty matrix', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultsFilterPanel(
            matrix: const ResultsMatrix(parts: [], rows: []),
            selected: ResultsFilter.all,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final tabs = find.byType(SegmentedButton<ResultsFilter>);
    for (final label in [
      'Все 0',
      'Выполнили 0',
      'Частично 0',
      'Не заполнили 0',
    ]) {
      expect(
        find.descendant(of: tabs, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.byType(Chip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
