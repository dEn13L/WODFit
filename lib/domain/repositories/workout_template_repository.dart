import '../entities/workout_template.dart';

abstract class WorkoutTemplateRepository {
  Future<List<WorkoutTemplate>> getCoachTemplates();
  Future<WorkoutTemplate> getTemplateById(String templateId);
  Future<WorkoutTemplate> createTemplate({
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  });
  Future<WorkoutTemplate> updateTemplate({
    required String id,
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  });
  Future<void> deleteTemplate(String templateId);
  Future<WorkoutTemplate> duplicateTemplate(String templateId);
}
