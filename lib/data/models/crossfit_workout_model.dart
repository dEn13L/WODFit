import '../../domain/entities/crossfit_workout.dart';

class WorkoutPartModel {
  final String id;
  final String workoutId;
  final String? type;
  final String? scoreType;
  final String title;
  final String description;
  final int sortOrder;

  const WorkoutPartModel({
    required this.id,
    required this.workoutId,
    this.type,
    this.scoreType,
    required this.title,
    this.description = '',
    this.sortOrder = 0,
  });

  factory WorkoutPartModel.fromJson(Map<String, dynamic> json) {
    return WorkoutPartModel(
      id: json['id'] as String,
      workoutId: json['workout_id'] as String,
      type: json['type'] as String?,
      scoreType: json['score_type'] as String?,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workout_id': workoutId,
      if (type != null) 'type': type,
      if (scoreType != null) 'score_type': scoreType,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
    };
  }

  WorkoutPart toDomain() {
    return WorkoutPart(
      id: id,
      workoutId: workoutId,
      type: type != null ? WorkoutPartType.fromString(type!) : null,
      scoreType: scoreType != null ? WorkoutScoreType.fromString(scoreType) : null,
      title: title,
      description: description,
      sortOrder: sortOrder,
    );
  }

  factory WorkoutPartModel.fromDomain(WorkoutPart entity) {
    return WorkoutPartModel(
      id: entity.id,
      workoutId: entity.workoutId,
      type: entity.type?.name,
      scoreType: entity.scoreType?.dbValue,
      title: entity.title,
      description: entity.description,
      sortOrder: entity.sortOrder,
    );
  }
}

class WorkoutAssignmentModel {
  final String workoutId;
  final String programId;
  final String assignedAt;
  final String? programName;

  // Backward compatibility aliases
  String get groupId => programId;
  String? get groupName => programName;

  const WorkoutAssignmentModel({
    required this.workoutId,
    required this.programId,
    required this.assignedAt,
    this.programName,
  });

  factory WorkoutAssignmentModel.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['programs'] != null && json['programs'] is Map) {
      name = json['programs']['name'] as String?;
    } else if (json['groups'] != null && json['groups'] is Map) {
      name = json['groups']['name'] as String?;
    }

    final pId = (json['program_id'] ?? json['group_id']) as String;

    return WorkoutAssignmentModel(
      workoutId: json['workout_id'] as String,
      programId: pId,
      assignedAt: (json['assigned_at'] as String?) ?? DateTime.now().toIso8601String(),
      programName: name,
    );
  }

  WorkoutAssignment toDomain() {
    return WorkoutAssignment(
      workoutId: workoutId,
      programId: programId,
      assignedAt: (DateTime.tryParse(assignedAt) ?? DateTime.now()).toLocal(),
      programName: programName,
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
      scheduledAt: (DateTime.tryParse(scheduledAt) ?? DateTime.now()).toLocal(),
      status: WorkoutStatus.fromString(status),
      createdAt: (DateTime.tryParse(createdAt) ?? DateTime.now()).toLocal(),
      updatedAt: (DateTime.tryParse(updatedAt) ?? DateTime.now()).toLocal(),
      parts: parts.map((p) => p.toDomain()).toList(),
      assignments: assignments.map((a) => a.toDomain()).toList(),
    );
  }
}
