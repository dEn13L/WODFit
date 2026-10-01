import 'package:flutter/widgets.dart';

abstract final class AppLayout {
  static const double maxContentWidth = 1200;
  static const double pagePadding = 16;
  static const double widePagePadding = 24;
  static const double cardRadius = 20;
  static const double fieldRadius = 12;
  static const double badgeRadius = 10;
  static const double controlHeight = 52;
  static const double sectionGap = 24;
  static const double itemGap = 12;

  static EdgeInsets pageInsets(double width) => EdgeInsets.symmetric(
        horizontal: width >= 600 ? widePagePadding : pagePadding,
        vertical: pagePadding,
      );
}
