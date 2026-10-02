import 'dart:async';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/part_result.dart';
import '../datasources/result_sync_local_data_source.dart';
import '../models/result_sync_operation.dart';

typedef SendResultOperation = Future<PartResult> Function(ResultSyncOperation operation);

class ResultSyncService {
  static const _tag = 'ResultSyncService';
  static const maxAutomaticAttempts = 5;

  final ResultSyncLocalDataSource localDataSource;
  final SendResultOperation sendOperation;
  final bool scheduleAutomaticRetries;
  final String? Function()? currentUserId;
  Future<void>? _activeSync;
  Timer? _retryTimer;

  ResultSyncService({
    required this.localDataSource,
    required this.sendOperation,
    this.scheduleAutomaticRetries = true,
    this.currentUserId,
  });

  Future<void> enqueue(ResultSyncOperation operation) async {
    await localDataSource.putOperation(operation);
    if (operation.type == ResultSyncOperationType.delete) {
      await localDataSource.removeCachedResult(operation.result.id);
    } else {
      await localDataSource.cacheResult(
        operation.result.copyWith(syncStatus: ResultSyncStatus.pending),
      );
    }
  }

  Future<void> synchronize({bool force = false}) {
    return _activeSync ??= _runSynchronization(force: force).whenComplete(() => _activeSync = null);
  }

  Future<void> _runSynchronization({required bool force}) async {
    final operations = await localDataSource.getOperations();
    for (final operation in operations) {
      final activeUserId = currentUserId?.call();
      if (currentUserId != null && operation.result.userId != activeUserId) continue;
      if (!force && operation.attempts >= maxAutomaticAttempts) continue;
      try {
        final serverResult = await sendOperation(operation);
        await localDataSource.removeOperation(operation.id);
        final queued = await localDataSource.getOperations();
        final hasNewerOperation = queued.any(
          (item) => item.result.partId == operation.result.partId &&
              item.result.userId == operation.result.userId,
        );
        if (hasNewerOperation) continue;
        if (operation.type == ResultSyncOperationType.delete) {
          if (serverResult.deletedAt != null) {
            await localDataSource.removeCachedResult(operation.result.id);
          } else {
            await localDataSource.cacheResult(
              serverResult.copyWith(syncStatus: ResultSyncStatus.synced),
            );
          }
        } else {
          if (serverResult.id != operation.result.id) {
            await localDataSource.removeCachedResult(operation.result.id);
          }
          await localDataSource.cacheResult(
            serverResult.copyWith(syncStatus: ResultSyncStatus.synced),
          );
        }
      } catch (error, stackTrace) {
        final failed = operation.copyWith(
          attempts: operation.attempts + 1,
          lastError: error.toString(),
        );
        await localDataSource.putOperation(failed);
        final stillQueued = (await localDataSource.getOperations())
            .any((item) => item.id == failed.id);
        if (stillQueued && operation.type != ResultSyncOperationType.delete) {
          await localDataSource.cacheResult(
            operation.result.copyWith(
              syncStatus: failed.attempts >= maxAutomaticAttempts
                  ? ResultSyncStatus.failed
                  : ResultSyncStatus.pending,
            ),
          );
        }
        AppLogger.e(_tag, 'Не удалось синхронизировать операцию ${operation.id}', error, stackTrace);
        _scheduleRetry(failed.attempts);
        break;
      }
    }
  }

  void _scheduleRetry(int attempts) {
    if (!scheduleAutomaticRetries ||
        attempts >= maxAutomaticAttempts ||
        _retryTimer?.isActive == true) {
      return;
    }
    final exponent = attempts <= 1 ? 0 : (attempts > 6 ? 5 : attempts - 1);
    final seconds = 1 << exponent;
    _retryTimer = Timer(Duration(seconds: seconds), () => synchronize());
  }

  Future<void> cacheServerResults(Iterable<PartResult> results) async {
    final pending = await localDataSource.getOperations();
    final pendingKeys = pending.map((item) => '${item.result.partId}:${item.result.userId}').toSet();
    for (final result in results) {
      if (!pendingKeys.contains('${result.partId}:${result.userId}')) {
        await localDataSource.cacheResult(result.copyWith(syncStatus: ResultSyncStatus.synced));
      }
    }
  }

  Future<List<PartResult>> mergeWithCache(
    Iterable<PartResult> serverResults, {
    String? workoutId,
    String? userId,
  }) async {
    final operations = await localDataSource.getOperations();
    final deletedKeys = operations
        .where((item) => item.type == ResultSyncOperationType.delete)
        .map((item) => '${item.result.partId}:${item.result.userId}')
        .toSet();
    final merged = <String, PartResult>{
      for (final result in serverResults)
        if (!deletedKeys.contains('${result.partId}:${result.userId}'))
          result.id: result,
    };
    for (final cached in localDataSource.getCachedResults(workoutId: workoutId, userId: userId)) {
      if (cached.syncStatus != ResultSyncStatus.synced) {
        merged[cached.id] = cached;
      }
    }
    return merged.values.toList();
  }
}
