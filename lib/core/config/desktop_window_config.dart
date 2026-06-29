import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端窗口配置：隐藏系统标题栏 + 透明背景，配合 [DesktopWindowFrame] 实现全平台一致圆角。
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

  /// 窗口外框圆角（与 macOS 视觉对齐）
  static const double windowBorderRadius = 12;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// macOS 使用系统交通灯；Windows / Linux 使用 [WindowCaption]。
  static bool get useWindowCaption => isDesktop && !Platform.isMacOS;

  /// 是否使用隐藏式标题栏（全桌面平台）。
  static bool get usesHiddenTitleBar => isDesktop;

  /// 主内容区顶部留白：macOS 为交通灯留空，其余平台由 [WindowCaption] 承担。
  static double topContentInset({required bool hasWindowCaption}) {
    if (!isDesktop) return 0;
    if (hasWindowCaption) return h8;
    if (Platform.isMacOS) return h28;
    return h8;
  }

  /// 写入原生窗口的标题。Windows / Linux 自定义标题栏下留空，避免左上角重复显示文案。
  static String get nativeWindowTitle => useWindowCaption ? '' : windowTitle;

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
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle(nativeWindowTitle);
      await windowManager.setSize(windowSize);
      await windowManager.setResizable(true);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: Platform.isMacOS,
      );
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
