import '../../domain/entities/crossfit_workout.dart';

class WorkoutPartModel {
  final String id;
  final String workoutId;
  final String type;
  final String scoreType;
  final String title;
  final String description;
  final int sortOrder;

  const WorkoutPartModel({
    required this.id,
    required this.workoutId,
    required this.type,
    this.scoreType = 'text',
    required this.title,
    this.description = '',
    this.sortOrder = 0,
  });

  factory WorkoutPartModel.fromJson(Map<String, dynamic> json) {
    return WorkoutPartModel(
      id: json['id'] as String,
      workoutId: json['workout_id'] as String,
      type: json['type'] as String,
      scoreType: (json['score_type'] as String?) ?? 'text',
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workout_id': workoutId,
      'type': type,
      'score_type': scoreType,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
    };
  }

  WorkoutPart toDomain() {
    return WorkoutPart(
      id: id,
      workoutId: workoutId,
      type: WorkoutPartType.fromString(type),
      scoreType: WorkoutScoreType.fromString(scoreType),
      title: title,
      description: description,
      sortOrder: sortOrder,
    );
  }

  factory WorkoutPartModel.fromDomain(WorkoutPart entity) {
    return WorkoutPartModel(
      id: entity.id,
      workoutId: entity.workoutId,
      type: entity.type.name,
      scoreType: entity.scoreType.dbValue,
      title: entity.title,
      description: entity.description,
      sortOrder: entity.sortOrder,
    );
  }
}

class WorkoutAssignmentModel {
  final String workoutId;
  final String groupId;
  final String assignedAt;
  final String? groupName;

  const WorkoutAssignmentModel({
    required this.workoutId,
    required this.groupId,
    required this.assignedAt,
    this.groupName,
  });

  factory WorkoutAssignmentModel.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['groups'] != null && json['groups'] is Map) {
      name = json['groups']['name'] as String?;
    }

    return WorkoutAssignmentModel(
      workoutId: json['workout_id'] as String,
      groupId: json['group_id'] as String,
      assignedAt: (json['assigned_at'] as String?) ?? DateTime.now().toIso8601String(),
      groupName: name,
    );
  }

  WorkoutAssignment toDomain() {
    return WorkoutAssignment(
      workoutId: workoutId,
      groupId: groupId,
      assignedAt: DateTime.tryParse(assignedAt) ?? DateTime.now(),
      groupName: groupName,
    );
  }
}

class CrossfitWorkoutModel {
  final String id;
  final String coachId;
  final String title;
  final String description;
  final String scheduledAt;
  final String status;
  final String createdAt;
  final String updatedAt;
  final List<WorkoutPartModel> parts;
  final List<WorkoutAssignmentModel> assignments;

  const CrossfitWorkoutModel({
    required this.id,
    required this.coachId,
    required this.title,
    this.description = '',
    required this.scheduledAt,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
    this.parts = const [],
    this.assignments = const [],
  });

  factory CrossfitWorkoutModel.fromJson(Map<String, dynamic> json) {
    final partsList = (json['workout_parts'] as List<dynamic>?)
            ?.map((e) => WorkoutPartModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    final assignmentsList = (json['workout_assignments'] as List<dynamic>?)
            ?.map((e) => WorkoutAssignmentModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return CrossfitWorkoutModel(
      id: json['id'] as String,
      coachId: json['coach_id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      scheduledAt: (json['scheduled_at'] as String?) ?? DateTime.now().toIso8601String(),
      status: (json['status'] as String?) ?? 'draft',
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      parts: partsList,
      assignments: assignmentsList,
    );
  }

  CrossfitWorkout toDomain() {
    return CrossfitWorkout(
      id: id,
      coachId: coachId,
      title: title,
      description: description,
      scheduledAt: DateTime.tryParse(scheduledAt) ?? DateTime.now(),
      status: WorkoutStatus.fromString(status),
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
      parts: parts.map((p) => p.toDomain()).toList(),
      assignments: assignments.map((a) => a.toDomain()).toList(),
    );
  }
}
