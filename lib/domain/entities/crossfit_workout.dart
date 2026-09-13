import 'package:equatable/equatable.dart';

enum WorkoutPartType {
  warmup,
  weightlifting,
  strength,
  crossfitComplex,
  cooldown,
  stretch,
  mobility;

  static WorkoutPartType fromString(String value) {
    return WorkoutPartType.values.firstWhere(
      (type) => type.name.toLowerCase() == value.toLowerCase(),
      orElse: () => WorkoutPartType.crossfitComplex,
    );
  }

  String get displayName {
    switch (this) {
      case WorkoutPartType.warmup:
        return 'Разминка';
      case WorkoutPartType.weightlifting:
        return 'Тяжелая атлетика';
      case WorkoutPartType.strength:
        return 'Силовая часть';
      case WorkoutPartType.crossfitComplex:
        return 'Комплекс (WOD)';
      case WorkoutPartType.cooldown:
        return 'Заминка';
      case WorkoutPartType.stretch:
        return 'Растяжка';
      case WorkoutPartType.mobility:
        return 'Мобильность';
    }
  }
}

enum WorkoutStatus {
  draft,
  published;

  static WorkoutStatus fromString(String value) {
    return WorkoutStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == value.toLowerCase(),
      orElse: () => WorkoutStatus.draft,
    );
  }

  String get displayName => this == WorkoutStatus.published ? 'Опубликовано' : 'Черновик';
}

class WorkoutPart extends Equatable {
  final String id;
  final String workoutId;
  final WorkoutPartType type;
  final String title;
  final String description;
  final int sortOrder;

  const WorkoutPart({
    required this.id,
    required this.workoutId,
    required this.type,
    required this.title,
    this.description = '',
    this.sortOrder = 0,
  });

  @override
  List<Object?> get props => [id, workoutId, type, title, description, sortOrder];
}

class WorkoutAssignment extends Equatable {
  final String workoutId;
  final String groupId;
  final DateTime assignedAt;
  final String? groupName;

  const WorkoutAssignment({
    required this.workoutId,
    required this.groupId,
    required this.assignedAt,
    this.groupName,
  });

  @override
  List<Object?> get props => [workoutId, groupId, assignedAt, groupName];
}

class CrossfitWorkout extends Equatable {
  final String id;
  final String coachId;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final WorkoutStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkoutPart> parts;
  final List<WorkoutAssignment> assignments;

  const CrossfitWorkout({
    required this.id,
    required this.coachId,
    required this.title,
    this.description = '',
    required this.scheduledAt,
    this.status = WorkoutStatus.draft,
    required this.createdAt,
    required this.updatedAt,
    this.parts = const [],
    this.assignments = const [],
  });

  bool get isPublished => status == WorkoutStatus.published;

  CrossfitWorkout copyWith({
    String? id,
    String? coachId,
    String? title,
    String? description,
    DateTime? scheduledAt,
    WorkoutStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WorkoutPart>? parts,
    List<WorkoutAssignment>? assignments,
  }) {
    return CrossfitWorkout(
      id: id ?? this.id,
      coachId: coachId ?? this.coachId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parts: parts ?? this.parts,
      assignments: assignments ?? this.assignments,
    );
  }

  @override
  List<Object?> get props => [
        id,
        coachId,
        title,
        description,
        scheduledAt,
        status,
        createdAt,
        updatedAt,
        parts,
        assignments,
      ];
}
