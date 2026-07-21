import 'package:flutter/material.dart';
import 'package:instant_share/core/config/common.dart';

/// 各端 ScreenUtil 设计稿尺寸。
///
/// - 桌面端（macOS / Windows / Linux）：横向窗口布局 900×700
/// - 移动端（iOS / Android）：竖屏 App 布局 375×812
class ScreenDesignConfig {
  ScreenDesignConfig._();

  /// PC 设计稿（与 [DesktopWindowConfig] 窗口比例一致）
  static const Size desktopDesignSize = Size(900, 700);

  /// App 设计稿（iPhone 标准竖屏基准）
  static const Size mobileDesignSize = Size(375, 812);

  /// 当前运行平台对应的设计稿尺寸。
  static Size get designSize =>
      CommonContext.isDesktop ? desktopDesignSize : mobileDesignSize;

  /// 设计宽度。
  static double get designWidth => designSize.width;

  /// 设计高度。
  static double get designHeight => designSize.height;

  /// 设计宽高比。
  static double get designAspectRatio => designWidth / designHeight;
}
