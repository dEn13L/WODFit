import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/domain/entities/crossfit_workout.dart';
import 'package:wod_fit/domain/entities/part_result.dart';
import 'package:wod_fit/domain/entities/user_profile.dart';
import 'package:wod_fit/presentation/screens/workout/results_matrix.dart';

void main() {
  final now = DateTime(2026);
  final participants = [
    UserProfile(id: 'empty', email: '', fullName: 'Виктор', role: UserRole.client, createdAt: now),
    UserProfile(id: 'complete', email: '', fullName: 'Анна', role: UserRole.client, createdAt: now),
    UserProfile(id: 'partial', email: '', fullName: 'Борис', role: UserRole.client, createdAt: now),
    UserProfile(id: 'not-done', email: '', fullName: 'Галина', role: UserRole.client, createdAt: now),
  ];
  final parts = [
    WorkoutPart(id: 'second', workoutId: 'workout', title: 'Второе', sortOrder: 2),
    WorkoutPart(id: 'first', workoutId: 'workout', title: 'Первое', sortOrder: 1),
  ];

  PartResult result(String id, String userId, String partId, {ResultStatus status = ResultStatus.done}) {
    return PartResult(
      id: id,
      workoutId: 'workout',
      partId: partId,
      userId: userId,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('builds participant categories and keeps participants without results', () {
    final matrix = buildResultsMatrix(
      parts: parts,
      participants: participants,
      results: [
        result('1', 'complete', 'first'),
        result('2', 'complete', 'second', status: ResultStatus.scaled),
        result('3', 'partial', 'first'),
        result('4', 'not-done', 'first'),
        result('5', 'not-done', 'second', status: ResultStatus.notDone),
      ],
    );

    expect(matrix.parts.map((part) => part.id), ['first', 'second']);
    expect(matrix.rows.map((row) => row.participant.fullName), ['Анна', 'Борис', 'Виктор', 'Галина']);
    expect(matrix.count(ParticipantCompletion.completed), 1);
    expect(matrix.count(ParticipantCompletion.partial), 2);
    expect(matrix.count(ParticipantCompletion.empty), 1);
  });

  test('filters use the same computed categories', () {
    final matrix = buildResultsMatrix(
      parts: parts,
      participants: participants,
      results: [
        result('1', 'complete', 'first'),
        result('2', 'complete', 'second'),
        result('3', 'partial', 'first'),
      ],
    );

    expect(matrix.filtered(ResultsFilter.all), hasLength(4));
    expect(matrix.filtered(ResultsFilter.completed).single.participant.id, 'complete');
    expect(matrix.filtered(ResultsFilter.partial).single.participant.id, 'partial');
    expect(matrix.filtered(ResultsFilter.empty).map((row) => row.participant.id), containsAll(['empty', 'not-done']));
  });

  test('a notDone result makes an otherwise complete row partial', () {
    final matrix = buildResultsMatrix(
      parts: parts,
      participants: [participants.last],
      results: [
        result('1', 'not-done', 'first'),
        result('2', 'not-done', 'second', status: ResultStatus.notDone),
      ],
    );

    expect(matrix.rows.single.completion, ParticipantCompletion.partial);
  });
}
