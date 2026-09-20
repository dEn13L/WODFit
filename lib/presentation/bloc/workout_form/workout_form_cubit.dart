import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../domain/entities/crossfit_workout.dart';
import '../../../../domain/repositories/crossfit_workout_repository.dart';

class WorkoutFormTask extends Equatable {
  final String id;
  final String title;
  final String description;

  const WorkoutFormTask({
    required this.id,
    this.title = '',
    this.description = '',
  });

  WorkoutFormTask copyWith({
    String? id,
    String? title,
    String? description,
  }) {
    return WorkoutFormTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
    };
  }

  factory WorkoutFormTask.fromMap(Map<dynamic, dynamic> map) {
    return WorkoutFormTask(
      id: (map['id'] as String?) ?? const Uuid().v4(),
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => [id, title, description];
}

enum WorkoutFormSubmitStatus { initial, loading, success, error }

class WorkoutFormState extends Equatable {
  final List<WorkoutFormTask> tasks;
  final Set<String> selectedProgramIds;
  final DateTime scheduledAt;
  final String sessionName;
  final bool isEditMode;
  final String? workoutId;
  final WorkoutStatus? initialStatus;
  final WorkoutFormSubmitStatus submitStatus;
  final String? errorMessage;
  final String? successMessage;
  final bool hasCachedDraft;
  final Map<String, dynamic>? cachedDraftData;

  const WorkoutFormState({
    required this.tasks,
    required this.selectedProgramIds,
    required this.scheduledAt,
    required this.sessionName,
    this.isEditMode = false,
    this.workoutId,
    this.initialStatus,
    this.submitStatus = WorkoutFormSubmitStatus.initial,
    this.errorMessage,
    this.successMessage,
    this.hasCachedDraft = false,
    this.cachedDraftData,
  });

  factory WorkoutFormState.initial({
    String? initialProgramId,
    List<String>? initialProgramIds,
  }) {
    final selectedPrograms = <String>{};
    if (initialProgramId != null) selectedPrograms.add(initialProgramId);
    if (initialProgramIds != null) selectedPrograms.addAll(initialProgramIds);

    return WorkoutFormState(
      tasks: [
        WorkoutFormTask(id: const Uuid().v4()),
      ],
      selectedProgramIds: selectedPrograms,
      scheduledAt: DateTime.now(),
      sessionName: '',
      isEditMode: false,
    );
  }

  WorkoutFormState copyWith({
    List<WorkoutFormTask>? tasks,
    Set<String>? selectedProgramIds,
    DateTime? scheduledAt,
    String? sessionName,
    bool? isEditMode,
    String? workoutId,
    WorkoutStatus? initialStatus,
    WorkoutFormSubmitStatus? submitStatus,
    String? errorMessage,
    String? successMessage,
    bool? hasCachedDraft,
    Map<String, dynamic>? cachedDraftData,
  }) {
    return WorkoutFormState(
      tasks: tasks ?? this.tasks,
      selectedProgramIds: selectedProgramIds ?? this.selectedProgramIds,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sessionName: sessionName ?? this.sessionName,
      isEditMode: isEditMode ?? this.isEditMode,
      workoutId: workoutId ?? this.workoutId,
      initialStatus: initialStatus ?? this.initialStatus,
      submitStatus: submitStatus ?? this.submitStatus,
      errorMessage: errorMessage,
      successMessage: successMessage,
      hasCachedDraft: hasCachedDraft ?? this.hasCachedDraft,
      cachedDraftData: cachedDraftData ?? this.cachedDraftData,
    );
  }

  @override
  List<Object?> get props => [
        tasks,
        selectedProgramIds,
        scheduledAt,
        sessionName,
        isEditMode,
        workoutId,
        initialStatus,
        submitStatus,
        errorMessage,
        successMessage,
        hasCachedDraft,
        cachedDraftData,
      ];
}

class WorkoutFormCubit extends Cubit<WorkoutFormState> {
  static const String _tag = 'WorkoutFormCubit';
  static const String _draftKey = 'draft_workout_form';
  static const String _boxName = 'workouts_box';

  final CrossfitWorkoutRepository workoutRepository;
  Timer? _debounceTimer;

  WorkoutFormCubit({
    required this.workoutRepository,
    CrossfitWorkout? workoutToEdit,
    String? initialProgramId,
    List<String>? initialProgramIds,
  }) : super(WorkoutFormState.initial(
          initialProgramId: initialProgramId,
          initialProgramIds: initialProgramIds,
        )) {
    if (workoutToEdit != null) {
      loadForEdit(workoutToEdit);
    } else {
      _checkCachedDraft();
    }
  }

  void loadForEdit(CrossfitWorkout workout) {
    final tasks = workout.parts.isNotEmpty
        ? workout.parts
            .map((p) => WorkoutFormTask(
                  id: p.id,
                  title: p.title,
                  description: p.description,
                ))
            .toList()
        : [WorkoutFormTask(id: const Uuid().v4())];

    emit(state.copyWith(
      tasks: tasks,
      selectedProgramIds: workout.assignedProgramIds.toSet(),
      scheduledAt: workout.scheduledAt.toLocal(),
      sessionName: workout.title,
      isEditMode: true,
      workoutId: workout.id,
      initialStatus: workout.status,
    ));
  }

  Future<void> _checkCachedDraft() async {
    try {
      final box = await _getBox();
      final draft = box.get(_draftKey);
      if (draft is Map && draft.isNotEmpty) {
        final draftMap = Map<String, dynamic>.from(draft);
        final hasContent = (draftMap['tasks'] as List?)?.isNotEmpty == true ||
            (draftMap['session_name'] as String?)?.isNotEmpty == true ||
            (draftMap['program_ids'] as List?)?.isNotEmpty == true;

        if (hasContent) {
          emit(state.copyWith(
            hasCachedDraft: true,
            cachedDraftData: draftMap,
          ));
        }
      }
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при чтении кэша черновика', e, st);
    }
  }

  void restoreCachedDraft() {
    final draft = state.cachedDraftData;
    if (draft == null) return;

    try {
      final rawTasks = draft['tasks'] as List<dynamic>?;
      final tasks = rawTasks != null && rawTasks.isNotEmpty
          ? rawTasks
              .map((t) => WorkoutFormTask.fromMap(Map<dynamic, dynamic>.from(t as Map)))
              .toList()
          : [WorkoutFormTask(id: const Uuid().v4())];

      final rawProgramIds = draft['program_ids'] as List<dynamic>?;
      final programIds = rawProgramIds?.map((e) => e.toString()).toSet() ?? <String>{};

      final rawScheduledAt = draft['scheduled_at'] as String?;
      final scheduledAt = rawScheduledAt != null
          ? DateTime.tryParse(rawScheduledAt)?.toLocal() ?? DateTime.now()
          : DateTime.now();

      final sessionName = (draft['session_name'] as String?) ?? '';

      emit(state.copyWith(
        tasks: tasks,
        selectedProgramIds: programIds,
        scheduledAt: scheduledAt,
        sessionName: sessionName,
        hasCachedDraft: false,
      ));
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при восстановлении черновика', e, st);
    }
  }

  void dismissCachedDraft() {
    emit(state.copyWith(hasCachedDraft: false));
    clearDraftCache();
  }

  void addTask({String title = '', String description = ''}) {
    final updated = List<WorkoutFormTask>.from(state.tasks)
      ..add(WorkoutFormTask(
        id: const Uuid().v4(),
        title: title,
        description: description,
      ));
    emit(state.copyWith(tasks: updated));
    _scheduleAutoSave();
  }

  void removeTask(String taskId) {
    if (state.tasks.length <= 1) {
      // Keep at least one empty task
      emit(state.copyWith(
        tasks: [WorkoutFormTask(id: const Uuid().v4())],
      ));
    } else {
      final updated = state.tasks.where((t) => t.id != taskId).toList();
      emit(state.copyWith(tasks: updated));
    }
    _scheduleAutoSave();
  }

  void reorderTasks(int oldIndex, int newIndex) {
    final updated = List<WorkoutFormTask>.from(state.tasks);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    emit(state.copyWith(tasks: updated));
    _scheduleAutoSave();
  }

  void setTaskTitle(String taskId, String title) {
    final updated = state.tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(title: title);
      }
      return t;
    }).toList();
    emit(state.copyWith(tasks: updated));
    _scheduleAutoSave();
  }

  void setTaskDescription(String taskId, String description) {
    final updated = state.tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(description: description);
      }
      return t;
    }).toList();
    emit(state.copyWith(tasks: updated));
    _scheduleAutoSave();
  }

  void toggleProgram(String programId) {
    final updated = Set<String>.from(state.selectedProgramIds);
    if (updated.contains(programId)) {
      updated.remove(programId);
    } else {
      updated.add(programId);
    }
    emit(state.copyWith(selectedProgramIds: updated));
    _scheduleAutoSave();
  }

  void setPrograms(Set<String> programIds) {
    emit(state.copyWith(selectedProgramIds: Set<String>.from(programIds)));
    _scheduleAutoSave();
  }

  void setDateTime(DateTime dateTime) {
    emit(state.copyWith(scheduledAt: dateTime));
    _scheduleAutoSave();
  }

  void setSessionName(String sessionName) {
    emit(state.copyWith(sessionName: sessionName));
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (state.isEditMode) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveDraftToCache();
    });
  }

  Future<void> _saveDraftToCache() async {
    if (state.isEditMode) return;
    try {
      final box = await _getBox();
      final draftData = {
        'tasks': state.tasks.map((t) => t.toMap()).toList(),
        'program_ids': state.selectedProgramIds.toList(),
        'scheduled_at': state.scheduledAt.toIso8601String(),
        'session_name': state.sessionName,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await box.put(_draftKey, draftData);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при автосохранении черновика в кэш', e, st);
    }
  }

  Future<void> clearDraftCache() async {
    try {
      final box = await _getBox();
      await box.delete(_draftKey);
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при очистке кэша черновика', e, st);
    }
  }

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  Future<void> saveDraft() async {
    await _submitWorkout(publish: false);
  }

  Future<void> publishWorkout() async {
    // 14. Валидация публикации: >=1 программа, >=1 задание, у каждого задания непустое название.
    if (state.selectedProgramIds.isEmpty) {
      emit(state.copyWith(
        submitStatus: WorkoutFormSubmitStatus.error,
        errorMessage: 'Для публикации выберите хотя бы одну программу',
      ));
      return;
    }

    if (state.tasks.isEmpty) {
      emit(state.copyWith(
        submitStatus: WorkoutFormSubmitStatus.error,
        errorMessage: 'Добавьте хотя бы одно задание для публикации',
      ));
      return;
    }

    final hasEmptyTitle = state.tasks.any((t) => t.title.trim().isEmpty);
    if (hasEmptyTitle) {
      emit(state.copyWith(
        submitStatus: WorkoutFormSubmitStatus.error,
        errorMessage: 'Заполните название для всех заданий',
      ));
      return;
    }

    await _submitWorkout(publish: true);
  }

  Future<void> _submitWorkout({required bool publish}) async {
    emit(state.copyWith(submitStatus: WorkoutFormSubmitStatus.loading));

    try {
      // Convert tasks to domain WorkoutPart
      final parts = state.tasks.asMap().entries.map((entry) {
        final index = entry.key;
        final task = entry.value;
        return WorkoutPart(
          id: task.id,
          workoutId: state.workoutId ?? '',
          title: task.title.trim(),
          description: task.description.trim(),
          sortOrder: index,
        );
      }).toList();

      if (state.isEditMode && state.workoutId != null) {
        await workoutRepository.updateWorkout(
          id: state.workoutId!,
          title: state.sessionName.trim(),
          description: '',
          scheduledAt: state.scheduledAt,
          parts: parts,
          programIds: state.selectedProgramIds.toList(),
          status: publish ? WorkoutStatus.published : WorkoutStatus.draft,
        );
        emit(state.copyWith(
          submitStatus: WorkoutFormSubmitStatus.success,
          successMessage: publish ? 'Тренировка опубликована' : 'Черновик сохранён',
        ));
      } else {
        await workoutRepository.createWorkout(
          title: state.sessionName.trim(),
          description: '',
          scheduledAt: state.scheduledAt,
          parts: parts,
          programIds: state.selectedProgramIds.toList(),
          publish: publish,
        );
        await clearDraftCache();
        emit(state.copyWith(
          submitStatus: WorkoutFormSubmitStatus.success,
          successMessage: publish ? 'Тренировка опубликована' : 'Черновик сохранён',
        ));
      }
    } catch (e, st) {
      AppLogger.e(_tag, 'Ошибка при сохранении тренировки', e, st);
      emit(state.copyWith(
        submitStatus: WorkoutFormSubmitStatus.error,
        errorMessage: 'Не удалось сохранить: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
