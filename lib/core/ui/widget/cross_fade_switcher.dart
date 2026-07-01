import 'package:flutter/material.dart';

/// 交叉淡入切换器
///
/// ```dart
/// CrossFadeSwitcher(
///   currentIndex: currentIndex,
///   children: children,
/// )
/// ```
///
/// -- `currentIndex` 当前索引
/// -- `children` 子组件列表
/// -- `duration` 动画持续时间
class CrossFadeSwitcher extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;
  final Duration duration;

  const CrossFadeSwitcher({
    super.key,
    required this.currentIndex,
    required this.children,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: children.asMap().entries.map((entry) {
        final int index = entry.key;
        final Widget child = entry.value;
        final visible = index == currentIndex;
        return Offstage(
          offstage: !visible,
          child: TickerMode(
            enabled: visible,
            child: IgnorePointer(ignoring: !visible, child: child),
          ),
        );
      }).toList(),
    );
  }
}
