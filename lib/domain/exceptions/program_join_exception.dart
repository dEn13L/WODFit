/// Ошибка вступления, которую безопасно показывать пользователю.
class ProgramJoinException implements Exception {
  final String message;

  const ProgramJoinException(this.message);

  @override
  String toString() => message;
}
