import 'dart:async';
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

  test('restart resumes persisted operation with the same id', () async {
    final operation = _operation(id: 'operation-a');
    await local.putOperation(
      operation.copyWith(attempts: 2, lastError: 'offline'),
    );
    await box.close();
    box = await Hive.openBox<dynamic>('result_sync_test');
    local = HiveResultSyncLocalDataSource(box);
    final sent = <String>[];
    final restarted = ResultSyncService(
      localDataSource: local,
      currentUserId: () => 'user',
      sendOperation: (value) async {
        sent.add(value.id);
        expect(value.attempts, 2);
        expect(value.lastError, 'offline');
        return value.result;
      },
      scheduleAutomaticRetries: false,
    );
    await restarted.synchronize();
    expect(sent, [operation.id]);
    expect(await local.getOperations(), isEmpty);
  });

  test(
    'logout and account switch preserve and isolate queued operations',
    () async {
      String? userId;
      final sent = <String>[];
      final service = ResultSyncService(
        localDataSource: local,
        currentUserId: () => userId,
        sendOperation: (value) async {
          expect(value.result.userId, userId);
          sent.add(value.id);
          return value.result;
        },
        scheduleAutomaticRetries: false,
      );
      await service.enqueue(_operation(id: 'operation-a'));
      await service.enqueue(
        _operation(
          id: 'operation-b',
          userId: 'other',
          resultId: 'other-result',
        ),
      );
      await service.synchronize();
      expect(sent, isEmpty);
      userId = 'other';
      await service.synchronize();
      expect(sent, ['operation-b']);
      expect((await local.getOperations()).single.id, 'operation-a');
      expect(local.getCachedResults(userId: 'other').single.id, 'other-result');
      userId = 'user';
      await service.synchronize();
      expect(sent, ['operation-b', 'operation-a']);
      expect(await local.getOperations(), isEmpty);
    },
  );

  test('account switch during a request does not send remaining old account operations', () async {
    var userId = 'user';
    final started = Completer<void>();
    final response = Completer<PartResult>();
    final sent = <String>[];
    final first = _operation(id: 'operation-a');
    final service = ResultSyncService(
      localDataSource: local,
      currentUserId: () => userId,
      sendOperation: (value) {
        sent.add(value.id);
        started.complete();
        return response.future;
      },
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(first);
    await service.enqueue(
      _operation(
        id: 'operation-b',
        partId: 'other-part',
        resultId: 'other-result',
      ),
    );
    final sync = service.synchronize();
    await started.future;
    userId = 'other';
    response.complete(first.result);
    await sync;
    expect(sent, ['operation-a']);
    expect((await local.getOperations()).single.id, 'operation-b');
  });

  test('remote winner replaces local id after two-device conflict', () async {
    final operation = _operation(id: 'operation-a');
    final winner = operation.result.copyWith(
      id: 'remote-result',
      scoreText: '20',
    );
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => winner,
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(operation);
    await service.synchronize();
    expect(await local.getOperations(), isEmpty);
    expect(local.getCachedResult('result'), isNull);
    expect(local.getCachedResult('remote-result')!.scoreText, '20');
  });

  test(
    'remote tombstone winning over offline update removes local projection',
    () async {
      final operation = _operation(id: 'operation-a');
      final service = ResultSyncService(
        localDataSource: local,
        sendOperation: (_) async => operation.result.copyWith(
          id: 'remote-result',
          deletedAt: DateTime.utc(2026, 10, 2, 12, 1),
        ),
        scheduleAutomaticRetries: false,
      );
      await service.enqueue(operation);
      await service.synchronize();
      expect(await local.getOperations(), isEmpty);
      expect(local.getCachedResults(), isEmpty);
    },
  );

  test(
    'pending local result replaces same part from another device during merge',
    () async {
      final operation = _operation(id: 'operation-a');
      final service = ResultSyncService(
        localDataSource: local,
        sendOperation: (_) async => operation.result,
        scheduleAutomaticRetries: false,
      );
      await service.enqueue(operation);
      final merged = await service.mergeWithCache([
        operation.result.copyWith(id: 'remote-result', scoreText: '20'),
      ], userId: 'user');
      expect(merged, hasLength(1));
      expect(merged.single.id, operation.result.id);
      expect(merged.single.syncStatus, ResultSyncStatus.pending);
    },
  );

  test('newer remote edit defeats stale offline deletion', () async {
    final operation = _operation(id: 'operation-a');
    final winner = operation.result.copyWith(
      id: 'remote-result',
      scoreText: '20',
    );
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => winner,
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(
      ResultSyncOperation(
        id: operation.id,
        type: ResultSyncOperationType.delete,
        result: operation.result,
        occurredAt: operation.occurredAt,
      ),
    );
    await service.synchronize();
    expect(await local.getOperations(), isEmpty);
    expect(local.getCachedResults().single.id, 'remote-result');
    expect(local.getCachedResults().single.scoreText, '20');
    expect(local.getCachedResults().single.syncStatus, ResultSyncStatus.synced);
  });

  test('confirmation of old request preserves newer pending edit', () async {
    final started = Completer<void>();
    final response = Completer<PartResult>();
    final first = _operation(id: 'operation-a');
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) {
        started.complete();
        return response.future;
      },
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(first);
    final sync = service.synchronize();
    await started.future;
    await service.enqueue(
      _operation(
        id: 'operation-b',
        occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
      ),
    );
    response.complete(
      first.result.copyWith(id: 'remote-result', scoreText: '20'),
    );
    await sync;
    expect((await local.getOperations()).single.id, 'operation-b');
    expect(local.getCachedResult('remote-result'), isNull);
    expect(
      local.getCachedResult('result')!.syncStatus,
      ResultSyncStatus.pending,
    );
  });

  test(
    'failed queue survives restart and requires explicit forced retry',
    () async {
      await local.putOperation(
        _operation(id: 'operation-a').copyWith(
          attempts: ResultSyncService.maxAutomaticAttempts,
          lastError: 'offline',
        ),
      );
      await box.close();
      box = await Hive.openBox<dynamic>('result_sync_test');
      local = HiveResultSyncLocalDataSource(box);
      var sends = 0;
      final restarted = ResultSyncService(
        localDataSource: local,
        currentUserId: () => 'user',
        sendOperation: (operation) async {
          sends++;
          return operation.result;
        },
        scheduleAutomaticRetries: false,
      );
      await restarted.synchronize();
      expect(sends, 0);
      expect(
        (await local.getOperations()).single.attempts,
        ResultSyncService.maxAutomaticAttempts,
      );
      await restarted.synchronize(force: true);
      expect(sends, 1);
      expect(await local.getOperations(), isEmpty);
    },
  );

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
    expect(
      local.getCachedResult('result')!.syncStatus,
      ResultSyncStatus.synced,
    );
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
    expect(
      local.getCachedResult('result')!.syncStatus,
      ResultSyncStatus.pending,
    );
  });

  test('marks result failed after automatic retry limit', () async {
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => throw Exception('network unavailable'),
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(_operation(id: 'operation-a'));

    for (
      var attempt = 0;
      attempt < ResultSyncService.maxAutomaticAttempts;
      attempt++
    ) {
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

  test(
    'new operation for the same result replaces stale queued operation',
    () async {
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
    },
  );

  test(
    'retry of stale operation cannot replace a newer queued change',
    () async {
      final newer = _operation(
        id: 'operation-b',
        occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
      );
      await local.putOperation(newer);
      await local.putOperation(
        _operation(id: 'operation-a').copyWith(attempts: 1),
      );

      final queued = await local.getOperations();
      expect(queued, hasLength(1));
      expect(queued.single.id, newer.id);
    },
  );

  test(
    'delete removes local projection and stays queued until confirmed',
    () async {
      final upsert = _operation(id: 'operation-a');
      final service = ResultSyncService(
        localDataSource: local,
        sendOperation: (_) async => throw Exception('offline'),
        scheduleAutomaticRetries: false,
      );
      await service.enqueue(upsert);

      await service.enqueue(
        ResultSyncOperation(
          id: 'operation-delete',
          type: ResultSyncOperationType.delete,
          result: upsert.result,
          occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
        ),
      );

      expect(local.getCachedResult('result'), isNull);
      expect(
        (await local.getOperations()).single.type,
        ResultSyncOperationType.delete,
      );
    },
  );

  test('pending delete hides stale server result during merge', () async {
    final source = _operation(id: 'operation-a');
    final service = ResultSyncService(
      localDataSource: local,
      sendOperation: (_) async => throw Exception('offline'),
      scheduleAutomaticRetries: false,
    );
    await service.enqueue(
      ResultSyncOperation(
        id: 'operation-delete',
        type: ResultSyncOperationType.delete,
        result: source.result,
        occurredAt: DateTime.utc(2026, 10, 2, 12, 1),
      ),
    );

    final merged = await service.mergeWithCache([
      source.result,
    ], userId: 'user');
    expect(merged, isEmpty);
  });
}

ResultSyncOperation _operation({
  required String id,
  DateTime? occurredAt,
  String userId = 'user',
  String resultId = 'result',
  String partId = 'part',
}) {
  final time = occurredAt ?? DateTime.utc(2026, 10, 2, 12);
  return ResultSyncOperation(
    id: id,
    type: ResultSyncOperationType.create,
    occurredAt: time,
    result: PartResult(
      id: resultId,
      workoutId: 'workout',
      partId: partId,
      userId: userId,
      status: ResultStatus.done,
      scoreText: '10',
      createdAt: time,
      updatedAt: time,
      syncStatus: ResultSyncStatus.pending,
    ),
  );
}
