import 'package:flutter/material.dart';
import 'package:instant_share/core/shared/theme_manager.dart';

extension ThemeExtension on BuildContext {
  /// 按 [ThemeManager.themeMode] 取色，与 MaterialApp 的 themeMode 同源。
  /// 主题由 GetBuilder<AppThemeController> 驱动时，与 MaterialApp 同帧重建，用于 Scaffold/页面取色可避免切换变灰。
  ColorValue get themeColor {
    switch (ThemeManager.instance.themeMode) {
      case ThemeMode.light:
        return LightColor.instance;
      case ThemeMode.dark:
        return DarkColor.instance;
      case ThemeMode.system:
        final brightness = MediaQuery.platformBrightnessOf(this);
        return brightness == Brightness.light
            ? LightColor.instance
            : DarkColor.instance;
    }
  }
}
