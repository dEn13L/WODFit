/// Ошибка сохранения тренировки, которую безопасно показывать пользователю.
class WorkoutSaveException implements Exception {
  final String message;

  final bool restoreRemovedTasks;

  const WorkoutSaveException(this.message, {this.restoreRemovedTasks = false});

  @override
  String toString() => message;
}
