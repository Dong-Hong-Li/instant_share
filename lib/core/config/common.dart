import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:instant_share/resource/keys.dart';
import 'package:instant_share/routes/navigation_service.dart';
import 'package:instant_share/core/utils/storage/prefs_util.dart';
import 'package:instant_share/core/ui/extension/media_query_extension.dart';
import 'package:fluro_router_generate/fluro_router.dart';

/// 公共配置（路由/导航/屏幕信息）
class CommonContext {
  /// 路由
  static FluroRouter get router => FluroRouter.appRouter;

  /// 导航键
  static GlobalKey<NavigatorState> get navigatorKey =>
      NavigateService.instance.navigatorKey;

  /// 上下文
  static BuildContext? get contextOrNull =>
      NavigateService.instance.contextOrNull;

  /// 是否同意用户协议和隐私政策
  static bool get agreeUserAgreementAndPrivacyPolicy {
    return PrefsUtil.getBool(AppKeys.agreeUserAgreementAndPrivacyPolicy) ??
        false;
  }

  /// 设置屏幕大小
  static void setupScreenSize(BuildContext context) =>
      size = context.screenSize;

  /// 屏幕大小
  static Size size = Size.zero;

  /// 屏幕宽度
  static double get screenWidth => size.width;

  /// 屏幕高度
  static double get screenHeight => size.height;

  /// 是否是移动设备
  static final bool isMobile =
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 是否是 iOS 设备
  static final bool isIOS = !kIsWeb && Platform.isIOS;

  /// 是否是 Android 设备
  static final bool isAndroid = !kIsWeb && Platform.isAndroid;

  /// 是否是 Web 设备
  static final bool isWeb = kIsWeb;

  /// 是否是桌面端（macOS / Windows / Linux）
  static final bool isDesktop =
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
}
