import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/core/config/common.dart';
import 'package:instant_share/core/controller/app_theme_controller.dart';
import 'package:instant_share/resource/color/light_color.dart';
import 'package:instant_share/resource/color/dark_color.dart';
import 'package:state_scope/state_scope.dart';
export 'package:instant_share/resource/color/color_value.dart';
export 'package:instant_share/resource/color/light_color.dart';
export 'package:instant_share/resource/color/dark_color.dart';

/// 主题管理器。
class ThemeManager {
  /// 单例实例。
  static final ThemeManager instance = ThemeManager._();
  ThemeManager._();

  /// 控制器。
  static AppThemeController get controller => DI.find<AppThemeController>();

  /// 是否深色模式。
  bool get isDarkMode => controller.isDarkMode;

  /// 主题模式。
  ThemeMode get themeMode => controller.themeMode;

  AppThemeMode get appThemeMode => _fromThemeMode(controller.themeMode);

  /// dark主题数据。
  ThemeData get darkThemeData => darkTheme;

  /// light主题数据。
  ThemeData get lightThemeData => lightTheme;

  /// current主题数据。
  ThemeData get currentThemeData =>
      controller.isDarkMode ? darkTheme : lightTheme;

  static const String _cjkFontFamily = 'PingFang SC';

  /// systemOverlay样式。
  SystemUiOverlayStyle get systemOverlayStyle {
    return getSystemOverlayStyleForBrightness(
      themeMode == ThemeMode.system && CommonContext.contextOrNull != null
          ? MediaQuery.platformBrightnessOf(CommonContext.contextOrNull!)
          : (isDarkMode ? Brightness.dark : Brightness.light),
    );
  }

  /// 根据亮度返回系统栏样式，用于「跟随系统」时随系统亮度同步导航条
  SystemUiOverlayStyle getSystemOverlayStyleForBrightness(
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;
    final contentBrightness = CommonContext.isIOS
        ? (isDark ? Brightness.dark : Brightness.light)
        : (isDark ? Brightness.light : Brightness.dark);
    final navBarColor = isDark ? Colors.black : Colors.white;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: navBarColor,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarIconBrightness: iconBrightness,
      statusBarBrightness: contentBrightness,
    );
  }

  /// light主题。
  ThemeData get lightTheme {
    final base = ThemeData.light().copyWith(
      scaffoldBackgroundColor: LightColor.instance.background,
      colorScheme: ThemeData.light().colorScheme.copyWith(
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: _cjkFontFamily),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _cjkFontFamily),
    );
  }

  /// dark主题。
  ThemeData get darkTheme {
    final base = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: DarkColor.instance.background,
      colorScheme: ThemeData.dark().colorScheme.copyWith(
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: _cjkFontFamily),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _cjkFontFamily),
    );
  }

  /// set主题Mode。
  Future<void> setThemeMode(ThemeMode mode) async =>
      controller.changeThemeMode(mode);

  /// set应用主题Mode。
  Future<void> setAppThemeMode(AppThemeMode mode) async =>
      controller.changeThemeMode(mode.toThemeMode());
}

/// 应用主题Mode枚举。
enum AppThemeMode { light, dark, system }

AppThemeMode _fromThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return AppThemeMode.light;
    case ThemeMode.dark:
      return AppThemeMode.dark;
    case ThemeMode.system:
      return AppThemeMode.system;
  }
}

/// 应用主题ModeX。
extension AppThemeModeX on AppThemeMode {
  /// to主题Mode。
  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// display文本。
  String get displayText {
    switch (this) {
      case AppThemeMode.light:
        return '亮色';
      case AppThemeMode.dark:
        return '暗色';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  /// stringValue。
  String get stringValue {
    switch (this) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }
}

/// app主题ModeFromString。
AppThemeMode appThemeModeFromString(String value) {
  switch (value) {
    case 'light':
      return AppThemeMode.light;
    case 'dark':
      return AppThemeMode.dark;
    default:
      return AppThemeMode.system;
  }
}
