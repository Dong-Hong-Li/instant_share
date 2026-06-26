import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/core/ui/base/app_consumer_mixin.dart';
import 'package:instant_share/core/shared/theme_manager.dart';
import 'package:instant_share/core/ui/extension/widget_extension.dart';
export 'package:instant_share/core/ui/base/common_setting_mixin.dart';
export 'package:instant_share/core/ui/extension/theme_extension.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:instant_share/routes/router_config.dart';
export 'package:state_scope/state_scope.dart';

/// 基于 [State] + [AppConsumerMixin] 的页面基类，可通过 [ref] 使用 Riverpod（[WidgetRef]）。
abstract class BaseStatePage<T extends StatefulWidget> extends State<T>
    with CommonMixin, AppConsumerMixin {
  // 背景色
  Color? get backgroundColor => ctx.themeColor.background;

  // 悬浮按钮
  Widget? get floatingActionButton => null;

  // 是否避免底部 inset
  bool get resizeToAvoidBottomInset => true;

  // 是否扩展 app bar
  // 默认不扩展
  bool get bodyExtendAppBar => false;

  // app bar
  PreferredSizeWidget? appBar() => null;

  // 底部 sheet
  Widget? bottomSheet() => null;

  /// 与 drawer 配合使用，用于 openDrawer()；子类重写并返回同一 key
  GlobalKey<ScaffoldState>? get scaffoldKey => null;

  /// 使用 themeColor（与 ThemeManager 同源），和 MaterialApp themeMode 一致；
  /// ControllerBuilder 保证主题切换时整页重建
  Widget materialScaffoldWith(BuildContext context) => SafeArea(
    top: false,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle ?? ThemeManager.instance.systemOverlayStyle,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: backgroundColor,
        extendBodyBehindAppBar: bodyExtendAppBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar(),
        body: buildPageWithRef(context),
        drawer: drawer,
        floatingActionButton: floatingActionButton,
        bottomSheet: bottomSheet(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    initBaseCommon(context);
    return materialScaffoldWith(context).onTap(
      () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.deferToChild,
    );
  }

  /// 侧边抽屉，子类重写即可显示（如首页）
  Widget? get drawer => null;
}
