import 'strings_mixin.dart';

/// 应用Strings。
class AppStrings with MixinStrings {
  /// 应用标题。
  String get appTitle => intlMessage('Flutter 模板', sid: 'appstrings_appTitle');

  /// 欢迎文案。
  String get welcome => intlMessage('欢迎使用', sid: 'appstrings_welcome');

  /// 设置文案。
  String get setting => intlMessage('设置', sid: 'appstrings_setting');

  /// 首页文案。
  String get home => intlMessage('首页', sid: 'appstrings_home');

  /// splashSubtitle。
  String get splashSubtitle =>
      intlMessage('基于 fate_map 架构 · 快速开发', sid: 'appstrings_splashSubtitle');

  /// themeDemoTitle。
  String get themeDemoTitle =>
      intlMessage('主题跟随示例', sid: 'appstrings_themeDemoTitle');

  /// themeDemoSubtitle。
  String get themeDemoSubtitle =>
      intlMessage('查看背景、卡片、文字随主题变化', sid: 'appstrings_themeDemoSubtitle');

  /// 主题模式。
  String get themeMode => intlMessage('主题模式', sid: 'appstrings_themeMode');

  /// followSystem。
  String get followSystem =>
      intlMessage('跟随系统', sid: 'appstrings_followSystem');

  /// light。
  String get light => intlMessage('亮色', sid: 'appstrings_light');

  /// dark。
  String get dark => intlMessage('暗色', sid: 'appstrings_dark');

  /// back。
  String get back => intlMessage('返回', sid: 'appstrings_back');

  /// templateDesc。
  String get templateDesc =>
      intlMessage('模板说明', sid: 'appstrings_templateDesc');

  /// bullet状态。
  String get bulletState => intlMessage(
    '• 自研 state_scope + DI 状态管理框架 + riverpod 轻量级状态管理',
    sid: 'appstrings_bulletState',
  );

  /// bulletFluro。
  String get bulletFluro =>
      intlMessage('• fluro 路由 + 注解生成', sid: 'appstrings_bulletFluro');

  /// bullet主题。
  String get bulletTheme =>
      intlMessage('• 主题切换（亮/暗/跟随系统）', sid: 'appstrings_bulletTheme');

  /// bulletNetwork。
  String get bulletNetwork => intlMessage(
    '• 网络层 dio + net_retrofit_dio',
    sid: 'appstrings_bulletNetwork',
  );

  /// bulletBase。
  String get bulletBase =>
      intlMessage('• BaseStatePage 页面基类', sid: 'appstrings_bulletBase');

  /// bulletFeature。
  String get bulletFeature =>
      intlMessage('• 按 feature 模块划分', sid: 'appstrings_bulletFeature');

  /// settings页面。
  String get settingsPage => intlMessage('设置页', sid: 'appstrings_settingsPage');

  /// current主题。
  String get currentTheme =>
      intlMessage('当前主题', sid: 'appstrings_currentTheme');

  /// themeDemoHint。
  String get themeDemoHint => intlMessage(
    '本页所有色块、边框、文字均通过 context.themeColor 获取，会随亮/暗主题自动变化。',
    sid: 'appstrings_themeDemoHint',
  );

  /// goToSettings主题。
  String get goToSettingsTheme =>
      intlMessage('去设置里切换主题', sid: 'appstrings_goToSettingsTheme');

  /// tapToSwitch主题。
  String get tapToSwitchTheme =>
      intlMessage('点击切换主题（亮 → 暗 → 跟随系统）', sid: 'appstrings_tapToSwitchTheme');

  /// 语言文案。
  String get language => intlMessage('语言', sid: 'appstrings_language');

  /// langZhHansCN。
  String get langZhHansCN =>
      intlMessage('简体中文', sid: 'appstrings_langZhHansCN');

  /// langEnUS。
  String get langEnUS => intlMessage('美式英语', sid: 'appstrings_langEnUS');

  /// langEnGB。
  String get langEnGB => intlMessage('英式英语', sid: 'appstrings_langEnGB');

  /// langEnIN。
  String get langEnIN => intlMessage('印度英语', sid: 'appstrings_langEnIN');

  /// langZhTW。
  String get langZhTW => intlMessage('繁體中文（台灣）', sid: 'appstrings_langZhTW');

  /// langZhHK。
  String get langZhHK => intlMessage('繁體中文（香港）', sid: 'appstrings_langZhHK');

  /// langJa。
  String get langJa => intlMessage('日本語', sid: 'appstrings_langJa');

  /// langKo。
  String get langKo => intlMessage('한국어', sid: 'appstrings_langKo');

  /// 当前语言文案。
  String get currentLanguage =>
      intlMessage('当前语言', sid: 'appstrings_currentLanguage');
}
