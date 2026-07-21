import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用路由Observer。
class AppRouterObserver extends NavigatorObserver {
  static final AppRouterObserver _instance = AppRouterObserver._internal();
  factory AppRouterObserver() => _instance;
  AppRouterObserver._internal();

  /// 页面入栈时处理焦点。
  @override
  void didPush(Route route, Route? previousRoute) {
    _unfocusAll();
    if (kDebugMode) {
      debugPrint(
        '[Push] ${previousRoute?.settings.name} -> ${route.settings.name}',
      );
    }
  }

  /// 页面出栈时处理焦点。
  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _unfocusAll();
    if (kDebugMode) {
      debugPrint(
        '[Pop] ${route.settings.name} -> ${previousRoute?.settings.name}',
      );
    }
  }

  void _unfocusAll() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
}
