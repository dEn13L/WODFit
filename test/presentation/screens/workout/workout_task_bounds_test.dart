import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_bloc.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_event.dart';
import 'package:wod_fit/presentation/bloc/workout/crossfit_workout_cubit.dart';
import 'package:wod_fit/presentation/screens/workout/workout_detail_screen.dart';
import 'package:wod_fit/presentation/widgets/browser_viewport/browser_viewport_frame.dart';

import '../../../support/fake_crossfit_workout_repository.dart';

final _title = ('Длинное название задания ' * 8).trim();
final _description =
    'EMOM8\n1 взятие в стойку + 1 фронтальный присед + 1 толчок в ножницы\n'
    '${'ОченьДлинноеСловоБезПробелов' * 12}\n4 подхода приседаний';

class _Auth extends Fake implements AuthRepository {
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
}

class _Workouts extends FakeCrossfitWorkoutRepository {
  @override
  Future<CrossfitWorkout> getWorkoutById(String id) async => CrossfitWorkout(
    id: id,
    coachId: 'coach',
    title: '',
    scheduledAt: DateTime(2031),
    status: WorkoutStatus.published,
    createdAt: DateTime(2031),
    updatedAt: DateTime(2031),
    parts: [
      WorkoutPart(
        id: 'part',
        workoutId: id,
        title: _title,
        description: _description,
        sortOrder: 0,
      ),
    ],
  );
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final width in [320.0, 350.0]) {
      testWidgets(
        'whole task card and wrapped text fit visible width $width (${theme.brightness})',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = AuthBloc(authRepository: _Auth());
          final workouts = CrossfitWorkoutCubit(workoutRepository: _Workouts());
          addTearDown(auth.close);
          addTearDown(workouts.close);
          auth.add(
            AuthUserChanged(
              UserProfile(
                id: 'coach',
                email: 'test@example.com',
                fullName: 'Тренер',
                role: UserRole.coach,
                createdAt: DateTime(2031),
              ),
            ),
          );
          await tester.pump();
          final viewport = Rect.fromLTWH(10, 47, width, 664);
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: auth),
                BlocProvider.value(value: workouts),
              ],
              child: MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.5)),
                  child: BrowserViewportFrame(
                    viewport: viewport,
                    child: child!,
                  ),
                ),
                home: const WorkoutDetailScreen(workoutId: 'workout'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = find
              .ancestor(
                of: find.text(_title),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container && widget.decoration is BoxDecoration,
                ),
              )
              .first;
          final cardRect = tester.getRect(card);
          expect(cardRect.left, closeTo(viewport.left + 20, 0.01));
          expect(cardRect.right, closeTo(viewport.right - 20, 0.01));
          for (final text in [_title, _description]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text(text),
            );
            final origin = paragraph.localToGlobal(Offset.zero);
            final lines = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length),
            );
            expect(lines.length, greaterThan(1));
            // A wrap-space can extend a selection box past the content edge
            // without painting there. Check the actual non-whitespace glyphs.
            for (final run in RegExp(r'\S+').allMatches(text)) {
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: run.start, extentOffset: run.end),
              );
              for (final line in boxes) {
                expect(
                  origin.dx + line.left,
                  greaterThanOrEqualTo(cardRect.left + 16),
                );
                expect(
                  origin.dx + line.right,
                  lessThanOrEqualTo(cardRect.right - 16),
                );
              }
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'iPhone Safari full-screen mode keeps actions and card within safe bounds (${theme.brightness})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = AuthBloc(authRepository: _Auth());
        final workouts = CrossfitWorkoutCubit(workoutRepository: _Workouts());
        addTearDown(auth.close);
        addTearDown(workouts.close);
        auth.add(
          AuthUserChanged(
            UserProfile(
              id: 'coach',
              email: 'test@example.com',
              fullName: 'Тренер',
              role: UserRole.coach,
              createdAt: DateTime(2031),
            ),
          ),
        );
        await tester.pump();

        // In Safari full-screen mode, bars are collapsed and hardware safe areas active
        const viewport = Rect.fromLTWH(0, 0, 390, 844);
        const safeArea = EdgeInsets.only(top: 47, bottom: 34);

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: workouts),
            ],
            child: MaterialApp(
              theme: theme,
              builder: (context, child) => BrowserViewportFrame(
                viewport: viewport,
                safeArea: safeArea,
                child: child!,
              ),
              home: const WorkoutDetailScreen(workoutId: 'workout'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check AppBar leading and actions are positioned below notch/status bar (>= 47)
        final backButton = find.byIcon(Icons.arrow_back_ios_new);
        expect(backButton.hitTestable(), findsOneWidget);
        expect(tester.getRect(backButton).top, greaterThanOrEqualTo(47));

        final diagnosticsButton = find.byIcon(Icons.bug_report_outlined);
        expect(diagnosticsButton.hitTestable(), findsOneWidget);
        expect(tester.getRect(diagnosticsButton).top, greaterThanOrEqualTo(47));

        for (final icon in [
          Icons.edit_outlined,
          Icons.copy_outlined,
          Icons.delete_outline,
        ]) {
          final button = find.byIcon(icon);
          expect(button.hitTestable(), findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.top, greaterThanOrEqualTo(47));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(390));
        }

        // Check card bounds stay inside screen
        final card = find
            .ancestor(
              of: find.text(_title),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ),
            )
            .first;
        final cardRect = tester.getRect(card);
        expect(cardRect.left, greaterThanOrEqualTo(0));
        expect(cardRect.right, lessThanOrEqualTo(390));

        // Check bottom results button is scrollable and reachable above home indicator
        final resultsButton = find.text('Результаты участников');
        await tester.scrollUntilVisible(
          resultsButton,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(resultsButton.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(resultsButton).bottom,
          lessThanOrEqualTo(844 - 34),
        );

        expect(tester.takeException(), isNull);
      },
    );
  }
}
