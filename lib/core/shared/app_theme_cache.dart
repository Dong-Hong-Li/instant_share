import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:instant_share/core/shared/theme_manager.dart'; // AppThemeMode
import 'package:instant_share/l10n/app_localizations.dart';

class AppThemeCache {
  static const String _themeKey = 'theme_mode';
  static const String _localeKey = 'cache_locale';

  static List<Locale> get supportedLocales => AppLocalizations.supportedLocales();

  static Locale get defaultLocale => supportedLocales.first;

  static bool localeMatches(Locale a, Locale b) {
    return a.languageCode == b.languageCode &&
        (a.scriptCode ?? '') == (b.scriptCode ?? '') &&
        (a.countryCode ?? '') == (b.countryCode ?? '');
  }

  static bool isSupported(Locale locale) {
    return supportedLocales.any((l) => localeMatches(l, locale));
  }

  /// 将任意 Locale 解析为支持列表中的项，不匹配时返回 [defaultLocale]
  static Locale resolveLocale(Locale? locale) {
    if (locale == null) return defaultLocale;
    return supportedLocales.firstWhere(
      (l) => localeMatches(l, locale),
      orElse: () => defaultLocale,
    );
  }

  static Future<ThemeMode> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_themeKey);
      if (s == 'light') return ThemeMode.light;
      if (s == 'dark') return ThemeMode.dark;
      return ThemeMode.system;
    } catch (_) {
      return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final s = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
        ? 'dark'
        : 'system';
    await prefs.setString(_themeKey, s);
  }

  static Future<AppThemeMode> getAppThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_themeKey);
      return appThemeModeFromString(s ?? 'system');
    } catch (_) {
      return AppThemeMode.system;
    }
  }

  static Future<void> setAppThemeMode(AppThemeMode mode) async {
    await setThemeMode(mode.toThemeMode());
  }

  static Future<Locale?> getLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tag = prefs.getString(_localeKey);
      if (tag == null) return null;
      final cached = _parseLocaleTag(tag);
      if (cached == null) return null;
      return isSupported(cached) ? resolveLocale(cached) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLocal(Locale locale) async {
    final resolved = resolveLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, resolved.toLanguageTag());
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    await prefs.remove(_localeKey);
  }

  static Locale? _parseLocaleTag(String tag) {
    // 兼容旧版仅 languageCode 的缓存
    if (tag == 'zh') {
      return const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      );
    }
    if (tag == 'en') return const Locale('en', 'US');

    final parts = tag.split('-');
    if (parts.length == 1) return Locale(parts[0]);
    if (parts.length == 2) {
      if (parts[1].length == 4) {
        return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
      }
      return Locale(parts[0], parts[1]);
    }
    if (parts.length == 3) {
      return Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: parts[1],
        countryCode: parts[2],
      );
    }
    return null;
  }
}
