import 'package:flutter/material.dart';

import '../../../../bloc/workout_form/workout_form_cubit.dart';
import '../../../../widgets/confirm_dialog.dart';

class WorkoutTaskCard extends StatefulWidget {
  final WorkoutFormTask task;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;

  const WorkoutTaskCard({
    super.key,
    required this.task,
    required this.index,
    required this.onDelete,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
  });

  @override
  State<WorkoutTaskCard> createState() => _WorkoutTaskCardState();
}

class _WorkoutTaskCardState extends State<WorkoutTaskCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  bool _isCardFocused = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _titleFocusNode.addListener(_onFocusChange);
    _descriptionFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant WorkoutTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.title != widget.task.title &&
        _titleController.text != widget.task.title) {
      _titleController.text = widget.task.title;
    }
    if (oldWidget.task.description != widget.task.description &&
        _descriptionController.text != widget.task.description) {
      _descriptionController.text = widget.task.description;
    }
  }

  void _onFocusChange() {
    setState(() {
      _isCardFocused =
          _titleFocusNode.hasFocus || _descriptionFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _descriptionFocusNode.removeListener(_onFocusChange);
    _descriptionFocusNode.dispose();
    _descriptionController.dispose();
    _titleFocusNode.removeListener(_onFocusChange);
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCardFocused
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: _isCardFocused ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 6-dot Drag Handle
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: ReorderableDragStartListener(
                index: widget.index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 22,
                    color: _isCardFocused
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

            // Название и текст задания редактируются в одной карточке.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title input
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    onChanged: widget.onTitleChanged,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Название задания',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _descriptionController,
                    focusNode: _descriptionFocusNode,
                    onChanged: widget.onDescriptionChanged,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: null,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Текст задания: движения, раунды, повторы, вес…',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Delete task cross icon
            IconButton(
              icon: Icon(
                Icons.cancel,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Удалить задание',
              onPressed: () async {
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'Удалить задание?',
                  message:
                      'Задание будет удалено при сохранении тренировки. '
                      'Если у него есть результаты участников, включая удалённые, '
                      'сохранение будет отклонено и задание вернётся в форму.',
                );
                if (confirmed && mounted) widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
