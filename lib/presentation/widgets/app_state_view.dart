import 'package:flutter/material.dart';
import '../../core/theme/app_theme_extension.dart';

class AppLoadingView extends StatelessWidget {
  final String semanticLabel;

  const AppLoadingView({super.key, this.semanticLabel = 'Загрузка'});

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: semanticLabel,
          liveRegion: true,
          child: const SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
}

class AppEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function()? onAction;

  const AppEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel = 'Обновить',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => _AppStateView(
        icon: icon,
        title: title,
        description: description,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

class AppErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const AppErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => _AppStateView(
        icon: Icons.error_outline,
        iconColor: context.appTheme.destructive,
        title: 'Не удалось загрузить данные',
        description: message,
        actionLabel: 'Повторить',
        onAction: onRetry,
      );
}

class _AppStateView extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function()? onAction;

  const _AppStateView({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
