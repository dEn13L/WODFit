import '../../domain/entities/crossfit_workout.dart';
import '../../domain/entities/workout_template.dart';

class WorkoutTemplatePartModel {
  final String id;
  final String templateId;
  final String type;
  final String scoreType;
  final String title;
  final String description;
  final int sortOrder;

  const WorkoutTemplatePartModel({
    required this.id,
    required this.templateId,
    required this.type,
    this.scoreType = 'text',
    required this.title,
    this.description = '',
    this.sortOrder = 0,
  });

  factory WorkoutTemplatePartModel.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplatePartModel(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
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
      'template_id': templateId,
      'type': type,
      'score_type': scoreType,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
    };
  }

  WorkoutTemplatePart toDomain() {
    return WorkoutTemplatePart(
      id: id,
      templateId: templateId,
      type: WorkoutPartType.fromString(type),
      scoreType: WorkoutScoreType.fromString(scoreType),
      title: title,
      description: description,
      sortOrder: sortOrder,
    );
  }

  factory WorkoutTemplatePartModel.fromDomain(WorkoutTemplatePart entity) {
    return WorkoutTemplatePartModel(
      id: entity.id,
      templateId: entity.templateId,
      type: entity.type.name,
      scoreType: entity.scoreType.dbValue,
      title: entity.title,
      description: entity.description,
      sortOrder: entity.sortOrder,
    );
  }
}

class WorkoutTemplateModel {
  final String id;
  final String coachId;
  final String title;
  final String description;
  final String createdAt;
  final String updatedAt;
  final List<WorkoutTemplatePartModel> parts;

  const WorkoutTemplateModel({
    required this.id,
    required this.coachId,
    required this.title,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.parts = const [],
  });

  factory WorkoutTemplateModel.fromJson(Map<String, dynamic> json) {
    final partsList = (json['workout_template_parts'] as List<dynamic>?)
            ?.map((e) => WorkoutTemplatePartModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return WorkoutTemplateModel(
      id: json['id'] as String,
      coachId: json['coach_id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      parts: partsList,
    );
  }

  WorkoutTemplate toDomain() {
    return WorkoutTemplate(
      id: id,
      coachId: coachId,
      title: title,
      description: description,
      createdAt: (DateTime.tryParse(createdAt) ?? DateTime.now()).toLocal(),
      updatedAt: (DateTime.tryParse(updatedAt) ?? DateTime.now()).toLocal(),
      parts: parts.map((p) => p.toDomain()).toList(),
    );
  }
}
