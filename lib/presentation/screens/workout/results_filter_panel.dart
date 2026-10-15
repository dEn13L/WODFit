import 'package:flutter/material.dart';

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ResultsFilter>(
        segments: [
          ButtonSegment(
            value: ResultsFilter.all,
            label: Text('Все ${matrix.rows.length}'),
          ),
          ButtonSegment(
            value: ResultsFilter.completed,
            label: Text(
              'Выполнили ${matrix.count(ParticipantCompletion.completed)}',
            ),
          ),
          ButtonSegment(
            value: ResultsFilter.partial,
            label: Text(
              'Частично ${matrix.count(ParticipantCompletion.partial)}',
            ),
          ),
          ButtonSegment(
            value: ResultsFilter.empty,
            label: Text(
              'Не заполнили ${matrix.count(ParticipantCompletion.empty)}',
            ),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.first),
        showSelectedIcon: false,
      ),
    );
  }
}
