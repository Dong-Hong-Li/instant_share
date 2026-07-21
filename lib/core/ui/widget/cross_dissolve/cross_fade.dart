import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/widget/cross_dissolve/expand_able_controller.dart';

/// 交叉淡入淡出组件。
class CrossFade extends StatelessWidget {
  /// 折叠状态下显示的组件
  final Widget? collapsed;

  /// 展开状态下显示的组件
  final Widget? expanded;

  /// 动画的持续时间 300 毫秒
  final Duration animationDuration;

  /// 折叠状态时淡入淡出的起始位置（范围0-1）
  final double collapsedFadeStart;

  /// 折叠状态时淡入淡出的结束位置（范围0-1）
  final double collapsedFadeEnd;

  /// 展开状态时淡入淡出的起始位置（范围0-1）
  final double expandedFadeStart;

  /// 展开状态时淡入淡出的结束位置（范围0-1）
  final double expandedFadeEnd;

  /// 淡入淡出动画的曲线，默认使用线性曲线
  final Curve fadeCurve;

  /// 尺寸变化动画的曲线，默认使用 [Curve.fastOutSlowIn] = Cubic(0.4, 0.0, 0.2, 1.0); 曲线
  final Curve sizeCurve;

  ///淡入淡出组件
  const CrossFade({
    super.key,
    this.collapsed,
    this.expanded,
    this.animationDuration = const Duration(milliseconds: 300),
    this.collapsedFadeStart = 0,
    this.collapsedFadeEnd = 1,
    this.expandedFadeStart = 0,
    this.expandedFadeEnd = 1,
    this.fadeCurve = Curves.easeInOut,
    this.sizeCurve = Curves.fastOutSlowIn,
  });

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final ExpandAbleController controller = ExpandAbleController.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return AnimatedCrossFade(
          firstChild: AnimatedOpacity(
            opacity: controller.isExpanded ? 0.0 : 1.0,
            duration: Duration(
              milliseconds: (animationDuration.inMilliseconds * 0.6).round(),
            ),
            curve: fadeCurve,
            child: collapsed ?? SizedBox.shrink(),
          ),

          secondChild: AnimatedOpacity(
            opacity: controller.isExpanded ? 1.0 : 0.0,
            duration: Duration(
              milliseconds: (animationDuration.inMilliseconds * 0.6).round(),
            ),
            curve: fadeCurve,
            child: expanded ?? SizedBox.shrink(),
          ),

          /// 定义折叠状态下淡入淡出的动画曲线
          firstCurve: Interval(
            collapsedFadeStart,
            collapsedFadeEnd,
            curve: fadeCurve,
          ),

          /// 定义展开状态下淡入淡出的动画曲线
          secondCurve: Interval(
            expandedFadeStart,
            expandedFadeEnd,
            curve: fadeCurve,
          ),

          /// 定义尺寸变化的动画曲线
          sizeCurve: sizeCurve,

          crossFadeState: controller.isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,

          /// 动画的持续时间
          duration: animationDuration,
        );
      },
    );
  }
}
