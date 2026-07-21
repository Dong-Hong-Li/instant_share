import 'package:flutter/material.dart';

/// ExpandAble控制器。
class ExpandAbleController extends ValueNotifier<bool> {
  ///返回当前的展开状态，true 表示已展开，false 表示已折叠
  bool get isExpanded => value;

  /// isExpanded。
  set isExpanded(bool expand) => value = expand;

  ExpandAbleController({bool initialExpanded = false}) : super(initialExpanded);

  /// of。
  static ExpandAbleController of(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<ExpandAbleInherited>()!;
    return notifier.notifier!;
  }

  /// toggle。
  void toggle() => isExpanded = !isExpanded;
}

/// 展开状态继承组件。
class ExpandAbleInherited extends InheritedNotifier<ExpandAbleController> {
  const ExpandAbleInherited({
    super.key,
    required super.child,
    required super.notifier,
  });
}
