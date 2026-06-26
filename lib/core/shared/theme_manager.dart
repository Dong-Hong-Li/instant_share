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

class ThemeManager {
  static final ThemeManager instance = ThemeManager._();
  ThemeManager._();

  static AppThemeController get controller => DI.find<AppThemeController>();
  bool get isDarkMode => controller.isDarkMode;
  ThemeMode get themeMode => controller.themeMode;
  AppThemeMode get appThemeMode => _fromThemeMode(controller.themeMode);
  ThemeData get darkThemeData => darkTheme;
  ThemeData get lightThemeData => lightTheme;
  ThemeData get currentThemeData =>
      controller.isDarkMode ? darkTheme : lightTheme;
  static const String _cjkFontFamily = 'PingFang SC';

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

  Future<void> setThemeMode(ThemeMode mode) async =>
      controller.changeThemeMode(mode);
  Future<void> setAppThemeMode(AppThemeMode mode) async =>
      controller.changeThemeMode(mode.toThemeMode());
}

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

extension AppThemeModeX on AppThemeMode {
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
