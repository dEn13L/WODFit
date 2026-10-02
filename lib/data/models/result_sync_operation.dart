import '../../domain/entities/part_result.dart';
import 'part_result_model.dart';

enum ResultSyncOperationType { create, update, delete }

class ResultSyncOperation {
  final String id;
  final ResultSyncOperationType type;
  final PartResult result;
  final DateTime occurredAt;
  final int attempts;
  final String? lastError;

  const ResultSyncOperation({
    required this.id,
    required this.type,
    required this.result,
    required this.occurredAt,
    this.attempts = 0,
    this.lastError,
  });

  ResultSyncOperation copyWith({int? attempts, String? lastError}) {
    return ResultSyncOperation(
      id: id,
      type: type,
      result: result,
      occurredAt: occurredAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError,
    );
  }

  factory ResultSyncOperation.fromJson(Map<String, dynamic> json) {
    return ResultSyncOperation(
      id: json['id'] as String,
      type: ResultSyncOperationType.values.byName(json['type'] as String),
      result: PartResultModel.fromJson(
        Map<String, dynamic>.from(json['result'] as Map),
      ).toDomain(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'result': PartResultModel.fromDomain(result).toJson(),
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
      };
}
