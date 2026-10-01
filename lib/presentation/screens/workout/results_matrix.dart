import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import '../../../domain/entities/user_profile.dart';

enum ParticipantCompletion { completed, partial, empty }

enum ResultsFilter { all, completed, partial, empty }

class ParticipantResultRow {
  final UserProfile participant;
  final ParticipantCompletion completion;
  final Map<String, PartResult> resultsByPartId;

  const ParticipantResultRow({
    required this.participant,
    required this.completion,
    required this.resultsByPartId,
  });
}

class ResultsMatrix {
  final List<WorkoutPart> parts;
  final List<ParticipantResultRow> rows;

  const ResultsMatrix({required this.parts, required this.rows});

  int count(ParticipantCompletion completion) =>
      rows.where((row) => row.completion == completion).length;

  List<ParticipantResultRow> filtered(ResultsFilter filter) {
    if (filter == ResultsFilter.all) return rows;
    final completion = switch (filter) {
      ResultsFilter.completed => ParticipantCompletion.completed,
      ResultsFilter.partial => ParticipantCompletion.partial,
      ResultsFilter.empty => ParticipantCompletion.empty,
      ResultsFilter.all => throw StateError('Фильтр уже обработан'),
    };
    return rows.where((row) => row.completion == completion).toList();
  }
}

ResultsMatrix buildResultsMatrix({
  required List<WorkoutPart> parts,
  required List<UserProfile> participants,
  required List<PartResult> results,
}) {
  final sortedParts = List<WorkoutPart>.from(parts)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final validPartIds = sortedParts.map((part) => part.id).toSet();
  final resultsByUser = <String, Map<String, PartResult>>{};

  for (final result in results) {
    if (!validPartIds.contains(result.partId)) continue;
    resultsByUser.putIfAbsent(result.userId, () => {})[result.partId] = result;
  }

  final sortedParticipants = List<UserProfile>.from(participants)
    ..sort((a, b) => a.fullName.compareTo(b.fullName));
  final rows = sortedParticipants.map((participant) {
    final participantResults = resultsByUser[participant.id] ?? const <String, PartResult>{};
    final hasNotDone = participantResults.values.any(
      (result) => result.status == ResultStatus.notDone,
    );
    final completion = participantResults.isEmpty
        ? ParticipantCompletion.empty
        : participantResults.length == sortedParts.length && !hasNotDone
            ? ParticipantCompletion.completed
            : ParticipantCompletion.partial;

    return ParticipantResultRow(
      participant: participant,
      completion: completion,
      resultsByPartId: Map.unmodifiable(participantResults),
    );
  }).toList();

  return ResultsMatrix(parts: List.unmodifiable(sortedParts), rows: List.unmodifiable(rows));
}

extension ParticipantCompletionLabel on ParticipantCompletion {
  String get displayName => switch (this) {
        ParticipantCompletion.completed => 'Выполнил',
        ParticipantCompletion.partial => 'Частично',
        ParticipantCompletion.empty => 'Не заполнил',
      };
}
