import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/widget/shell/bottom_tab_bar_view.dart';

/// Tab 页滚动区域底部留白（浮动底栏高度 + 安全区）。
///
/// 仅用于 [ListView] / [CustomScrollView] 等滚动组件的 padding 或 [SliverPadding]，
/// 不要在页面外层包 [Padding]。
abstract final class TabScrollInsets {
  TabScrollInsets._();

  static const double extraBottom = 10;

  static double bottom(BuildContext context) =>
      BottomTabBarView.overlayHeight(context) + extraBottom;

  static EdgeInsets onlyBottom(BuildContext context) =>
      EdgeInsets.only(bottom: bottom(context));

  static EdgeInsets merge(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottomExtra = 0,
  }) {
    return EdgeInsets.fromLTRB(left, top, right, bottomExtra + bottom(context));
  }
}
