import 'package:equatable/equatable.dart';
import 'crossfit_workout.dart';
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
  final WorkoutScoreType? scoreType;
  final ResultStatus status;
  final String scoreText;
  final String note;
  final int? timeMs;
  final int? rounds;
  final int? reps;
  final double? weightKg;
  final double? distanceM;
  final int? calories;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserProfile? userProfile;

  const PartResult({
    required this.id,
    required this.workoutId,
    required this.partId,
    required this.userId,
    this.scoreType,
    this.status = ResultStatus.done,
    this.scoreText = '',
    this.note = '',
    this.timeMs,
    this.rounds,
    this.reps,
    this.weightKg,
    this.distanceM,
    this.calories,
    required this.createdAt,
    required this.updatedAt,
    this.userProfile,
  });

  /// Человекочитаемое представление результата с форматированием по score_type (fallback: text)
  String get formattedScore {
    final type = scoreType ?? WorkoutScoreType.text;
    switch (type) {
      case WorkoutScoreType.none:
        return status == ResultStatus.done ? 'Выполнено' : status.displayName;
      case WorkoutScoreType.time:
        if (timeMs != null) {
          final totalSec = timeMs! ~/ 1000;
          final m = totalSec ~/ 60;
          final s = totalSec % 60;
          return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        }
        return scoreText.isNotEmpty ? scoreText : (status == ResultStatus.done ? 'Выполнено' : status.displayName);
      case WorkoutScoreType.roundsReps:
        if (rounds != null) {
          if (reps != null && reps! > 0) {
            return '$rounds рд + $reps повт';
          }
          return '$rounds рд';
        }
        return scoreText.isNotEmpty ? scoreText : (status == ResultStatus.done ? 'Выполнено' : status.displayName);
      case WorkoutScoreType.weight:
        if (weightKg != null) {
          final wStr = weightKg!.truncateToDouble() == weightKg! ? weightKg!.toInt().toString() : weightKg!.toString();
          if (reps != null && reps! > 0) {
            return '$wStr кг ($reps повт)';
          }
          return '$wStr кг';
        }
        return scoreText.isNotEmpty ? scoreText : (status == ResultStatus.done ? 'Выполнено' : status.displayName);
      case WorkoutScoreType.reps:
        if (reps != null) {
          return '$reps повт';
        }
        return scoreText.isNotEmpty ? scoreText : (status == ResultStatus.done ? 'Выполнено' : status.displayName);
      case WorkoutScoreType.distance:
        if (distanceM != null) {
          final dStr = distanceM!.truncateToDouble() == distanceM! ? distanceM!.toInt().toString() : distanceM!.toString();
          return '$dStr м';
        }
        return scoreText.isNotEmpty ? scoreText : (status == ResultStatus.done ? 'Выполнено' : status.displayName);
      case WorkoutScoreType.calories:
        if (calories != null) {
          return '$calories кал';
        }
        return scoreText.isNotEmpty ? scoreText : (status == ResultStatus.done ? 'Выполнено' : status.displayName);
      case WorkoutScoreType.text:
        if (scoreText.isNotEmpty) {
          return scoreText;
        }
        return status == ResultStatus.done ? 'Выполнено' : status.displayName;
    }
  }

  PartResult copyWith({
    String? id,
    String? workoutId,
    String? partId,
    String? userId,
    WorkoutScoreType? scoreType,
    ResultStatus? status,
    String? scoreText,
    String? note,
    int? timeMs,
    int? rounds,
    int? reps,
    double? weightKg,
    double? distanceM,
    int? calories,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? userProfile,
  }) {
    return PartResult(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      partId: partId ?? this.partId,
      userId: userId ?? this.userId,
      scoreType: scoreType ?? this.scoreType,
      status: status ?? this.status,
      scoreText: scoreText ?? this.scoreText,
      note: note ?? this.note,
      timeMs: timeMs ?? this.timeMs,
      rounds: rounds ?? this.rounds,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      distanceM: distanceM ?? this.distanceM,
      calories: calories ?? this.calories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userProfile: userProfile ?? this.userProfile,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workoutId,
        partId,
        userId,
        scoreType,
        status,
        scoreText,
        note,
        timeMs,
        rounds,
        reps,
        weightKg,
        distanceM,
        calories,
        createdAt,
        updatedAt,
        userProfile,
      ];
}
