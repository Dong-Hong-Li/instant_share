import 'package:flutter/material.dart';

/// 媒体查询扩展。
extension MediaQueryExt on BuildContext {
  /// screenSize。
  Size get screenSize => MediaQuery.sizeOf(this);

  /// screenWidth。
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// screenHeight。
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// statusBarHeight。
  double get statusBarHeight => MediaQuery.viewPaddingOf(this).top;

  /// bottomSafeHeight。
  double get bottomSafeHeight => MediaQuery.viewPaddingOf(this).bottom;
}
