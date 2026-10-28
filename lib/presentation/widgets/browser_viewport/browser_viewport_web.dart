import 'dart:js_interop';

import 'package:flutter/widgets.dart';

import 'browser_viewport_frame.dart';

@JS('window.visualViewport')
external _VisualViewport? get _visualViewport;

extension type _VisualViewport(JSObject _) implements JSObject {
  external double get width;
  external double get height;
  external double get offsetTop;
  external double get offsetLeft;
  external double get scale;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

/// Browser UI and viewport panning can obscure a full-page FlutterView without
/// changing its physical size. Keep the engine's normal keyboard handling and
/// constrain the Navigator instead of embedding Flutter in a custom DOM host.
class BrowserViewport extends StatefulWidget {
  final Widget child;

  const BrowserViewport({super.key, required this.child});

  @override
  State<BrowserViewport> createState() => _BrowserViewportState();
}

class _BrowserViewportState extends State<BrowserViewport> {
  late final _VisualViewport? _viewport;
  late final JSFunction _listener;
  Rect? _lastUnzoomedViewport;

  @override
  void initState() {
    super.initState();
    _viewport = _visualViewport;
    _listener = ((JSAny? _) {
      if (mounted) setState(() {});
    }).toJS;
    _viewport?.addEventListener('resize', _listener);
    _viewport?.addEventListener('scroll', _listener);
  }

  @override
  void dispose() {
    _viewport?.removeEventListener('resize', _listener);
    _viewport?.removeEventListener('scroll', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = _viewport;
    // During pinch zoom, preserve the last layout and let the browser magnify
    // and pan it normally. Native text scaling still flows through MediaQuery.
    if (viewport != null && (viewport.scale - 1).abs() < 0.01) {
      final rect = Rect.fromLTWH(
        viewport.offsetLeft,
        viewport.offsetTop,
        viewport.width,
        viewport.height,
      );
      if (rect.isFinite && !rect.isEmpty) _lastUnzoomedViewport = rect;
    }
    final rect = _lastUnzoomedViewport;
    if (rect == null) return widget.child;
    return BrowserViewportFrame(viewport: rect, child: widget.child);
  }
}
