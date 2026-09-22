import 'package:flutter/material.dart';
import '../../../../bloc/workout_form/workout_form_cubit.dart';
import 'task_description_editor.dart';

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
  final FocusNode _titleFocusNode = FocusNode();
  bool _isCardFocused = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _titleFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant WorkoutTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.title != widget.task.title &&
        _titleController.text != widget.task.title) {
      _titleController.text = widget.task.title;
    }
  }

  void _onFocusChange() {
    setState(() {
      _isCardFocused = _titleFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onFocusChange);
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDescription = widget.task.description.trim().isNotEmpty;

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

            // Middle Content: Title and Description Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title input
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    onChanged: widget.onTitleChanged,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'например: Разминка, Силовая, Комплекс',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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

                  // Description preview zone (clickable)
                  InkWell(
                    onTap: () {
                      TaskDescriptionEditor.show(
                        context,
                        initialDescription: widget.task.description,
                        onSaved: widget.onDescriptionChanged,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: hasDescription
                          ? Text(
                              widget.task.description,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            )
                          : Text(
                              'Опишите движения, раунды, повторы, вес, лимиты времени и масштабирование…',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                height: 1.3,
                              ),
                            ),
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
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
