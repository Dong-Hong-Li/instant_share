import 'package:flutter/material.dart';

extension MediaQueryExt on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  double get statusBarHeight => MediaQuery.viewPaddingOf(this).top;
  double get bottomSafeHeight => MediaQuery.viewPaddingOf(this).bottom;
}
