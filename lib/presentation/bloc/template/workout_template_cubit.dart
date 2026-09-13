import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/workout_template.dart';
import '../../../domain/repositories/workout_template_repository.dart';

abstract class WorkoutTemplateState extends Equatable {
  const WorkoutTemplateState();

  @override
  List<Object?> get props => [];
}

class WorkoutTemplateInitial extends WorkoutTemplateState {
  const WorkoutTemplateInitial();
}

class WorkoutTemplateLoading extends WorkoutTemplateState {
  const WorkoutTemplateLoading();
}

class WorkoutTemplateLoaded extends WorkoutTemplateState {
  final List<WorkoutTemplate> templates;
  final String? successMessage;

  const WorkoutTemplateLoaded({
    required this.templates,
    this.successMessage,
  });

  @override
  List<Object?> get props => [templates, successMessage];
}

class WorkoutTemplateError extends WorkoutTemplateState {
  final String message;

  const WorkoutTemplateError(this.message);

  @override
  List<Object?> get props => [message];
}

class WorkoutTemplateCubit extends Cubit<WorkoutTemplateState> {
  static const String _tag = 'WorkoutTemplateCubit';
  final WorkoutTemplateRepository templateRepository;

  WorkoutTemplateCubit({required this.templateRepository}) : super(const WorkoutTemplateInitial());

  Future<void> loadTemplates() async {
    emit(const WorkoutTemplateLoading());
    try {
      final templates = await templateRepository.getCoachTemplates();
      emit(WorkoutTemplateLoaded(templates: templates));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadTemplates failed', e, st);
      emit(WorkoutTemplateError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> createTemplate({
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    try {
      final newTemplate = await templateRepository.createTemplate(
        title: title,
        description: description,
        parts: parts,
      );
      final currentList = state is WorkoutTemplateLoaded
          ? (state as WorkoutTemplateLoaded).templates
          : <WorkoutTemplate>[];
      emit(WorkoutTemplateLoaded(
        templates: [newTemplate, ...currentList.where((t) => t.id != newTemplate.id)],
        successMessage: 'Шаблон "${newTemplate.title}" сохранён',
      ));
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'createTemplate failed', e, st);
      emit(WorkoutTemplateError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> updateTemplate({
    required String id,
    required String title,
    required String description,
    required List<WorkoutTemplatePart> parts,
  }) async {
    try {
      final updated = await templateRepository.updateTemplate(
        id: id,
        title: title,
        description: description,
        parts: parts,
      );
      if (state is WorkoutTemplateLoaded) {
        final current = (state as WorkoutTemplateLoaded).templates;
        final updatedList = current.map((t) => t.id == id ? updated : t).toList();
        emit(WorkoutTemplateLoaded(
          templates: updatedList,
          successMessage: 'Шаблон обновлен',
        ));
      } else {
        await loadTemplates();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'updateTemplate failed', e, st);
      emit(WorkoutTemplateError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> deleteTemplate(String id) async {
    try {
      await templateRepository.deleteTemplate(id);
      if (state is WorkoutTemplateLoaded) {
        final current = (state as WorkoutTemplateLoaded).templates;
        emit(WorkoutTemplateLoaded(
          templates: current.where((t) => t.id != id).toList(),
          successMessage: 'Шаблон удален',
        ));
      } else {
        await loadTemplates();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'deleteTemplate failed', e, st);
      emit(WorkoutTemplateError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> duplicateTemplate(String id) async {
    try {
      final copy = await templateRepository.duplicateTemplate(id);
      if (state is WorkoutTemplateLoaded) {
        final current = (state as WorkoutTemplateLoaded).templates;
        emit(WorkoutTemplateLoaded(
          templates: [copy, ...current],
          successMessage: 'Шаблон продублирован как "${copy.title}"',
        ));
      } else {
        await loadTemplates();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'duplicateTemplate failed', e, st);
      emit(WorkoutTemplateError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }
}
