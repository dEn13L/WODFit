import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/utils/workout_date_formatter.dart';
import 'package:wod_fit/core/utils/workout_progress_formatter.dart';

void main() {
  test('formats list, detail, day and time consistently', () {
    final date = DateTime(2026, 9, 19, 19, 5);

    expect(WorkoutDateFormatter.formatList(date), 'Сб, 19.09.2026, 19:05');
    expect(
      WorkoutDateFormatter.formatDetail(date, 'Вечер'),
      'Суббота, 19 сентября 2026, 19:05 (Вечер)',
    );
    expect(WorkoutDateFormatter.formatDay(date), 'Суббота, 19 сентября 2026');
    expect(WorkoutDateFormatter.formatTime(date), '19:05');
    expect(
      WorkoutDateFormatter.formatPublished(date),
      'Опубликована 19 сентября 2026, 19:05',
    );
  });

  test('detail includes the supplied year without a label', () {
    expect(
      WorkoutDateFormatter.formatDetail(DateTime(2031, 9, 19, 7, 5)),
      'Пятница, 19 сентября 2031, 07:05',
    );
  });

  test('detail preserves label trimming and omits blank labels', () {
    final date = DateTime(2026, 9, 19, 19, 5);
    expect(
      WorkoutDateFormatter.formatDetail(date, '  Вечер  '),
      'Суббота, 19 сентября 2026, 19:05 (Вечер)',
    );
    expect(
      WorkoutDateFormatter.formatDetail(date, '  '),
      'Суббота, 19 сентября 2026, 19:05',
    );
  });

  test('detail converts UTC to local time across both year boundaries', () {
    // Running under positive and negative TZ offsets exercises both crossings.
    final localNewYear = DateTime(2031, 1, 1, 0, 30);
    final localYearEnd = DateTime(2030, 12, 31, 23, 30);
    expect(
      WorkoutDateFormatter.formatDetail(localNewYear.toUtc()),
      'Среда, 1 января 2031, 00:30',
    );
    expect(
      WorkoutDateFormatter.formatDetail(localYearEnd.toUtc()),
      'Вторник, 31 декабря 2030, 23:30',
    );
    if (localNewYear.timeZoneOffset > Duration.zero) {
      expect(localNewYear.toUtc().year, 2030);
    } else if (localYearEnd.timeZoneOffset < Duration.zero) {
      expect(localYearEnd.toUtc().year, 2031);
    }
  });

  test('formats completed and total progress as X/Y', () {
    expect(WorkoutProgressFormatter.format(0, 5), '0/5');
    expect(WorkoutProgressFormatter.format(3, 5), '3/5');
    expect(WorkoutProgressFormatter.format(5, 5), '5/5');
  });
}
