import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fits the Navigator (including app bars and overlays) into the browser's
/// visible rectangle while retaining keyboard insets for Scaffold/bottom sheets.
class BrowserViewportFrame extends StatefulWidget {
  final Rect viewport;
  final Widget child;

  const BrowserViewportFrame({
    super.key,
    required this.viewport,
    required this.child,
  });

  @override
  State<BrowserViewportFrame> createState() => _BrowserViewportFrameState();
}

class _BrowserViewportFrameState extends State<BrowserViewportFrame> {
  EdgeInsets? _browserInsets;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bounds = Offset.zero & media.size;
    final visible = widget.viewport.intersect(bounds);
    if (visible.isEmpty) return widget.child;

    final occlusion = EdgeInsets.fromLTRB(
      visible.left,
      visible.top,
      math.max(0, bounds.right - visible.right),
      math.max(0, bounds.bottom - visible.bottom),
    );
    // Flutter's full-page web engine preserves physicalSize during editing and
    // reports the keyboard through viewInsets. Remember browser chrome separately
    // so we do not subtract the keyboard both here and again inside Scaffold.
    if (media.viewInsets.bottom == 0 || _browserInsets == null) {
      _browserInsets = occlusion;
    }
    final padding = occlusion.copyWith(
      bottom: math.min(_browserInsets!.bottom, occlusion.bottom),
    );
    final keyboard = EdgeInsets.only(bottom: occlusion.bottom - padding.bottom);
    final size = Size(
      math.max(0, media.size.width - padding.horizontal),
      math.max(0, media.size.height - padding.vertical),
    );
    EdgeInsets remaining(EdgeInsets insets) => EdgeInsets.fromLTRB(
      math.max(0, insets.left - padding.left),
      math.max(0, insets.top - padding.top),
      math.max(0, insets.right - padding.right),
      math.max(0, insets.bottom - padding.bottom),
    );

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: padding,
        child: MediaQuery(
          data: media.copyWith(
            size: size,
            padding: remaining(media.padding),
            viewPadding: remaining(media.viewPadding),
            viewInsets: keyboard,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
