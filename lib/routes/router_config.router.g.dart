// GENERATED CODE - DO NOT MODIFY BY HAND
//
// **************************************************************************
// FluroRouterGenerator
// **************************************************************************
//
// GENERATED CODE - DO NOT MODIFY BY HAND
// 由 @EntranceAnnotation 在 RouteConfig 上生成

import 'package:instant_share/features/tab/view/tab_page.dart';
import 'package:instant_share/routes/router_config.dart';
import 'package:fluro_router_generate/fluro_router.dart';

extension RouteConfigX on RouteConfig {
  /// [default] 模块（内联）
  List<RouterHandler> get _handlersDefault => [
    RouterHandler(
      '/',
      FluroHandler(handlerFunc: (context, parameters) => const TabPage()),
    ),
  ];

  /// 由 fluro_router_generate 生成的 RouterHandler 列表（各模块合并）。
  List<RouterHandler> get generatedHandlers => [..._handlersDefault];

  /// 注册生成的路由到 [FluroConfig.router]，
  void initAllHandlers() {
    for (final h in generatedHandlers) {
      FluroConfig.router.define(h.path, handler: h.handler);
    }
  }
}
