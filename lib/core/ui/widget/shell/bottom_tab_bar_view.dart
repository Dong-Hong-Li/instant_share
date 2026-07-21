import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:instant_share/core/ui/extension/theme_extension.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 底部导航：浮动胶囊毛玻璃样式。
class BottomTabBarView extends StatelessWidget {
  const BottomTabBarView({
    super.key,
    required this.tabs,
    required this.activeIndex,
    this.maxContentWidth = 430,
  });

  /// tabs。
  final List<Widget> tabs;

  /// activeIndex。
  final int activeIndex;

  /// maxContentWidth。
  final double maxContentWidth;

  /// TSX: `h-[58px]`
  static double barHeight = h58;

  /// TSX: `min-w-[338px]`
  static const double minBarWidth = 300;

  /// TSX: `max-w-[calc(100vw-92px)]` → 左右各 46
  static const double horizontalInset = 46;

  /// TSX: `bottom-4`
  static const double bottomOffset = 16;

  /// 页面正文需预留的底部高度（胶囊 + 间距 + 安全区）。
  static double overlayHeight(BuildContext context) =>
      barHeight + bottomOffset + MediaQuery.paddingOf(context).bottom;

  static const Color _outerShadowColor = Color(0x2E121218);

  static const Color _insetRingColor = Color(0x94FFFFFF);

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBarWidth = (screenWidth - horizontalInset * 2).clamp(
      minBarWidth,
      maxContentWidth,
    );
    final ColorValue c = context.themeColor;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomOffset + bottomInset),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minBarWidth,
                maxWidth: maxBarWidth,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: _outerShadowColor,
                      blurRadius: 48,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.bottomBarBackdrop,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _insetRingColor, width: 1),
                      ),
                      child: SizedBox(
                        height: barHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: tabs,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底栏单个入口：Material 图标 + 文案。
class BottomTabSlot extends StatelessWidget {
  const BottomTabSlot({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.semanticLabel,
  });

  /// icon。
  final IconData icon;

  /// label。
  final String label;

  /// 是否激活。
  final bool active;

  /// 点击回调。
  final VoidCallback onTap;

  /// semanticLabel。
  final String? semanticLabel;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final ColorValue colors = context.themeColor;
    final Color color = active ? colors.accentAi : colors.textTertiary;

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      selected: active,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: colors.accentAi.withValues(alpha: 0.12),
          highlightColor: colors.accentAi.withValues(alpha: 0.06),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: w42),
            child: SizedBox(
              height: BottomTabBarView.barHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      key: ValueKey('$icon-$active'),
                      icon,
                      color: color,
                      size: w23,
                    ),
                  ),
                  SizedBox(height: h4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
