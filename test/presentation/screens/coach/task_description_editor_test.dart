import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/presentation/screens/coach/widgets/coach_welcome_banner.dart';
import 'package:wod_fit/presentation/screens/coach/workouts/widgets/task_description_editor.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets(
      'description can be saved above keyboard in ${theme.brightness}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        String? saved;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => TaskDescriptionEditor.show(
                    context,
                    initialDescription: 'Существующее описание',
                    onSaved: (value) => saved = value,
                  ),
                  child: const Text('Открыть'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Открыть'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getBottomRight(find.text('Сохранить')).dy, lessThan(340));
        await tester.enterText(
          find.byType(TextField),
          '  3 раунда\n10 приседаний  ',
        );
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        expect(saved, '3 раунда\n10 приседаний');
        expect(find.byType(TaskDescriptionEditor), findsNothing);
      },
    );

    testWidgets(
      'welcome fits narrow screen with enlarged text in ${theme.brightness}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: CoachWelcomeBanner(name: 'Александра Тестовая'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Привет, Александра'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'closing editor does not save changes; wide dialog scrolls long text',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TaskDescriptionEditor.show(
                  context,
                  initialDescription: List.filled(
                    100,
                    'Длинное описание',
                  ).join('\n'),
                  onSaved: (_) => saves++,
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.byType(TaskDescriptionEditor), findsNothing);
    },
  );
}
