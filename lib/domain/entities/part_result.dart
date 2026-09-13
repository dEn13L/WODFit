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

  /// Человекочитаемое представление результата с обратной совместимостью
  String get formattedScore {
    if (scoreText.isNotEmpty) {
      return scoreText;
    }
    final items = <String>[];
    if (timeMs != null) {
      final totalSec = timeMs! ~/ 1000;
      final m = totalSec ~/ 60;
      final s = totalSec % 60;
      items.add('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
    }
    if (rounds != null) {
      items.add('$rounds рд');
    }
    if (reps != null) {
      items.add('$reps повт');
    }
    if (weightKg != null) {
      items.add('$weightKg кг');
    }
    if (distanceM != null) {
      final isInt = distanceM!.truncateToDouble() == distanceM;
      items.add('${isInt ? distanceM!.toInt() : distanceM} м');
    }
    if (calories != null) {
      items.add('$calories кал');
    }
    if (items.isEmpty) {
      return status == ResultStatus.done ? 'Выполнено' : status.displayName;
    }
    return items.join(' • ');
  }

  PartResult copyWith({
    String? id,
    String? workoutId,
    String? partId,
    String? userId,
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
