class WorkoutDateFormatter {
  static const List<String> _weekdaysFull = [
    '',
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  static const List<String> _weekdaysShort = [
    '',
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  static const List<String> _monthsGenitive = [
    '',
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static String _appendLabel(String base, String? label) {
    if (label == null || label.trim().isEmpty) {
      return base;
    }
    return '$base (${label.trim()})';
  }

  /// Формат дня без времени:
  /// "Четверг, 23 сентября 2026"
  static String formatDay(DateTime dateTime, [String? label]) {
    final local = dateTime.toLocal();
    final weekday = _weekdaysFull[local.weekday];
    final day = local.day;
    final month = _monthsGenitive[local.month];
    final year = local.year;
    final base = '$weekday, $day $month $year';
    return _appendLabel(base, label);
  }

  /// Формат для деталей:
  /// "Вторник, 22 сентября, 07:00" или "Вторник, 22 сентября, 07:00 (Сессия 1)"
  static String formatDetail(DateTime dateTime, [String? label]) {
    final local = dateTime.toLocal();
    final weekday = _weekdaysFull[local.weekday];
    final day = local.day;
    final month = _monthsGenitive[local.month];
    final time = _formatTime(local);
    final base = '$weekday, $day $month, $time';
    return _appendLabel(base, label);
  }

  /// Формат для списков:
  /// "Вт, 22.09.2026, 07:00" или "Вт, 22.09.2026, 07:00 (Сессия 1)"
  static String formatList(DateTime dateTime, [String? label]) {
    final local = dateTime.toLocal();
    final weekday = _weekdaysShort[local.weekday];
    final day = _pad2(local.day);
    final month = _pad2(local.month);
    final year = local.year;
    final time = _formatTime(local);
    final base = '$weekday, $day.$month.$year, $time';
    return _appendLabel(base, label);
  }

  /// Формат сегодня/завтра:
  /// "Сегодня, 07:00" или "Сегодня, 07:00 (Утро)"
  static String formatTodayTomorrow(DateTime dateTime, [String? label]) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final diffDays = targetDay.difference(today).inDays;

    String base;
    if (diffDays == 0) {
      base = 'Сегодня, ${_formatTime(local)}';
    } else if (diffDays == 1) {
      base = 'Завтра, ${_formatTime(local)}';
    } else if (diffDays == -1) {
      base = 'Вчера, ${_formatTime(local)}';
    } else {
      return formatList(dateTime, label);
    }
    return _appendLabel(base, label);
  }

  /// Формат только времени с опциональным лейблом:
  /// "07:00" или "07:00 (Утро)"
  static String formatTime(DateTime dateTime, [String? label]) {
    final local = dateTime.toLocal();
    final base = _formatTime(local);
    return _appendLabel(base, label);
  }
}
