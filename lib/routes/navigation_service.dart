import 'package:flutter/material.dart';

/// 全局导航：持有 navigatorKey，供 MaterialApp 与 CommonContext 使用
class NavigateService {
  NavigateService._();
  static final NavigateService instance = NavigateService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey(
    debugLabel: 'navigate_key',
  );

  NavigatorState? get navigator => navigatorKey.currentState;
  BuildContext? get contextOrNull => navigator?.context;
}
