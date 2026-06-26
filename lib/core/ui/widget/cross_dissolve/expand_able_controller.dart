import 'package:flutter/material.dart';

class ExpandAbleController extends ValueNotifier<bool> {
  ///返回当前的展开状态，true 表示已展开，false 表示已折叠
  bool get isExpanded => value;

  set isExpanded(bool expand) => value = expand;

  ExpandAbleController({bool initialExpanded = false}) : super(initialExpanded);

  static ExpandAbleController of(BuildContext context) {
    final notifier =
        context.dependOnInheritedWidgetOfExactType<ExpandAbleInherited>()!;
    return notifier.notifier!;
  }

  void toggle() => isExpanded = !isExpanded;
}

class ExpandAbleInherited extends InheritedNotifier<ExpandAbleController> {
  const ExpandAbleInherited({
    super.key,
    required super.child,
    required super.notifier,
  });
}
