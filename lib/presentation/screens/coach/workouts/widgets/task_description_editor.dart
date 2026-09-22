import 'package:flutter/material.dart';

class TaskDescriptionEditor extends StatefulWidget {
  final String initialDescription;
  final ValueChanged<String> onSaved;

  const TaskDescriptionEditor({
    super.key,
    required this.initialDescription,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialDescription,
    required ValueChanged<String> onSaved,
  }) async {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1000;

    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: TaskDescriptionEditor(
              initialDescription: initialDescription,
              onSaved: onSaved,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: TaskDescriptionEditor(
            initialDescription: initialDescription,
            onSaved: onSaved,
          ),
        ),
      );
    }
  }

  @override
  State<TaskDescriptionEditor> createState() => _TaskDescriptionEditorState();
}

class _TaskDescriptionEditorState extends State<TaskDescriptionEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Описание задания',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 6,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                hintText: 'Опишите движения, раунды, повторы, вес, лимиты времени и масштабирование…',
                hintMaxLines: 3,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    widget.onSaved(_controller.text.trim());
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
