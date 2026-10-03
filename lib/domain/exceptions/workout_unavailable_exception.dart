/// Сервер подтвердил отсутствие тренировки или доступа к ней.
class WorkoutUnavailableException implements Exception {
  const WorkoutUnavailableException();
  String get message =>
      'Тренировка удалена или недоступна. Обновите список тренировок.';
  @override
  String toString() => message;
}
