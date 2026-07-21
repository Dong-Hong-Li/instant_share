import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:instant_share/core/shared/theme_manager.dart'; // AppThemeMode
import 'package:instant_share/l10n/app_localizations.dart';

/// 应用主题Cache。
class AppThemeCache {
  static const String _themeKey = 'theme_mode';

  static const String _localeKey = 'cache_locale';

  /// 支持的语言列表。
  static List<Locale> get supportedLocales =>
      AppLocalizations.supportedLocales();

  /// default语言。
  static Locale get defaultLocale => supportedLocales.first;

  /// localeMatches。
  static bool localeMatches(Locale a, Locale b) {
    return a.languageCode == b.languageCode &&
        (a.scriptCode ?? '') == (b.scriptCode ?? '') &&
        (a.countryCode ?? '') == (b.countryCode ?? '');
  }

  /// isSupported。
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

  /// get主题Mode。
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

  /// set主题Mode。
  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final s = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
        ? 'dark'
        : 'system';
    await prefs.setString(_themeKey, s);
  }

  /// get应用主题Mode。
  static Future<AppThemeMode> getAppThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_themeKey);
      return appThemeModeFromString(s ?? 'system');
    } catch (_) {
      return AppThemeMode.system;
    }
  }

  /// set应用主题Mode。
  static Future<void> setAppThemeMode(AppThemeMode mode) async {
    await setThemeMode(mode.toThemeMode());
  }

  /// getLocal。
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

  /// setLocal。
  static Future<void> setLocal(Locale locale) async {
    final resolved = resolveLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, resolved.toLanguageTag());
  }

  /// clearAll。
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
