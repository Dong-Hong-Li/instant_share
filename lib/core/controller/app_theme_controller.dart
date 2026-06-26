import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/resource/screen_utils/screen_dimens.dart';
import 'package:state_scope/state_scope.dart';
import 'package:ai_localizations/ai_localizations.dart';
import 'package:instant_share/core/config/common.dart';
import 'package:instant_share/core/model/app_theme.dart';
import 'package:instant_share/core/shared/app_theme_cache.dart';
import 'package:instant_share/core/shared/theme_manager.dart';

class AppThemeController extends AppController {
  /// 当前应用主题
  AppTheme _appTheme = const AppTheme();

  /// 是否在初始化前改变过主题模式
  bool _themeChangedBeforeInit = false;

  /// 当前应用主题
  AppTheme get appTheme => _appTheme;

  /// 当前应用主题模式
  ThemeMode get themeMode => _appTheme.themeMode;

  /// 当前应用语言
  Locale get currentLocale => _appTheme.currentLocale;

  /// 支持的 BCP-47 语言列表（见 config.yaml）
  List<Locale> get supportedLocales => AppThemeCache.supportedLocales;

  /// 屏幕适配
  ScreenDimens get screenDimens => ScreenDimens.instance;

  @override
  void onInit() {
    super.onInit();
    _loadInitial();
  }

  // 初始化屏幕适配
  void initScreenDimens() {
    ScreenDimens.ensureInitialized();
  }

  // 重新计算屏幕适配
  void recalculateScreenDimens() {
    ScreenDimens.reset();
    ScreenDimens.ensureInitialized();
    update();
  }

  /// 加载初始化数据
  Future<void> _loadInitial() async {
    final locale = await AppThemeCache.getLocal();
    final themeMode = await AppThemeCache.getThemeMode();
    if (!_themeChangedBeforeInit) {
      _appTheme = AppTheme(themeMode: themeMode, cacheLocale: locale);
      _applySystemOverlayStyle();
      update();
    }
  }

  /// 应用系统导航栏样式
  void _applySystemOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      ThemeManager.instance.systemOverlayStyle,
    );
  }

  /// 改变语言
  Future<void> changeLanguage(Locale locale) async {
    final resolved = AppThemeCache.resolveLocale(locale);
    if (AppThemeCache.localeMatches(resolved, currentLocale)) return;
    _appTheme = _appTheme.copyWith(cacheLocale: resolved);
    await AppThemeCache.setLocal(resolved);
    await LocalizationsSdk.load(resolved);
    update();
  }

  /// 按 supportedLocales 顺序循环切换语言
  Future<void> cycleLanguage() async {
    final locales = supportedLocales;
    final index = locales.indexWhere(
      (l) => AppThemeCache.localeMatches(l, currentLocale),
    );
    final next = locales[(index + 1) % locales.length];
    await changeLanguage(next);
  }

  /// 改变主题模式
  Future<void> changeThemeMode(ThemeMode themeMode) async {
    _themeChangedBeforeInit = true;
    _appTheme = _appTheme.copyWith(themeMode: themeMode);
    await AppThemeCache.setThemeMode(themeMode);
    _applySystemOverlayStyle();
    update();
  }

  /// 是否为暗色模式
  bool get isDarkMode {
    if (isSystemMode) {
      final ctx = CommonContext.contextOrNull;
      return ctx != null &&
          MediaQuery.platformBrightnessOf(ctx) == Brightness.dark;
    }
    return themeMode == ThemeMode.dark;
  }

  /// 是否为系统模式
  bool get isSystemMode => themeMode == ThemeMode.system;
}
