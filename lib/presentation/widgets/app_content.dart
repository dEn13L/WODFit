import 'package:flutter/material.dart';
import '../../core/theme/app_layout.dart';

class AppContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const AppContent({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppLayout.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: padding ?? AppLayout.pageInsets(constraints.maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
