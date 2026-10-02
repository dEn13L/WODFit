import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wod_fit/data/datasources/result_sync_local_data_source.dart';
import 'package:wod_fit/data/models/result_sync_operation.dart';
import 'package:wod_fit/data/services/result_sync_service.dart';
import 'package:wod_fit/domain/entities/part_result.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late HiveResultSyncLocalDataSource local;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wod_fit_result_sync_');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('result_sync_test');
    local = HiveResultSyncLocalDataSource(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('pending operation and local result survive box reopen', () async {
    final operation = _operation(id: 'operation-a');
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => throw Exception('offline'),
      scheduleAutomaticRetries: false,
    );

    await service.enqueue(operation);
    await box.close();
    box = await Hive.openBox<dynamic>('result_sync_test');
    local = HiveResultSyncLocalDataSource(box);

    final restoredOperations = await local.getOperations();
    final restoredResults = local.getCachedResults(workoutId: 'workout');
    expect(restoredOperations.single.id, operation.id);
    expect(restoredResults.single.id, operation.result.id);
    expect(restoredResults.single.syncStatus, ResultSyncStatus.pending);
  });

  test('confirmed operation is removed and cached as synced', () async {
    final operation = _operation(id: 'operation-a');
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (value) async => value.result,
      scheduleAutomaticRetries: false,
    );

    await service.enqueue(operation);
    await service.synchronize();

    expect(await local.getOperations(), isEmpty);
    expect(local.getCachedResult('result')!.syncStatus, ResultSyncStatus.synced);
  });

  test('failed operation remains queued with retry metadata', () async {
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => throw Exception('network unavailable'),
      scheduleAutomaticRetries: false,
    );

    await service.enqueue(_operation(id: 'operation-a'));
    await service.synchronize();

    final queued = (await local.getOperations()).single;
    expect(queued.attempts, 1);
    expect(queued.lastError, contains('network unavailable'));
    expect(local.getCachedResult('result')!.syncStatus, ResultSyncStatus.pending);
  });

  test('marks result failed after automatic retry limit', () async {
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => throw Exception('network unavailable'),
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(_operation(id: 'operation-a'));

    for (var attempt = 0; attempt < ResultSyncService.maxAutomaticAttempts; attempt++) {
      await service.synchronize();
    }

    expect(
      local.getCachedResult('result')!.syncStatus,
      ResultSyncStatus.failed,
    );
    expect(
      (await local.getOperations()).single.attempts,
      ResultSyncService.maxAutomaticAttempts,
    );
  });

  test('new operation for the same result replaces stale queued operation', () async {
    await local.putOperation(_operation(id: 'operation-a'));
    await local.putOperation(
      _operation(
        id: 'operation-b',
        occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
      ),
    );

    final queued = await local.getOperations();
    expect(queued, hasLength(1));
    expect(queued.single.id, 'operation-b');
  });

  test('retry of stale operation cannot replace a newer queued change', () async {
    final newer = _operation(
      id: 'operation-b',
      occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
    );
    await local.putOperation(newer);
    await local.putOperation(_operation(id: 'operation-a').copyWith(attempts: 1));

    final queued = await local.getOperations();
    expect(queued, hasLength(1));
    expect(queued.single.id, newer.id);
  });

  test('delete removes local projection and stays queued until confirmed', () async {
    final upsert = _operation(id: 'operation-a');
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => throw Exception('offline'),
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(upsert);

    await service.enqueue(ResultSyncOperation(
      id: 'operation-delete',
      type: ResultSyncOperationType.delete,
      result: upsert.result,
      occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
    ));

    expect(local.getCachedResult('result'), isNull);
    expect((await local.getOperations()).single.type, ResultSyncOperationType.delete);
  });

  test('pending delete hides stale server result during merge', () async {
    final source = _operation(id: 'operation-a');
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => throw Exception('offline'),
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(ResultSyncOperation(
      id: 'operation-delete',
      type: ResultSyncOperationType.delete,
      result: source.result,
      occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
    ));

    final merged = await service.mergeWithCache([source.result], userId: 'user');
    expect(merged, isEmpty);
  });
}

ResultSyncOperation _operation({
  required String id,
  DateTime? occurredAt,
}) {
  final time = occurredAt ?? DateTime.utc(2026, 10, 2, 12);
  return ResultSyncOperation(
    id: id,
    type: ResultSyncOperationType.create,
    occurredAt: time,
    result: PartResult(
      id: 'result',
      workoutId: 'workout',
      partId: 'part',
      userId: 'user',
      status: ResultStatus.done,
      scoreText: '10',
      createdAt: time,
      updatedAt: time,
      syncStatus: ResultSyncStatus.pending,
    ),
  );
}
