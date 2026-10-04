import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme_extension.dart';
import '../../core/utils/workout_date_formatter.dart';
import '../../domain/entities/crossfit_workout.dart';

/// Календарь использует уже загруженный ролевой список, без новых запросов.
class WorkoutCalendar extends StatefulWidget {
  final List<CrossfitWorkout> workouts;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool monthView;
  final bool showDrafts;

  const WorkoutCalendar({
    super.key,
    required this.workouts,
    required this.selectedDate,
    required this.onDateSelected,
    this.monthView = false,
    this.showDrafts = false,
  });

  @override
  State<WorkoutCalendar> createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<WorkoutCalendar> {
  late DateTime _visibleDate;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _visibleDate = WorkoutDateFormatter.localDay(widget.selectedDate);
    _expanded = widget.monthView;
  }

  @override
  void didUpdateWidget(WorkoutCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!WorkoutDateFormatter.sameDay(
      oldWidget.selectedDate,
      widget.selectedDate,
    )) {
      _visibleDate = WorkoutDateFormatter.localDay(widget.selectedDate);
    }
  }

  void _select(DateTime date) {
    setState(() => _visibleDate = date);
    widget.onDateSelected(date);
  }

  void _move(int direction) {
    if (_expanded) {
      final month = DateTime(_visibleDate.year, _visibleDate.month + direction);
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      _select(
        DateTime(month.year, month.month, _visibleDate.day.clamp(1, lastDay)),
      );
    } else {
      // Конструктор, а не Duration: переходы DST не сдвигают день.
      _select(
        DateTime(
          _visibleDate.year,
          _visibleDate.month,
          _visibleDate.day + direction * 7,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final start = _expanded
        ? DateTime(_visibleDate.year, _visibleDate.month)
        : DateTime(
            _visibleDate.year,
            _visibleDate.month,
            _visibleDate.day - _visibleDate.weekday + 1,
          );
    final leading = _expanded ? start.weekday - 1 : 0;
    final days = _expanded ? DateTime(start.year, start.month + 1, 0).day : 7;
    final rows = ((leading + days) / 7).ceil();
    final counts = <DateTime, ({int published, int drafts})>{};
    for (final workout in widget.workouts) {
      final day = WorkoutDateFormatter.localDay(workout.scheduledAt);
      final count = counts[day] ?? (published: 0, drafts: 0);
      counts[day] = (
        published:
            count.published +
            (workout.status == WorkoutStatus.published ? 1 : 0),
        drafts:
            count.drafts +
            (widget.showDrafts && workout.status == WorkoutStatus.draft
                ? 1
                : 0),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: _expanded ? 'Предыдущий месяц' : 'Предыдущая неделя',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  WorkoutDateFormatter.formatCalendarMonth(_visibleDate),
                  style: theme.textTheme.titleSmall,
                ),
                IconButton(
                  tooltip: _expanded ? 'Следующий месяц' : 'Следующая неделя',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () =>
                      _select(WorkoutDateFormatter.localDay(DateTime.now())),
                  child: const Text('Сегодня'),
                ),
                if (!widget.monthView)
                  IconButton(
                    tooltip: _expanded ? 'Показать неделю' : 'Показать месяц',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                for (final day in const [
                  'Пн',
                  'Вт',
                  'Ср',
                  'Чт',
                  'Пт',
                  'Сб',
                  'Вс',
                ])
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < rows; row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: _cell(
                        context,
                        start,
                        row * 7 + column - leading,
                        days,
                        counts,
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _legend(context, 'Тренировки', draft: false),
                  if (widget.showDrafts)
                    _legend(context, 'Черновики', draft: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mark(
    BuildContext context, {
    required bool draft,
    bool selected = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final color = selected
        ? colors.onPrimary
        : draft
        ? context.appTheme.draft
        : colors.primary;
    final shape = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: draft ? null : color,
        shape: draft ? BoxShape.rectangle : BoxShape.circle,
        border: draft ? Border.all(color: color, width: 1.5) : null,
      ),
    );
    return draft ? Transform.rotate(angle: math.pi / 4, child: shape) : shape;
  }

  Widget _legend(BuildContext context, String label, {required bool draft}) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mark(context, draft: draft),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: draft
                  ? context.appTheme.draft
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );

  Widget _cell(
    BuildContext context,
    DateTime start,
    int offset,
    int days,
    Map<DateTime, ({int published, int drafts})> counts,
  ) {
    if (offset < 0 || offset >= days) return const SizedBox(height: 56);
    final date = DateTime(start.year, start.month, start.day + offset);
    final selected = WorkoutDateFormatter.sameDay(date, widget.selectedDate);
    final today = WorkoutDateFormatter.sameDay(date, DateTime.now());
    final count = counts[date] ?? (published: 0, drafts: 0);
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    return Semantics(
      label:
          '${WorkoutDateFormatter.formatDay(date)}${today ? ', сегодня' : ''}, '
          'тренировок: ${count.published}${widget.showDrafts ? ', черновиков: ${count.drafts}' : ''}',
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _select(date),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? colors.primary : null,
            borderRadius: BorderRadius.circular(12),
            border: today ? Border.all(color: colors.primary) : null,
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  height: 18,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (count.published > 0)
                        _mark(context, draft: false, selected: selected),
                      if (count.published > 0 && count.drafts > 0)
                        const SizedBox(width: 5),
                      if (count.drafts > 0)
                        _mark(context, draft: true, selected: selected),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
