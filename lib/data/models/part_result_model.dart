import '../../domain/entities/part_result.dart';
import 'user_profile_model.dart';

class PartResultModel {
  final String id;
  final String workoutId;
  final String partId;
  final String userId;
  final String status;
  final String scoreText;
  final String note;
  final int? timeMs;
  final int? rounds;
  final int? reps;
  final double? weightKg;
  final double? distanceM;
  final int? calories;
  final String createdAt;
  final String updatedAt;
  final UserProfileModel? profile;

  const PartResultModel({
    required this.id,
    required this.workoutId,
    required this.partId,
    required this.userId,
    this.status = 'done',
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
    this.profile,
  });

  factory PartResultModel.fromJson(Map<String, dynamic> json) {
    UserProfileModel? profileModel;
    if (json['profiles'] != null && json['profiles'] is Map) {
      profileModel = UserProfileModel.fromJson(Map<String, dynamic>.from(json['profiles'] as Map));
    }

    return PartResultModel(
      id: json['id'] as String,
      workoutId: json['workout_id'] as String,
      partId: json['part_id'] as String,
      userId: json['user_id'] as String,
      status: (json['status'] as String?) ?? 'done',
      scoreText: (json['score_text'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      timeMs: (json['time_ms'] as num?)?.toInt(),
      rounds: (json['rounds'] as num?)?.toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      distanceM: json['distance_m'] != null ? (json['distance_m'] as num).toDouble() : null,
      calories: (json['calories'] as num?)?.toInt(),
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      profile: profileModel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workout_id': workoutId,
      'part_id': partId,
      'user_id': userId,
      'status': status,
      'score_text': scoreText,
      'note': note,
      'time_ms': timeMs,
      'rounds': rounds,
      'reps': reps,
      'weight_kg': weightKg,
      'distance_m': distanceM,
      'calories': calories,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  PartResult toDomain() {
    return PartResult(
      id: id,
      workoutId: workoutId,
      partId: partId,
      userId: userId,
      status: ResultStatus.fromString(status),
      scoreText: scoreText,
      note: note,
      timeMs: timeMs,
      rounds: rounds,
      reps: reps,
      weightKg: weightKg,
      distanceM: distanceM,
      calories: calories,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
      userProfile: profile?.toDomain(),
    );
  }
}
