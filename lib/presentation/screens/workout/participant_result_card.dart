import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../domain/entities/crossfit_workout.dart';
import '../../../domain/entities/part_result.dart';
import 'results_matrix.dart';

class ParticipantResultCard extends StatelessWidget {
  final ParticipantResultRow row;
  final List<WorkoutPart> parts;

  const ParticipantResultCard({
    super.key,
    required this.row,
    required this.parts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completionColor = _completionColor(context, row.completion);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _participantName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusLabel(
                  label: row.completion.displayName,
                  color: completionColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < parts.length; index++) ...[
              if (index > 0) Divider(color: theme.colorScheme.outlineVariant),
              _PartResultLine(
                part: parts[index],
                result: row.resultsByPartId[parts[index].id],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _participantName {
    final name = row.participant.fullName.trim();
    return name.isEmpty ? 'Атлет' : name;
  }
}

class _PartResultLine extends StatelessWidget {
  final WorkoutPart part;
  final PartResult? result;

  const _PartResultLine({required this.part, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentResult = result;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(part.title.trim().isEmpty ? 'Задание' : part.title.trim(), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (currentResult == null)
            Text(
              'Нет результата',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    currentResult.formattedScore,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  currentResult.status.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _resultColor(context, currentResult.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

Color _completionColor(BuildContext context, ParticipantCompletion completion) => switch (completion) {
      ParticipantCompletion.completed => context.appTheme.success,
      ParticipantCompletion.partial => context.appTheme.warning,
      ParticipantCompletion.empty => Theme.of(context).colorScheme.onSurfaceVariant,
    };

Color _resultColor(BuildContext context, ResultStatus status) => switch (status) {
      ResultStatus.done => context.appTheme.success,
      ResultStatus.scaled => context.appTheme.warning,
      ResultStatus.notDone => context.appTheme.destructive,
    };
