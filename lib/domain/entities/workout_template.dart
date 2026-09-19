import 'package:equatable/equatable.dart';
import 'crossfit_workout.dart';

class WorkoutTemplatePart extends Equatable {
  final String id;
  final String templateId;
  final WorkoutPartType type;
  final WorkoutScoreType scoreType;
  final String title;
  final String description;
  final int sortOrder;

  const WorkoutTemplatePart({
    required this.id,
    required this.templateId,
    required this.type,
    this.scoreType = WorkoutScoreType.text,
    required this.title,
    this.description = '',
    this.sortOrder = 0,
  });

  WorkoutTemplatePart copyWith({
    String? id,
    String? templateId,
    WorkoutPartType? type,
    WorkoutScoreType? scoreType,
    String? title,
    String? description,
    int? sortOrder,
  }) {
    return WorkoutTemplatePart(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      type: type ?? this.type,
      scoreType: scoreType ?? this.scoreType,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [id, templateId, type, scoreType, title, description, sortOrder];
}

class WorkoutTemplate extends Equatable {
  final String id;
  final String coachId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkoutTemplatePart> parts;

  const WorkoutTemplate({
    required this.id,
    required this.coachId,
    required this.title,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.parts = const [],
  });

  String get workoutTypesSummary {
    if (parts.isEmpty) return 'Шаблон';
    return parts.map((p) => p.type.displayName).toSet().join(', ');
  }

  WorkoutTemplate copyWith({
    String? id,
    String? coachId,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WorkoutTemplatePart>? parts,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      coachId: coachId ?? this.coachId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parts: parts ?? this.parts,
    );
  }

  @override
  List<Object?> get props => [
        id,
        coachId,
        title,
        description,
        createdAt,
        updatedAt,
        parts,
      ];
}
