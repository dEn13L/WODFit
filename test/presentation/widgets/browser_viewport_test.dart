import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/presentation/widgets/browser_viewport/browser_viewport_frame.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets(
      'browser bars, keyboard and rotation keep content visible (${theme.brightness})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        MediaQueryData? innerMedia;
        Future<void> show(Rect viewport, {double keyboard = 0}) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
                child: BrowserViewportFrame(viewport: viewport, child: child!),
              ),
              home: Builder(
                builder: (context) {
                  innerMedia = MediaQuery.of(context);
                  return Scaffold(
                    appBar: AppBar(
                      actions: [
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => const AlertDialog(
                              content: Text('Проверка диалога'),
                            ),
                          ),
                          child: const Text('Сохранить'),
                        ),
                      ],
                    ),
                    body: const SingleChildScrollView(
                      child: Column(
                        children: [TextField(), SizedBox(height: 1200)],
                      ),
                    ),
                    bottomNavigationBar: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Добавить задание'),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        void expectButtonsInside(Rect visible) {
          for (final label in ['Сохранить', 'Добавить задание']) {
            final finder = find.text(label);
            final rect = tester.getRect(finder);
            expect(rect.top, greaterThanOrEqualTo(visible.top));
            expect(rect.bottom, lessThanOrEqualTo(visible.bottom));
            expect(rect.left, greaterThanOrEqualTo(visible.left));
            expect(rect.right, lessThanOrEqualTo(visible.right));
            expect(finder.hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }

        const expanded = Rect.fromLTWH(0, 47, 390, 664);
        await show(expanded);
        expectButtonsInside(expanded);
        expect(innerMedia!.size, const Size(390, 664));
        expect(innerMedia!.viewInsets, EdgeInsets.zero);
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        final dialog = tester.getRect(find.byType(AlertDialog));
        expect(dialog.top, greaterThanOrEqualTo(expanded.top));
        expect(dialog.bottom, lessThanOrEqualTo(expanded.bottom));
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await tester.pumpAndSettle();
        const narrow = Rect.fromLTWH(35, 47, 320, 664);
        await show(narrow);
        expectButtonsInside(narrow);
        await show(expanded);

        // The engine retains a full-height view while reporting the keyboard.
        // A second subtraction of 504 here would collapse the form.
        await show(const Rect.fromLTWH(0, 120, 390, 340), keyboard: 504);
        expect(innerMedia!.viewInsets.bottom, 251);
        expect(innerMedia!.size.height - innerMedia!.viewInsets.bottom, 340);
        final field = tester.getRect(find.byType(TextField));
        expect(field.top, greaterThanOrEqualTo(120));
        expect(field.bottom, lessThanOrEqualTo(460));
        expect(find.text('Сохранить').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);

        const collapsed = Rect.fromLTWH(0, 0, 390, 750);
        await show(collapsed);
        expectButtonsInside(collapsed);
        expect(innerMedia!.viewInsets, EdgeInsets.zero);

        tester.view.physicalSize = const Size(844, 390);
        const landscape = Rect.fromLTWH(47, 0, 750, 340);
        await show(landscape);
        expectButtonsInside(landscape);
        expect(innerMedia!.size, const Size(750, 340));
      },
    );
  }

  testWidgets('Chrome-sized view with no browser overlap stays unchanged', (
    tester,
  ) async {
    MediaQueryData? actual;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => BrowserViewportFrame(
          viewport: const Rect.fromLTWH(0, 0, 800, 600),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            actual = MediaQuery.of(context);
            return const Scaffold();
          },
        ),
      ),
    );
    expect(actual!.size, const Size(800, 600));
    expect(actual!.viewInsets, EdgeInsets.zero);
    expect(actual!.padding, EdgeInsets.zero);
  });
}
