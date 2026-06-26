import 'package:flutter/material.dart';

extension WidgetExtension on Widget {
  Widget onTap(
    GestureTapCallback? onTap, {
    Key? key,
    HitTestBehavior? behavior,
  }) =>
      GestureDetector(
        key: key,
        onTap: onTap,
        behavior: behavior ?? HitTestBehavior.opaque,
        child: this,
      );
}
