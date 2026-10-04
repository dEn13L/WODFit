import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/data/models/crossfit_workout_model.dart';

void main() {
  test('maps publication and current user view timestamps', () {
    final workout = CrossfitWorkoutModel.fromJson({
      'id': 'workout-id',
      'coach_id': 'coach-id',
      'title': '',
      'scheduled_at': '2026-10-05T10:00:00Z',
      'status': 'published',
      'created_at': '2026-10-01T10:00:00Z',
      'updated_at': '2026-10-02T10:00:00Z',
      'published_at': '2026-10-02T10:00:00Z',
      'workout_views': [
        {'viewed_at': '2026-10-03T10:00:00Z'},
      ],
    }).toDomain();

    expect(
      workout.publishedAt,
      DateTime.parse('2026-10-02T10:00:00Z').toLocal(),
    );
    expect(workout.viewedAt, DateTime.parse('2026-10-03T10:00:00Z').toLocal());
    expect(workout.isNew, isFalse);
  });

  test('program numbers are independent and legacy title is hidden', () {
    final workout = CrossfitWorkoutModel.fromJson({
      'id': 'w',
      'coach_id': 'c',
      'title': 'Старое уточнение',
      'workout_assignments': [
        {
          'workout_id': 'w',
          'program_id': 'a',
          'workout_number': 13,
          'programs': {'name': 'A'},
        },
        {
          'workout_id': 'w',
          'program_id': 'b',
          'workout_number': 2,
          'programs': {'name': 'B'},
        },
      ],
    }).toDomain();
    expect(workout.nameForProgram('a'), 'Тренировка 13');
    expect(workout.nameForProgram('b'), 'Тренировка 2');
    expect(workout.nameForProgram(), 'A: Тренировка 13 · B: Тренировка 2');
    expect(workout.nameForProgram('unassigned'), 'Тренировка');
  });

  test('published workout without a view is new', () {
    final workout = CrossfitWorkoutModel.fromJson({
      'id': 'workout-id',
      'coach_id': 'coach-id',
      'title': '',
      'scheduled_at': '2026-10-05T10:00:00Z',
      'status': 'published',
      'created_at': '2026-10-01T10:00:00Z',
      'updated_at': '2026-10-02T10:00:00Z',
      'published_at': '2026-10-02T10:00:00Z',
      'workout_views': <Map<String, String>>[],
    }).toDomain();

    expect(workout.isNew, isTrue);
  });
}
