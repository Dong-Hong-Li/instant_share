import 'strings_mixin.dart';

class AppStrings with MixinStrings {
  String get appTitle => intlMessage('Flutter 模板', sid: 'appstrings_appTitle');

  String get welcome => intlMessage('欢迎使用', sid: 'appstrings_welcome');

  String get setting => intlMessage('设置', sid: 'appstrings_setting');

  String get home => intlMessage('首页', sid: 'appstrings_home');

  String get splashSubtitle => intlMessage('基于 fate_map 架构 · 快速开发', sid: 'appstrings_splashSubtitle');

  String get themeDemoTitle => intlMessage('主题跟随示例', sid: 'appstrings_themeDemoTitle');

  String get themeDemoSubtitle => intlMessage('查看背景、卡片、文字随主题变化', sid: 'appstrings_themeDemoSubtitle');

  String get themeMode => intlMessage('主题模式', sid: 'appstrings_themeMode');

  String get followSystem => intlMessage('跟随系统', sid: 'appstrings_followSystem');

  String get light => intlMessage('亮色', sid: 'appstrings_light');

  String get dark => intlMessage('暗色', sid: 'appstrings_dark');

  String get back => intlMessage('返回', sid: 'appstrings_back');

  String get templateDesc => intlMessage('模板说明', sid: 'appstrings_templateDesc');

  String get bulletState => intlMessage('• 自研 state_scope + DI 状态管理框架 + riverpod 轻量级状态管理', sid: 'appstrings_bulletState');

  String get bulletFluro => intlMessage('• fluro 路由 + 注解生成', sid: 'appstrings_bulletFluro');

  String get bulletTheme => intlMessage('• 主题切换（亮/暗/跟随系统）', sid: 'appstrings_bulletTheme');

  String get bulletNetwork => intlMessage('• 网络层 dio + net_retrofit_dio', sid: 'appstrings_bulletNetwork');

  String get bulletBase => intlMessage('• BaseStatePage 页面基类', sid: 'appstrings_bulletBase');

  String get bulletFeature => intlMessage('• 按 feature 模块划分', sid: 'appstrings_bulletFeature');

  String get settingsPage => intlMessage('设置页', sid: 'appstrings_settingsPage');

  String get currentTheme => intlMessage('当前主题', sid: 'appstrings_currentTheme');

  String get themeDemoHint => intlMessage('本页所有色块、边框、文字均通过 context.themeColor 获取，会随亮/暗主题自动变化。', sid: 'appstrings_themeDemoHint');

  String get goToSettingsTheme => intlMessage('去设置里切换主题', sid: 'appstrings_goToSettingsTheme');

  String get tapToSwitchTheme => intlMessage('点击切换主题（亮 → 暗 → 跟随系统）', sid: 'appstrings_tapToSwitchTheme');

  String get language => intlMessage('语言', sid: 'appstrings_language');

  String get langZhHansCN => intlMessage('简体中文', sid: 'appstrings_langZhHansCN');

  String get langEnUS => intlMessage('美式英语', sid: 'appstrings_langEnUS');

  String get langEnGB => intlMessage('英式英语', sid: 'appstrings_langEnGB');

  String get langEnIN => intlMessage('印度英语', sid: 'appstrings_langEnIN');

  String get langZhTW => intlMessage('繁體中文（台灣）', sid: 'appstrings_langZhTW');

  String get langZhHK => intlMessage('繁體中文（香港）', sid: 'appstrings_langZhHK');

  String get langJa => intlMessage('日本語', sid: 'appstrings_langJa');

  String get langKo => intlMessage('한국어', sid: 'appstrings_langKo');

  String get currentLanguage => intlMessage('当前语言', sid: 'appstrings_currentLanguage');
}
