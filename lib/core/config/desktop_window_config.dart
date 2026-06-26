import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端窗口配置：设定默认尺寸（横向桌面布局），但允许用户自由缩放窗口。
class DesktopWindowConfig {
  DesktopWindowConfig._();

  /// 与 ScreenUtilInit designSize 保持一致（横向桌面布局）
  static const double designWidth = 900;
  static const double designHeight = 700;
  static const double designAspectRatio = designWidth / designHeight;

  /// 窗口高度占主屏高度比例
  static const double heightRatio = 0.68;
  static const double minHeight = 580;
  static const double maxHeight = 760;

  static const String windowTitle = '极速分享';

  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static TitleBarStyle get titleBarStyle =>
      Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal;

  static Future<void> ensureInitialized() async {
    if (!isDesktop) return;

    await windowManager.ensureInitialized();

    final view = PlatformDispatcher.instance.views.first;
    final screenSize = view.physicalSize / view.devicePixelRatio;
    final height = (screenSize.height * heightRatio).clamp(
      minHeight,
      maxHeight,
    );
    final width = height * designAspectRatio;
    final windowSize = Size(width, height);

    final windowOptions = WindowOptions(
      size: windowSize,
      center: true,
      backgroundColor: HomePalette.gradientTop,
      skipTaskbar: false,
      titleBarStyle: titleBarStyle,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle(windowTitle);
      await windowManager.setSize(windowSize);
      await windowManager.setResizable(true);
      if (Platform.isMacOS) {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: true,
        );
      }
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
