import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/presentation/screens/workout/result_sync_status_view.dart';

void main() {
  Widget app(ResultSyncStatus status, {VoidCallback? onRetry}) => MaterialApp(
        home: Scaffold(
          body: ResultSyncStatusView(status: status, onRetry: onRetry),
        ),
      );

  testWidgets('shows pending synchronization state', (tester) async {
    await tester.pumpWidget(app(ResultSyncStatus.pending));

    expect(find.text('Сохранено локально · ожидает синхронизации'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('shows failed state and invokes retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      app(ResultSyncStatus.failed, onRetry: () => retried = true),
    );

    expect(find.text('Ошибка синхронизации'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    expect(retried, isTrue);
  });

  testWidgets('hides synchronized state', (tester) async {
    await tester.pumpWidget(app(ResultSyncStatus.synced));

    expect(find.byType(Text), findsNothing);
  });
}
