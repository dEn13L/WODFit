import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wod_fit/core/theme/app_theme.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/domain/repositories/auth_repository.dart';
import 'package:wod_fit/presentation/bloc/auth/auth_bloc.dart';
import 'package:wod_fit/presentation/screens/auth/login_screen.dart';
import 'package:wod_fit/presentation/widgets/login_welcome_panel.dart';

class _Auth extends Fake implements AuthRepository {
  final response = Completer<UserProfile>();
  int requests = 0;
  String? email;
  String? password;

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    requests++;
    this.email = email;
    this.password = password;
    return response.future;
  }
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  ThemeData? theme,
  double scale = 1,
  _Auth? repository,
}) async {
  final auth = AuthBloc(authRepository: repository ?? _Auth());
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Scaffold(body: Text('Registration')),
      ),
    ],
  );
  addTearDown(() async {
    router.dispose();
    await auth.close();
  });
  await tester.pumpWidget(
    BlocProvider.value(
      value: auth,
      child: MaterialApp.router(
        theme: theme ?? AppTheme.darkTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final width in [320.0, 390.0, 1440.0]) {
      testWidgets('login ${theme.brightness} fits $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpLogin(tester, theme: theme, scale: width == 320 ? 1.5 : 1);
        expect(find.byType(LoginWelcomePanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Войти'));
        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle();
        expect(find.text('Введите email'), findsOneWidget);
        expect(find.text('Введите пароль'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('keyboard hides artwork and preserves entered credentials', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _pumpLogin(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'athlete@example.com',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(LoginWelcomePanel), findsNothing);
    expect(find.text('athlete@example.com'), findsOneWidget);
    await tester.ensureVisible(find.text('Войти'));
    expect(find.text('Войти').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(LoginWelcomePanel), findsOneWidget);
    expect(find.text('athlete@example.com'), findsOneWidget);
  });

  testWidgets('password visibility, keyboard submission and loading guard', (
    tester,
  ) async {
    final repository = _Auth();
    await _pumpLogin(tester, repository: repository);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'athlete@example.com');
    await tester.enterText(fields.last, 'secret123');
    await tester.ensureVisible(find.byTooltip('Показать пароль'));
    await tester.tap(find.byTooltip('Показать пароль'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(repository.requests, 1);
    expect(repository.email, 'athlete@example.com');
    expect(repository.password, 'secret123');
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    repository.response.completeError(Exception('Ошибка входа'));
    await tester.pumpAndSettle();
    expect(find.text('Ошибка входа'), findsOneWidget);
    expect(find.text('athlete@example.com'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('registration link keeps existing route', (tester) async {
    await _pumpLogin(tester);
    final link = find.textContaining('Зарегистрироваться');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Registration'), findsOneWidget);
  });
}
