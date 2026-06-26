import 'package:flutter/material.dart';
import 'package:instant_share/core/shared/app_theme_cache.dart';

class AppTheme {
  final ThemeMode themeMode;
  final Locale? cacheLocale;

  const AppTheme({this.themeMode = ThemeMode.system, this.cacheLocale});

  Locale get currentLocale => AppThemeCache.resolveLocale(cacheLocale);

  AppTheme copyWith({ThemeMode? themeMode, Locale? cacheLocale}) {
    return AppTheme(
      themeMode: themeMode ?? this.themeMode,
      cacheLocale: cacheLocale ?? this.cacheLocale,
    );
  }
}
