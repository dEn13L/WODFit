import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/core/utils/workout_date_formatter.dart';
import 'package:wod_fit/core/utils/workout_progress_formatter.dart';

void main() {
  test('formats list, detail, day and time consistently', () {
    final date = DateTime(2026, 9, 19, 19, 5);

    expect(WorkoutDateFormatter.formatList(date), 'Сб, 19.09.2026, 19:05');
    expect(
      WorkoutDateFormatter.formatDetail(date, 'Вечер'),
      'Суббота, 19 сентября, 19:05 (Вечер)',
    );
    expect(
      WorkoutDateFormatter.formatDay(date),
      'Суббота, 19 сентября 2026',
    );
    expect(WorkoutDateFormatter.formatTime(date), '19:05');
  });

  test('formats completed and total progress as X/Y', () {
    expect(WorkoutProgressFormatter.format(0, 5), '0/5');
    expect(WorkoutProgressFormatter.format(3, 5), '3/5');
    expect(WorkoutProgressFormatter.format(5, 5), '5/5');
  });
}
