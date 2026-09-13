import 'package:equatable/equatable.dart';
import 'user_profile.dart';

enum ResultStatus {
  done,
  scaled,
  notDone;

  static ResultStatus fromString(String value) {
    return ResultStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ResultStatus.done,
    );
  }

  String get displayName {
    switch (this) {
      case ResultStatus.done:
        return 'Выполнено (Rx)';
      case ResultStatus.scaled:
        return 'Масштабировано (Scaled)';
      case ResultStatus.notDone:
        return 'Не выполнено';
    }
  }
}

class PartResult extends Equatable {
  final String id;
  final String workoutId;
  final String partId;
  final String userId;
  final ResultStatus status;
  final String scoreText;
  final String note;
  final int? timeMs;
  final int? rounds;
  final int? reps;
  final double? weightKg;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserProfile? userProfile;

  const PartResult({
    required this.id,
    required this.workoutId,
    required this.partId,
    required this.userId,
    this.status = ResultStatus.done,
    this.scoreText = '',
    this.note = '',
    this.timeMs,
    this.rounds,
    this.reps,
    this.weightKg,
    required this.createdAt,
    required this.updatedAt,
    this.userProfile,
  });

  @override
  List<Object?> get props => [
        id,
        workoutId,
        partId,
        userId,
        status,
        scoreText,
        note,
        timeMs,
        rounds,
        reps,
        weightKg,
        createdAt,
        updatedAt,
        userProfile,
      ];
}
