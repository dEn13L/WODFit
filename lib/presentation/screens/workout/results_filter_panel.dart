import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_extension.dart';
import 'results_matrix.dart';

class ResultsFilterPanel extends StatelessWidget {
  final ResultsMatrix matrix;
  final ResultsFilter selected;
  final ValueChanged<ResultsFilter> onChanged;

  const ResultsFilterPanel({
    super.key,
    required this.matrix,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              label: 'Выполнили',
              count: matrix.count(ParticipantCompletion.completed),
              color: appTheme.success,
            ),
            _SummaryChip(
              label: 'Частично',
              count: matrix.count(ParticipantCompletion.partial),
              color: appTheme.warning,
            ),
            _SummaryChip(
              label: 'Не заполнили',
              count: matrix.count(ParticipantCompletion.empty),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ResultsFilter>(
            segments: const [
              ButtonSegment(value: ResultsFilter.all, label: Text('Все')),
              ButtonSegment(value: ResultsFilter.completed, label: Text('Выполнили')),
              ButtonSegment(value: ResultsFilter.partial, label: Text('Частично')),
              ButtonSegment(value: ResultsFilter.empty, label: Text('Не заполнили')),
            ],
            selected: {selected},
            onSelectionChanged: (value) => onChanged(value.first),
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      side: BorderSide(color: color.withValues(alpha: 0.45)),
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text(
        '$label $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
