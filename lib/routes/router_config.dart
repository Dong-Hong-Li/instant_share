import 'package:flutter/material.dart';
import 'package:instant_share/core/config/common.dart';
import 'package:flutter/services.dart';
import 'package:fluro_router_generate/fluro_router.dart';
export 'router.dart';

/// 路由配置。
@EntranceAnnotation()
class RouteConfig extends FluroConfig {
  RouteConfig._();

  /// 单例实例。
  static final RouteConfig instance = RouteConfig._();

  static void pop<T extends Object?>([T? result]) {
    if (canPop) {
      CommonContext.navigatorKey.currentState!.pop(result);
    } else {
      SystemNavigator.pop();
    }
  }

  /// 打开指定页面。
  static void push(
    String path, {
    TransitionType? transition,
    bool clearStack = false,
    bool maintainState = true,
    bool rootNavigator = false,
    bool replace = false,
    RouteSettings? routeSettings,
  }) {
    final ctx = CommonContext.contextOrNull;
    if (ctx == null) return;
    CommonContext.router.navigateTo(
      ctx,
      path,
      replace: replace,
      maintainState: maintainState,
      rootNavigator: rootNavigator,
      transition: transition ?? TransitionType.inFromRight,
      clearStack: clearStack,
      routeSettings: routeSettings,
      opaque: false,
    );
  }

  static Future<T?> pushResult<T extends Object?>(
    String path, {
    TransitionType? transition,
  }) async {
    final ctx = CommonContext.contextOrNull;
    if (ctx == null) return null;
    return CommonContext.router.navigateTo(
      ctx,
      path,
      transition: transition,
      opaque: false,
    );
  }

  /// 是否可以返回上一页。
  static bool get canPop =>
      CommonContext.navigatorKey.currentState?.canPop() ?? false;
}
