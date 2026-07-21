import 'package:flutter/material.dart';

/// 组件Extension。
extension WidgetExtension on Widget {
  /// 点击回调。
  Widget onTap(
    GestureTapCallback? onTap, {
    Key? key,
    HitTestBehavior? behavior,
  }) => GestureDetector(
    key: key,
    onTap: onTap,
    behavior: behavior ?? HitTestBehavior.opaque,
    child: this,
  );
}
