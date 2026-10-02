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

    expect(workout.publishedAt, DateTime.parse('2026-10-02T10:00:00Z').toLocal());
    expect(workout.viewedAt, DateTime.parse('2026-10-03T10:00:00Z').toLocal());
    expect(workout.isNew, isFalse);
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
