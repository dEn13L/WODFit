import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/theme/app_theme_extension.dart';
import 'package:wod_fit/domain/entities/training_program.dart';
import 'package:wod_fit/domain/repositories/program_repository.dart';
import 'package:wod_fit/presentation/bloc/program/program_cubit.dart';
import 'package:wod_fit/presentation/screens/coach/programs/create_program_screen.dart';

class _FailingProgramRepository implements ProgramRepository {
  int attempts = 0;

  @override
  Future<TrainingProgram> createProgram({
    required String name,
    ProgramKind kind = ProgramKind.group,
    String description = '',
  }) async {
    attempts++;
    throw Exception('sensitive database details');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('failed creation shows safe error, preserves input and allows retry', (tester) async {
    final repository = _FailingProgramRepository();
    final cubit = ProgramCubit(programRepository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppThemeExtension.light]),
          home: const CreateProgramScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Новая программа');
    final button = find.widgetWithText(ElevatedButton, 'Создать программу');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось создать программу. Проверьте подключение и попробуйте снова.'), findsOneWidget);
    expect(find.textContaining('sensitive'), findsNothing);
    expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text,
        'Новая программа');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repository.attempts, 2);
  });
}
