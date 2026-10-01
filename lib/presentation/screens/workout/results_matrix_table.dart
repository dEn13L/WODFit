import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../domain/entities/part_result.dart';
import 'results_matrix.dart';

class ResultsMatrixTable extends StatelessWidget {
  final List<ParticipantResultRow> rows;
  final ResultsMatrix matrix;

  const ResultsMatrixTable({
    super.key,
    required this.rows,
    required this.matrix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest),
            columnSpacing: 24,
            columns: [
              const DataColumn(label: SizedBox(width: 190, child: Text('Участник'))),
              for (final part in matrix.parts)
                DataColumn(
                  label: SizedBox(
                    width: 180,
                    child: Tooltip(
                      message: part.title.trim().isEmpty ? 'Задание' : part.title.trim(),
                      child: Text(
                        part.title.trim().isEmpty ? 'Задание' : part.title.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(
                      Container(
                        width: 190,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.participant.fullName.trim().isEmpty ? 'Атлет' : row.participant.fullName.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              row.completion.displayName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _completionColor(context, row.completion),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final part in matrix.parts)
                      DataCell(_ResultCell(result: row.resultsByPartId[part.id])),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCell extends StatelessWidget {
  final PartResult? result;

  const _ResultCell({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentResult = result;
    if (currentResult == null) {
      return SizedBox(
        width: 180,
        child: Text('Нет результата', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return SizedBox(
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentResult.formattedScore,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700),
          ),
          Text(
            currentResult.status.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: _resultColor(context, currentResult.status)),
          ),
        ],
      ),
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
