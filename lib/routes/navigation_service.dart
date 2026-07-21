import 'package:flutter/material.dart';

/// 全局导航：持有 navigatorKey，供 MaterialApp 与 CommonContext 使用
class NavigateService {
  NavigateService._();

  /// 单例实例。
  static final NavigateService instance = NavigateService._();

  /// 导航键。
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey(
    debugLabel: 'navigate_key',
  );

  /// 当前导航器。
  NavigatorState? get navigator => navigatorKey.currentState;

  /// 可空上下文。
  BuildContext? get contextOrNull => navigator?.context;
}
