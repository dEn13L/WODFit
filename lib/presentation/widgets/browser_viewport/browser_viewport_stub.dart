import 'package:flutter/widgets.dart';

/// Native platforms already supply their visible bounds through FlutterView.
class BrowserViewport extends StatelessWidget {
  final Widget child;

  const BrowserViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
