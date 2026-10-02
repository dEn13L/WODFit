import 'package:hive/hive.dart';

import '../../domain/entities/part_result.dart';
import '../models/part_result_model.dart';
import '../models/result_sync_operation.dart';

abstract class ResultSyncLocalDataSource {
  Future<List<ResultSyncOperation>> getOperations();
  Future<void> putOperation(ResultSyncOperation operation);
  Future<void> removeOperation(String operationId);
  Future<void> cacheResult(PartResult result);
  Future<void> removeCachedResult(String resultId);
  List<PartResult> getCachedResults({String? workoutId, String? userId});
  PartResult? getCachedResult(String resultId);
}

class HiveResultSyncLocalDataSource implements ResultSyncLocalDataSource {
  static const boxName = 'result_sync_box';
  static const _operationPrefix = 'operation:';
  static const _resultPrefix = 'result:';

  final Box<dynamic> box;

  HiveResultSyncLocalDataSource(this.box);

  @override
  Future<List<ResultSyncOperation>> getOperations() async {
    final operations = <ResultSyncOperation>[];
    for (final key in box.keys.where((key) => key.toString().startsWith(_operationPrefix))) {
      final value = box.get(key);
      if (value is Map) {
        operations.add(ResultSyncOperation.fromJson(Map<String, dynamic>.from(value)));
      }
    }
    operations.sort((a, b) {
      final time = a.occurredAt.compareTo(b.occurredAt);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
    return operations;
  }

  @override
  Future<void> putOperation(ResultSyncOperation operation) async {
    final existing = await getOperations();
    final sameResult = existing.where(
      (item) => item.result.partId == operation.result.partId && item.result.userId == operation.result.userId,
    );
    if (sameResult.any((queued) => _isAfter(queued, operation))) return;
    for (final queued in sameResult) {
      await removeOperation(queued.id);
    }
    await box.put('$_operationPrefix${operation.id}', operation.toJson());
  }

  bool _isAfter(ResultSyncOperation left, ResultSyncOperation right) {
    final time = left.occurredAt.compareTo(right.occurredAt);
    return time > 0 || (time == 0 && left.id.compareTo(right.id) > 0);
  }

  @override
  Future<void> removeOperation(String operationId) => box.delete('$_operationPrefix$operationId');

  @override
  Future<void> cacheResult(PartResult result) => box.put(
        '$_resultPrefix${result.id}',
        PartResultModel.fromDomain(result).toJson(),
      );

  @override
  Future<void> removeCachedResult(String resultId) => box.delete('$_resultPrefix$resultId');

  @override
  List<PartResult> getCachedResults({String? workoutId, String? userId}) {
    return box.keys
        .where((key) => key.toString().startsWith(_resultPrefix))
        .map(box.get)
        .whereType<Map>()
        .map((value) => PartResultModel.fromJson(Map<String, dynamic>.from(value)).toDomain())
        .where((result) => workoutId == null || result.workoutId == workoutId)
        .where((result) => userId == null || result.userId == userId)
        .toList();
  }

  @override
  PartResult? getCachedResult(String resultId) {
    final value = box.get('$_resultPrefix$resultId');
    return value is Map
        ? PartResultModel.fromJson(Map<String, dynamic>.from(value)).toDomain()
        : null;
  }
}
