import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_extension.dart';
import '../../../domain/entities/part_result.dart';

class ResultSyncStatusView extends StatelessWidget {
  final ResultSyncStatus status;
  final VoidCallback? onRetry;

  const ResultSyncStatusView({
    super.key,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ResultSyncStatus.synced) return const SizedBox.shrink();

    final failed = status == ResultSyncStatus.failed;
    final color = failed ? context.appTheme.destructive : context.appTheme.warning;
    return Row(
      children: [
        Expanded(
          child: Text(
            failed
                ? 'Ошибка синхронизации'
                : 'Сохранено локально · ожидает синхронизации',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (failed && onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
      ],
    );
  }
}
