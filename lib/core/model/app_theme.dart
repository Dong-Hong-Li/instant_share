import 'package:flutter/material.dart';
import 'package:instant_share/core/shared/app_theme_cache.dart';

/// 应用主题。
class AppTheme {
  /// 主题模式。
  final ThemeMode themeMode;

  /// cache语言。
  final Locale? cacheLocale;

  const AppTheme({this.themeMode = ThemeMode.system, this.cacheLocale});

  /// current语言。
  Locale get currentLocale => AppThemeCache.resolveLocale(cacheLocale);

  /// 复制并替换部分字段。
  AppTheme copyWith({ThemeMode? themeMode, Locale? cacheLocale}) {
    return AppTheme(
      themeMode: themeMode ?? this.themeMode,
      cacheLocale: cacheLocale ?? this.cacheLocale,
    );
  }
}
